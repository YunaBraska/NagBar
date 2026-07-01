//
//  SettingsTests.swift
//  NagBar
//
//  Created by Volen Davidov on 18.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest
@testable import NagBar

class NagiosSettingsTests: XCTestCase {
    
    override func setUp() {
        let appSettings = Settings()
        appSettings.resetKnownSettings()

        let settings = [
            "refreshInterval": "30",
            "monitoringInstance": "0",
            "status": "0",
            "lastCheck": "0",
            "duration": "0",
            "attempt": "0",
            "statusInformation": "0",
            "critical": "0",
            "warning": "0",
            "unknown": "1",
            "pending": "1",
            "down": "1",
            "unreachable": "0",
            "hostPending": "1",
            "sortColumn": "7",
            "sortOrder": "3",
            "statusInformationLength": "200",
            "ok": "0",
            "up": "0",
            "scheduledDowntime": "0",
            "acknowledged": "1",
            "flapping": "0",
            "checksDisabled": "0",
            "disabledNotifications": "0",
            "softState": "1",
            "skipServicesOfHostsWithScD": "0",
            "hostScheduledDowntime": "1",
            "hostAcknowledged": "0",
            "hostFlapping": "1",
            "hostDisabledNotifications": "1",
            "hostSoftState": "0",
            "hostChecksDisabled": "0",
            "showExtendedStatusInformation": "0",
            "flashStatusBar": "0",
            "flashStatusBarType": "0",
            "savePassword": "0",
            "acceptInvalidCertificates": "0",
            "enableAudibleAlarms": "0",
            "enableAudibleAlarmsCritical": "0",
            "enableAudibleAlarmsWarning": "0",
            "enableAudibleAlarmsDown": "0",
            "enableAudibleAlarmsUnreachable": "0",
            "enableAudibleAlarmsRecovery": "0",
            "audibleAlarmsCriticalSoundFile": "",
            "audibleAlarmsWarningSoundFile": "",
            "audibleAlarmsDownSoundFile": "",
            "audibleAlarmsUnreachableSoundFile": "",
            "audibleAlarmsRecoverySoundFile": "",
            "showDockIcon": "0",
            "useNotifications": "0",
            "newVersionCheck": "0",
            "acknowledgementDefaultComment": "",
            "scheduleDowntimeDefaultComment": ""
        ]
        
        for (key, value) in settings {
            appSettings.setString(value, forKey: key)
        }
    }
    
    func testGetHostProperties() {
        XCTAssertEqual(NagiosSettings().getHostProperties(), "10242");
    }
    
    func testGetHostStatusTypes() {
        XCTAssertEqual(NagiosSettings().getHostStatusTypes(), "5");
    }
    
    func testGetServiceStatusTypes() {
        XCTAssertEqual(NagiosSettings().getServiceStatusTypes(), "9");
    }
    
    func testgetServiceProperties() {
        XCTAssertEqual(NagiosSettings().getServiceProperties(), "262152");
    }
    
    func testGetSortOrder() {
        XCTAssertEqual(NagiosSettings().getSortOrder(), "3");
    }
    
    func testGetSortColumn() {
        XCTAssertEqual(NagiosSettings().getSortColumn(), "7");
    }

    func testSortSettingsUseDefaultsWhenKeysAreMissing() {
        let settings = Settings()
        settings.resetKnownSettings()

        XCTAssertEqual(NagiosSettings().getSortOrder(), "1")
        XCTAssertEqual(NagiosSettings().getSortColumn(), "1")
    }

    func testCheckMKSortSettingsReturnEmptyQueryFragments() {
        XCTAssertEqual(CheckMKSettings().getSortOrder(), "")
        XCTAssertEqual(CheckMKSettings().getSortColumn(), "")
    }

    func testInitConfigMigratesLegacyFlashStatusBarType() {
        Settings().setString("1", forKey: "flashStatusBarType")

        InitConfig().initConfig()

        XCTAssertEqual(Settings().stringForKey("flashStatusBarType"), "2")
    }

