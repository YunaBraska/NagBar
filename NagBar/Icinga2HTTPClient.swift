//
//  Icinga2HTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 06.08.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import Foundation

class Icinga2HTTPClient : NagiosHTTPClient {

    override func post(_ url: String, postData: Dictionary<String, String>) -> Promise<Data> {
        
        return Promise{ seal in

            let body: Data
            do {
                body = try ConnectionManager.sharedInstance.jsonBody(postData)
            } catch {
                seal.reject(error)
                return
            }

            let headers = [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]

            ConnectionManager.sharedInstance.request(url, method: "POST", headers: headers, body: body, username: self.monitoringInstance!.username, password: self.monitoringInstance!.password) { result in
                switch result {
                case .success(let response):
                    // if the response is 401, then we have basic auth
                    // otherwise we have cookie auth enabled
                    if response.response.statusCode == 401 {
                        seal.reject(NSError(domain: "", code: -999, userInfo: nil))
                    } else {
                        seal.fulfill(response.data)
                    }
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}
