//
//  StatusBarAnimationTrigger.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation

enum StatusBarAnimationTrigger {
    case recovery
    case alarm
    case none

    static func evaluate(oldResults: Array<MonitoringItem>?, newResults: Array<MonitoringItem>?) -> StatusBarAnimationTrigger {
        guard let newResults = newResults else {
            return .none
        }

        guard let oldResults = oldResults else {
            return .none
        }

        if oldResults.count < newResults.count {
            return .alarm
        }

        if oldResults.count > newResults.count {
            return .recovery
        }

        if oldResults.count == newResults.count {
            for (index, _) in oldResults.enumerated() {
                let currentMonitoringItem = oldResults[index]
                let oldMonitoringItem = newResults[index]

                if currentMonitoringItem.uniqueIdentifier() != oldMonitoringItem.uniqueIdentifier() {
                    return .alarm
                }
            }
        }

        return .none
    }
}
