//
//  LoadMonitoringData.swift
//  NagBar
//
//  Created by Volen Davidov on 06.03.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class LoadMonitoringData {
    private let core: LoadMonitoringDataCore

    var dataRefreshActions: Array<DataRefreshAction> {
        get {
            return core.dataRefreshActions
        }
        set {
            core.dataRefreshActions = newValue
        }
    }

    init(loadStatusBar: @escaping (Array<MonitoringItem>, FailedMonitoringInstances) -> Void = { results, failedMonitoringInstances in
        StatusBar.get().load(results, failedMonitoringInstances: failedMonitoringInstances)
    }) {
        self.core = LoadMonitoringDataCore(loadStatusBar: loadStatusBar)
    }

    /**
     * Refresh the status bar and panel
     */
    func refreshStatusData(completion: ((Array<MonitoringItem>, FailedMonitoringInstances) -> Void)? = nil) {
        core.refreshStatusData(completion: completion)
    }
}
