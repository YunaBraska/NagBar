//
//  NagBarDiagnostics.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation
import os

enum NagBarDiagnosticsCategory: String {
    case startup
    case storage
    case refresh
    case localServer
    case statusItem
}

enum FailReason {
    case wrongCredentials
    case ssl
    case unknown
}

struct NagBarRuntimeSnapshot: Equatable {
    let bundleIdentifier: String
    let version: String
    let build: String
    let processIdentifier: Int32
    let applicationSupportPath: String
    let configuredRemoteCount: Int
    let enabledConfiguredRemoteCount: Int
    let usingLocalFallback: Bool
    let legacyRealmFileCount: Int
    let requiresManualReconfiguration: Bool

    static func capture(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        monitoringInstances: MonitoringInstances = MonitoringInstances(),
        upgradeReport: UpgradeCompatibilityReport = UpgradeCompatibility.assess()
    ) -> NagBarRuntimeSnapshot {
        let allInstances = monitoringInstances.getAll().values
        let configuredRemotes = allInstances.filter { $0.isConfiguredRemote }
        let enabledConfiguredRemotes = configuredRemotes.filter { $0.enabled == 1 }

        return NagBarRuntimeSnapshot(
            bundleIdentifier: bundle.bundleIdentifier ?? "com.volendavidov.NagBar",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            processIdentifier: processInfo.processIdentifier,
            applicationSupportPath: NagBarStorage.bundleStorageDirectory().path,
            configuredRemoteCount: configuredRemotes.count,
            enabledConfiguredRemoteCount: enabledConfiguredRemotes.count,
            usingLocalFallback: configuredRemotes.isEmpty,
            legacyRealmFileCount: upgradeReport.legacyRealmFiles.count,
            requiresManualReconfiguration: upgradeReport.requiresManualReconfiguration
        )
    }
}

struct NagBarDiagnosticEvent: Equatable {
    let category: NagBarDiagnosticsCategory
    let message: String
}

enum NagBarDiagnostics {
    static func startupEvent(_ snapshot: NagBarRuntimeSnapshot) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(
            category: .startup,
            message: "startup bundle=\(snapshot.bundleIdentifier) version=\(snapshot.version) build=\(snapshot.build) pid=\(snapshot.processIdentifier) appSupport=\(snapshot.applicationSupportPath) configuredRemotes=\(snapshot.configuredRemoteCount) enabledRemotes=\(snapshot.enabledConfiguredRemoteCount) localFallback=\(snapshot.usingLocalFallback) legacyRealmFiles=\(snapshot.legacyRealmFileCount) manualReconfiguration=\(snapshot.requiresManualReconfiguration)"
        )
    }

    static func upgradeEvent(_ report: UpgradeCompatibilityReport) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(
            category: .storage,
            message: "upgradeCompatibility legacyRealmFiles=\(report.legacyRealmFiles.count) currentJSONFiles=\(report.currentJSONFiles.count) manualReconfiguration=\(report.requiresManualReconfiguration) message=\"\(report.message)\""
        )
    }

    static func refreshFinishedEvent(itemCount: Int, failedCount: Int) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(
            category: .refresh,
            message: "refreshFinished items=\(itemCount) failedInstances=\(failedCount)"
        )
    }

    static func refreshFailureEvent(instance: MonitoringInstance, reason: FailReason, error: Error) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(
            category: .refresh,
            message: "refreshFailure instance=\"\(instance.name)\" type=\(instance.type.rawValue) reason=\(reason.diagnosticName) errorCode=\((error as NSError).code) errorDomain=\"\((error as NSError).domain)\""
        )
    }

    static func localServerEvent(message: String) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(category: .localServer, message: message)
    }

    static func statusItemEvent(message: String) -> NagBarDiagnosticEvent {
        return NagBarDiagnosticEvent(category: .statusItem, message: message)
    }

    static func logStartup(_ snapshot: NagBarRuntimeSnapshot = NagBarRuntimeSnapshot.capture()) {
        log(startupEvent(snapshot), type: .info)
    }

    static func logUpgradeReport(_ report: UpgradeCompatibilityReport) {
        if report.legacyRealmFiles.isEmpty {
            return
        }
        log(upgradeEvent(report), type: report.requiresManualReconfiguration ? .fault : .info)
    }

    static func logRefreshFailure(instance: MonitoringInstance, reason: FailReason, error: Error) {
        log(refreshFailureEvent(instance: instance, reason: reason, error: error), type: .error)
    }

    static func logRefreshFinished(itemCount: Int, failedCount: Int) {
        log(refreshFinishedEvent(itemCount: itemCount, failedCount: failedCount), type: failedCount > 0 ? .error : .info)
    }

    static func logLocalServerStarted(baseURL: String) {
        log(localServerEvent(message: "localIcingaServerStarted baseURL=\(baseURL)"), type: .info)
    }

    static func logLocalServerStartFailed(_ error: Error) {
        let nsError = error as NSError
        log(localServerEvent(message: "localIcingaServerStartFailed domain=\"\(nsError.domain)\" code=\(nsError.code)"), type: .fault)
    }

    static func logLocalServerEvent(message: String) {
        log(localServerEvent(message: message), type: .error)
    }

    static func logStatusItemEvent(message: String) {
        log(statusItemEvent(message: message), type: .info)
    }

    static func logStorageError(_ message: String, error: Error) {
        let nsError = error as NSError
        log(NagBarDiagnosticEvent(category: .storage, message: "\(message) domain=\"\(nsError.domain)\" code=\(nsError.code)"), type: .error)
    }

    private static func log(_ event: NagBarDiagnosticEvent, type: OSLogType) {
        logger(for: event.category).log(level: type, "\(event.message, privacy: .public)")
    }

    private static func logger(for category: NagBarDiagnosticsCategory) -> Logger {
        return Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.volendavidov.NagBar", category: category.rawValue)
    }
}

extension FailReason {
    var diagnosticName: String {
        switch self {
        case .wrongCredentials:
            return "wrongCredentials"
        case .ssl:
            return "ssl"
        case .unknown:
            return "unknown"
        }
    }
}
