//
//  Icinga2Commands.swift
//  NagBar
//
//  Created by Volen Davidov on 23.07.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import Foundation

class Icinga2Commands : MonitoringProcessorBase, CommandInterface {
    
    func capabilities() -> Array<CommandTypes> {
        return [CommandTypes.acknowledge, CommandTypes.openInBrowser, CommandTypes.scheduleDowntime, CommandTypes.recheck]
    }
    
    func acknowledge(_ monitoringItems: Array<MonitoringItem>, comment: String) -> Promise<CommandResult> {
        
        var promise: Promise<Data> = Promise<Data>.value(Data())
        
        for monitoringItem in monitoringItems {
            promise = promise.then { _ -> Promise<Data> in
                
                let parameters: Dictionary<String, String> = [
                    "author": self.monitoringInstance!.username,
                    "comment": comment
                ]

                let httpClient = self.monitoringInstance!.monitoringProcessor().httpClient()
                return httpClient.post(self.monitoringInstance!.url + "/actions/acknowledge-problem?" + self.hostServiceQueryParam(monitoringItem), postData: parameters)
            }
        }
        
        return promise.then { _ -> Promise<CommandResult> in
            return Promise<CommandResult>.value(CommandResult(action: .acknowledge, itemCount: monitoringItems.count))
        }
    }

    func scheduleDowntime(_ monitoringItems: Array<MonitoringItem>, from: String, to: String, comment: String, type: String, hours: String, minutes: String) -> Promise<CommandResult> {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm:ss"
        let fromDate = dateFormatter.date(from: from)
        let toDate = dateFormatter.date(from: to)
        
        var promise: Promise<Data> = Promise<Data>.value(Data())

        for monitoringItem in monitoringItems {
            promise = promise.then { _ -> Promise<Data> in
                
                var parameters: Dictionary<String, String> = [
                    "author": self.monitoringInstance!.username,
                    "comment": comment,
                    "start_time": String(fromDate!.timeIntervalSince1970),
                    "end_time": String(toDate!.timeIntervalSince1970),
                    "fixed": type
                ]
                
                if type == "0" {
                    let hoursInt = Int(hours)!
                    let minutesInt = Int(minutes)!
                    parameters["duration"] = String((hoursInt * 60 * 60) + (minutesInt * 60))
                }
                
                
                let httpClient = self.monitoringInstance!.monitoringProcessor().httpClient()
                return httpClient.post(self.monitoringInstance!.url + "/actions/schedule-downtime?" + self.hostServiceQueryParam(monitoringItem), postData: parameters)
            }
        }
        
        return promise.then { _ -> Promise<CommandResult> in
            return Promise<CommandResult>.value(CommandResult(action: .scheduleDowntime, itemCount: monitoringItems.count))
        }
    }

    func recheck(_ monitoringItems: Array<MonitoringItem>) -> Promise<CommandResult> {
        
        var promise: Promise<Data> = Promise<Data>.value(Data())
        
        for monitoringItem in monitoringItems {
            promise = promise.then { _ -> Promise<Data> in
                
                let parameters: Dictionary<String, String> = [
                    "force_check": "true"
                ]
                
                let httpClient = self.monitoringInstance!.monitoringProcessor().httpClient()
                return httpClient.post(self.monitoringInstance!.url + "/actions/reschedule-check?" + self.hostServiceQueryParam(monitoringItem), postData: parameters)
            }
        }
        
        return promise.then { _ -> Promise<CommandResult> in
            return Promise<CommandResult>.value(CommandResult(action: .recheck, itemCount: monitoringItems.count))
        }
    }
    
    private func hostServiceQueryParam(_ monitoringItem: MonitoringItem) -> String {
        
        var queryParams = ""
        
        if monitoringItem.monitoringItemType == .service {
            queryParams += "service=" + self.queryValue(monitoringItem.host + "!" + monitoringItem.service)
        } else if monitoringItem.monitoringItemType == .host {
            queryParams += "host=" + self.queryValue(monitoringItem.host)
        }
        
        return queryParams
    }

    private func queryValue(_ value: String) -> String {
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&+=?/")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
    }
    
    func getTime(_ monitoringItems: Array<MonitoringItem>) -> Promise<(String,String)> {
        
        return Promise{ seal in
            
            let timeUrl = self.monitoringInstance!.url + "/status"
            
            let promise: Promise<Data> = Promise<Data>.value(Data())
            
            promise.then { _ -> Promise<Data> in
                // get the start time from nagios first
                return self.monitoringInstance!.monitoringProcessor().httpClient().get(timeUrl)
                }.done { data -> Void in
                    // parse the start time
                    
                    guard let jsonResults = Icinga2Parser(self.monitoringInstance!).getJSON(data as NSData) else {
                        seal.reject(NSError(domain: "NagBar.Icinga2Commands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"]))
                        return
                    }
                    
                    var uptime: Double?
                    var programStart: Double?
                    
                    for jsonObj in jsonResults {
                        if let uptimeFound = jsonObj["status"]["uptime"].double {
                            uptime = uptimeFound
                        }
                        
                        if let programStartFound = jsonObj["status"]["icingaapplication"]["app"]["program_start"].double {
                            programStart = programStartFound
                        }
                    }

                    let startTimestamp = Date(timeIntervalSince1970: uptime! + programStart!)
                    let endTimestamp = Date(timeIntervalSince1970: uptime! + programStart! + 3600)
                    
                    let dayTimePeriodFormatter = DateFormatter()
                    dayTimePeriodFormatter.dateFormat = "dd.MM.YYYY, HH:mm:ss"
                    
                    let startTime = dayTimePeriodFormatter.string(from: startTimestamp)
                    let endTime = dayTimePeriodFormatter.string(from: endTimestamp)
                    
                    seal.fulfill((startTime, endTime))
                }.catch { error in
                    seal.reject(error)
            }
        }
    }
}
