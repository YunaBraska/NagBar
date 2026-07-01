//
//  MenuAction.swift
//  NagBar
//
//  Created by Volen Davidov on 24.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

@objc protocol MenuAction {
    func action(_ sender: NSMenuItem)
}

class RecheckAction: NSObject, MenuAction {
    func action(_ sender: NSMenuItem) {
        guard let monitoringItems = sender.representedObject as? Array<MonitoringItem>,
              let monitoringInstance = monitoringItems.first?.monitoringInstance else {
            return
        }

        let promise = monitoringInstance.monitoringProcessor().command().recheck(monitoringItems)
        CommandFeedback.shared.observe(.recheck, promise: promise)
    }
}

class ScheduleDowntimeAction: NSObject, MenuAction {
    
    private var downtimeWindow: ScheduleDowntimeWindow?
    
    func action(_ sender: NSMenuItem) {
        guard let monitoringItems = sender.representedObject as? Array<MonitoringItem>,
              !monitoringItems.isEmpty else {
            return
        }

        if self.downtimeWindow == nil {
            self.downtimeWindow = ScheduleDowntimeWindow(windowNibName: "ScheduleDowntimeWindow")
        }
        
        self.downtimeWindow?.monitoringItems = monitoringItems
        
        self.downtimeWindow?.showWindow(self)
    }
}

class AcknowledgeAction: NSObject, MenuAction {
    
    private var downtimeWindow: AcknowledgeWindow?
    
    func action(_ sender: NSMenuItem) {
        guard let monitoringItems = sender.representedObject as? Array<MonitoringItem>,
              !monitoringItems.isEmpty else {
            return
        }
        
        if self.downtimeWindow == nil {
            self.downtimeWindow = AcknowledgeWindow(windowNibName: "AcknowledgeWindow")
        }
        
        self.downtimeWindow?.monitoringItems = monitoringItems
        
        self.downtimeWindow?.showWindow(self)
    }
}

class AddToFilterAction : NSObject, MenuAction {
    var confirmAddToFilter: () -> Bool = {
        let alert = NSAlert()
        alert.addButton(withTitle: NSLocalizedString("no", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("yes", comment: ""))
        alert.messageText = NSLocalizedString("addToFilter", comment: "")
        alert.informativeText = NSLocalizedString("addToFilterConfirm", comment: "")
        alert.alertStyle = .warning
        return alert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn
    }

    func action(_ sender: NSMenuItem) {
        if self.confirmAddToFilter() {
            guard let monitoringItems = sender.representedObject as? Array<MonitoringItem>,
                  !monitoringItems.isEmpty else {
                return
            }
            self.addToFilter(monitoringItems)
        }
    }
    
    func addToFilter(_ monitoringItems: Array<MonitoringItem>) {
        
        let filterItemServiceStatus = ["CRITICAL": 16, "UNKNOWN": 8, "WARNING": 4, "PENDING" : 1]
        let filterItemHostStatus = ["UNREACHABLE": 8, "DOWN": 4, "PENDING" : 1]
        
        for monitoringItem in monitoringItems {
            guard let statusCode = self.filterStatusCode(for: monitoringItem, serviceStatuses: filterItemServiceStatus, hostStatuses: filterItemHostStatus) else {
                NSLog("Unsupported filter status \(monitoringItem.status) for \(monitoringItem.host) \(monitoringItem.service)")
                continue
            }
            
            let key = FilterItems.generateKey(monitoringItem.host, service: monitoringItem.service)
            
            // this is the case where the monitoring item already has a filter, but it is
            // for a different status
            if let filterItem = FilterItems().getByKey(key) {
                // There is no need to use bitwise operations, as if the value already exists, it won't be displayed in the table view at first place. But bitwise is the proper way to do it.
                FilterItems().updateStatus(filterItem: filterItem, status: filterItem.status | statusCode)
                
            } else {
                let filterItem = FilterItem().initDefault(host: monitoringItem.host, service: monitoringItem.service, status: statusCode)
                
                FilterItems().insert(key: key, value: filterItem)
            }
        }
    }

    private func filterStatusCode(for monitoringItem: MonitoringItem, serviceStatuses: [String: Int], hostStatuses: [String: Int]) -> Int? {
        if monitoringItem.monitoringItemType == .service {
            return serviceStatuses[monitoringItem.status]
        }

        return hostStatuses[monitoringItem.status]
    }
}
