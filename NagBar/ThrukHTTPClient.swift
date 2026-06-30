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
    
    func get(_ url: String) -> Promise<Data> {
        
        return Promise{ seal in
           
            let headers = self.headers()

            ConnectionManager.sharedInstance.request(url, method: "GET", headers: headers) { result in
                switch result {
                case .success(let response):
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
    
    func checkConnection() -> Promise<Bool> {
        
        return Promise{ seal in
            
            let headers = self.headers()
            
            ConnectionManager.sharedInstance.request(self.monitoringInstance!.url, method: "GET", headers: headers) { result in
                switch result {
                case .success(let response):
                    if response.response.statusCode == 401 {
                        seal.fulfill(false)
                    } else {
                        seal.fulfill(true)
                    }
                case .failure:
                    seal.fulfill(false)
                }
            }
        }
    }
    
    func post(_ url: String, postData: Dictionary<String, String>) -> Promise<Data> {
        
        return Promise{ seal in
            
            var headers = self.headers()
            headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
            let body = ConnectionManager.sharedInstance.formBody(postData)
            
            ConnectionManager.sharedInstance.request(url, method: "POST", headers: headers, body: body) { result in
                switch result {
                case .success(let response):
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

    private func headers() -> [String: String] {
        return [
            "Authorization": ConnectionManager.sharedInstance.authorizationHeader(username: self.monitoringInstance!.username, password: self.monitoringInstance!.password),
            "User-agent": "curl"
        ]
    }
}
