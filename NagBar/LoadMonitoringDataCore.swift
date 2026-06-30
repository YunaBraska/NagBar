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

        // load the actions that will be performed after all results
        // are fetched
        initDataRefreshAction()

        // get all enabled monitoring instances
        let monitoringInstances = MonitoringInstances().getAllEnabled()

        var promise: Promise<Void> = Promise<Void>.value(Void())

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

                promise = promise
                    .then { _ -> Promise<Data> in
                        return monitoringInstance.monitoringProcessor().httpClient().get(url.url)
                    }
                    .done { data -> Void in
                        // parse the data into Array<HostMonitoringItem>
                        let urlResults = monitoringInstance.monitoringProcessor().parser().parse(urlType: url.urlType, data: data as Data)

                        // process the data (add the monitoring items form the previous request,
                        // filter out some of them and etc.)
                        monitoringInstanceResults = self.processMonitoringData(urlResults, allItems: monitoringInstanceResults, urlType: url.urlType)

                    }.recover { error -> Void in
                        // if the promise was rejected (i.e. when connection to the
                        // monitoring instance could not be established), then add
                        // the monitoring instance to the failed list
                        let reason = self.errorCodes[(error as NSError).code] ?? .unknown
                        failedMonitoringInstances[monitoringInstance] = reason
                        NagBarDiagnostics.logRefreshFailure(instance: monitoringInstance, reason: reason, error: error)
                }
            }

            _ = promise.done { _ -> Void in
                // add the results from the current monitoring instance to the
                // results with all monitoring instances
                allResults += monitoringInstanceResults

            }
        }

        // after all data is parsed and filtered, update the status bar
        _ = promise.done { _ -> Void in
            DispatchQueue.main.async {

                // before the update, do some other tasks (e.g. visual notifications and sound alarms based on the difference
                // of the old and new monitoring data)
                // NOTE: The status bar takes care by itself for its animation; check the StatusBar class
                if let oldStatusData = OldStatusData.sharedInstance.statusData {
                    for dataRefreshAction in self.dataRefreshActions {
                        dataRefreshAction.process(oldStatusData, newResults: allResults)
                    }
                }

                // after we used the old data, overwrite it with the new data that will become old data
                // on the next run
                OldStatusData.sharedInstance.statusData = allResults
                NagBarDiagnostics.logRefreshFinished(itemCount: allResults.count, failedCount: failedMonitoringInstances.count)

                // finally update the status bar
                self.loadStatusBar(allResults, failedMonitoringInstances)
                completion?(allResults, failedMonitoringInstances)
            }
        }
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
