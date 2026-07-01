//
//  DataRefreshActionTests.swift
//  NagBar
//
//  Created by Volen Davidov on 30.04.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import XCTest
@testable import NagBar

class NotificationDisplayTests: XCTestCase {
    func testProcess() {
        var deliveredNotifications: Array<NSUserNotification> = []
        let notificationDisplay = NotificationDisplay { notification, _ in
            deliveredNotifications.append(notification)
        }
        
        let serviceMonitoringItem1 = ServiceMonitoringItem()
        serviceMonitoringItem1.host = "testhost"
        serviceMonitoringItem1.service = "testservice1"
        serviceMonitoringItem1.status = "CRITICAL"
        serviceMonitoringItem1.duration = "351d 0h 15m 23s"
        serviceMonitoringItem1.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem1.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem1.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem2 = ServiceMonitoringItem()
        serviceMonitoringItem2.host = "testhost"
        serviceMonitoringItem2.service = "testservice2"
        serviceMonitoringItem2.status = "CRITICAL"
        serviceMonitoringItem2.duration = "351d 0h 15m 23s"
        serviceMonitoringItem2.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem2.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem2.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        let serviceMonitoringItem3 = ServiceMonitoringItem()
        serviceMonitoringItem3.host = "testhost"
        serviceMonitoringItem3.service = "testservice1"
        serviceMonitoringItem3.status = "WARNING"
        serviceMonitoringItem3.duration = "351d 0h 15m 23s"
        serviceMonitoringItem3.lastCheck = "04-17-2016 17:27:02"
        serviceMonitoringItem3.statusInformation = "CRITICAL - Packet loss = 100% "
        serviceMonitoringItem3.itemUrl = "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107"
        
        notificationDisplay.process([serviceMonitoringItem1], newResults: [serviceMonitoringItem1, serviceMonitoringItem2])

        XCTAssertEqual(deliveredNotifications.count, 1)
        XCTAssertEqual(deliveredNotifications[0].title, "testhost")
        XCTAssertEqual(deliveredNotifications[0].subtitle, "testservice2 CRITICAL")
        XCTAssertEqual(deliveredNotifications[0].informativeText, "CRITICAL - Packet loss = 100%")
        XCTAssertEqual(deliveredNotifications[0].userInfo?["monitoringItemUrl"] as? String, "http://192.168.1.106/nagios/cgi-bin/extinfo.cgi?type=1&host=192.168.1.107")
    }

    func testProcessDoesNotDeliverNotificationForExistingResult() {
        var deliveredNotifications: Array<NSUserNotification> = []
        let notificationDisplay = NotificationDisplay { notification, _ in
            deliveredNotifications.append(notification)
        }
        let existing = service("web-01", service: "HTTP", status: "CRITICAL")

        notificationDisplay.process([existing], newResults: [existing])

        XCTAssertEqual(deliveredNotifications.count, 0)
    }

    func testProcessDeliversNotificationWhenExistingServiceChangesStatus() {
        var deliveredNotifications: Array<NSUserNotification> = []
        let notificationDisplay = NotificationDisplay { notification, _ in
            deliveredNotifications.append(notification)
        }
        let oldResult = service("web-01", service: "HTTP", status: "WARNING")
        let newResult = service("web-01", service: "HTTP", status: "CRITICAL", information: "HTTP CRITICAL")

        notificationDisplay.process([oldResult], newResults: [newResult])

        XCTAssertEqual(deliveredNotifications.count, 1)
        XCTAssertEqual(deliveredNotifications[0].subtitle, "HTTP CRITICAL")
        XCTAssertEqual(deliveredNotifications[0].informativeText, "HTTP CRITICAL")
    }

    func testProcessDeliversOneNotificationPerNewResult() {
        var deliveredNotifications: Array<NSUserNotification> = []
        let notificationDisplay = NotificationDisplay { notification, _ in
            deliveredNotifications.append(notification)
        }
        let oldResult = service("web-01", service: "HTTP", status: "WARNING")
        let newService = service("web-02", service: "Disk", status: "CRITICAL")
        let newHost = host("db-01", status: "DOWN")

        notificationDisplay.process([oldResult], newResults: [oldResult, newService, newHost])

        XCTAssertEqual(deliveredNotifications.count, 2)
        XCTAssertEqual(deliveredNotifications.map { $0.title }, ["web-02", "db-01"])
        XCTAssertEqual(deliveredNotifications.map { $0.subtitle }, ["Disk CRITICAL", "DOWN"])
    }

    func testNotificationActivationIgnoresMissingUserInfo() {
        let notification = NSUserNotification()

        NotificationDisplay().userNotificationCenter(.default, didActivate: notification)

        XCTAssertNil(notification.userInfo)
    }

    func testNotificationActivationIgnoresMissingMonitoringItemURL() {
        let notification = NSUserNotification()
        notification.userInfo = ["other": "value"]

        NotificationDisplay().userNotificationCenter(.default, didActivate: notification)

        XCTAssertEqual(notification.userInfo?["other"] as? String, "value")
    }

    func testNotificationActivationRejectsMalformedMonitoringItemURL() {
        let notification = NSUserNotification()
        notification.userInfo = ["monitoringItemUrl": "http://["]

        NotificationDisplay().userNotificationCenter(.default, didActivate: notification)

        XCTAssertEqual(notification.userInfo?["monitoringItemUrl"] as? String, "http://[")
    }

    private func host(_ name: String, status: String, information: String = "Host problem") -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        item.statusInformation = information
        item.itemUrl = "https://monitoring.example/hosts/" + name
        return item
    }

    private func service(_ host: String, service: String, status: String, information: String = "Service problem") -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        item.statusInformation = information
        item.itemUrl = "https://monitoring.example/services/" + host + "/" + service
        return item
    }
}

