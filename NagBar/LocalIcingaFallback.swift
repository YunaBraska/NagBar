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
    static let instanceName = "icinga"
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
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=gmx-pop">gmx-pop</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:03:00</td><td>133d 3h 59m 3s</td><td>1/10</td><td>CRITICAL - TCP socket timeout after 10 seconds</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=gmx-www">gmx-www</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:05:00</td><td>79d 0h 3m 56s</td><td>1/10</td><td>CRITICAL - HTTP request timed out</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=google-www">google-www</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:06:00</td><td>61d 10h 25m 3s</td><td>1/10</td><td>CRITICAL - packet loss above threshold</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-de-pop">web-de-pop</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:07:00</td><td>5d 16h 7m 52s</td><td>1/10</td><td>CRITICAL - POP3 login failed</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-de-www">web-de-www</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:08:00</td><td>0d 0h 27m 52s</td><td>4/10</td><td>HTTP CRITICAL: HTTP/1.1 503 Service Unavailable</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=yahoo-www">yahoo-www</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>30-06-2026 12:08:30</td><td>3d 0h 1m 24s</td><td>4/10</td><td>CRITICAL - DNS lookup returned no records</td>
          </tr>
        </table></div></form></body></html>
        """.utf8)
    }

    private func serviceStatusPage() -> Data {
        return Data("""
        <html><body><form id="tableformservice"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-de-smtp">web-de-smtp</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-de-smtp&amp;service=SMTP">SMTP</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:00:00</td><td>35d 6h 48m 25s</td><td>4/4</td><td>Connection refused</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=secure.nagios.com">secure.nagios.com</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=secure.nagios.com&amp;service=Web%20Page%20Content">Web Page Content</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:01:00</td><td>0d 0h 49m 14s</td><td>5/5</td><td>HTTP CRITICAL: HTTP/1.1 200 OK - string not found</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=secure.nagios.com">secure.nagios.com</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=secure.nagios.com&amp;service=SSL%20Certificate">SSL Certificate</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:01:30</td><td>0d 0h 28m 50s</td><td>5/5</td><td>CRITICAL - Certificate 'secure.nagios.com' expired</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=www.twitter.com">www.twitter.com</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=www.twitter.com&amp;service=DNS%20IP%20Match">DNS IP Match</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:01:45</td><td>0d 0h 1m 41s</td><td>5/5</td><td>DNS CRITICAL - expected '199.59.148.10,199.59.149.230'</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=NOAA">NOAA</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=NOAA&amp;service=Weather%20Strafford%20New%20Hampshire">Weather Strafford New Hampshire</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>WARNING</td><td>30-06-2026 12:02:00</td><td>158d 23h 11m 37s</td><td>3/3</td><td>Weather Warning: Flood Watch, Winter Weather Advisory</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=localhost">localhost</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=localhost&amp;service=XI%20Software%20Updates">XI Software Updates</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>30-06-2026 12:02:30</td><td>0d 0h 2m 15s</td><td>3/3</td><td>XI Updates CRITICAL: New XI version available</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=www.twitter.com">www.twitter.com</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=www.twitter.com&amp;service=HTTP">HTTP</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
            <td>UNKNOWN</td><td>30-06-2026 12:04:00</td><td>210d 2h 11m 52s</td><td>5/5</td><td>check_smtp: Invalid onredirect option -- usage output follows</td>
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
