//
//  CheckMKParser.swift
//  NagBar
//
//  Created by Volen Davidov on 16.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class CheckMKParser : MonitoringProcessorBase, ParserInterface {
    
    func parse(urlType: MonitoringURLType, data: Data) -> Array<MonitoringItem> {
        
        switch urlType {
        case .hosts:
            return self.getHostMonitoringItems(data)
        case .services:
            return self.getServiceMonitoringItems(data)
        case .hostScheduledDowntime:
            return self.getHostMonitoringItems(data)
        }
    }
    
    private func getHostMonitoringItems(_ data: Data) -> Array<HostMonitoringItem> {
        
        var results: Array<HostMonitoringItem> = []
        
        guard let jsonResults = self.getJSON(data) else {
            return results
        }
        
        for jsonHost in jsonResults {
            let monitoringItem = HostMonitoringItem()
            
            monitoringItem.monitoringInstance = self.monitoringInstance
            monitoringItem.host = jsonHost[0].string ?? ""
            monitoringItem.status = self.statusMap(jsonHost[5].string ?? "")
            monitoringItem.lastCheck = jsonHost[2].string ?? ""
            monitoringItem.duration = jsonHost[3].string ?? ""
            monitoringItem.statusInformation = jsonHost[6].string ?? ""
            
            let itemUrlHostPart = self.monitoringInstance!.url + "/view.py?host=" + monitoringItem.host
            
            monitoringItem.itemUrl = itemUrlHostPart + "&site=" + self.sitePart() + "&view_name=host"
            
            results.append(monitoringItem)
        }
        
        results = self.postProcessHosts(results)
        
        return results
    }
    
    private func getServiceMonitoringItems(_ data: Data) -> Array<ServiceMonitoringItem> {
        var results: Array<ServiceMonitoringItem> = []
        
        guard let jsonResults = self.getJSON(data) else {
            return results
        }
        
        for jsonHost in jsonResults {
            let monitoringItem = ServiceMonitoringItem()
            
            monitoringItem.monitoringInstance = self.monitoringInstance
            monitoringItem.host = jsonHost[0].string ?? ""
            monitoringItem.service = jsonHost[1].string ?? ""
            monitoringItem.attempt = jsonHost[6].string ?? ""
            monitoringItem.status = self.statusMap(jsonHost[3].string ?? "")
            monitoringItem.lastCheck = jsonHost[4].string ?? ""
            monitoringItem.duration = jsonHost[5].string ?? ""
            monitoringItem.statusInformation = jsonHost[7].string ?? ""
            
            let itelUrlHostPart = self.monitoringInstance!.url + "/view.py?host=" + monitoringItem.host
            
            let itemUrlServicePart = itelUrlHostPart + "&service=" + monitoringItem.service + "&site=" + self.sitePart() + "&view_name=service"
            
            monitoringItem.itemUrl = itemUrlServicePart
            
            results.append(monitoringItem)
        }
        
        results = self.postProcessServices(results)
        
        return results
    }
    
    func getJSON(_ data: Data) -> [JSONValue]? {
        guard let json = try? JSONValue(data: data) else {
            NSLog("Invalid JSON")
            return nil
        }
        
        guard var jsonResults = json.array else {
            return nil
        }
        
        guard !jsonResults.isEmpty else {
            return []
        }

        // the first value is description of the columns
        jsonResults.removeFirst()
        
        return jsonResults
    }
    
    func postProcessHosts(_ results: Array<HostMonitoringItem>) -> Array<HostMonitoringItem> {
        return results
    }
    
    func postProcessServices(_ results: Array<ServiceMonitoringItem>) -> Array<ServiceMonitoringItem> {
        return results
    }
    
    private func statusMap(_ status: String) -> String {
        switch status {
        case "WARN":
            return "WARNING"
        case "CRIT":
            return "CRITICAL"
        case "UNKN":
            return "UNKNOWN"
        case "PEND":
            return "PENDING"
        case "UNREACH":
            return "UNREACHABLE"
        case "OK":
            return "OK"
        case "DOWN":
            return "DOWN"
        case "UP":
            return "UP"
        default:
            return "N/A"
        }
    }

    private func sitePart() -> String {
        guard let url = self.monitoringInstance?.url,
              let components = URLComponents(string: url) else {
            return ""
        }

        let pathSegments = components.path.split(separator: "/").map(String.init)
        guard let checkMKIndex = pathSegments.firstIndex(of: "check_mk"),
              checkMKIndex > pathSegments.startIndex else {
            return ""
        }

        return pathSegments[pathSegments.index(before: checkMKIndex)]
    }
}