class PlaySoundAlarmTests: XCTestCase {
    private var originalDefaultSoundPlayer: ((String) -> Void)!
    private var originalCustomSoundPlayer: ((String) -> Void)!
    private var playedDefaultSounds: [String] = []
    private var playedCustomSounds: [String] = []
    private let settings = Settings()

    override func setUp() {
        super.setUp()
        originalDefaultSoundPlayer = AlarmProcessor.playDefaultSound
        originalCustomSoundPlayer = AlarmProcessor.playCustomSound
        playedDefaultSounds = []
        playedCustomSounds = []
        AlarmProcessor.playDefaultSound = { [weak self] sound in
            self?.playedDefaultSounds.append(sound)
        }
        AlarmProcessor.playCustomSound = { [weak self] path in
            self?.playedCustomSounds.append(path)
        }
        resetAlarmSettings()
    }

    override func tearDown() {
        resetAlarmSettings()
        AlarmProcessor.playDefaultSound = originalDefaultSoundPlayer
        AlarmProcessor.playCustomSound = originalCustomSoundPlayer
        super.tearDown()
    }

    func testPlaySoundAlarmDoesNotPlayForUnchangedResults() {
        let existing = service("web-01", service: "HTTP", status: "CRITICAL")

        PlaySoundAlarm().process([existing], newResults: [existing])

        XCTAssertEqual(playedDefaultSounds, [])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testPlaySoundAlarmIgnoresNewOkUnknownAndPendingResults() {
        let oldResults: [MonitoringItem] = []
        let newResults: [MonitoringItem] = [
            service("web-01", service: "HTTP", status: "OK"),
            service("web-02", service: "Disk", status: "UNKNOWN"),
            host("web-03", status: "PENDING")
        ]

        PlaySoundAlarm().process(oldResults, newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, [])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testPlaySoundAlarmPlaysHighestPriorityFailureSoundWhenDownAppears() {
        let newResults: [MonitoringItem] = [
            host("web-01", status: "DOWN"),
            service("web-02", service: "Disk", status: "CRITICAL")
        ]

        PlaySoundAlarm().process([], newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, ["siren-horn"])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testPlaySoundAlarmFallsThroughDisabledDownAlarmToCriticalAlarm() {
        settings.setBool(false, forKey: "enableAudibleAlarmsDown")
        let newResults: [MonitoringItem] = [
            host("web-01", status: "DOWN"),
            service("web-02", service: "Disk", status: "CRITICAL")
        ]

        PlaySoundAlarm().process([], newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, ["critical"])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testPlaySoundAlarmFallsThroughDisabledDownToUnreachableAlarm() {
        settings.setBool(false, forKey: "enableAudibleAlarmsDown")
        let newResults: [MonitoringItem] = [
            host("web-01", status: "DOWN"),
            host("edge-01", status: "UNREACHABLE")
        ]

        PlaySoundAlarm().process([], newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, ["siren-horn"])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testBaseAlarmProcessorExposesEmptyDefaults() {
        let processor = AlarmProcessor()

        XCTAssertEqual(processor.alertType, "")
        XCTAssertEqual(processor.alertKeyEnabled, "")
        XCTAssertEqual(processor.alertKeyFilePath, "")
        XCTAssertEqual(processor.defaultSound, "")
    }

    func testPlaySoundAlarmUsesCustomWarningSoundPathWhenConfigured() {
        settings.setString("/tmp/nagbar-warning.aiff", forKey: "audibleAlarmsWarningSoundFile")

        PlaySoundAlarm().process([], newResults: [service("web-01", service: "CPU", status: "WARNING")])

        XCTAssertEqual(playedDefaultSounds, [])
        XCTAssertEqual(playedCustomSounds, ["/tmp/nagbar-warning.aiff"])
    }

    func testPlaySoundAlarmPlaysRecoveryOnlyWhenFailuresDisappear() {
        let oldResults: [MonitoringItem] = [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ]
        let newResults: [MonitoringItem] = [
            service("web-01", service: "HTTP", status: "OK")
        ]

        PlaySoundAlarm().process(oldResults, newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, ["ok"])
        XCTAssertEqual(playedCustomSounds, [])
    }

    func testPlaySoundAlarmKeepsFailurePriorityWhenOneProblemRecoversAndAnotherAppears() {
        let oldResults: [MonitoringItem] = [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ]
        let newResults: [MonitoringItem] = [
            service("web-01", service: "HTTP", status: "OK"),
            service("web-02", service: "Disk", status: "WARNING")
        ]

        PlaySoundAlarm().process(oldResults, newResults: newResults)

        XCTAssertEqual(playedDefaultSounds, ["warning"])
        XCTAssertEqual(playedCustomSounds, [])
    }

    private func resetAlarmSettings() {
        [
            "enableAudibleAlarmsDown",
            "enableAudibleAlarmsUnreachable",
            "enableAudibleAlarmsCritical",
            "enableAudibleAlarmsWarning",
            "enableAudibleAlarmsRecovery"
        ].forEach { settings.setBool(true, forKey: $0) }
        [
            "audibleAlarmsDownSoundFile",
            "audibleAlarmsUnreachableSoundFile",
            "audibleAlarmsCriticalSoundFile",
            "audibleAlarmsWarningSoundFile",
            "audibleAlarmsRecoverySoundFile"
        ].forEach { settings.setString("", forKey: $0) }
    }

    private func host(_ name: String, status: String) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        item.statusInformation = status
        item.itemUrl = "https://monitoring.example/hosts/" + name
        return item
    }

    private func service(_ host: String, service: String, status: String) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        item.statusInformation = status
        item.itemUrl = "https://monitoring.example/services/" + host + "/" + service
        return item
    }
}
