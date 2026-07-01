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

    func testStatusItemEventKeepsMessageInDedicatedCategory() {
        let event = NagBarDiagnostics.statusItemEvent(message: "showStatusOpeningPanel items=6")

        XCTAssertEqual(event.category, .statusItem)
        XCTAssertEqual(event.message, "showStatusOpeningPanel items=6")
    }
}
