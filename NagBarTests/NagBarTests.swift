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

    func testCheckNewVersionAlertUsesLocalizedMessageText() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.first?.messageText, "newVersionMessageText")
    }

    func testCheckNewVersionAlertIncludesVersionAndChangelog() {
        var shownAlerts: [(messageText: String, informativeText: String)] = []
        let checker = makeVersionChecker(
            responseData: versionPayload(version: "1.4.0", changelog: "Fixed status refresh"),
            currentVersion: "1.3.7",
            shownAlert: { shownAlerts.append($0) }
        )

        checker.checkNewVersion()

        XCTAssertEqual(shownAlerts.first?.informativeText, "newVersionInformativeText")
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

    private func makeVersionChecker(
        responseData: Data,
        currentVersion: String?,
        requestedURL: @escaping (String) -> Void = { _ in },
        shownAlert: @escaping ((messageText: String, informativeText: String)) -> Void = { _ in },
        log: @escaping (String) -> Void = { _ in }
    ) -> CheckNewVersion {
        return CheckNewVersion(
            versionUrl: "https://updates.example/version.json",
            currentVersion: { currentVersion },
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

    private func httpResponse() -> HTTPURLResponse {
        return HTTPURLResponse(
            url: URL(string: "https://updates.example/version.json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
