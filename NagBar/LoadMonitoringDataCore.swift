//
//  LoadMonitoringDataCore.swift
//  NagBar
//
//  Created by NagBar maintainers.
//

import Foundation

typealias FailedMonitoringInstances = Dictionary<MonitoringInstance, FailReason>

class LoadMonitoringDataCore {

    var dataRefreshActions: Array<DataRefreshAction> = []
    private let loadStatusBar: (Array<MonitoringItem>, FailedMonitoringInstances) -> Void

    let errorCodes: Dictionary<Int, FailReason> = [-999: .wrongCredentials, -1202: .ssl]

    init(loadStatusBar: @escaping (Array<MonitoringItem>, FailedMonitoringInstances) -> Void) {
        self.loadStatusBar = loadStatusBar
    }

    func refreshStatusData(completion: ((Array<MonitoringItem>, FailedMonitoringInstances) -> Void)? = nil) {
        Task {
            let (allResults, failedMonitoringInstances) = await self.loadMonitoringData()
            await MainActor.run {
                if let oldStatusData = OldStatusData.sharedInstance.statusData {
                    for dataRefreshAction in self.dataRefreshActions {
                        dataRefreshAction.process(oldStatusData, newResults: allResults)
                    }
                }

                OldStatusData.sharedInstance.statusData = allResults
                NagBarDiagnostics.logRefreshFinished(itemCount: allResults.count, failedCount: failedMonitoringInstances.count)
                self.loadStatusBar(allResults, failedMonitoringInstances)
                completion?(allResults, failedMonitoringInstances)
            }
        }
    }

    private func loadMonitoringData() async -> (Array<MonitoringItem>, FailedMonitoringInstances) {
        // load the actions that will be performed after all results
        // are fetched
        initDataRefreshAction()

        // get all enabled monitoring instances
        let monitoringInstances = MonitoringInstances().getAllEnabled()

        // store the results from all monitoring instances here
        var allResults: Array<MonitoringItem> = []

        // keep track of the failed instances
        var failedMonitoringInstances: FailedMonitoringInstances = [:]

        // loop over all monitoring instances
        for (_, monitoringInstance) in monitoringInstances {

            // store the results only for the current monitoring instance
            var monitoringInstanceResults: Array<MonitoringItem> = []

            // A monitoring instance usually has more than one URL which we have to
            // check. E.g. URL for hosts, for services, for hosts in downtime and etc.
            // Each of the URLs has a priority so that we call them in a specific order
            let urls = monitoringInstance.monitoringProcessor().urlProvider().create().sorted(by: { $0.priority < $1.priority })

            for url in urls {
                do {
                    let data = try await monitoringInstance.monitoringProcessor().httpClient().get(url.url)
                    let urlResults = monitoringInstance.monitoringProcessor().parser().parse(urlType: url.urlType, data: data)
                    monitoringInstanceResults = self.processMonitoringData(urlResults, allItems: monitoringInstanceResults, urlType: url.urlType)
                } catch {
                    let reason = self.errorCodes[(error as NSError).code] ?? .unknown
                    failedMonitoringInstances[monitoringInstance] = reason
                    NagBarDiagnostics.logRefreshFailure(instance: monitoringInstance, reason: reason, error: error)
                    break
                }
            }

            allResults += monitoringInstanceResults
        }

        return (allResults, failedMonitoringInstances)
    }

    private func initDataRefreshAction() {
        if Settings().boolForKey("useNotifications") {
            self.dataRefreshActions.append(NotificationDisplay())
        }

        if Settings().boolForKey("enableAudibleAlarms") {
            self.dataRefreshActions.append(PlaySoundAlarm())
        }
    }

    private func processMonitoringData(_ currentItems: Array<MonitoringItem>, allItems: Array<MonitoringItem>, urlType: MonitoringURLType) -> Array<MonitoringItem> {
        let additionProcessor = AdditionProcessor()
        let filterItemsProcessor = FilterItemsProcessor()

        additionProcessor.setNextProcessor(filterItemsProcessor)

        if Settings().boolForKey("skipServicesOfHostsWithScD") {
            let scheduledDowntimeProcessor = FilterScheduledDowntimeProcessor()
            filterItemsProcessor.setNextProcessor(scheduledDowntimeProcessor)
            additionProcessor.process(ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType))
            return scheduledDowntimeProcessor.get()
        } else {
            additionProcessor.process(ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType))
            return filterItemsProcessor.get()
        }
    }
}

class OldStatusData {
    static let sharedInstance = OldStatusData()

    var statusData: Array<MonitoringItem>?
}
