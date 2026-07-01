//
//  DataProcessorTests.swift
//  NagBar
//
//  Created by Volen Davidov on 17.04.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import XCTest
import Cocoa
@testable import NagBar

class AdditionProcessorTests: XCTestCase {
    
    func testProcess() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        let hostMonitoringItem1 = HostMonitoringItem()
        hostMonitoringItem1.monitoringInstance = monitoringInstance
        hostMonitoringItem1.host = "host1"
        hostMonitoringItem1.status = "DOWN"
        hostMonitoringItem1.duration = "351d 0h 15m 23s"
        hostMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        hostMonitoringItem1.statusInformation = "PING CRITICAL - Packet loss = 100% "
        hostMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let hostMonitoringItem2 = HostMonitoringItem()
        hostMonitoringItem2.monitoringInstance = monitoringInstance
        hostMonitoringItem2.host = "host2"
        hostMonitoringItem2.status = "UP"
        hostMonitoringItem2.duration = "351d 0h 15m 23s"
        hostMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        hostMonitoringItem2.statusInformation = "PING CRITICAL - Packet loss = 100% "
        hostMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let currentItems: Array<HostMonitoringItem> = [hostMonitoringItem2]
        let allItems: Array<HostMonitoringItem> = [hostMonitoringItem1]
        let urlType: MonitoringURLType = .hosts
        
        let processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        
        let additionProcessor = AdditionProcessor()
        additionProcessor.process(processorRequest)
        let results = additionProcessor.get()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === hostMonitoringItem1)
        XCTAssertTrue(results[1] === hostMonitoringItem2)
    }

    func testProcessWithEmptyCurrentItemsPreservesExistingItems() {
        let existing = host("web-01", status: "DOWN")
        let processorRequest = ProcessorRequest(currentItems: [], allItems: [existing], urlType: .hosts)

        let additionProcessor = AdditionProcessor()
        additionProcessor.process(processorRequest)
        let results = additionProcessor.get()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === existing)
    }

    func testProcessWithEmptyAllItemsReturnsCurrentItems() {
        let current = host("web-01", status: "DOWN")
        let processorRequest = ProcessorRequest(currentItems: [current], allItems: [], urlType: .hosts)

        let additionProcessor = AdditionProcessor()
        additionProcessor.process(processorRequest)
        let results = additionProcessor.get()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === current)
    }

    func testProcessDoesNotDeduplicateRepeatedItems() {
        let existing = host("web-01", status: "DOWN")
        let processorRequest = ProcessorRequest(currentItems: [existing], allItems: [existing], urlType: .hosts)

        let additionProcessor = AdditionProcessor()
        additionProcessor.process(processorRequest)
        let results = additionProcessor.get()

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === existing)
        XCTAssertTrue(results[1] === existing)
    }

    func testProcessForwardsMergedRequestToNextProcessor() {
        let existing = host("web-01", status: "DOWN")
        let current = host("db-01", status: "UNREACHABLE")
        let capture = CapturingProcessor()
        let additionProcessor = AdditionProcessor()
        additionProcessor.setNextProcessor(capture)

        additionProcessor.process(ProcessorRequest(currentItems: [current], allItems: [existing], urlType: .hosts))

        XCTAssertEqual(capture.receivedRequests.count, 1)
        XCTAssertTrue(capture.receivedRequests[0].currentItems[0] === current)
        XCTAssertTrue(capture.receivedRequests[0].allItems[0] === existing)
        XCTAssertTrue(capture.receivedRequests[0].allItems[1] === current)
        XCTAssertEqual(capture.receivedRequests[0].urlType, .hosts)
    }

    private func host(_ name: String, status: String) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        return item
    }
}

private class CapturingProcessor: Processor {
    var receivedRequests: Array<ProcessorRequest> = []

    override func process(_ processorRequest: ProcessorRequest) {
        receivedRequests.append(processorRequest)
        super.process(processorRequest)
    }
}

class MonitoringItemSorterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
    }

    override func tearDown() {
        Settings().resetKnownSettings()
        super.tearDown()
    }

    func testSortHostsByHostNameAscendingUsesStoredSettings() {
        Settings().setInteger(1, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortHosts([
            host("web-20", status: "DOWN"),
            host("api-01", status: "UP"),
            host("db-01", status: "UNREACHABLE")
        ])

        XCTAssertEqual(results.map { $0.host }, ["api-01", "db-01", "web-20"])
    }

    func testSortServicesByServiceNameDescendingUsesStoredSettings() {
        Settings().setInteger(2, forKey: "sortColumn")
        Settings().setInteger(2, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortServices([
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING"),
            service("web-01", service: "CPU", status: "OK")
        ])

        XCTAssertEqual(results.map { $0.service }, ["HTTP", "Disk", "CPU"])
    }

    func testSortHostsByLastCheckAscendingPlacesOldestFirst() {
        Settings().setInteger(4, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortHosts([
            host("newer", status: "DOWN", lastCheck: "30-06-2026 15:00:00"),
            host("older", status: "DOWN", lastCheck: "30-06-2026 14:00:00")
        ])

        XCTAssertEqual(results.map { $0.host }, ["older", "newer"])
    }

    func testSortHostsByDurationDescendingPlacesLongestFirst() {
        Settings().setInteger(6, forKey: "sortColumn")
        Settings().setInteger(2, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortHosts([
            host("minutes", status: "DOWN", duration: "32m 54s"),
            host("days", status: "DOWN", duration: "1d 2h 3m 4s"),
            host("hours", status: "DOWN", duration: "3h 12m 43s")
        ])

        XCTAssertEqual(results.map { $0.host }, ["days", "hours", "minutes"])
    }

    func testSortHostsByStatusAscendingUsesExplicitCurrentContract() {
        Settings().setInteger(3, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortHosts([
            host("host-warning", status: "WARNING"),
            host("host-critical", status: "CRITICAL"),
            host("host-up", status: "UP"),
            host("host-down", status: "DOWN")
        ])

        XCTAssertEqual(results.map { $0.status }, ["CRITICAL", "DOWN", "UP", "WARNING"])
    }

    func testSortServicesByStatusDescendingUsesExplicitCurrentContract() {
        Settings().setInteger(3, forKey: "sortColumn")
        Settings().setInteger(2, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortServices([
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING"),
            service("web-01", service: "CPU", status: "OK"),
            service("web-01", service: "Deploy", status: "PENDING")
        ])

        XCTAssertEqual(results.map { $0.status }, ["WARNING", "PENDING", "OK", "CRITICAL"])
    }

    func testSortServicesByAttemptAscendingUsesStoredSettings() {
        Settings().setInteger(5, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let first = service("web-01", service: "HTTP", status: "CRITICAL")
        first.attempt = "3/5"
        let second = service("web-01", service: "Disk", status: "WARNING")
        second.attempt = "1/5"
        let third = service("web-01", service: "CPU", status: "OK")
        third.attempt = "2/5"

        let results = MonitoringItemSorter().sortServices([first, second, third])

        XCTAssertEqual(results.map { $0.attempt }, ["1/5", "2/5", "3/5"])
    }

    func testSortServicesByDurationAscendingPlacesShortestFirst() {
        Settings().setInteger(6, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let results = MonitoringItemSorter().sortServices([
            service("web-01", service: "days", status: "CRITICAL", duration: "1d 2h 3m 4s"),
            service("web-01", service: "minutes", status: "WARNING", duration: "32m 54s"),
            service("web-01", service: "hours", status: "OK", duration: "3h 12m 43s")
        ])

        XCTAssertEqual(results.map { $0.service }, ["minutes", "hours", "days"])
    }

    func testSortHostsWithEqualDurationsPreservesInputOrder() {
        Settings().setInteger(6, forKey: "sortColumn")
        Settings().setInteger(1, forKey: "sortOrder")

        let first = host("first", status: "DOWN", duration: "3h 12m 43s")
        let second = host("second", status: "DOWN", duration: "3h 12m 43s")
        let results = MonitoringItemSorter().sortHosts([first, second])

        XCTAssertTrue(results[0] === first)
        XCTAssertTrue(results[1] === second)
    }

    func testInvalidStoredSortSettingsPreserveInputOrderInsteadOfCrashing() {
        Settings().setInteger(7, forKey: "sortColumn")
        Settings().setInteger(3, forKey: "sortOrder")

        let first = host("web-20", status: "DOWN")
        let second = host("api-01", status: "UP")
        let results = MonitoringItemSorter().sortHosts([first, second])

        XCTAssertTrue(results[0] === first)
        XCTAssertTrue(results[1] === second)
    }

    func testExtendedStatusTitleSummarizesEverySupportedStateInStableOrder() {
        let title = StatusItemTitleFormatter.title(for: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING"),
            service("web-01", service: "DNS", status: "UNKNOWN"),
            service("web-01", service: "Deploy", status: "PENDING"),
            service("web-01", service: "Ping", status: "OK"),
            host("router-01", status: "UNREACHABLE"),
            host("db-01", status: "DOWN"),
            host("api-01", status: "UP")
        ], showExtendedStatusInformation: true)

        XCTAssertEqual(title, "C:1 W:1 U:1 P:1 O:1 UR:1 D:1 UP:1")
    }

    func testExtendedStatusTitleUsesNoAlarmsForUnknownOnlyResults() {
        let title = StatusItemTitleFormatter.title(for: [
            host("unknown-backend", status: "N/A")
        ], showExtendedStatusInformation: true)

        XCTAssertEqual(title, "No Alarms")
    }

    func testCompactStatusTitleShowsTotalCount() {
        let title = StatusItemTitleFormatter.title(for: [
            host("db-01", status: "DOWN"),
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], showExtendedStatusInformation: false)

        XCTAssertEqual(title, "Total Count: 2")
    }

    private func host(_ name: String, status: String, lastCheck: String = "30-06-2026 12:00:00", duration: String = "1m") -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        item.lastCheck = lastCheck
        item.duration = duration
        return item
    }

    private func service(_ host: String, service: String, status: String, lastCheck: String = "30-06-2026 12:00:00", duration: String = "1m") -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        item.lastCheck = lastCheck
        item.duration = duration
        return item
    }
}

class FilterScheduledDowntimeProcessorTests: XCTestCase {
    func testProcess() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        let hostMonitoringItem1 = ServiceMonitoringItem()
        hostMonitoringItem1.monitoringInstance = monitoringInstance
        hostMonitoringItem1.host = "host1"
        hostMonitoringItem1.status = "UP"
        hostMonitoringItem1.duration = "351d 0h 15m 23s"
        hostMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        hostMonitoringItem1.statusInformation = "PING OK - Packet loss = 0%, RTA = 0.31 ms"
        hostMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem1 = ServiceMonitoringItem()
        serviceMonitoringItem1.monitoringInstance = monitoringInstance
        serviceMonitoringItem1.host = "host1"
        serviceMonitoringItem1.service = "test service"
        serviceMonitoringItem1.status = "CRITICAL"
        serviceMonitoringItem1.duration = "351d 0h 15m 23s"
        serviceMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem1.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem2 = ServiceMonitoringItem()
        serviceMonitoringItem2.monitoringInstance = monitoringInstance
        serviceMonitoringItem2.host = "host2"
        serviceMonitoringItem2.service = "test service2"
        serviceMonitoringItem2.status = "CRITICAL"
        serviceMonitoringItem2.duration = "351d 0h 15m 23s"
        serviceMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem2.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let currentItems: Array<MonitoringItem> = [hostMonitoringItem1]
        let allItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2]
        var urlType: MonitoringURLType = .hostScheduledDowntime
        
        var processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        
        var filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        var results = filterDowntimeProcessor.get()
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === serviceMonitoringItem2)
        
        
        urlType = .hosts
        processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        results = filterDowntimeProcessor.get()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === serviceMonitoringItem1)
        XCTAssertTrue(results[1] === serviceMonitoringItem2)
        
        
        urlType = .services
        processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        results = filterDowntimeProcessor.get()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === serviceMonitoringItem1)
        XCTAssertTrue(results[1] === serviceMonitoringItem2)
    }

    func testHostScheduledDowntimeRemovesOnlyServicesForMatchingHosts() {
        let downtimeHost = host("web-01", status: "DOWN")
        let downtimeHostService = service("web-01", service: "HTTP", status: "CRITICAL")
        let unrelatedService = service("db-01", service: "Disk", status: "WARNING")
        let processorRequest = ProcessorRequest(
            currentItems: [downtimeHost],
            allItems: [downtimeHost, downtimeHostService, unrelatedService],
            urlType: .hostScheduledDowntime
        )

        let filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        let results = filterDowntimeProcessor.get()

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === downtimeHost)
        XCTAssertTrue(results[1] === unrelatedService)
    }

    func testMultipleDowntimeHostsRemoveOnlyTheirItems() {
        let webDowntime = host("web-01", status: "DOWN")
        let dbDowntime = host("db-01", status: "DOWN")
        let webService = service("web-01", service: "HTTP", status: "CRITICAL")
        let dbService = service("db-01", service: "Disk", status: "WARNING")
        let apiService = service("api-01", service: "Queue", status: "WARNING")
        let processorRequest = ProcessorRequest(
            currentItems: [webDowntime, dbDowntime],
            allItems: [webService, dbService, apiService],
            urlType: .hostScheduledDowntime
        )

        let filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        let results = filterDowntimeProcessor.get()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === apiService)
    }

    func testNonHostScheduledDowntimeRequestPreservesItemsWithoutNextProcessor() {
        let downtimeHost = host("web-01", status: "DOWN")
        let service = service("web-01", service: "HTTP", status: "CRITICAL")
        let processorRequest = ProcessorRequest(currentItems: [downtimeHost], allItems: [service], urlType: .hosts)

        let filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.process(processorRequest)
        let results = filterDowntimeProcessor.get()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === service)
    }

    func testNonHostScheduledDowntimeRequestIsForwardedUnchangedToNextProcessor() {
        let downtimeHost = host("web-01", status: "DOWN")
        let service = service("web-01", service: "HTTP", status: "CRITICAL")
        let capture = CapturingProcessor()
        let filterDowntimeProcessor = FilterScheduledDowntimeProcessor()
        filterDowntimeProcessor.setNextProcessor(capture)

        filterDowntimeProcessor.process(ProcessorRequest(currentItems: [downtimeHost], allItems: [service], urlType: .services))

        XCTAssertEqual(capture.receivedRequests.count, 1)
        XCTAssertTrue(capture.receivedRequests[0].currentItems[0] === downtimeHost)
        XCTAssertTrue(capture.receivedRequests[0].allItems[0] === service)
        XCTAssertEqual(capture.receivedRequests[0].urlType, .services)
    }

    private func host(_ name: String, status: String) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        return item
    }

    private func service(_ host: String, service: String, status: String) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        return item
    }
}

class FilterItemsProcessorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        FilterItems.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("json")
        FilterItems().resetStorage()
    }

    override func tearDown() {
        FilterItems().resetStorage()
        FilterItems.storageURLOverride = nil
        NagBarAlert.presentAlert = { alert in
            alert.runModal()
        }
        super.tearDown()
    }

    func testFilterItemValidationRejectsEmptyHostAndService() {
        let result = FilterItem.validate(host: "", service: "")

        XCTAssertEqual(result, .empty)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.title, "Invalid filter")
        XCTAssertEqual(result.message, "Enter at least a host pattern or a service pattern.")
    }

    func testFilterItemValidationRejectsInvalidHostPattern() {
        let result = FilterItem.validate(host: "[", service: "")

        XCTAssertEqual(result, .invalidHostPattern("["))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "The host pattern is not a valid regular expression: [")
    }

    func testFilterItemValidationRejectsInvalidServicePattern() {
        let result = FilterItem.validate(host: "web-.*", service: "(")

        XCTAssertEqual(result, .invalidServicePattern("("))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "The service pattern is not a valid regular expression: (")
    }

    func testFilterItemValidationAcceptsValidServiceOnlyPattern() {
        let result = FilterItem.validate(host: "", service: "HTTP|Disk")

        XCTAssertEqual(result, .valid)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.message, "")
    }
    
    func testProcess() {
        
        let filterItem = FilterItem()
        filterItem.host = "testhost"
        filterItem.service = "testservice1"
        filterItem.status = 24
        
        FilterItems().insert(key: FilterItems.generateKey(filterItem.host, service: filterItem.service), value: filterItem)
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        
        let serviceMonitoringItem1 = ServiceMonitoringItem()
        serviceMonitoringItem1.monitoringInstance = monitoringInstance
        serviceMonitoringItem1.host = "testhost"
        serviceMonitoringItem1.service = "testservice1"
        serviceMonitoringItem1.status = "CRITICAL"
        serviceMonitoringItem1.duration = "351d 0h 15m 23s"
        serviceMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem1.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem2 = ServiceMonitoringItem()
        serviceMonitoringItem2.monitoringInstance = monitoringInstance
        serviceMonitoringItem2.host = "testhost"
        serviceMonitoringItem2.service = "testservice2"
        serviceMonitoringItem2.status = "CRITICAL"
        serviceMonitoringItem2.duration = "351d 0h 15m 23s"
        serviceMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem2.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem3 = ServiceMonitoringItem()
        serviceMonitoringItem3.monitoringInstance = monitoringInstance
        serviceMonitoringItem3.host = "testhost"
        serviceMonitoringItem3.service = "testservice1"
        serviceMonitoringItem3.status = "WARNING"
        serviceMonitoringItem3.duration = "351d 0h 15m 23s"
        serviceMonitoringItem3.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem3.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem3.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let currentItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        let urlType: MonitoringURLType = .hostScheduledDowntime
        let allItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        
        let processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        
        let filterItemsProcessor = FilterItemsProcessor()
        filterItemsProcessor.process(processorRequest)
        var results = filterItemsProcessor.get()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0] === serviceMonitoringItem2)
        XCTAssertTrue(results[1] === serviceMonitoringItem3)
        
        FilterItems().removeByKey(FilterItems.generateKey(filterItem.host, service: filterItem.service))
    }
    
    func testProcessServiceFilter() {
        
        let filterItem = FilterItem()
        filterItem.host = ".*"
        filterItem.service = "testservice1"
        filterItem.status = 29
        
        FilterItems().insert(key: FilterItems.generateKey(filterItem.host, service: filterItem.service), value: filterItem)
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        
        let serviceMonitoringItem1 = HostMonitoringItem()
        serviceMonitoringItem1.monitoringInstance = monitoringInstance
        serviceMonitoringItem1.host = "testhost1"
        serviceMonitoringItem1.status = "DOWN"
        serviceMonitoringItem1.duration = "351d 0h 15m 23s"
        serviceMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem1.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem2 = ServiceMonitoringItem()
        serviceMonitoringItem2.monitoringInstance = monitoringInstance
        serviceMonitoringItem2.host = "testhost2"
        serviceMonitoringItem2.service = "testservice1"
        serviceMonitoringItem2.status = "CRITICAL"
        serviceMonitoringItem2.duration = "351d 0h 15m 23s"
        serviceMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem2.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem3 = ServiceMonitoringItem()
        serviceMonitoringItem3.monitoringInstance = monitoringInstance
        serviceMonitoringItem3.host = "testhost2"
        serviceMonitoringItem3.service = "testservice2"
        serviceMonitoringItem3.status = "WARNING"
        serviceMonitoringItem3.duration = "351d 0h 15m 23s"
        serviceMonitoringItem3.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem3.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem3.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let currentItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        let urlType: MonitoringURLType = .hostScheduledDowntime
        let allItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        
        let processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        
        let filterItemsProcessor = FilterItemsProcessor()
        filterItemsProcessor.process(processorRequest)
        var results = filterItemsProcessor.get()
        
        XCTAssertEqual(results.count, 2)
//        XCTAssertTrue(results[0] === serviceMonitoringItem1)
//        XCTAssertTrue(results[1] === serviceMonitoringItem3)
        
        FilterItems().removeByKey(FilterItems.generateKey(filterItem.host, service: filterItem.service))
    }
    
    func testProcessHostFilter() {
        
        let filterItem = FilterItem()
        filterItem.host = "test"
        filterItem.service = ""
        filterItem.status = 13
        
        FilterItems().insert(key: FilterItems.generateKey(filterItem.host, service: filterItem.service), value: filterItem)
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        
        let serviceMonitoringItem1 = HostMonitoringItem()
        serviceMonitoringItem1.monitoringInstance = monitoringInstance
        serviceMonitoringItem1.host = "testhost1"
        serviceMonitoringItem1.status = "DOWN"
        serviceMonitoringItem1.duration = "351d 0h 15m 23s"
        serviceMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem1.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem2 = ServiceMonitoringItem()
        serviceMonitoringItem2.monitoringInstance = monitoringInstance
        serviceMonitoringItem2.host = "testhost2"
        serviceMonitoringItem2.service = "testservice1"
        serviceMonitoringItem2.status = "CRITICAL"
        serviceMonitoringItem2.duration = "351d 0h 15m 23s"
        serviceMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem2.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem3 = ServiceMonitoringItem()
        serviceMonitoringItem3.monitoringInstance = monitoringInstance
        serviceMonitoringItem3.host = "testhost2"
        serviceMonitoringItem3.service = "testservice2"
        serviceMonitoringItem3.status = "WARNING"
        serviceMonitoringItem3.duration = "351d 0h 15m 23s"
        serviceMonitoringItem3.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem3.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem3.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let currentItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        let urlType: MonitoringURLType = .hostScheduledDowntime
        let allItems: Array<MonitoringItem> = [serviceMonitoringItem1, serviceMonitoringItem2, serviceMonitoringItem3]
        
        let processorRequest = ProcessorRequest(currentItems: currentItems, allItems: allItems, urlType: urlType)
        
        let filterItemsProcessor = FilterItemsProcessor()
        filterItemsProcessor.process(processorRequest)
        var results = filterItemsProcessor.get()
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === serviceMonitoringItem2)
        
        FilterItems().removeByKey(FilterItems.generateKey(filterItem.host, service: filterItem.service))
    }

    func testFilterItemsCollectionPersistsUpdatesOrdersAndRemovesByKey() {
        let first = FilterItem().initDefault(host: "web-02", service: "Disk", status: 16)
        let second = FilterItem().initDefault(host: "web-01", service: "", status: 4)
        let filterItems = FilterItems()

        filterItems.insert(key: FilterItems.generateKey(first.host, service: first.service), value: first)
        filterItems.insert(key: FilterItems.generateKey(second.host, service: second.service), value: second)

        XCTAssertEqual(filterItems.count(), 2)
        XCTAssertEqual(filterItems.getKeys(), ["web-01", "web-02Disk"])
        XCTAssertEqual(filterItems.getById(0).host, "web-01")

        filterItems.updateStatus(filterItem: first, status: 24)

        XCTAssertEqual(FilterItems().getByKey("web-02Disk")?.status, 24)

        filterItems.removeByKey("web-02Disk")

        XCTAssertNil(FilterItems().getByKey("web-02Disk"))
        XCTAssertEqual(FilterItems().count(), 1)
    }

    func testFilterItemsMalformedStorageReturnsEmptyAndRecoversOnSave() throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
            .appendingPathExtension("filter-items.json")
        FilterItems.storageURLOverride = storageURL
        defer {
            FilterItems().resetStorage()
            FilterItems.storageURLOverride = nil
        }
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: storageURL, options: .atomic)

        XCTAssertEqual(FilterItems().count(), 0)

        let recovered = FilterItem().initDefault(host: "web-01", service: "Disk", status: 16)
        FilterItems().insert(key: FilterItems.generateKey(recovered.host, service: recovered.service), value: recovered)

        let reloaded = FilterItems().getByKey("web-01Disk")
        XCTAssertEqual(FilterItems().count(), 1)
        XCTAssertEqual(reloaded?.host, "web-01")
        XCTAssertEqual(reloaded?.service, "Disk")
        XCTAssertEqual(reloaded?.status, 16)
    }

    func testAddToFilterCreatesServiceFilterForCriticalSelection() {
        AddToFilterAction().addToFilter([service("web-01", service: "HTTP", status: "CRITICAL")])

        let saved = FilterItems().getByKey("web-01HTTP")

        XCTAssertEqual(saved?.host, "web-01")
        XCTAssertEqual(saved?.service, "HTTP")
        XCTAssertEqual(saved?.status, 16)
    }

    func testAddToFilterMergesServiceStatusIntoExistingFilter() {
        let existing = FilterItem().initDefault(host: "web-01", service: "HTTP", status: 4)
        FilterItems().insert(key: "web-01HTTP", value: existing)

        AddToFilterAction().addToFilter([service("web-01", service: "HTTP", status: "CRITICAL")])

        XCTAssertEqual(FilterItems().getByKey("web-01HTTP")?.status, 20)
    }

    func testAddToFilterCreatesHostFilterForDownSelection() {
        AddToFilterAction().addToFilter([host("router-01", status: "DOWN")])

        let saved = FilterItems().getByKey("router-01")

        XCTAssertEqual(saved?.host, "router-01")
        XCTAssertEqual(saved?.service, "")
        XCTAssertEqual(saved?.status, 4)
    }

    func testAddToFilterMergesHostStatusIntoExistingFilter() {
        let existing = FilterItem().initDefault(host: "router-01", service: "", status: 1)
        FilterItems().insert(key: "router-01", value: existing)

        AddToFilterAction().addToFilter([host("router-01", status: "UNREACHABLE")])

        XCTAssertEqual(FilterItems().getByKey("router-01")?.status, 9)
    }

    func testAddToFilterMenuActionCreatesFilterAfterConfirmation() {
        let action = AddToFilterAction()
        action.confirmAddToFilter = { true }
        let menuItem = NSMenuItem()
        menuItem.representedObject = [service("web-01", service: "HTTP", status: "CRITICAL")]

        action.action(menuItem)

        XCTAssertEqual(FilterItems().getByKey("web-01HTTP")?.status, 16)
    }

    func testAddToFilterMenuActionLeavesFiltersUnchangedWhenCancelled() {
        let action = AddToFilterAction()
        action.confirmAddToFilter = { false }
        let menuItem = NSMenuItem()
        menuItem.representedObject = [host("router-01", status: "DOWN")]

        action.action(menuItem)

        XCTAssertNil(FilterItems().getByKey("router-01"))
    }

    func testProcessIgnoresPersistedFilterWithInvalidRegex() {
        let invalidFilter = FilterItem().initDefault(host: "[", service: "", status: 4)
        FilterItems().insert(key: FilterItems.generateKey(invalidFilter.host, service: invalidFilter.service), value: invalidFilter)

        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "test", type: .Nagios, username: "test", password: "test", enabled: 1)
        let hostMonitoringItem = HostMonitoringItem()
        hostMonitoringItem.monitoringInstance = monitoringInstance
        hostMonitoringItem.host = "web-01"
        hostMonitoringItem.status = "DOWN"
        hostMonitoringItem.duration = "1m"
        hostMonitoringItem.lastCheck = "06-30-2026 15:30:00"
        hostMonitoringItem.statusInformation = "Host down"
        hostMonitoringItem.itemUrl = "http://monitoring.example/nagios/cgi-bin/extinfo.cgi?type=1&host=web-01"

        let processorRequest = ProcessorRequest(currentItems: [hostMonitoringItem], allItems: [hostMonitoringItem], urlType: .hosts)
        let filterItemsProcessor = FilterItemsProcessor()
        filterItemsProcessor.process(processorRequest)
        let results = filterItemsProcessor.get()

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0] === hostMonitoringItem)
    }

    private func host(_ name: String, status: String) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        return item
    }

    private func service(_ host: String, service: String, status: String) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        return item
    }
}

class FilterItemWindowControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FilterItems.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("json")
        FilterItems().resetStorage()
    }

    override func tearDown() {
        FilterItems().resetStorage()
        FilterItems.storageURLOverride = nil
        super.tearDown()
    }

    func testNewFilterDisablesServiceStatusButtonsUntilServicePatternIsEntered() {
        let fixture = FilterItemWindowControllerFixture()

        fixture.controller.awakeFromNib()

        XCTAssertTrue(fixture.hostDown.isEnabled)
        XCTAssertTrue(fixture.hostUnreachable.isEnabled)
        XCTAssertTrue(fixture.hostPending.isEnabled)
        XCTAssertFalse(fixture.critical.isEnabled)
        XCTAssertFalse(fixture.warning.isEnabled)
        XCTAssertFalse(fixture.unknown.isEnabled)
        XCTAssertFalse(fixture.pending.isEnabled)
    }

    func testServiceTextChangeSwitchesStatusButtonsFromHostToServiceMode() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.awakeFromNib()

        fixture.service.stringValue = "HTTP|Disk"
        fixture.controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: fixture.service))

        XCTAssertFalse(fixture.hostDown.isEnabled)
        XCTAssertFalse(fixture.hostUnreachable.isEnabled)
        XCTAssertFalse(fixture.hostPending.isEnabled)
        XCTAssertTrue(fixture.critical.isEnabled)
        XCTAssertTrue(fixture.warning.isEnabled)
        XCTAssertTrue(fixture.unknown.isEnabled)
        XCTAssertTrue(fixture.pending.isEnabled)
    }

    func testClearingServiceTextSwitchesStatusButtonsBackToHostMode() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.awakeFromNib()
        fixture.service.stringValue = "HTTP"
        fixture.controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: fixture.service))

        fixture.service.stringValue = ""
        fixture.controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: fixture.service))

        XCTAssertTrue(fixture.hostDown.isEnabled)
        XCTAssertTrue(fixture.hostUnreachable.isEnabled)
        XCTAssertTrue(fixture.hostPending.isEnabled)
        XCTAssertFalse(fixture.critical.isEnabled)
        XCTAssertFalse(fixture.warning.isEnabled)
        XCTAssertFalse(fixture.unknown.isEnabled)
        XCTAssertFalse(fixture.pending.isEnabled)
    }

    func testCancelButtonClosesWindowWithoutPersistingFilter() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.host.stringValue = "web-.*"
        fixture.service.stringValue = "HTTP"

        fixture.controller.cancelButtonClick(fixture.cancelButton)

        XCTAssertFalse(fixture.window.isVisible)
        XCTAssertEqual(FilterItems().count(), 0)
    }

    func testSavingNewServiceFilterPersistsSelectedServiceStatusesAndClosesWindow() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.host.stringValue = "web-.*"
        fixture.service.stringValue = "HTTP"
        fixture.critical.state = .on
        fixture.warning.state = .on

        fixture.controller.saveButtonClick(fixture.saveButton)

        let saved = FilterItems().getByKey("web-.*HTTP")
        XCTAssertEqual(saved?.host, "web-.*")
        XCTAssertEqual(saved?.service, "HTTP")
        XCTAssertEqual(saved?.status, 20)
        XCTAssertFalse(fixture.window.isVisible)
    }

    func testSavingNewHostFilterPersistsSelectedHostStatusesAndClosesWindow() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.host.stringValue = "router-.*"
        fixture.hostDown.state = .on
        fixture.hostPending.state = .on

        fixture.controller.saveButtonClick(fixture.saveButton)

        let saved = FilterItems().getByKey("router-.*")
        XCTAssertEqual(saved?.host, "router-.*")
        XCTAssertEqual(saved?.service, "")
        XCTAssertEqual(saved?.status, 5)
        XCTAssertFalse(fixture.window.isVisible)
    }

    func testEditingExistingHostFilterLoadsSelectedHostStatuses() {
        let existing = FilterItem().initDefault(host: "router-.*", service: "", status: 13)
        FilterItems().insert(key: "router-.*", value: existing)
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.filterItemKey = "router-.*"

        fixture.controller.awakeFromNib()

        XCTAssertEqual(fixture.host.stringValue, "router-.*")
        XCTAssertEqual(fixture.service.stringValue, "")
        XCTAssertEqual(fixture.hostDown.state, .on)
        XCTAssertEqual(fixture.hostUnreachable.state, .on)
        XCTAssertEqual(fixture.hostPending.state, .on)
        XCTAssertFalse(fixture.critical.isEnabled)
        XCTAssertFalse(fixture.warning.isEnabled)
        XCTAssertFalse(fixture.unknown.isEnabled)
        XCTAssertFalse(fixture.pending.isEnabled)
    }

    func testEditingExistingServiceFilterLoadsSelectedServiceStatuses() {
        let existing = FilterItem().initDefault(host: "web-01", service: "HTTP", status: 29)
        FilterItems().insert(key: "web-01HTTP", value: existing)
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.filterItemKey = "web-01HTTP"

        fixture.controller.awakeFromNib()

        XCTAssertEqual(fixture.host.stringValue, "web-01")
        XCTAssertEqual(fixture.service.stringValue, "HTTP")
        XCTAssertEqual(fixture.critical.state, .on)
        XCTAssertEqual(fixture.warning.state, .on)
        XCTAssertEqual(fixture.unknown.state, .on)
        XCTAssertEqual(fixture.pending.state, .on)
        XCTAssertFalse(fixture.hostDown.isEnabled)
        XCTAssertFalse(fixture.hostUnreachable.isEnabled)
        XCTAssertFalse(fixture.hostPending.isEnabled)
    }

    func testEditingMissingFilterKeyLeavesNewFilterStateWithoutCrashing() {
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.filterItemKey = "missing-filter"

        fixture.controller.awakeFromNib()

        XCTAssertEqual(fixture.host.stringValue, "")
        XCTAssertEqual(fixture.service.stringValue, "")
        XCTAssertFalse(fixture.critical.isEnabled)
        XCTAssertFalse(fixture.warning.isEnabled)
        XCTAssertFalse(fixture.unknown.isEnabled)
        XCTAssertFalse(fixture.pending.isEnabled)
    }

    func testEditingExistingServiceFilterReplacesStoredKeyAndStatus() {
        let existing = FilterItem().initDefault(host: "web-01", service: "HTTP", status: 16)
        FilterItems().insert(key: "web-01HTTP", value: existing)
        let fixture = FilterItemWindowControllerFixture()
        fixture.controller.filterItemKey = "web-01HTTP"
        fixture.controller.awakeFromNib()
        fixture.host.stringValue = "web-02"
        fixture.service.stringValue = "Disk"
        fixture.critical.state = .off
        fixture.warning.state = .on
        fixture.unknown.state = .on
        fixture.pending.state = .off

        fixture.controller.saveButtonClick(fixture.saveButton)

        XCTAssertNil(FilterItems().getByKey("web-01HTTP"))
        let saved = FilterItems().getByKey("web-02Disk")
        XCTAssertEqual(saved?.status, 12)
        XCTAssertFalse(fixture.window.isVisible)
    }

    func testSavingInvalidFilterShowsWarningAndKeepsWindowOpen() throws {
        var capturedAlert: NSAlert?
        NagBarAlert.presentAlert = { capturedAlert = $0 }
        let fixture = FilterItemWindowControllerFixture()
        fixture.host.stringValue = "["
        fixture.service.stringValue = ""

        fixture.controller.saveButtonClick(fixture.saveButton)

        let alert = try XCTUnwrap(capturedAlert)
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map { $0.title }, ["OK"])
        XCTAssertEqual(FilterItems().count(), 0)
        XCTAssertTrue(fixture.window.isVisible)
    }

    func testSavingDuplicateServiceFilterShowsWarningAndDoesNotOverwrite() throws {
        var capturedAlert: NSAlert?
        NagBarAlert.presentAlert = { capturedAlert = $0 }
        let existing = FilterItem().initDefault(host: "web-01", service: "HTTP", status: 16)
        FilterItems().insert(key: "web-01HTTP", value: existing)
        let fixture = FilterItemWindowControllerFixture()
        fixture.host.stringValue = "web-01"
        fixture.service.stringValue = "HTTP"
        fixture.warning.state = .on

        fixture.controller.saveButtonClick(fixture.saveButton)

        let alert = try XCTUnwrap(capturedAlert)
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertTrue(alert.informativeText.contains("web-01"))
        XCTAssertTrue(alert.informativeText.contains("HTTP"))
        XCTAssertEqual(FilterItems().getByKey("web-01HTTP")?.status, 16)
        XCTAssertTrue(fixture.window.isVisible)
    }
}

class FilterOptionsTabControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FilterItems.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("json")
        FilterItems().resetStorage()
    }

    override func tearDown() {
        FilterItems().resetStorage()
        FilterItems.storageURLOverride = nil
        super.tearDown()
    }

    func testFilterOptionsAddOpensNewFilterWindow() {
        let fixture = FilterOptionsTabControllerFixture()

        fixture.controller.segControlClicked(fixture.segmentedControl(selectedSegment: SegmentControl.add.rawValue))

        XCTAssertEqual(fixture.createdWindows.count, 1)
        XCTAssertTrue(fixture.createdWindows[0].didShowWindow)
        XCTAssertNil(fixture.createdWindows[0].filterItemKey)
    }

    func testFilterOptionsDeleteSelectedFilterRemovesStorageAndReloadsTable() {
        let filter = FilterItem().initDefault(host: "web-01", service: "HTTP", status: 16)
        FilterItems().insert(key: "web-01HTTP", value: filter)
        let fixture = FilterOptionsTabControllerFixture(selectedRow: 0)

        fixture.controller.segControlClicked(fixture.segmentedControl(selectedSegment: SegmentControl.delete.rawValue))

        XCTAssertNil(FilterItems().getByKey("web-01HTTP"))
        XCTAssertEqual(fixture.tableView.reloadDataCallCount, 1)
        XCTAssertEqual(fixture.createdWindows.count, 0)
    }

    func testFilterOptionsEditSelectedFilterOpensExistingFilterByGeneratedKey() {
        let filter = FilterItem().initDefault(host: "web-02", service: "Disk", status: 12)
        FilterItems().insert(key: "web-02Disk", value: filter)
        let fixture = FilterOptionsTabControllerFixture(selectedRow: 0)

        fixture.controller.segControlClicked(fixture.segmentedControl(selectedSegment: SegmentControl.edit.rawValue))

        XCTAssertEqual(fixture.createdWindows.count, 1)
        XCTAssertTrue(fixture.createdWindows[0].didShowWindow)
        XCTAssertEqual(fixture.createdWindows[0].filterItemKey, "web-02Disk")
        XCTAssertEqual(FilterItems().count(), 1)
    }

    func testFilterOptionsDeleteAndEditIgnoreNoSelection() {
        let filter = FilterItem().initDefault(host: "web-03", service: "", status: 4)
        FilterItems().insert(key: "web-03", value: filter)
        let fixture = FilterOptionsTabControllerFixture(selectedRow: -1)

        fixture.controller.segControlClicked(fixture.segmentedControl(selectedSegment: SegmentControl.delete.rawValue))
        fixture.controller.segControlClicked(fixture.segmentedControl(selectedSegment: SegmentControl.edit.rawValue))

        XCTAssertEqual(FilterItems().count(), 1)
        XCTAssertEqual(fixture.tableView.reloadDataCallCount, 0)
        XCTAssertEqual(fixture.createdWindows.count, 0)
    }

    func testFilterTableDatasourceCountsStoredRows() {
        FilterItems().insert(key: "web-01HTTP", value: FilterItem().initDefault(host: "web-01", service: "HTTP", status: 16))
        FilterItems().insert(key: "router-01", value: FilterItem().initDefault(host: "router-01", service: "", status: 4))

        XCTAssertEqual(FilterTableViewDatasource().numberOfRows(in: NSTableView()), 2)
    }

    func testFilterTableDelegateRendersHostServiceAndPlainColumns() throws {
        FilterItems().insert(key: "web-01HTTP", value: FilterItem().initDefault(host: "web-01", service: "HTTP", status: 16))
        let delegate = FilterTableViewDelegate()

        let hostView = try XCTUnwrap(delegate.tableView(NSTableView(), viewFor: HostTableColumn(identifier: NSUserInterfaceItemIdentifier("host")), row: 0) as? NSTextField)
        let serviceView = try XCTUnwrap(delegate.tableView(NSTableView(), viewFor: ServiceTableColumn(identifier: NSUserInterfaceItemIdentifier("service")), row: 0) as? NSTextField)
        let plainView = try XCTUnwrap(delegate.tableView(NSTableView(), viewFor: NSTableColumn(identifier: NSUserInterfaceItemIdentifier("plain")), row: 0) as? NSTextField)

        XCTAssertEqual(hostView.stringValue, "web-01")
        XCTAssertEqual(serviceView.stringValue, "HTTP")
        XCTAssertEqual(plainView.stringValue, "")
        XCTAssertFalse(hostView.isEditable)
        XCTAssertFalse(hostView.isBordered)
        XCTAssertEqual(hostView.identifier?.rawValue, "host")
    }

    func testFilterStatusColumnRendersServiceStatusLetters() throws {
        FilterItems().insert(key: "web-01HTTP", value: FilterItem().initDefault(host: "web-01", service: "HTTP", status: 29))

        let view = try XCTUnwrap(FilterTableViewDelegate().tableView(NSTableView(), viewFor: StatusTableColumn(identifier: NSUserInterfaceItemIdentifier("status")), row: 0) as? NSTextField)

        XCTAssertEqual(Set(view.stringValue.split(separator: ",").map(String.init)), Set(["P", "W", "U", "C"]))
    }

    func testFilterStatusColumnRendersHostStatusLetters() throws {
        FilterItems().insert(key: "router-01", value: FilterItem().initDefault(host: "router-01", service: "", status: 13))

        let view = try XCTUnwrap(FilterTableViewDelegate().tableView(NSTableView(), viewFor: StatusTableColumn(identifier: NSUserInterfaceItemIdentifier("status")), row: 0) as? NSTextField)

        XCTAssertEqual(Set(view.stringValue.split(separator: ",").map(String.init)), Set(["PE", "D", "UR"]))
    }
}

