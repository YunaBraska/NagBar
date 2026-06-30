//
//  FakeIcingaServer.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation
import Network

final class FakeIcingaServer {
    struct Request {
        let method: String
        let path: String
        let query: String
        let authorization: String?
        let contentType: String?
        let userAgent: String?
        let body: String
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "FakeIcingaServer")
    private let lock = NSLock()
    private var receivedRequests: [Request] = []
    private let hostStatus: Data
    private let serviceStatus: Data
    private let icinga2Status: Data
    private let expectedAuthorization: String
    private var stopped = false

    private(set) var port: UInt16 = 0

    init(hostStatus: Data, serviceStatus: Data, username: String, password: String, icinga2Status: Data = FakeIcingaServer.defaultIcinga2Status()) throws {
        self.hostStatus = hostStatus
        self.serviceStatus = serviceStatus
        self.icinga2Status = icinga2Status
        self.expectedAuthorization = "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        self.listener = try NWListener(using: .tcp, on: .any)

        let ready = DispatchSemaphore(value: 0)
        var readyPort: UInt16 = 0

        listener.stateUpdateHandler = { state in
            if case .ready = state, let port = self.listener.port {
                readyPort = port.rawValue
                ready.signal()
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 5)
        self.port = readyPort
    }

    deinit {
        stop()
    }

    func stop() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        lock.unlock()
        listener.cancel()
    }

    func requests() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        return receivedRequests
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
        let contentType = header(named: "Content-Type", in: lines)
        let userAgent = header(named: "User-Agent", in: lines)
        let body = requestText.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n")
        let parsed = parse(target)
        let request = Request(method: method, path: parsed.path, query: parsed.query, authorization: authorization, contentType: contentType, userAgent: userAgent, body: body)

        lock.lock()
        receivedRequests.append(request)
        lock.unlock()

        let response: Data
        if authorization != expectedAuthorization {
            response = httpResponse(status: "401 Unauthorized", headers: ["WWW-Authenticate": "Basic realm=\"Icinga\""], body: Data())
        } else if parsed.path.hasSuffix("/status") && method == "GET" {
            response = httpResponse(status: "200 OK", headers: ["Content-Type": "application/json"], body: icinga2Status)
        } else if parsed.path.hasSuffix("/cmd.cgi") && method == "GET" {
            response = httpResponse(status: "200 OK", headers: [:], body: commandTimePage())
        } else if parsed.path.hasSuffix("/cmd.cgi") && method == "POST" {
            response = httpResponse(status: "200 OK", headers: [:], body: Data("OK".utf8))
        } else if parsed.path.contains("/actions/") && method == "POST" {
            response = httpResponse(status: "200 OK", headers: ["Content-Type": "application/json"], body: Data("{\"results\":[]}".utf8))
        } else if parsed.path.hasSuffix("/status.cgi") && parsed.query.contains("hostgroup=all") {
            response = httpResponse(status: "200 OK", headers: [:], body: hostStatus)
        } else if parsed.path.hasSuffix("/status.cgi") && parsed.query.contains("service=all") {
            response = httpResponse(status: "200 OK", headers: [:], body: serviceStatus)
        } else {
            response = httpResponse(status: "404 Not Found", headers: [:], body: Data())
        }

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
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

    static func defaultIcinga2Status(programStart: Double = 1_782_800_000, uptime: Double = 3_600) -> Data {
        return Data("""
        {"results":[{"status":{"uptime":\(uptime),"icingaapplication":{"app":{"program_start":\(programStart)}}}}]}
        """.utf8)
    }
}
