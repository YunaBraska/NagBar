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

    func getTime(_ monitoringItems: Array<MonitoringItem>) async throws -> (String, String) {
        throw self.unsupportedError()
    }

    func recheck(_ monitoringItems: Array<MonitoringItem>) async throws -> CommandResult {
        throw self.unsupportedError()
    }

    func scheduleDowntime(_ monitoringItems: Array<MonitoringItem>, from: String, to: String, comment: String, type: String, hours: String, minutes: String) async throws -> CommandResult {
        throw self.unsupportedError()
    }

    func acknowledge(_ monitoringItems: Array<MonitoringItem>, comment: String) async throws -> CommandResult {
        throw self.unsupportedError()
    }

    private func unsupportedError() -> NSError {
        return NSError(domain: "NagBar.UnsupportedCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Commands are not supported for this monitoring backend"])
    }
}