private final class FilterItemWindowControllerFixture {
    let controller = FilterItemWindowController(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false))
    let window: NSWindow
    let host = NSTextField()
    let service = NSTextField()
    let hostDown = NSButton()
    let hostUnreachable = NSButton()
    let hostPending = NSButton()
    let critical = NSButton()
    let warning = NSButton()
    let unknown = NSButton()
    let pending = NSButton()
    let saveButton = NSButton()
    let cancelButton = NSButton()

    init() {
        window = controller.window!
        service.identifier = NSUserInterfaceItemIdentifier("service")
        controller.host = host
        controller.service = service
        controller.hostDown = hostDown
        controller.hostUnreachable = hostUnreachable
        controller.hostPending = hostPending
        controller.critical = critical
        controller.warning = warning
        controller.unknown = unknown
        controller.pending = pending
        [hostDown, hostUnreachable, hostPending, critical, warning, unknown, pending].forEach {
            $0.isEnabled = true
            $0.state = .off
        }
        window.orderFront(nil)
    }

    deinit {
        window.close()
    }
}

private final class FilterOptionsTabControllerFixture {
    let controller = FilterOptionsTabController(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false))
    let tableView: FilterOptionsTableView
    var createdWindows: [RecordingFilterItemWindowController] = []

    init(selectedRow: Int = -1) {
        tableView = FilterOptionsTableView(selectedRow: selectedRow)
        controller.filterItemsTable = tableView
        controller.filterItemWindowFactory = {
            let window = RecordingFilterItemWindowController()
            self.createdWindows.append(window)
            return window
        }
    }

    func segmentedControl(selectedSegment: Int) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: ["+", "-", "Edit"], trackingMode: .selectOne, target: nil, action: nil)
        control.selectedSegment = selectedSegment
        return control
    }
}

private final class FilterOptionsTableView: NSTableView {
    private let row: Int
    private(set) var reloadDataCallCount = 0

    init(selectedRow: Int) {
        row = selectedRow
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var selectedRow: Int {
        return row
    }

    override func reloadData() {
        reloadDataCallCount += 1
    }
}

private final class RecordingFilterItemWindowController: FilterItemWindowController {
    private(set) var didShowWindow = false

    init() {
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120), styleMask: [.titled], backing: .buffered, defer: false))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func showWindow(_ sender: Any?) {
        didShowWindow = true
    }
}
