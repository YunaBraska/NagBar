//
//  NagiosHTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 02.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class NagiosHTTPClient : MonitoringProcessorBase, HTTPClient {
    
    func get(_ url: String) -> Promise<Data> {
        
        return Promise{ seal in
            
            ConnectionManager.sharedInstance.request(url, username: self.monitoringInstance!.username, password: self.monitoringInstance!.password, validateStatus: true) { result in
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
    
    func checkConnection() -> Promise<Bool> {
        
        return Promise{ seal in
            
            ConnectionManager.sharedInstance.request(self.monitoringInstance!.url, method: "HEAD", username: self.monitoringInstance!.username, password: self.monitoringInstance!.password, validateStatus: true) { result in
                switch result {
                case .success(let response):
                    // if the response is 401, then we have basic auth
                    // otherwise we have cookie auth enabled
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
            
            let body = ConnectionManager.sharedInstance.formBody(postData)
            let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]

            ConnectionManager.sharedInstance.request(url, method: "POST", headers: headers, body: body, username: self.monitoringInstance!.username, password: self.monitoringInstance!.password, validateStatus: true) { result in
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
