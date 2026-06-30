//
//  PasswordPromptFlow.swift
//  NagBar
//
//  Created by NagBar maintainers.
//

import Foundation

struct PasswordPromptFlow {
    static func next(currentName: String?, enabledInstances: Dictionary<String, MonitoringInstance>) -> MonitoringInstance? {
        let names = Array(enabledInstances.keys.sorted())

        guard let currentName = currentName else {
            return names.first.flatMap { enabledInstances[$0] }
        }

        guard let currentIndex = names.firstIndex(of: currentName) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < names.count else {
            return nil
        }

        return enabledInstances[names[nextIndex]]
    }

    static func promptMessage(for instance: MonitoringInstance) -> String {
        return String(format: NSLocalizedString("pleaseEnterPassword", comment: ""), instance.name)
    }

    static func emptyPromptMessage() -> String {
        return NSLocalizedString("noMonitoringInstancesRequirePassword", comment: "")
    }

    static func errorText(forCode code: Int) -> String {
        switch code {
        case -999:
            return NSLocalizedString("incorrectPassword", comment: "")
        case -1001:
            return NSLocalizedString("connectionTimedOut", comment: "")
        case -1004:
            return NSLocalizedString("couldNotConnect", comment: "")
        default:
            return NSLocalizedString("unknownError", comment: "")
        }
    }
}
