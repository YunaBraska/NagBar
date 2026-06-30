//
//  UnsupportedCommands.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation

class UnsupportedCommands: MonitoringProcessorBase, CommandInterface {
    func capabilities() -> Array<CommandTypes> {
        return [CommandTypes.openInBrowser]
    }

    func getTime(_ monitoringItems: Array<MonitoringItem>) -> Promise<(String, String)> {
        return Promise { seal in
            seal.reject(self.unsupportedError())
        }
    }

    func recheck(_ monitoringItems: Array<MonitoringItem>) -> Promise<CommandResult> {
        return Promise { seal in
            seal.reject(self.unsupportedError())
        }
    }

    func scheduleDowntime(_ monitoringItems: Array<MonitoringItem>, from: String, to: String, comment: String, type: String, hours: String, minutes: String) -> Promise<CommandResult> {
        return Promise { seal in
            seal.reject(self.unsupportedError())
        }
    }

    func acknowledge(_ monitoringItems: Array<MonitoringItem>, comment: String) -> Promise<CommandResult> {
        return Promise { seal in
            seal.reject(self.unsupportedError())
        }
    }

    private func unsupportedError() -> NSError {
        return NSError(domain: "NagBar.UnsupportedCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Commands are not supported for this monitoring backend"])
    }
}
