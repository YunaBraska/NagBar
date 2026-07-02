//
//  Icinga2HTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 06.08.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import Foundation

class Icinga2HTTPClient : NagiosHTTPClient {

    override func post(_ url: String, postData: Dictionary<String, String>) async throws -> Data {
        let body = try ConnectionManager.sharedInstance.jsonBody(postData)
        let headers = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]

        let response = try await ConnectionManager.sharedInstance.request(
            url,
            method: "POST",
            headers: headers,
            body: body,
            username: self.monitoringInstance!.username,
            password: self.monitoringInstance!.password
        )

        if response.response.statusCode == 401 {
            throw wrongCredentialsError()
        }

        return response.data
    }
}