    func testCheckMKSettingsBuildsEnabledHostAndServiceFilters() {
        Settings().setBool(true, forKey: "up")
        Settings().setBool(false, forKey: "down")
        Settings().setBool(true, forKey: "unreachable")
        Settings().setBool(false, forKey: "pending")
        Settings().setBool(true, forKey: "ok")
        Settings().setBool(true, forKey: "warning")
        Settings().setBool(false, forKey: "critical")
        Settings().setBool(true, forKey: "unknown")
        Settings().setBool(true, forKey: "hostScheduledDowntime")
        Settings().setBool(true, forKey: "hostAcknowledged")
        Settings().setBool(true, forKey: "hostChecksDisabled")
        Settings().setBool(true, forKey: "hostDisabledNotifications")
        Settings().setBool(true, forKey: "scheduledDowntime")
        Settings().setBool(true, forKey: "acknowledged")
        Settings().setBool(true, forKey: "checksDisabled")
        Settings().setBool(true, forKey: "flapping")
        Settings().setBool(true, forKey: "disabledNotifications")
        Settings().setBool(true, forKey: "softState")
        let checkMKSettings = CheckMKSettings()

        let hostStatusTypes = checkMKSettings.getHostStatusTypes()
        let serviceStatusTypes = checkMKSettings.getServiceStatusTypes()

        XCTAssertTrue(hostStatusTypes.contains("hst0=on&"))
        XCTAssertTrue(hostStatusTypes.contains("hst1=&"))
        XCTAssertTrue(hostStatusTypes.contains("hst2=on&"))
        XCTAssertTrue(hostStatusTypes.contains("hstp=&"))
        XCTAssertTrue(serviceStatusTypes.contains("st0=on&"))
        XCTAssertTrue(serviceStatusTypes.contains("st1=on&"))
        XCTAssertTrue(serviceStatusTypes.contains("st2=&"))
        XCTAssertTrue(serviceStatusTypes.contains("st3=on&"))
        XCTAssertTrue(checkMKSettings.getHostProperties().contains("is_host_scheduled_downtime_depth=0&"))
        XCTAssertTrue(checkMKSettings.getHostProperties().contains("is_host_acknowledged=0&"))
        XCTAssertTrue(checkMKSettings.getHostProperties().contains("is_host_active_checks_enabled=1&"))
        XCTAssertTrue(checkMKSettings.getHostProperties().contains("is_host_notifications_enabled=1&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_in_downtime=0&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_service_acknowledged=0&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_service_active_checks_enabled=1&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_service_is_flapping=0&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_service_in_notification_period=1&"))
        XCTAssertTrue(checkMKSettings.getServiceProperties().contains("is_service_state_type=1&"))
    }
    
    func testSavePassword() {
        XCTAssertEqual(Settings().savePassword(), false);
    }

    func testSettersPersistTypedSettingsByKey() {
        let settings = Settings()

        settings.setBool(true, forKey: "useNotifications")
        settings.setInteger(42, forKey: "refreshInterval")
        settings.setString("operator note", forKey: "acknowledgementDefaultComment")

        XCTAssertEqual(Settings().boolForKey("useNotifications"), true)
        XCTAssertEqual(Settings().integerForKey("refreshInterval"), 42)
        XCTAssertEqual(Settings().stringForKey("acknowledgementDefaultComment"), "operator note")
    }

    func testUtilityBooleanConversionsCoverAcceptedAndRejectedValues() {
        XCTAssertEqual("True".toBool(), true)
        XCTAssertEqual("true".toBool(), true)
        XCTAssertEqual("yes".toBool(), true)
        XCTAssertEqual("1".toBool(), true)
        XCTAssertEqual("False".toBool(), false)
        XCTAssertEqual("false".toBool(), false)
        XCTAssertEqual("no".toBool(), false)
        XCTAssertEqual("0".toBool(), false)
        XCTAssertNil("maybe".toBool())
        XCTAssertEqual(true.intValue, 1)
        XCTAssertEqual(false.intValue, 0)
    }

    func testArrayRemoveObjectRemovesOnlyIdenticalObject() {
        let first = NSObject()
        let second = NSObject()
        var values = [first, second]

        values.removeObject(first)

        XCTAssertEqual(values, [second])
    }

    func testInMemoryKeychainStoresDeletesAndClearsPasswordsByServiceAccount() {
        let keychain = InMemoryKeychainClient()

        XCTAssertNil(keychain.password(forService: "NagBar", account: "web-01"))
        XCTAssertTrue(keychain.setPassword("secret", forService: "NagBar", account: "web-01"))
        XCTAssertEqual(keychain.password(forService: "NagBar", account: "web-01"), "secret")
        XCTAssertNil(keychain.password(forService: "Other", account: "web-01"))
        XCTAssertTrue(keychain.deletePassword(forService: "NagBar", account: "web-01"))
        XCTAssertNil(keychain.password(forService: "NagBar", account: "web-01"))

        _ = keychain.setPassword("again", forService: "NagBar", account: "web-01")
        keychain.removeAll()

        XCTAssertNil(keychain.password(forService: "NagBar", account: "web-01"))
    }

