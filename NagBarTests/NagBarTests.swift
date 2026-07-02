//
//  NagBarTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 20.08.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import XCTest
@testable import NagBar

class NagBarTests: XCTestCase {

    func testCheckNewVersionRequestsConfiguredVersionURL() {
        var requestedURL = ""
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.3.7", changelog: "No change"),
            currentVersion: "1.3.7",
            requestedURL: { requestedURL = $0 }
        )

        checker.checkNewVersion()

        XCTAssertEqual(requestedURL, "https://updates.example/version.json")
    }

    func testCheckNewVersionDefaultURLUsesGitHubLatestReleaseEndpoint() {
        XCTAssertEqual(CheckNewVersion.defaultVersionUrl, "https://api.github.com/repos/YunaBraska/NagBar/releases/latest")
    }

    func testCheckNewVersionShowsAlertWhenFetchedVersionIsNewer() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.count, 1)
    }

    func testCheckNewVersionShowsAlertForNewerGitHubLatestRelease() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: githubReleasePayload(tag: "v1.4.0", body: "Fixed status refresh", htmlURL: "https://github.com/YunaBraska/NagBar/releases/tag/v1.4.0"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.first?.informativeText, "Version 1.4.0 of NagBar is available with the following features:\nFixed status refresh\n\nDownload at https://github.com/YunaBraska/NagBar/releases/tag/v1.4.0")
    }

    func testCheckNewVersionAlertUsesLocalizedMessageText() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.first?.messageText, "New version available")
    }

    func testCheckNewVersionAlertIncludesVersionAndChangelog() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.first?.informativeText, "Version 1.4.0 of NagBar is available with the following features:\nFixed status refresh\n\nDownload at https://github.com/YunaBraska/NagBar/releases")
    }

    func testCheckNewVersionDoesNotShowAlertWhenVersionMatches() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.3.7", changelog: "No change"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertTrue(shownAlerts.isEmpty)
    }

    func testCheckNewVersionDoesNotShowAlertWhenFetchedVersionIsOlder() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.2.0", changelog: "Old"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertTrue(shownAlerts.isEmpty)
    }

    func testCheckNewVersionLogsInvalidJSON() {
        var logs: [String] = []
        let checker = makeVersionChecker(
            responseData: Data("not-json".utf8),
            currentVersion: "1.3.7",
            log: { logs.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(logs, ["Invalid JSON"])
    }

    func testCheckNewVersionLogsMissingVersionKey() {
        var logs: [String] = []
        let checker = makeVersionChecker(
            responseData: Data(#"{"changelog":"Fixed status refresh"}"#.utf8),
            currentVersion: "1.3.7",
            log: { logs.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(logs, ["Unable to find new version key"])
    }

    func testCheckNewVersionLogsMissingCurrentVersion() {
        var logs: [String] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: nil,
            log: { logs.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(logs, ["Unable to find current version"])
    }

    func testCheckNewVersionLogsMissingChangelogForNewerVersion() {
        var logs: [String] = []
        let checker = makeVersionChecker(
            responseData: Data(#"{"version":"1.4.0"}"#.utf8),
            currentVersion: "1.3.7",
            log: { logs.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(logs, ["Unable to find changelog"])
    }

    func testCheckNewVersionLogsRequestFailureCode() {
        var logs: [String] = []
        let checker = CheckNewVersion(
            versionUrl: "https://updates.example/version.json",
            currentVersion: { "1.3.7" },
            lastCheck: { nil },
            saveLastCheck: { _ in },
            now: { Date(timeIntervalSince1970: 1_000_000) },
            saveAvailableRelease: { _, _, _ in },
            clearAvailableRelease: { },
            request: { _, completion in
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil)))
            },
            showWarningAlert: { _, _ in },
            log: { logs.append($0) },
            deliver: { action in action() }
        )

        checker.checkNewVersion()

        XCTAssertEqual(logs, ["Unable to fetch version data; error code -1003"])
    }

    func testCheckNewVersionSkipsRequestWhenLastCheckIsLessThanOneWeekOld() {
        var requestCount = 0
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            lastCheck: Date(timeIntervalSince1970: 1_000_000),
            now: Date(timeIntervalSince1970: 1_000_000 + CheckNewVersion.weeklyInterval - 1),
            requestedURL: { _ in requestCount += 1 }
        )

        checker.checkNewVersion()

        XCTAssertEqual(requestCount, 0)
    }

    func testCheckNewVersionRequestsWhenLastCheckIsAtLeastOneWeekOld() {
        var requestCount = 0
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.3.7", changelog: "No change"),
            currentVersion: "1.3.7",
            lastCheck: Date(timeIntervalSince1970: 1_000_000),
            now: Date(timeIntervalSince1970: 1_000_000 + CheckNewVersion.weeklyInterval),
            requestedURL: { _ in requestCount += 1 }
        )

        checker.checkNewVersion()

        XCTAssertEqual(requestCount, 1)
    }

    func testCheckNewVersionSavesAttemptTimeAfterRequestCompletes() {
        var savedDates: [Date] = []
        let now = Date(timeIntervalSince1970: 1_234_567)
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.3.7", changelog: "No change"),
            currentVersion: "1.3.7",
            now: now,
            savedCheck: { savedDates.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(savedDates, [now])
    }

    func testCheckNewVersionStoresAvailableReleaseWhenGitHubVersionIsNewer() {
        var savedReleases: [(version: String, releaseURL: String, changelog: String)] = []
        let checker = makeVersionChecker(
            responseData: githubReleasePayload(tag: "v1.4.0", body: "Fixed status refresh", htmlURL: "https://github.com/YunaBraska/NagBar/releases/tag/v1.4.0"),
            currentVersion: "1.3.7",
            savedRelease: { savedReleases.append(($0, $1, $2)) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(savedReleases.count, 1)
        XCTAssertEqual(savedReleases.first?.version, "1.4.0")
        XCTAssertEqual(savedReleases.first?.releaseURL, "https://github.com/YunaBraska/NagBar/releases/tag/v1.4.0")
        XCTAssertEqual(savedReleases.first?.changelog, "Fixed status refresh")
    }

    func testCheckNewVersionClearsAvailableReleaseWhenCurrentVersionIsUpToDate() {
        var clearCount = 0
        let checker = makeVersionChecker(
            responseData: githubReleasePayload(tag: "v1.3.7", body: "No change", htmlURL: "https://github.com/YunaBraska/NagBar/releases/tag/v1.3.7"),
            currentVersion: "1.3.7",
            clearedRelease: { clearCount += 1 }
        )

        checker.checkNewVersion()

        XCTAssertEqual(clearCount, 1)
    }

    func testAvailableReleaseReturnsStoredReleaseWhenVersionAndURLExist() {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = Settings(defaults: defaults)
        settings.setString("2026.07.1820815", forKey: "availableReleaseVersion")
        settings.setString("https://github.com/YunaBraska/NagBar/releases/tag/2026.07.1820815", forKey: "availableReleaseURL")

        let release = AvailableRelease.current(settings: settings)

        XCTAssertEqual(release?.version, "2026.07.1820815")
        XCTAssertEqual(release?.releaseURL, "https://github.com/YunaBraska/NagBar/releases/tag/2026.07.1820815")
    }

    func testAvailableReleaseReturnsNilWhenStoredReleaseIsIncomplete() {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = Settings(defaults: defaults)
        settings.setString("2026.07.1820815", forKey: "availableReleaseVersion")
        settings.setString("", forKey: "availableReleaseURL")

        XCTAssertNil(AvailableRelease.current(settings: settings))
    }

    private func makeVersionChecker(
        responseData: Data,
        currentVersion: String?,
        lastCheck: Date? = nil,
        now: Date = Date(timeIntervalSince1970: 1_000_000),
        requestedURL: @escaping (String) -> Void = { _ in },
        savedCheck: @escaping (Date) -> Void = { _ in },
        savedRelease: @escaping (_ version: String, _ releaseURL: String, _ changelog: String) -> Void = { _, _, _ in },
        clearedRelease: @escaping () -> Void = { },
        shownAlert: @escaping ((messageText: String, informativeText: String)) -> Void = { _ in },
        log: @escaping (String) -> Void = { _ in }
    ) -> CheckNewVersion {
        return CheckNewVersion(
            versionUrl: "https://updates.example/version.json",
            currentVersion: { currentVersion },
            lastCheck: { lastCheck },
            saveLastCheck: savedCheck,
            now: { now },
            saveAvailableRelease: savedRelease,
            clearAvailableRelease: clearedRelease,
            request: { url, completion in
                requestedURL(url)
                completion(.success(HTTPResponse(data: responseData, response: self.httpResponse())))
            },
            showWarningAlert: { messageText, informativeText in
                shownAlert((messageText, informativeText))
            },
            log: log,
            deliver: { action in action() }
        )
    }

    private func versionPayload(version: String, changelog: String) -> Data {
        return Data(#"{"version":"\#(version)","changelog":"\#(changelog)"}"#.utf8)
    }

    private func githubReleasePayload(tag: String, body: String, htmlURL: String) -> Data {
        return Data(#"{"tag_name":"\#(tag)","body":"\#(body)","html_url":"\#(htmlURL)"}"#.utf8)
    }

    private func httpResponse() -> HTTPURLResponse {
        return HTTPURLResponse(
            url: URL(string: "https://updates.example/version.json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
