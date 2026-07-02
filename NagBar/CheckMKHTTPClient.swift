//
//  CheckMKHTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 03.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class CheckMKHTTPClient : MonitoringProcessorBase, HTTPClient {
    func get(_ url: String) async throws -> Data {
        let basicAuth = try await self.checkBasicAuth(self.monitoringInstance!.url)
        let shouldProceed: Bool

        if basicAuth {
            shouldProceed = true
        } else if self.hasSessionCookie(for: self.monitoringInstance!) {
            shouldProceed = true
        } else {
            shouldProceed = try await self.login(self.monitoringInstance!)
        }

        guard shouldProceed else {
            throw wrongCredentialsError()
        }

        return try await self.getBasicAuth(url, monitoringInstance: self.monitoringInstance!)
    }

    private func login(_ monitoringInstance: MonitoringInstance) async throws -> Bool {
        let params = ["_username": monitoringInstance.username,
            "_password": monitoringInstance.password,
            "_login": "1"]

        let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
        let body = ConnectionManager.sharedInstance.formBody(params)
        _ = try await ConnectionManager.sharedInstance.request(monitoringInstance.url + "login.py", method: "POST", headers: headers, body: body)
        return self.hasSessionCookie(for: monitoringInstance)
    }

    private func checkBasicAuth(_ url: String) async throws -> Bool {
        let response = try await ConnectionManager.sharedInstance.request(url, method: "HEAD")
        return response.response.statusCode == 401
    }

    func getBasicAuth(_ url: String, monitoringInstance: MonitoringInstance) async throws -> Data {
        let response = try await ConnectionManager.sharedInstance.request(url, username: monitoringInstance.username, password: monitoringInstance.password)

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }

    func checkConnection() async -> Bool {
        do {
            let response = try await ConnectionManager.sharedInstance.request(self.monitoringInstance!.url, method: "HEAD", username: self.monitoringInstance!.username, password: self.monitoringInstance!.password)
            return (200...299).contains(response.response.statusCode)
        } catch {
            return false
        }
    }

    func post(_ url: String, postData: Dictionary<String, String>) async throws -> Data {
        throw NSError(domain: "NagBar.CheckMKHTTPClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Check_MK commands are not supported"])
    }

    private func hasSessionCookie(for monitoringInstance: MonitoringInstance) -> Bool {
        guard let url = URL(string: monitoringInstance.url), let host = url.host else {
            return false
        }

        let instancePath = url.path.isEmpty ? "/" : url.path
        return (ConnectionManager.sharedInstance.cookies.cookies ?? []).contains { cookie in
            let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            let hostMatches = host == domain || host.hasSuffix("." + domain)
            let pathMatches = instancePath.hasPrefix(cookie.path)
            return hostMatches && pathMatches
        }
    }

    private func wrongCredentialsError() -> NSError {
        return NSError(domain: "", code: -999, userInfo: nil)
    }
}
