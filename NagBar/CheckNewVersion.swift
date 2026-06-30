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

    private let versionUrl: String
    private let currentVersion: () -> String?
    private let request: VersionRequest
    private let showWarningAlert: AlertPresenter
    private let log: Logger
    private let deliver: DeliveryQueue

    convenience init() {
        self.init(
            versionUrl: "https://sites.google.com/site/nagbarapp/version",
            currentVersion: {
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
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
        request: @escaping VersionRequest,
        showWarningAlert: @escaping AlertPresenter,
        log: @escaping Logger,
        deliver: @escaping DeliveryQueue
    ) {
        self.versionUrl = versionUrl
        self.currentVersion = currentVersion
        self.request = request
        self.showWarningAlert = showWarningAlert
        self.log = log
        self.deliver = deliver
    }

    func checkNewVersion() {
        self.request(self.versionUrl) { result in
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

        guard let newVersion = json["version"].string else {
            self.log("Unable to find new version key")
            return
        }

        guard let currentVersion = self.currentVersion() else {
            self.log("Unable to find current version")
            return
        }

        if newVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
            self.deliver {
                self.showAlert(data)
            }
        }
    }

    private func showAlert(_ jsonData: Data) {

        guard let json = try? JSONValue(data: jsonData) else {
            return
        }

        let newVersion = json["version"].string!

        guard let changelog = json["changelog"].string else {
            self.log("Unable to find changelog")
            return
        }

        let messageText = NSLocalizedString("newVersionMessageText", comment: "")
        let informativeText = String(format:NSLocalizedString("newVersionInformativeText", comment: ""), newVersion, changelog)

        self.showWarningAlert(messageText, informativeText)
    }
}
