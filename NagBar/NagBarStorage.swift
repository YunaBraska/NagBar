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
