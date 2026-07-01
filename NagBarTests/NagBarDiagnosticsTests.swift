//
//  NagBarDiagnosticsTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import XCTest
@testable import NagBar

final class NagBarDiagnosticsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
        NagBarStorage.applicationSupportDirectoryOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarDiagnosticsTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: true)
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
        MonitoringInstances.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarDiagnosticsTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("monitoring-instances.json")
        MonitoringInstances().resetStorage()
        PasswordStore.sharedInstance.removeAll()
        (KeychainAccess().get() as? InMemoryKeychainClient)?.removeAll()
    }

    override func tearDown() {
        MonitoringInstances().resetStorage()
        MonitoringInstances.storageURLOverride = nil
        if let applicationSupportDirectory = NagBarStorage.applicationSupportDirectoryOverride {
            try? FileManager.default.removeItem(at: applicationSupportDirectory)
        }
        NagBarStorage.applicationSupportDirectoryOverride = nil
        super.tearDown()
    }

    func testRuntimeSnapshotReportsLocalFallbackWithoutStartingFakeServerThroughEnabledList() {
        let report = UpgradeCompatibilityReport(
            legacyRealmFiles: [],
            currentJSONFiles: [],
            requiresManualReconfiguration: false,
            message: "No legacy Realm configuration was found."
        )

        let snapshot = NagBarRuntimeSnapshot.capture(
            bundle: Bundle(for: NagBarDiagnosticsTests.self),
            monitoringInstances: MonitoringInstances(),
            upgradeReport: report
        )

        XCTAssertEqual(snapshot.configuredRemoteCount, 0)
        XCTAssertEqual(snapshot.enabledConfiguredRemoteCount, 0)
        XCTAssertTrue(snapshot.usingLocalFallback)
        XCTAssertEqual(snapshot.legacyRealmFileCount, 0)
        XCTAssertFalse(snapshot.requiresManualReconfiguration)
        XCTAssertTrue(snapshot.applicationSupportPath.hasSuffix("ApplicationSupport/com.volendavidov.NagBar"))
    }

    func testRuntimeSnapshotReportsConfiguredEnabledRemotesAndBundleFallbacks() {
        let enabled = MonitoringInstance().initDefault(
            name: "enabled",
            url: "https://icinga.example",
            type: .Icinga,
            username: "user",
            password: "",
            enabled: 1
        )
        let disabled = MonitoringInstance().initDefault(
            name: "disabled",
            url: "https://nagios.example",
            type: .Nagios,
            username: "user",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: enabled.name, value: enabled)
        MonitoringInstances().insert(key: disabled.name, value: disabled)
        let report = UpgradeCompatibilityReport(
            legacyRealmFiles: ["/tmp/default.realm"],
            currentJSONFiles: [],
            requiresManualReconfiguration: true,
            message: "Manual reconfiguration required."
        )

        let snapshot = NagBarRuntimeSnapshot.capture(
            bundle: Bundle(),
            monitoringInstances: MonitoringInstances(),
            upgradeReport: report
        )

        XCTAssertEqual(snapshot.bundleIdentifier, "com.volendavidov.NagBar")
        XCTAssertEqual(snapshot.version, "unknown")
        XCTAssertEqual(snapshot.build, "unknown")
        XCTAssertEqual(snapshot.configuredRemoteCount, 2)
        XCTAssertEqual(snapshot.enabledConfiguredRemoteCount, 1)
        XCTAssertFalse(snapshot.usingLocalFallback)
        XCTAssertEqual(snapshot.legacyRealmFileCount, 1)
        XCTAssertTrue(snapshot.requiresManualReconfiguration)
    }

    func testApplicationSupportDirectoryUsesTemporaryStorageDuringHostedTests() {
        NagBarStorage.applicationSupportDirectoryOverride = nil
        let directory = NagBarStorage.applicationSupportDirectory(
            environment: ["TESTS_RUNNING": "YES"],
            defaultDirectory: URL(fileURLWithPath: "/Users/example/Library/Application Support", isDirectory: true),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/nagbar-tests", isDirectory: true)
        )

        XCTAssertEqual(directory.path, "/tmp/nagbar-tests/NagBarTests/ApplicationSupport")
    }

    func testApplicationSupportDirectoryExplicitOverrideWinsDuringHostedTests() {
        NagBarStorage.applicationSupportDirectoryOverride = nil
        let directory = NagBarStorage.applicationSupportDirectory(
            environment: [
                "TESTS_RUNNING": "YES",
                "NAGBAR_APPLICATION_SUPPORT_DIR": "/tmp/explicit-support"
            ],
            defaultDirectory: URL(fileURLWithPath: "/Users/example/Library/Application Support", isDirectory: true),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/nagbar-tests", isDirectory: true)
        )

        XCTAssertEqual(directory.path, "/tmp/explicit-support")
    }

    func testApplicationSupportDirectoryUsesTemporaryStorageWhenXCTestBundleIsLoaded() {
        NagBarStorage.applicationSupportDirectoryOverride = nil
        let directory = NagBarStorage.applicationSupportDirectory(
            environment: [:],
            defaultDirectory: URL(fileURLWithPath: "/Users/example/Library/Application Support", isDirectory: true),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/nagbar-tests", isDirectory: true),
            loadedBundles: [Bundle(for: NagBarDiagnosticsTests.self)]
        )

        XCTAssertEqual(directory.path, "/tmp/nagbar-tests/NagBarTests/ApplicationSupport")
    }

    func testStartupEventIncludesVersionStorageRemoteAndUpgradeSignals() {
        let snapshot = NagBarRuntimeSnapshot(
            bundleIdentifier: "com.volendavidov.NagBar",
            version: "1.3.7",
            build: "42",
            processIdentifier: 1234,
            applicationSupportPath: "/tmp/NagBar/ApplicationSupport/com.volendavidov.NagBar",
            configuredRemoteCount: 2,
            enabledConfiguredRemoteCount: 1,
            usingLocalFallback: false,
            legacyRealmFileCount: 3,
            requiresManualReconfiguration: true
        )

        let event = NagBarDiagnostics.startupEvent(snapshot)

        XCTAssertEqual(event.category, .startup)
        XCTAssertTrue(event.message.contains("bundle=com.volendavidov.NagBar"))
        XCTAssertTrue(event.message.contains("version=1.3.7"))
        XCTAssertTrue(event.message.contains("build=42"))
        XCTAssertTrue(event.message.contains("configuredRemotes=2"))
        XCTAssertTrue(event.message.contains("enabledRemotes=1"))
        XCTAssertTrue(event.message.contains("localFallback=false"))
        XCTAssertTrue(event.message.contains("legacyRealmFiles=3"))
        XCTAssertTrue(event.message.contains("manualReconfiguration=true"))
    }

    func testUpgradeEventSummarizesCutoffReportWithoutDumpingFileContents() {
        let report = UpgradeCompatibilityReport(
            legacyRealmFiles: ["/tmp/default.realm"],
            currentJSONFiles: ["/tmp/monitoring-instances.json"],
            requiresManualReconfiguration: false,
            message: "Legacy Realm configuration was found and left untouched."
        )

        let event = NagBarDiagnostics.upgradeEvent(report)

        XCTAssertEqual(event.category, .storage)
        XCTAssertTrue(event.message.contains("legacyRealmFiles=1"))
        XCTAssertTrue(event.message.contains("currentJSONFiles=1"))
        XCTAssertTrue(event.message.contains("manualReconfiguration=false"))
        XCTAssertFalse(event.message.contains("/tmp/default.realm"))
    }

    func testRefreshFailureEventIncludesInstanceTypeReasonAndErrorIdentity() {
        let instance = MonitoringInstance().initDefault(
            name: "prod-icinga",
            url: "https://icinga.example/v1",
            type: .Icinga2,
            username: "icinga",
            password: "secret",
            enabled: 1
        )
        let error = NSError(domain: NSURLErrorDomain, code: -1202, userInfo: nil)

        let event = NagBarDiagnostics.refreshFailureEvent(instance: instance, reason: .ssl, error: error)

        XCTAssertEqual(event.category, .refresh)
        XCTAssertTrue(event.message.contains("instance=\"prod-icinga\""))
        XCTAssertTrue(event.message.contains("type=Icinga2"))
        XCTAssertTrue(event.message.contains("reason=ssl"))
        XCTAssertTrue(event.message.contains("errorCode=-1202"))
        XCTAssertTrue(event.message.contains("errorDomain=\"NSURLErrorDomain\""))
        XCTAssertFalse(event.message.contains("secret"))
    }

    func testRefreshFinishedAndLocalServerEventsUseDedicatedCategories() {
        let refresh = NagBarDiagnostics.refreshFinishedEvent(itemCount: 7, failedCount: 2)
        let local = NagBarDiagnostics.localServerEvent(message: "localIcingaServerStarted baseURL=http://127.0.0.1:1234/")

        XCTAssertEqual(refresh.category, .refresh)
        XCTAssertEqual(refresh.message, "refreshFinished items=7 failedInstances=2")
        XCTAssertEqual(local.category, .localServer)
        XCTAssertTrue(local.message.contains("localIcingaServerStarted"))
    }

    func testFailReasonDiagnosticNamesCoverAllReasons() {
        XCTAssertEqual(FailReason.wrongCredentials.diagnosticName, "wrongCredentials")
        XCTAssertEqual(FailReason.ssl.diagnosticName, "ssl")
        XCTAssertEqual(FailReason.unknown.diagnosticName, "unknown")
    }

    func testDiagnosticLogEntryPointsAcceptSuccessFailureAndStorageEvents() {
        let instance = MonitoringInstance().initDefault(
            name: "prod-icinga",
            url: "https://icinga.example",
            type: .Icinga,
            username: "user",
            password: "secret",
            enabled: 1
        )
        let report = UpgradeCompatibilityReport(
            legacyRealmFiles: ["/tmp/default.realm"],
            currentJSONFiles: [],
            requiresManualReconfiguration: true,
            message: "Manual reconfiguration required."
        )
        let error = NSError(domain: NSURLErrorDomain, code: -1012, userInfo: nil)

        NagBarDiagnostics.logStartup(NagBarRuntimeSnapshot(
            bundleIdentifier: "com.volendavidov.NagBar",
            version: "1.0",
            build: "1",
            processIdentifier: 42,
            applicationSupportPath: "/tmp/support",
            configuredRemoteCount: 1,
            enabledConfiguredRemoteCount: 1,
            usingLocalFallback: false,
            legacyRealmFileCount: 1,
            requiresManualReconfiguration: true
        ))
        NagBarDiagnostics.logUpgradeReport(report)
        NagBarDiagnostics.logUpgradeReport(UpgradeCompatibilityReport(
            legacyRealmFiles: [],
            currentJSONFiles: [],
            requiresManualReconfiguration: false,
            message: "No legacy Realm configuration was found."
        ))
        NagBarDiagnostics.logRefreshFailure(instance: instance, reason: .wrongCredentials, error: error)
        NagBarDiagnostics.logRefreshFinished(itemCount: 3, failedCount: 0)
        NagBarDiagnostics.logRefreshFinished(itemCount: 3, failedCount: 1)
        NagBarDiagnostics.logLocalServerStarted(baseURL: "http://127.0.0.1:1234/icinga/cgi-bin/")
        NagBarDiagnostics.logLocalServerStartFailed(error)
        NagBarDiagnostics.logLocalServerEvent(message: "localIcingaServerStartTimedOut")
        NagBarDiagnostics.logStatusItemEvent(message: "showStatus")
        NagBarDiagnostics.logStorageError("storageFailure", error: error)

        XCTAssertEqual(NagBarDiagnostics.refreshFailureEvent(instance: instance, reason: .wrongCredentials, error: error).category, .refresh)
    }

    func testStatusItemEventKeepsMessageInDedicatedCategory() {
        let event = NagBarDiagnostics.statusItemEvent(message: "showStatusOpeningPanel items=6")

        XCTAssertEqual(event.category, .statusItem)
        XCTAssertEqual(event.message, "showStatusOpeningPanel items=6")
    }
}
