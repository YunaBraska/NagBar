//
//  LocalIcingaFallback.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation
import Network

enum LocalIcingaFallback {
    static let instanceName = "Local Icinga Fallback"
    static let username = "local-fallback"
    static let password = "local-fallback"

    static func instance() -> MonitoringInstance {
        return MonitoringInstance().initDefault(
            name: instanceName,
            url: LocalIcingaFakeServer.shared.baseURL,
            type: .Icinga,
            username: username,
            password: password,
            enabled: 1
        )
    }
}

final class LocalIcingaFakeServer {
    static let shared = LocalIcingaFakeServer()
    static let host = "127.0.0.1"

    private let queue = DispatchQueue(label: "LocalIcingaFakeServer")
    private let lock = NSLock()
    private var listener: NWListener?
    private var serverPort: UInt16 = 0

    var baseURL: String {
        if !startIfNeeded() {
            return "http://\(Self.host):9/icinga/cgi-bin/"
        }
        return "http://\(Self.host):\(serverPort)/icinga/cgi-bin/"
    }

    private init() {}

    @discardableResult
    private func startIfNeeded() -> Bool {
        lock.lock()
        if listener != nil {
            let isReady = serverPort != 0
            lock.unlock()
            return isReady
        }

        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address(Self.host)!), port: .any)
            let newListener = try NWListener(using: parameters, on: .any)
            let ready = DispatchSemaphore(value: 0)
            var readyPort: UInt16 = 0

            newListener.stateUpdateHandler = { state in
                if case .ready = state, let port = newListener.port {
                    readyPort = port.rawValue
                    ready.signal()
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener = newListener
            newListener.start(queue: queue)
            lock.unlock()

            let readyResult = ready.wait(timeout: .now() + 5)

            lock.lock()
            if readyResult == .timedOut || readyPort == 0 {
                newListener.cancel()
                listener = nil
                lock.unlock()
                NagBarDiagnostics.logLocalServerEvent(message: "localIcingaServerStartTimedOut")
                return false
            }

            serverPort = readyPort
            lock.unlock()
            NagBarDiagnostics.logLocalServerStarted(baseURL: "http://\(Self.host):\(readyPort)/icinga/cgi-bin/")
            return true
        } catch {
            NagBarDiagnostics.logLocalServerStartFailed(error)
            lock.unlock()
            return false
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, data: Data())
    }

    private func receive(on connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] chunk, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }

            var received = data
            if let chunk = chunk {
                received.append(chunk)
            }

            if self.isCompleteRequest(received) || isComplete || error != nil {
                self.respond(on: connection, requestData: received)
            } else {
                self.receive(on: connection, data: received)
            }
        }
    }

    private func respond(on connection: NWConnection, requestData: Data) {
        let requestText = String(decoding: requestData, as: UTF8.self)
        let lines = requestText.components(separatedBy: "\r\n")
        let requestLine = lines.first ?? ""
        let requestParts = requestLine.split(separator: " ")
        let method = requestParts.first.map(String.init) ?? ""
        let target = requestParts.count > 1 ? String(requestParts[1]) : "/"
        let authorization = header(named: "Authorization", in: lines)
        let parsed = parse(target)

        let response: Data
        if authorization != expectedAuthorization {
            response = httpResponse(status: "401 Unauthorized", headers: ["WWW-Authenticate": "Basic realm=\"Icinga\""], body: Data())
        } else if method == "HEAD" {
            response = httpResponse(status: "200 OK", headers: [:], body: Data())
        } else if parsed.path.hasSuffix("/cmd.cgi") && method == "GET" {
            response = httpResponse(status: "200 OK", headers: [:], body: commandTimePage())
        } else if parsed.path.hasSuffix("/cmd.cgi") && method == "POST" {
            response = httpResponse(status: "200 OK", headers: [:], body: Data("OK".utf8))
        } else if parsed.path.hasSuffix("/status.cgi") && parsed.query.contains("hostgroup=all") {
            response = httpResponse(status: "200 OK", headers: [:], body: hostStatusPage())
        } else if parsed.path.hasSuffix("/status.cgi") && parsed.query.contains("service=all") {
            response = httpResponse(status: "200 OK", headers: [:], body: serviceStatusPage())
        } else {
            response = httpResponse(status: "404 Not Found", headers: [:], body: Data())
        }

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private var expectedAuthorization: String {
        return "Basic " + Data("\(LocalIcingaFallback.username):\(LocalIcingaFallback.password)".utf8).base64EncodedString()
    }

    private func isCompleteRequest(_ data: Data) -> Bool {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return false
        }

        let headerData = data[..<headerRange.lowerBound]
        let headerText = String(decoding: headerData, as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        let contentLength = header(named: "Content-Length", in: lines).flatMap(Int.init) ?? 0
        let bodyStart = headerRange.upperBound
        return data.count - bodyStart >= contentLength
    }

    private func parse(_ target: String) -> (path: String, query: String) {
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = parts.first.map(String.init) ?? "/"
        let query = parts.count > 1 ? String(parts[1]) : ""
        return (path, query)
    }

    private func header(named name: String, in lines: [String]) -> String? {
        let prefix = name.lowercased() + ":"
        return lines.first { $0.lowercased().hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
    }

    private func httpResponse(status: String, headers: [String: String], body: Data) -> Data {
        var responseHeaders = headers
        responseHeaders["Content-Length"] = String(body.count)
        if responseHeaders["Content-Type"] == nil {
            responseHeaders["Content-Type"] = "text/html; charset=utf-8"
        }
        responseHeaders["Connection"] = "close"

        var text = "HTTP/1.1 \(status)\r\n"
        for (key, value) in responseHeaders {
            text += "\(key): \(value)\r\n"
        }
        text += "\r\n"

        var response = Data(text.utf8)
        response.append(body)
        return response
    }

    private func hostStatusPage() -> Data {
        return Data("""
        <html><body><form id="tableformhost"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:00:00</td><td>0d 1h 14m 0s</td><td>3/3</td><td>CRITICAL - Host unreachable (10.0.0.11)</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=db-01">db-01</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>PENDING</td><td>30-06-2026 12:05:00</td><td>0d 0h 10m 0s</td><td>1/3</td><td>Service checks are waiting for the first host check result</td>
          </tr>
        </table></div></form></body></html>
        """.utf8)
    }

    private func serviceStatusPage() -> Data {
        return Data("""
        <html><body><form id="tableformservice"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=HTTP">HTTP</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:01:00</td><td>0d 0h 44m 0s</td><td>3/3</td><td>HTTP CRITICAL: HTTP/1.1 503 Service Unavailable</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=db-01">db-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=db-01&amp;service=Disk%20%2Fvar">Disk /var</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>WARNING</td><td>30-06-2026 12:02:00</td><td>0d 2h 3m 0s</td><td>1/3</td><td>DISK WARNING: /var is 87% full</td>
          </tr>
        </table></div></form></body></html>
        """.utf8)
    }

    private func commandTimePage() -> Data {
        return Data("""
        <html>
          <body>
            <input name="start_time" value="30-06-2026 12:00:00">
            <input name="end_time" value="30-06-2026 13:00:00">
          </body>
        </html>
        """.utf8)
    }
}
