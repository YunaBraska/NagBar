//
//  ConnectionManager.swift
//  NagBar
//
//  Created by Volen Davidov on 26.08.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import Foundation

struct HTTPResponse {
    let data: Data
    let response: HTTPURLResponse
}

/**
 * Custom connection manager that allows us to ignore invalid SSL certificates
 */
class ConnectionManager: NSObject, URLSessionDelegate {

    static let sharedInstance = ConnectionManager()

    let cookies = HTTPCookieStorage.shared

    private let sessionLock = NSLock()
    private var session: URLSession!
    private var invalidCertificateHosts: Set<String> = []

    override init() {
        super.init()
        self.setSession()
    }

    func update() {
        self.setSession()
    }

    func request(_ url: String, method: String = "GET", headers: [String: String] = [:], body: Data? = nil, username: String? = nil, password: String? = nil, validateStatus: Bool = false, completion: @escaping (Result<HTTPResponse, Error>) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil)))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        self.perform(request, username: username, password: password, validateStatus: validateStatus, didRetryAuthentication: false, completion: completion)
    }

    func formBody(_ parameters: Dictionary<String, String>) -> Data {
        let body = parameters.keys.sorted().map { key -> String in
            return "\(self.urlEncode(key))=\(self.urlEncode(parameters[key] ?? ""))"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    func jsonBody(_ parameters: Dictionary<String, String>) throws -> Data {
        return try JSONSerialization.data(withJSONObject: parameters, options: [])
    }

    func authorizationHeader(username: String, password: String) -> String {
        return "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let invalidCertificateHosts = self.withSessionLock { self.invalidCertificateHosts }
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust,
           invalidCertificateHosts.contains(challenge.protectionSpace.host) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func perform(_ request: URLRequest, username: String?, password: String?, validateStatus: Bool, didRetryAuthentication: Bool, completion: @escaping (Result<HTTPResponse, Error>) -> Void) {
        let session = self.withSessionLock { self.session! }
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil)))
                return
            }

            if httpResponse.statusCode == 401,
               !didRetryAuthentication,
               let username = username,
               let password = password {
                var authenticatedRequest = request
                authenticatedRequest.setValue(self.authorizationHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
                self.perform(authenticatedRequest, username: username, password: password, validateStatus: validateStatus, didRetryAuthentication: true, completion: completion)
                return
            }

            if validateStatus && !(200...299).contains(httpResponse.statusCode) {
                let code = httpResponse.statusCode == 401 ? -999 : httpResponse.statusCode
                completion(.failure(NSError(domain: "NagBar.HTTPStatus", code: code, userInfo: nil)))
                return
            }

            completion(.success(HTTPResponse(data: data ?? Data(), response: httpResponse)))
        }
        task.resume()
    }

    private func setSession() {
        let invalidCertificateHosts = self.invalidCertificateHostsFromSettings()
        let newSession = URLSession(configuration: self.defaultConfiguration(), delegate: self, delegateQueue: nil)
        let oldSession: URLSession? = self.withSessionLock {
            let oldSession = self.session
            self.invalidCertificateHosts = invalidCertificateHosts
            self.session = newSession
            return oldSession
        }
        oldSession?.finishTasksAndInvalidate()
    }

    private func invalidCertificateHostsFromSettings() -> Set<String> {
        guard Settings().boolForKey("acceptInvalidCertificates") else {
            return []
        }

        var hosts = Set<String>()
        let monitoringInstances = MonitoringInstances().getAll()

        for (_, value) in monitoringInstances {
            guard let url = URL(string: value.url) else {
                NSLog("Invalid URL: " + value.url)
                continue
            }
            guard let host = url.host else {
                NSLog("Invalid URL: " + value.url)
                continue
            }
            hosts.insert(host)
        }

        return hosts
    }

    private func urlEncode(_ string: String) -> String {
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&+=?")
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
    }

    private func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default

        configuration.httpCookieStorage = cookies
        configuration.httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy.always
        configuration.httpShouldSetCookies = true
        configuration.httpAdditionalHeaders = [
            "Accept-Language": Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
                let quality = 1.0 - (Double(index) * 0.1)
                return "\(languageCode);q=\(String(format: "%.1f", quality))"
            }.joined(separator: ", "),
            "User-Agent": "NagBar"
        ]

        return configuration
    }

    private func withSessionLock<T>(_ action: () -> T) -> T {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return action()
    }
}
