//
//  NagBarStorage.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation

enum NagBarStorage {
    static var applicationSupportDirectoryOverride: URL?

    static func applicationSupportDirectory() -> URL {
        return applicationSupportDirectory(
            environment: ProcessInfo.processInfo.environment,
            defaultDirectory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
    }

    static func applicationSupportDirectory(
        environment: [String: String],
        defaultDirectory: URL,
        temporaryDirectory: URL
    ) -> URL {
        return applicationSupportDirectory(
            environment: environment,
            defaultDirectory: defaultDirectory,
            temporaryDirectory: temporaryDirectory,
            loadedBundles: Bundle.allBundles
        )
    }

    static func applicationSupportDirectory(
        environment: [String: String],
        defaultDirectory: URL,
        temporaryDirectory: URL,
        loadedBundles: [Bundle]
    ) -> URL {
        if let applicationSupportDirectoryOverride = applicationSupportDirectoryOverride {
            return applicationSupportDirectoryOverride
        }

        if let overridePath = environment["NAGBAR_APPLICATION_SUPPORT_DIR"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        if isTestHost(environment: environment, loadedBundles: loadedBundles) {
            return temporaryDirectory
                .appendingPathComponent("NagBarTests", isDirectory: true)
                .appendingPathComponent("ApplicationSupport", isDirectory: true)
        }

        return defaultDirectory
    }

    static func isTestHost(environment: [String: String], loadedBundles: [Bundle]) -> Bool {
        if environment["TESTS_RUNNING"] == "YES" || environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        if loadedBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            return true
        }

        return NSClassFromString("XCTestCase") != nil
    }

    static func bundleStorageDirectory() -> URL {
        return applicationSupportDirectory()
            .appendingPathComponent("com.volendavidov.NagBar", isDirectory: true)
    }
}

struct UpgradeCompatibilityReport: Codable {
    let legacyRealmFiles: [String]
    let currentJSONFiles: [String]
    let requiresManualReconfiguration: Bool
    let message: String
}

enum UpgradeCompatibility {
    static let reportFileName = "upgrade-compatibility.json"

    static func assess() -> UpgradeCompatibilityReport {
        let legacyRealmFiles = existingLegacyRealmFiles()
        let currentJSONFiles = existingCurrentJSONFiles()
        let requiresManualReconfiguration = !legacyRealmFiles.isEmpty && !hasCurrentConfiguredMonitoringRemote()
        let message: String

        if requiresManualReconfiguration {
            message = "Legacy Realm configuration was found, but this build no longer embeds Realm and no valid current monitoring remote configuration was found. Reconfigure monitoring instances in Settings or migrate through an earlier bridge build before using this release."
        } else if !legacyRealmFiles.isEmpty {
            message = "Legacy Realm configuration was found and left untouched. Current JSON configuration exists and will be used."
        } else {
            message = "No legacy Realm configuration was found. Current JSON/UserDefaults storage is authoritative."
        }

        return UpgradeCompatibilityReport(
            legacyRealmFiles: legacyRealmFiles.map { $0.path }.sorted(),
            currentJSONFiles: currentJSONFiles.map { $0.path }.sorted(),
            requiresManualReconfiguration: requiresManualReconfiguration,
            message: message
        )
    }

    @discardableResult
    static func writeReportIfNeeded() -> UpgradeCompatibilityReport {
        let report = assess()
        if !report.legacyRealmFiles.isEmpty {
            write(report)
        }
        return report
    }

    static func reportURL() -> URL {
        return NagBarStorage.bundleStorageDirectory()
            .appendingPathComponent(reportFileName, isDirectory: false)
    }

    private static func existingLegacyRealmFiles() -> [URL] {
        let applicationSupport = NagBarStorage.applicationSupportDirectory()
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        let candidates = [
            bundleDirectory.appendingPathComponent("default.realm", isDirectory: false),
            bundleDirectory.appendingPathComponent("default.realm.lock", isDirectory: false),
            bundleDirectory.appendingPathComponent("default.realm.note", isDirectory: false),
            bundleDirectory.appendingPathComponent("default.realm.management", isDirectory: true),
            applicationSupport.appendingPathComponent("default.realm", isDirectory: false),
            applicationSupport.appendingPathComponent("default.realm.lock", isDirectory: false),
            applicationSupport.appendingPathComponent("default.realm.note", isDirectory: false),
            applicationSupport.appendingPathComponent("default.realm.management", isDirectory: true),
        ]

        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func existingCurrentJSONFiles() -> [URL] {
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        var candidates = [
            bundleDirectory.appendingPathComponent("monitoring-instances.json", isDirectory: false),
            bundleDirectory.appendingPathComponent("filter-items.json", isDirectory: false),
            bundleDirectory.appendingPathComponent("server-login.json", isDirectory: false),
        ]

        if let monitoringInstancesURL = MonitoringInstances.storageURLOverride {
            candidates.append(monitoringInstancesURL)
        }
        if let filterItemsURL = FilterItems.storageURLOverride {
            candidates.append(filterItemsURL)
        }
        if let serverLoginURL = ServerLogin.storageURLOverride {
            candidates.append(serverLoginURL)
        }

        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func hasCurrentConfiguredMonitoringRemote() -> Bool {
        return monitoringInstancesJSONCandidates().contains { url in
            guard let data = try? Data(contentsOf: url),
                  let instances = try? JSONDecoder().decode([MonitoringInstance].self, from: data) else {
                return false
            }

            return instances.contains { $0.isConfiguredRemote }
        }
    }

    private static func monitoringInstancesJSONCandidates() -> [URL] {
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        var candidates = [
            bundleDirectory.appendingPathComponent("monitoring-instances.json", isDirectory: false),
        ]

        if let monitoringInstancesURL = MonitoringInstances.storageURLOverride {
            candidates.append(monitoringInstancesURL)
        }

        return candidates
    }

    private static func write(_ report: UpgradeCompatibilityReport) {
        do {
            let reportURL = self.reportURL()
            try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(report)
            try data.write(to: reportURL, options: .atomic)
        } catch {
            NagBarDiagnostics.logStorageError("upgradeCompatibilityReportWriteFailed", error: error)
        }
    }
}