    func testSettingsDetectStoredValuesAndFallbackDefaults() {
        let settings = Settings()
        settings.resetKnownSettings()

        XCTAssertFalse(settings.hasStoredValue(forKey: "refreshInterval"))
        XCTAssertEqual(settings.doubleForKey("refreshInterval"), 30)

        settings.setString("12.5", forKey: "refreshInterval")

        XCTAssertTrue(settings.hasStoredValue(forKey: "refreshInterval"))
        XCTAssertEqual(settings.doubleForKey("refreshInterval"), 12.5)
    }

    func testIcinga2SettingsBuildsAllEnabledHostAndServiceFilters() {
        let settings = Settings()
        [
            "hostScheduledDowntime",
            "hostAcknowledged",
            "hostChecksDisabled",
            "hostFlapping",
            "hostDisabledNotifications",
            "hostSoftState",
            "scheduledDowntime",
            "acknowledged",
            "checksDisabled",
            "flapping",
            "disabledNotifications",
            "softState"
        ].forEach { settings.setBool(true, forKey: $0) }

        let icingaSettings = Icinga2Settings()

        XCTAssertEqual(icingaSettings.getHostProperties(), "%26%26host.downtime_depth==0.0%26%26host.acknowledgement==0.0%26%26host.enable_active_checks==true%26%26host.enable_notifications==true%26%26host.state_type==1")
        XCTAssertEqual(icingaSettings.getServiceProperties(), "%26%26service.downtime_depth==0.0%26%26service.acknowledgement==0.0%26%26service.enable_active_checks==true%26%26service.enable_notifications==true%26%26service.state_type==1")
        XCTAssertEqual(icingaSettings.getSortOrder(), "")
        XCTAssertEqual(icingaSettings.getSortColumn(), "")
    }

    func testMonitoringItemSorterCoversHostServiceDurationAttemptAndLastCheckOrders() {
        let settings = Settings()
        let older = service(host: "web-02", service: "Disk", status: "WARNING", duration: "2m 0s", lastCheck: "30-06-2026 12:00:00", attempt: "1/3")
        let newer = service(host: "web-01", service: "HTTP", status: "CRITICAL", duration: "1h 0m 0s", lastCheck: "01-07-2026 12:00:00", attempt: "2/3")

        settings.setInteger(MonitoringItemSorter.SortColumn.host.rawValue, forKey: "sortColumn")
        settings.setInteger(MonitoringItemSorter.SortOrder.ascending.rawValue, forKey: "sortOrder")
        XCTAssertEqual(MonitoringItemSorter().sortServices([older, newer]).map(\.host), ["web-01", "web-02"])

        settings.setInteger(MonitoringItemSorter.SortColumn.service.rawValue, forKey: "sortColumn")
        settings.setInteger(MonitoringItemSorter.SortOrder.descending.rawValue, forKey: "sortOrder")
        XCTAssertEqual(MonitoringItemSorter().sortServices([older, newer]).map(\.service), ["HTTP", "Disk"])

        settings.setInteger(MonitoringItemSorter.SortColumn.duration.rawValue, forKey: "sortColumn")
        settings.setInteger(MonitoringItemSorter.SortOrder.ascending.rawValue, forKey: "sortOrder")
        XCTAssertEqual(MonitoringItemSorter().sortServices([newer, older]).map(\.duration), ["2m 0s", "1h 0m 0s"])

        settings.setInteger(MonitoringItemSorter.SortColumn.lastCheck.rawValue, forKey: "sortColumn")
        settings.setInteger(MonitoringItemSorter.SortOrder.descending.rawValue, forKey: "sortOrder")
        XCTAssertEqual(MonitoringItemSorter().sortServices([older, newer]).map(\.lastCheck), ["01-07-2026 12:00:00", "30-06-2026 12:00:00"])

        settings.setInteger(MonitoringItemSorter.SortColumn.attempt.rawValue, forKey: "sortColumn")
        settings.setInteger(MonitoringItemSorter.SortOrder.ascending.rawValue, forKey: "sortOrder")
        XCTAssertEqual(MonitoringItemSorter().sortServices([newer, older]).map(\.attempt), ["1/3", "2/3"])
    }

    private func service(host: String, service: String, status: String, duration: String, lastCheck: String, attempt: String) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        item.duration = duration
        item.lastCheck = lastCheck
        item.attempt = attempt
        return item
    }
}
