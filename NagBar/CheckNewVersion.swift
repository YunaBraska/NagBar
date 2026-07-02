//
//  CheckNewVersion.swift
//  NagBar
//
//  Created by Volen Davidov on 01.05.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class CheckNewVersion {
    typealias VersionRequest = (_ url: String, _ completion: @escaping (Result<HTTPResponse, Error>) -> Void) -> Void
    typealias AlertPresenter = (_ messageText: String, _ informativeText: String) -> Void
    typealias Logger = (_ message: String) -> Void
    typealias DeliveryQueue = (_ action: @escaping () -> Void) -> Void
    typealias DateProvider = () -> Date
    typealias LastCheckReader = () -> Date?
    typealias LastCheckWriter = (Date) -> Void
    typealias AvailableReleaseWriter = (_ version: String, _ releaseURL: String, _ changelog: String) -> Void
    typealias AvailableReleaseClearer = () -> Void

    static let defaultVersionUrl = "https://api.github.com/repos/YunaBraska/NagBar/releases/latest"
    static let weeklyInterval: TimeInterval = 7 * 24 * 60 * 60

    private let versionUrl: String
    private let currentVersion: () -> String?
    private let lastCheck: LastCheckReader
    private let saveLastCheck: LastCheckWriter
    private let now: DateProvider
    private let saveAvailableRelease: AvailableReleaseWriter
    private let clearAvailableRelease: AvailableReleaseClearer
    private let request: VersionRequest
    private let showWarningAlert: AlertPresenter
    private let log: Logger
    private let deliver: DeliveryQueue

    convenience init() {
        self.init(
            versionUrl: Self.defaultVersionUrl,
            currentVersion: {
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            },
            lastCheck: {
                let timestamp = Settings().doubleForKey("newVersionLastCheck")
                guard timestamp > 0 else {
                    return nil
                }

                return Date(timeIntervalSince1970: timestamp)
            },
            saveLastCheck: { date in
                Settings().setString(String(date.timeIntervalSince1970), forKey: "newVersionLastCheck")
            },
            now: {
                Date()
            },
            saveAvailableRelease: { version, releaseURL, changelog in
                Settings().setString(version, forKey: "availableReleaseVersion")
                Settings().setString(releaseURL, forKey: "availableReleaseURL")
                Settings().setString(changelog, forKey: "availableReleaseNotes")
            },
            clearAvailableRelease: {
                Settings().setString("", forKey: "availableReleaseVersion")
                Settings().setString("", forKey: "availableReleaseURL")
                Settings().setString("", forKey: "availableReleaseNotes")
            },
            request: { url, completion in
                ConnectionManager.sharedInstance.request(url, completion: completion)
            },
            showWarningAlert: { messageText, informativeText in
                NagBarAlert().showWarningAlert(messageText, informativeText: informativeText)
            },
            log: { message in
                NSLog(message)
            },
            deliver: { action in
                DispatchQueue.main.async(execute: action)
            }
        )
    }

    init(
        versionUrl: String,
        currentVersion: @escaping () -> String?,
        lastCheck: @escaping LastCheckReader,
        saveLastCheck: @escaping LastCheckWriter,
        now: @escaping DateProvider,
        saveAvailableRelease: @escaping AvailableReleaseWriter,
        clearAvailableRelease: @escaping AvailableReleaseClearer,
        request: @escaping VersionRequest,
        showWarningAlert: @escaping AlertPresenter,
        log: @escaping Logger,
        deliver: @escaping DeliveryQueue
    ) {
        self.versionUrl = versionUrl
        self.currentVersion = currentVersion
        self.lastCheck = lastCheck
        self.saveLastCheck = saveLastCheck
        self.now = now
        self.saveAvailableRelease = saveAvailableRelease
        self.clearAvailableRelease = clearAvailableRelease
        self.request = request
        self.showWarningAlert = showWarningAlert
        self.log = log
        self.deliver = deliver
    }

    func checkNewVersion() {
        let checkDate = self.now()
        if let lastCheck = self.lastCheck(), checkDate.timeIntervalSince(lastCheck) < Self.weeklyInterval {
            return
        }

        self.request(self.versionUrl) { result in
            self.saveLastCheck(checkDate)
            switch result {
            case .success(let response):
                self.compareVersions(response.data)
            case .failure(let error):
                self.log("Unable to fetch version data; error code " + String((error as NSError).code))
            }
        }
    }

    private func compareVersions(_ data: Data) {

        guard let json = try? JSONValue(data: data) else {
            self.log("Invalid JSON")
            return
        }

        guard let release = self.releaseInfo(from: json) else {
            if json["version"].string == nil && json["tag_name"].string == nil {
                self.log("Unable to find new version key")
            }
            return
        }

        guard let currentVersion = self.currentVersion() else {
            self.log("Unable to find current version")
            return
        }

        if release.version.compare(currentVersion, options: .numeric) == .orderedDescending {
            self.saveAvailableRelease(release.version, release.releaseURL, release.changelog)
            self.deliver {
                self.showAlert(release)
            }
        } else {
            self.clearAvailableRelease()
        }
    }

    private func showAlert(_ release: ReleaseInfo) {
        let messageText = NSLocalizedString("newVersionMessageText", comment: "")
        let informativeText = String(format:NSLocalizedString("newVersionInformativeText", comment: ""), release.version, release.changelog, release.releaseURL)

        self.showWarningAlert(messageText, informativeText)
    }

    private func releaseInfo(from json: JSONValue) -> ReleaseInfo? {
        if let version = json["version"].string {
            guard let changelog = json["changelog"].string else {
                self.log("Unable to find changelog")
                return nil
            }

            return ReleaseInfo(
                version: normalizedVersion(version),
                changelog: changelog,
                releaseURL: "https://github.com/YunaBraska/NagBar/releases"
            )
        }

        guard let tagName = json["tag_name"].string else {
            return nil
        }

        return ReleaseInfo(
            version: normalizedVersion(tagName),
            changelog: json["body"].string ?? "",
            releaseURL: json["html_url"].string ?? "https://github.com/YunaBraska/NagBar/releases"
        )
    }

    private func normalizedVersion(_ version: String) -> String {
        if version.lowercased().hasPrefix("v") {
            return String(version.dropFirst())
        }

        return version
    }
}

struct AvailableRelease {
    let version: String
    let releaseURL: String

    static func current(settings: Settings = Settings()) -> AvailableRelease? {
        guard let version = settings.stringForKey("availableReleaseVersion"),
              let releaseURL = settings.stringForKey("availableReleaseURL"),
              !version.isEmpty,
              !releaseURL.isEmpty else {
            return nil
        }

        return AvailableRelease(version: version, releaseURL: releaseURL)
    }
}

private struct ReleaseInfo {
    let version: String
    let changelog: String
    let releaseURL: String
}
