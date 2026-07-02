//
//  NagiosCommands.swift
//  NagBar
//
//  Created by Volen Davidov on 30.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class NagiosCommands : MonitoringProcessorBase, CommandInterface {
    
    func capabilities() -> Array<CommandTypes> {
        return [CommandTypes.acknowledge, CommandTypes.openInBrowser, CommandTypes.recheck, CommandTypes.scheduleDowntime]
    }
    
    func getTime(_ monitoringItems: Array<MonitoringItem>) async throws -> (String,String) {
        let nagiosTimeUrl = NagiosParser.stripStatusCGI(self.monitoringInstance!.url) + String(format: "cmd.cgi?cmd_typ=55&host=%@", monitoringItems[0].host)
        let data = try await self.monitoringInstance!.monitoringProcessor().httpClient().get(nagiosTimeUrl)
        let parser = NagiosParser(self.monitoringInstance!)
        return (parser.parseStartTime(data), parser.parseEndTime(data))
    }

    func recheck(_ monitoringItems: Array<MonitoringItem>) async throws -> CommandResult {
        let nagiosTimeUrl = NagiosParser.stripStatusCGI(self.monitoringInstance!.url) + String(format: "cmd.cgi?cmd_typ=55&host=%@", monitoringItems[0].host)
        let startData = try await self.monitoringInstance!.monitoringProcessor().httpClient().get(nagiosTimeUrl)
        let startTime = NagiosParser(self.monitoringInstance!).parseStartTime(startData)

        for monitoringItem in monitoringItems {
            var parameters: Dictionary<String, String> = [
                "cmd_typ": "96",
                "cmd_mod": "2",
                "start_time": startTime,
                "host": monitoringItem.host,
                "force_check": "on",
                "btnSubmit": "Commit"
            ]

            if monitoringItem.monitoringItemType == .service {
                parameters["cmd_typ"] = "7"
                parameters["service"] = monitoringItem.service
            }

            _ = try await self.monitoringInstance!.monitoringProcessor().httpClient().post(
                NagiosParser.stripStatusCGI(self.monitoringInstance!.url) + "cmd.cgi",
                postData: parameters
            )
        }

        return CommandResult(action: .recheck, itemCount: monitoringItems.count)
    }

    func scheduleDowntime(_ monitoringItems: Array<MonitoringItem>, from: String, to: String, comment: String, type: String, hours: String, minutes: String) async throws -> CommandResult {
        for monitoringItem in monitoringItems {
            var parameters: Dictionary<String, String> = [
                "cmd_typ": "55",
                "cmd_mod": "2",
                "start_time": from,
                "end_time": to,
                "host": monitoringItem.host,
                "com_data": comment,
                "fixed": type,
                "hours": hours,
                "minutes": minutes,
                "btnSubmit": "Commit"
            ]

            if monitoringItem.monitoringItemType == .service {
                parameters["cmd_typ"] = "56"
                parameters["service"] = monitoringItem.service
            }

            _ = try await self.monitoringInstance!.monitoringProcessor().httpClient().post(
                NagiosParser.stripStatusCGI(self.monitoringInstance!.url) + "cmd.cgi",
                postData: parameters
            )
        }

        return CommandResult(action: .scheduleDowntime, itemCount: monitoringItems.count)
    }

    func acknowledge(_ monitoringItems: Array<MonitoringItem>, comment: String) async throws -> CommandResult {
        for monitoringItem in monitoringItems {
            var parameters: Dictionary<String, String> = [
                "cmd_typ": "33",
                "cmd_mod": "2",
                "host": monitoringItem.host,
                "com_data": comment,
                "btnSubmit": "Commit"
            ]

            if monitoringItem.monitoringItemType == .service {
                parameters["cmd_typ"] = "34"
                parameters["service"] = monitoringItem.service
            }

            _ = try await self.monitoringInstance!.monitoringProcessor().httpClient().post(
                NagiosParser.stripStatusCGI(self.monitoringInstance!.url) + "cmd.cgi",
                postData: parameters
            )
        }

        return CommandResult(action: .acknowledge, itemCount: monitoringItems.count)
    }
}
