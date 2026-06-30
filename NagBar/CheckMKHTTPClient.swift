//
//  CheckMKHTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 03.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class CheckMKHTTPClient : MonitoringProcessorBase, HTTPClient {
    func get(_ url: String) -> Promise<Data> {
        
        return Promise{ seal in
            
            let promise: Promise<Void> = Promise<Void>.value(Void())
            
            promise
                .then { _ -> Promise<Bool> in
                    // check if Check_MK is set to use basic auth or cookie auth
                    return self.checkBasicAuth(self.monitoringInstance!.url)
                }
                .then { basicAuth -> Promise<Bool> in
                    // if Check_MK is not using basic auth, then we have to log in
                    if !basicAuth {
                        if !self.hasSessionCookie(for: self.monitoringInstance!) {
                            // try to log in and return the result of the login
                            return self.login(self.monitoringInstance!)
                        } else {
                            return Promise<Bool>.value(true)
                        }
                    } else {
                        return Promise<Bool>.value(true)
                    }
                }
                .then { shouldProceed -> Promise<Data> in
                    // if the login was successfull, proceeed;
                    // otherwise reject the Promise with error for wrong password
                    if shouldProceed {
                        return self.getBasicAuth(url, monitoringInstance: self.monitoringInstance!)
                    } else {
                        return Promise<Data>.value(Data())
                    }
                }
                .done { data -> Void in
                    if data == Data() {
                        seal.reject(NSError(domain: "", code: -999, userInfo: nil))
                    } else {
                        seal.fulfill(data)
                    }
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }
    
    private func login(_ monitoringInstance: MonitoringInstance) -> Promise<Bool> {
        return Promise{ seal in
            
            let params = ["_username": monitoringInstance.username,
                "_password": monitoringInstance.password,
                "_login": "1"]

            let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
            let body = ConnectionManager.sharedInstance.formBody(params)

            ConnectionManager.sharedInstance.request(monitoringInstance.url + "login.py", method: "POST", headers: headers, body: body) { result in
                if case .failure(let error) = result {
                    seal.reject(error)
                    return
                }
                
                if self.hasSessionCookie(for: monitoringInstance) {
                    seal.fulfill(true)
                } else {
                    seal.fulfill(false)
                }
            }

        }
    }
    
    private func checkBasicAuth(_ url: String) -> Promise<Bool> {
        
        return Promise{ seal in
            
            ConnectionManager.sharedInstance.request(url, method: "HEAD") { result in
                switch result {
                case .success(let response):
                
                    // if the response is 401, then we have basic auth
                    // otherwise we have cookie auth enabled
                    if response.response.statusCode == 401 {
                        seal.fulfill(true)
                    } else {
                        seal.fulfill(false)
                    }
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
    
    func getBasicAuth(_ url: String, monitoringInstance: MonitoringInstance) -> Promise<Data> {
        
        return Promise{ seal in
            
            ConnectionManager.sharedInstance.request(url, username: monitoringInstance.username, password: monitoringInstance.password) { result in
                switch result {
                case .success(let response):
                // if the response is 401, then we have basic auth
                // otherwise we have cookie auth enabled
                    if response.response.statusCode == 401 {
                        seal.fulfill(Data())
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
            
            ConnectionManager.sharedInstance.request(self.monitoringInstance!.url, method: "HEAD", username: self.monitoringInstance!.username, password: self.monitoringInstance!.password) { result in
                switch result {
                case .success(let response):
                    seal.fulfill((200...299).contains(response.response.statusCode))
                case .failure:
                    seal.fulfill(false)
                }
            }
        }
    }
    
    func post(_ url: String, postData: Dictionary<String, String>) -> Promise<Data> {
        return Promise { seal in
            seal.reject(NSError(domain: "NagBar.CheckMKHTTPClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Check_MK commands are not supported"]))
        }
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
}
