//
//  NagiosHTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 02.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class NagiosHTTPClient : MonitoringProcessorBase, HTTPClient {

    func get(_ url: String) async throws -> Data {
        let response = try await ConnectionManager.sharedInstance.request(
            url,
            username: self.monitoringInstance!.username,
            password: self.monitoringInstance!.password,
            validateStatus: true
        )

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }

    func checkConnection() async -> Bool {
        do {
            let response = try await ConnectionManager.sharedInstance.request(
                self.monitoringInstance!.url,
                method: "HEAD",
                username: self.monitoringInstance!.username,
                password: self.monitoringInstance!.password,
                validateStatus: true
            )
            return response.response.statusCode != 401
        } catch {
            return false
        }
    }

    func post(_ url: String, postData: Dictionary<String, String>) async throws -> Data {
        let body = ConnectionManager.sharedInstance.formBody(postData)
        let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
        let response = try await ConnectionManager.sharedInstance.request(
            url,
            method: "POST",
            headers: headers,
            body: body,
            username: self.monitoringInstance!.username,
            password: self.monitoringInstance!.password,
            validateStatus: true
        )

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }

    func wrongCredentialsError() -> NSError {
        return NSError(domain: "", code: -999, userInfo: nil)
    }
}
