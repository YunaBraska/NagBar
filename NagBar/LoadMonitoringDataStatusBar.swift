//
//  LoadMonitoringDataStatusBar.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation

extension LoadMonitoringData {
    convenience init() {
        self.init(loadStatusBar: { results, failedMonitoringInstances in
            StatusBar.get().load(results, failedMonitoringInstances: failedMonitoringInstances)
        })
    }
}
