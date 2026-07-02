//
//  ThrukHTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 28.09.19.
//  Copyright © 2019 Volen Davidov. All rights reserved.
//

//  Thruk uses cookie authentication by default. We can force
//  basic auth as well but we have to send the Authorization header
//  before receiving a challenge.
//  Also, we have to fake the user agent as curl for this to work.

import Foundation

class ThrukHTTPClient : MonitoringProcessorBase, HTTPClient {

    func get(_ url: String) async throws -> Data {
        let response = try await ConnectionManager.sharedInstance.request(url, method: "GET", headers: self.headers())

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }

    func checkConnection() async -> Bool {
        do {
            let response = try await ConnectionManager.sharedInstance.request(self.monitoringInstance!.url, method: "GET", headers: self.headers())
            return response.response.statusCode != 401
        } catch {
            return false
        }
    }

    func post(_ url: String, postData: Dictionary<String, String>) async throws -> Data {
        var headers = self.headers()
        headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
        let body = ConnectionManager.sharedInstance.formBody(postData)
        let response = try await ConnectionManager.sharedInstance.request(url, method: "POST", headers: headers, body: body)

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }

    private func headers() -> [String: String] {
        return [
            "Authorization": ConnectionManager.sharedInstance.authorizationHeader(username: self.monitoringInstance!.username, password: self.monitoringInstance!.password),
            "User-agent": "curl"
        ]
    }

    private func wrongCredentialsError() -> NSError {
        return NSError(domain: "", code: -999, userInfo: nil)
    }
}
