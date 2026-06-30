//
//  CheckMKHTTPClientFakeServerTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import XCTest

final class CheckMKHTTPClientFakeServerTests: XCTestCase {
    private var server: FakeCheckMKServer?

    override func setUp() {
        super.setUp()
        MonitoringInstances.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
            .appendingPathExtension("monitoring-instances.json")
        MonitoringInstances().resetStorage()
        seedSettings()
        clearCookies()
        ConnectionManager.sharedInstance.update()
    }

    override func tearDown() {
        server?.stop()
        server = nil
        MonitoringInstances().resetStorage()
        MonitoringInstances.storageURLOverride = nil
        clearCookies()
        ConnectionManager.sharedInstance.update()
        super.tearDown()
    }

    func testCookieLoginLoadsHostDataThroughFakeServer() throws {
        let server = try makeServer(authMode: .cookie)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "testpass")
        let hostURL = try XCTUnwrap(monitoringInstance.monitoringProcessor().urlProvider().create().first { $0.urlType == .hosts })

        let data = try fetchData(hostURL.url, client: CheckMKHTTPClient(monitoringInstance))
        let hosts = CheckMKParser(monitoringInstance).parse(urlType: .hosts, data: data)
        let requests = server.requests()

        XCTAssertGreaterThan(hosts.count, 0)
        XCTAssertTrue(requests.contains { $0.method == "HEAD" && $0.path.hasSuffix("/check_mk/") })
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/login.py") && formValues($0.body)["_username"] == "testuser" })
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/login.py") && formValues($0.body)["_password"] == "testpass" })
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.contentType == "application/x-www-form-urlencoded; charset=utf-8" })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") && $0.query.contains("view_name=nagstamon_hosts") && $0.cookie?.contains("auth=ok") == true })
    }

    func testCookieLoginRejectsWrongPassword() throws {
        let server = try makeServer(authMode: .cookie)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "wrongpass")
        let hostURL = try XCTUnwrap(monitoringInstance.monitoringProcessor().urlProvider().create().first { $0.urlType == .hosts })

        let result = fetchResult(hostURL.url, client: CheckMKHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertNil(result.data)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/login.py") })
        XCTAssertFalse(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") })
    }

    func testCookieLoginIgnoresUnrelatedExistingCookie() throws {
        let server = try makeServer(authMode: .cookie)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "testpass")
        let unrelatedCookie = HTTPCookie(properties: [
            .domain: "example.invalid",
            .path: "/",
            .name: "auth",
            .value: "unrelated",
            .secure: "FALSE"
        ])
        if let unrelatedCookie = unrelatedCookie {
            ConnectionManager.sharedInstance.cookies.setCookie(unrelatedCookie)
        }
        let hostURL = try XCTUnwrap(monitoringInstance.monitoringProcessor().urlProvider().create().first { $0.urlType == .hosts })

        let data = try fetchData(hostURL.url, client: CheckMKHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertGreaterThan(data.count, 0)
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/login.py") })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") && $0.cookie?.contains("auth=ok") == true })
    }

    func testBasicAuthLoadsServiceDataThroughFakeServer() throws {
        let server = try makeServer(authMode: .basic)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "testpass")
        let serviceURL = try XCTUnwrap(monitoringInstance.monitoringProcessor().urlProvider().create().first { $0.urlType == .services })

        let data = try fetchData(serviceURL.url, client: CheckMKHTTPClient(monitoringInstance))
        let services = CheckMKParser(monitoringInstance).parse(urlType: .services, data: data)
        let requests = server.requests()

        XCTAssertGreaterThan(services.count, 0)
        XCTAssertTrue(requests.contains { $0.method == "HEAD" && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") && $0.authorization != nil })
        XCTAssertFalse(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/login.py") })
    }

    func testBasicAuthRejectsWrongPassword() throws {
        let server = try makeServer(authMode: .basic)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "wrongpass")
        let serviceURL = try XCTUnwrap(monitoringInstance.monitoringProcessor().urlProvider().create().first { $0.urlType == .services })

        let result = fetchResult(serviceURL.url, client: CheckMKHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertNil(result.data)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/view.py") && $0.authorization != nil })
    }

    func testCheckConnectionReportsUnauthorizedAsFalse() throws {
        let server = try makeServer(authMode: .basic)
        let monitoringInstance = makeMonitoringInstance(server: server, password: "wrongpass")

        let connected = checkConnection(client: CheckMKHTTPClient(monitoringInstance))

        XCTAssertEqual(connected, false)
    }

    private func makeServer(authMode: FakeCheckMKServer.AuthMode) throws -> FakeCheckMKServer {
        let hostStatus = try fixtureData(name: "Check_MKHostStatus")
        let serviceStatus = try fixtureData(name: "Check_MKServiceStatus")
        let server = try FakeCheckMKServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass", authMode: authMode)
        self.server = server
        return server
    }

    private func makeMonitoringInstance(server: FakeCheckMKServer, password: String) -> MonitoringInstance {
        return MonitoringInstance().initDefault(
            name: "fake-checkmk",
            url: "http://127.0.0.1:\(server.port)/site/check_mk/",
            type: .Check_MK,
            username: "testuser",
            password: password,
            enabled: 1
        )
    }

    private func fixtureData(name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: ""))
        return try Data(contentsOf: url)
    }

    private func fetchData(_ url: String, client: HTTPClient) throws -> Data {
        let result = fetchResult(url, client: client)
        if let loadedError = result.error {
            throw loadedError
        }
        return try XCTUnwrap(result.data)
    }

    private func fetchResult(_ url: String, client: HTTPClient) -> (data: Data?, error: Error?) {
        let expectation = self.expectation(description: "Fetch \(url)")
        var loadedData: Data?
        var loadedError: Error?

        client.get(url).done { data in
            loadedData = data
            expectation.fulfill()
        }.catch { error in
            loadedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return (loadedData, loadedError)
    }

    private func checkConnection(client: HTTPClient) -> Bool? {
        let expectation = self.expectation(description: "Check connection")
        var connected: Bool?

        client.checkConnection().done { value in
            connected = value
            expectation.fulfill()
        }.catch { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return connected
    }

    private func formValues(_ body: String) -> [String: String] {
        let components = URLComponents(string: "http://localhost/?" + body)
        return Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func clearCookies() {
        for cookie in ConnectionManager.sharedInstance.cookies.cookies ?? [] {
            ConnectionManager.sharedInstance.cookies.deleteCookie(cookie)
        }
    }

    private func seedSettings() {
        let settings = [
            "critical": "1",
            "warning": "1",
            "unknown": "1",
            "pending": "1",
            "ok": "0",
            "down": "1",
            "unreachable": "1",
            "hostPending": "1",
            "up": "0",
            "scheduledDowntime": "0",
            "acknowledged": "0",
            "flapping": "0",
            "checksDisabled": "0",
            "disabledNotifications": "0",
            "softState": "0",
            "hostScheduledDowntime": "0",
            "hostAcknowledged": "0",
            "hostFlapping": "0",
            "hostDisabledNotifications": "0",
            "hostSoftState": "0",
            "hostChecksDisabled": "0",
            "sortColumn": "1",
            "sortOrder": "1",
            "skipServicesOfHostsWithScD": "0",
            "savePassword": "0",
            "acceptInvalidCertificates": "0",
            "useNotifications": "0",
            "enableAudibleAlarms": "0",
        ]

        let appSettings = Settings()
        appSettings.resetKnownSettings()
        for (key, value) in settings {
            appSettings.setString(value, forKey: key)
        }
    }
}
