//
//  LoadMonitoringDataFakeIcingaTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest
@testable import NagBar

final class LoadMonitoringDataFakeIcingaTests: XCTestCase {
    private var server: FakeIcingaServer?

    override func setUp() {
        super.setUp()
        MonitoringInstances.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
            .appendingPathExtension("monitoring-instances.json")
        MonitoringInstances().resetStorage()
        PasswordStore.sharedInstance.removeAll()
        OldStatusData.sharedInstance.statusData = nil
        seedSettings()
    }

    override func tearDown() {
        server?.stop()
        server = nil
        MonitoringInstances().resetStorage()
        MonitoringInstances.storageURLOverride = nil
        PasswordStore.sharedInstance.removeAll()
        OldStatusData.sharedInstance.statusData = nil
        AlertCommandFeedbackPresenter.presentAlert = { alert in
            alert.runModal()
        }
        super.tearDown()
    }

    func testIcingaProcessorLoadsDataThroughFakeServer() throws {
        let hostStatus = try fixtureData(name: "IcingaHostStatus", type: "htm")
        let serviceStatus = try fixtureData(name: "IcingaServiceStatus", type: "htm")
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass")
        self.server = server

        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-icinga",
            url: "http://127.0.0.1:\(server.port)/icinga/cgi-bin/",
            type: .Icinga,
            username: "testuser",
            password: "testpass",
            enabled: 1
        )
        monitoringInstance.type = .Icinga
        PasswordStore.sharedInstance.set("fake-icinga", password: "testpass")
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        ConnectionManager.sharedInstance.update()

        let processor = monitoringInstance.monitoringProcessor()
        let urls = processor.urlProvider().create().sorted { $0.priority < $1.priority }
        let hostURL = try XCTUnwrap(urls.first { $0.urlType == .hosts })
        let serviceURL = try XCTUnwrap(urls.first { $0.urlType == .services })
        let hostData = try fetchData(hostURL.url, client: processor.httpClient())
        let serviceData = try fetchData(serviceURL.url, client: processor.httpClient())

        let hosts = processor.parser().parse(urlType: .hosts, data: hostData).compactMap { $0 as? HostMonitoringItem }
        let services = processor.parser().parse(urlType: .services, data: serviceData).compactMap { $0 as? ServiceMonitoringItem }
        let requests = server.requests()

        XCTAssertGreaterThan(hosts.count, 0)
        XCTAssertGreaterThan(services.count, 0)
        XCTAssertTrue(hosts.contains { $0.monitoringInstance?.name == "fake-icinga" && $0.host == "hplj2605dn" && $0.status == "DOWN" })
        XCTAssertTrue(services.contains { $0.monitoringInstance?.name == "fake-icinga" && $0.host == "localhost" && $0.service == "Total Processes" && $0.status == "WARNING" })
        XCTAssertTrue(requests.contains { $0.path.hasSuffix("/status.cgi") && $0.query.contains("hostgroup=all") })
        XCTAssertTrue(requests.contains { $0.path.hasSuffix("/status.cgi") && $0.query.contains("service=all") })
        XCTAssertTrue(requests.contains { $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.authorization != nil })
    }

    func testRefreshStatusDataLoadsEnabledIcingaRemoteThroughFakeServerAndPublishesResults() throws {
        let server = try makeServer()
        _ = storeEnabledMonitoringInstance(server: server, type: .Icinga)
        let refreshed = expectation(description: "Refresh publishes status data")
        var publishedResults: [MonitoringItem] = []
        var publishedFailures: FailedMonitoringInstances = [:]
        let loader = LoadMonitoringDataCore(loadStatusBar: { results, failedMonitoringInstances in
            publishedResults = results
            publishedFailures = failedMonitoringInstances
        })

        loader.refreshStatusData { _, _ in
            refreshed.fulfill()
        }

        waitForExpectations(timeout: 5)
        let requests = server.requests()
        XCTAssertTrue(publishedFailures.isEmpty)
        XCTAssertGreaterThan(publishedResults.count, 0)
        XCTAssertTrue(publishedResults.contains { $0.monitoringInstance?.name == "fake-Icinga" && $0.host == "hplj2605dn" && $0.status == "DOWN" })
        XCTAssertTrue(publishedResults.contains { $0.monitoringInstance?.name == "fake-Icinga" && $0.host == "localhost" && $0.service == "Total Processes" && $0.status == "WARNING" })
        XCTAssertEqual(OldStatusData.sharedInstance.statusData?.count, publishedResults.count)
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/status.cgi") && $0.query.contains("hostgroup=all") })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/status.cgi") && $0.query.contains("service=all") })
        XCTAssertTrue(requests.contains { $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.authorization != nil })
    }

    func testLoadMonitoringDataWrapperPublishesFakeServerRefreshThroughInjectedStatusBarLoader() throws {
        let server = try makeServer()
        _ = storeEnabledMonitoringInstance(server: server, type: .Icinga)
        let refreshed = expectation(description: "Wrapper refresh publishes status data")
        var publishedResults: [MonitoringItem] = []
        var publishedFailures: FailedMonitoringInstances = [:]
        let loader = LoadMonitoringData(loadStatusBar: { results, failedMonitoringInstances in
            publishedResults = results
            publishedFailures = failedMonitoringInstances
        })

        loader.refreshStatusData { _, _ in
            refreshed.fulfill()
        }

        waitForExpectations(timeout: 5)
        XCTAssertTrue(publishedFailures.isEmpty)
        XCTAssertGreaterThan(publishedResults.count, 0)
        XCTAssertTrue(publishedResults.contains { $0.monitoringInstance?.name == "fake-Icinga" && $0.host == "hplj2605dn" && $0.status == "DOWN" })
        XCTAssertTrue(publishedResults.contains { $0.monitoringInstance?.name == "fake-Icinga" && $0.host == "localhost" && $0.service == "Total Processes" && $0.status == "WARNING" })
        XCTAssertEqual(OldStatusData.sharedInstance.statusData?.count, publishedResults.count)
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization != nil })
    }

    func testLoadMonitoringDataWrapperExposesRefreshActions() {
        let loader = LoadMonitoringData(loadStatusBar: { _, _ in })
        let firstAction = RecordingRefreshAction()
        let secondAction = RecordingRefreshAction()

        loader.dataRefreshActions = [firstAction, secondAction]

        XCTAssertEqual(loader.dataRefreshActions.count, 2)
        XCTAssertTrue(loader.dataRefreshActions[0] as? RecordingRefreshAction === firstAction)
        XCTAssertTrue(loader.dataRefreshActions[1] as? RecordingRefreshAction === secondAction)
    }

    func testNagBarAlertBuildsWarningAlertWithoutRunningModal() throws {
        var capturedAlert: NSAlert?
        NagBarAlert.presentAlert = { capturedAlert = $0 }

        NagBarAlert().showWarningAlert("Configuration problem", informativeText: "The Icinga URL is invalid.")

        let alert = try XCTUnwrap(capturedAlert)
        XCTAssertEqual(alert.messageText, "Configuration problem")
        XCTAssertEqual(alert.informativeText, "The Icinga URL is invalid.")
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map { $0.title }, ["OK"])
    }

    func testRefreshStatusDataReportsWrongCredentialsForFailedIcingaRemote() throws {
        let server = try makeServer()
        _ = storeEnabledMonitoringInstance(server: server, type: .Icinga, password: "wrongpass")
        let refreshed = expectation(description: "Refresh publishes failed instance")
        var publishedResults: [MonitoringItem] = []
        var publishedFailures: FailedMonitoringInstances = [:]
        let loader = LoadMonitoringDataCore(loadStatusBar: { results, failedMonitoringInstances in
            publishedResults = results
            publishedFailures = failedMonitoringInstances
        })

        loader.refreshStatusData { _, _ in
            refreshed.fulfill()
        }

        waitForExpectations(timeout: 5)
        let failed = try XCTUnwrap(publishedFailures.first)
        XCTAssertTrue(publishedResults.isEmpty)
        XCTAssertEqual(failed.key.name, "fake-Icinga")
        XCTAssertEqual(failed.value.diagnosticName, "wrongCredentials")
        XCTAssertEqual(OldStatusData.sharedInstance.statusData?.count, 0)
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization == nil })
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization != nil })
    }

    func testRefreshStatusDataPublishesHealthyResultsAndFailedInstanceWhenOneRemoteFails() throws {
        let server = try makeServer()
        let healthy = storeEnabledMonitoringInstance(server: server, type: .Icinga)
        let failing = makeMonitoringInstance(server: server, type: .Icinga, password: "wrongpass")
        failing.name = "fake-Icinga-wrong-password"
        MonitoringInstances().insert(key: failing.name, value: failing)
        MonitoringInstances().updatePassword(monitoringInstance: failing, password: "wrongpass")
        ConnectionManager.sharedInstance.update()
        let refreshed = expectation(description: "Refresh publishes mixed success and failure")
        var publishedResults: [MonitoringItem] = []
        var publishedFailures: FailedMonitoringInstances = [:]
        let loader = LoadMonitoringDataCore(loadStatusBar: { results, failedMonitoringInstances in
            publishedResults = results
            publishedFailures = failedMonitoringInstances
        })

        loader.refreshStatusData { _, _ in
            refreshed.fulfill()
        }

        waitForExpectations(timeout: 5)
        let failed = try XCTUnwrap(publishedFailures.first)
        XCTAssertEqual(failed.key.name, "fake-Icinga-wrong-password")
        XCTAssertEqual(failed.value.diagnosticName, "wrongCredentials")
        XCTAssertGreaterThan(publishedResults.count, 0)
        XCTAssertTrue(publishedResults.allSatisfy { $0.monitoringInstance?.name == healthy.name })
        XCTAssertTrue(publishedResults.contains { $0.host == "hplj2605dn" && $0.status == "DOWN" })
        XCTAssertTrue(publishedResults.contains { $0.host == "localhost" && $0.service == "Total Processes" && $0.status == "WARNING" })
        XCTAssertEqual(OldStatusData.sharedInstance.statusData?.count, publishedResults.count)
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization == nil })
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization == ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "testpass") })
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.authorization == ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "wrongpass") })
    }

    func testRefreshStatusDataProcessesExistingRefreshActionsBeforePublishing() throws {
        let server = try makeServer()
        _ = storeEnabledMonitoringInstance(server: server, type: .Icinga)
        let oldItem = makeService(host: "old-host", service: "Old Service", monitoringInstance: makeMonitoringInstance(server: server, type: .Icinga))
        OldStatusData.sharedInstance.statusData = [oldItem]
        let action = RecordingRefreshAction()
        let refreshed = expectation(description: "Refresh publishes action-processed status data")
        var publishedResults: [MonitoringItem] = []
        let loader = LoadMonitoringDataCore(loadStatusBar: { results, _ in
            publishedResults = results
        })
        loader.dataRefreshActions = [action]

        loader.refreshStatusData { _, _ in
            refreshed.fulfill()
        }

        waitForExpectations(timeout: 5)
        XCTAssertEqual(action.processCount, 1)
        XCTAssertEqual(action.oldResults.first?.host, "old-host")
        XCTAssertEqual(action.newResults.count, publishedResults.count)
        XCTAssertGreaterThan(action.newResults.count, 0)
        XCTAssertEqual(OldStatusData.sharedInstance.statusData?.count, publishedResults.count)
    }

    func testNagiosHTTPClientRejectsUnauthorizedGet() throws {
        let hostStatus = try fixtureData(name: "IcingaHostStatus", type: "htm")
        let serviceStatus = try fixtureData(name: "IcingaServiceStatus", type: "htm")
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass")
        self.server = server

        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-icinga",
            url: "http://127.0.0.1:\(server.port)/icinga/cgi-bin/",
            type: .Icinga,
            username: "testuser",
            password: "wrongpass",
            enabled: 1
        )
        ConnectionManager.sharedInstance.update()

        let result = fetchResult("http://127.0.0.1:\(server.port)/icinga/cgi-bin/status.cgi?hostgroup=all&style=hostdetail", client: NagiosHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertNotNil(result.error)
        XCTAssertNil(result.data)
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.authorization != nil })
    }

    func testNagiosHTTPClientRejectsAuthenticatedNotFoundGet() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)

        let result = fetchResult("http://127.0.0.1:\(server.port)/icinga/cgi-bin/missing.cgi", client: NagiosHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertNotNil(result.error)
        XCTAssertNil(result.data)
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/missing.cgi") && $0.authorization != nil })
    }

    func testNagiosHTTPClientReportsUnauthorizedConnectionCheckAsFalse() throws {
        let hostStatus = try fixtureData(name: "IcingaHostStatus", type: "htm")
        let serviceStatus = try fixtureData(name: "IcingaServiceStatus", type: "htm")
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass")
        self.server = server

        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-icinga",
            url: "http://127.0.0.1:\(server.port)/icinga/cgi-bin/",
            type: .Icinga,
            username: "testuser",
            password: "wrongpass",
            enabled: 1
        )
        ConnectionManager.sharedInstance.update()

        let expectation = self.expectation(description: "Check connection")
        var connected: Bool?
        NagiosHTTPClient(monitoringInstance).checkConnection().done { value in
            connected = value
            expectation.fulfill()
        }.catch { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        let requests = server.requests()

        XCTAssertEqual(connected, false)
        XCTAssertTrue(requests.contains { $0.method == "HEAD" && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "HEAD" && $0.authorization != nil })
    }

    func testThrukProcessorLoadsJSONThroughFakeServer() throws {
        let hostStatus = try fixtureData(name: "ThrukHostStatus", type: nil)
        let serviceStatus = try fixtureData(name: "ThrukServiceStatus", type: nil)
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass")
        self.server = server
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Thruk)

        let processor = monitoringInstance.monitoringProcessor()
        let urls = processor.urlProvider().create().sorted { $0.priority < $1.priority }
        let hostURL = try XCTUnwrap(urls.first { $0.urlType == .hosts })
        let serviceURL = try XCTUnwrap(urls.first { $0.urlType == .services })
        let hostData = try fetchData(hostURL.url, client: processor.httpClient())
        let serviceData = try fetchData(serviceURL.url, client: processor.httpClient())

        let hosts = processor.parser().parse(urlType: .hosts, data: hostData).compactMap { $0 as? HostMonitoringItem }
        let services = processor.parser().parse(urlType: .services, data: serviceData).compactMap { $0 as? ServiceMonitoringItem }
        let requests = server.requests()

        XCTAssertTrue(processor is ThrukProcessor)
        XCTAssertGreaterThan(hosts.count, 0)
        XCTAssertGreaterThan(services.count, 0)
        XCTAssertTrue(hosts.contains { $0.monitoringInstance?.name == "fake-Thruk" && $0.host == "localhost" && $0.status == "UP" })
        XCTAssertTrue(services.contains { $0.monitoringInstance?.name == "fake-Thruk" && $0.host == "localhost" && $0.service == "Current Load" && $0.status == "OK" })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/status.cgi") && $0.query.contains("hostgroup=all") && $0.query.contains("view_mode=json") })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/status.cgi") && $0.query.contains("service=all") && $0.query.contains("view_mode=json") })
        XCTAssertTrue(requests.allSatisfy { $0.authorization == ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "testpass") })
        XCTAssertTrue(requests.allSatisfy { $0.authorization != nil })
        XCTAssertTrue(requests.allSatisfy { $0.method != "HEAD" })
    }

    func testThrukHTTPClientRejectsUnauthorizedGetWithoutChallengeRetry() throws {
        let server = try makeThrukServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Thruk, password: "wrongpass")

        let result = fetchResult("http://127.0.0.1:\(server.port)/icinga/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&view_mode=json", client: ThrukHTTPClient(monitoringInstance))
        let requests = server.requests()

        XCTAssertNotNil(result.error)
        XCTAssertNil(result.data)
        let getRequests = requests.filter { $0.method == "GET" }
        XCTAssertGreaterThanOrEqual(getRequests.count, 1)
        XCTAssertTrue(getRequests.allSatisfy { $0.authorization == ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "wrongpass") })
    }

    func testThrukHTTPClientReportsUnauthorizedConnectionCheckAsFalse() throws {
        let server = try makeThrukServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Thruk, password: "wrongpass")
        let expectation = self.expectation(description: "Thruk check connection")
        var connected: Bool?

        ThrukHTTPClient(monitoringInstance).checkConnection().done { value in
            connected = value
            expectation.fulfill()
        }.catch { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        let requests = server.requests()
        XCTAssertEqual(connected, false)
        let getRequests = requests.filter { $0.method == "GET" }
        XCTAssertGreaterThanOrEqual(getRequests.count, 1)
        XCTAssertTrue(getRequests.allSatisfy { $0.authorization == ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "wrongpass") })
    }

    func testThrukHTTPClientPostsFormWithBasicAuthAndCurlUserAgent() throws {
        let server = try makeThrukServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Thruk)

        let result = waitForDataResult(ThrukHTTPClient(monitoringInstance).post("http://127.0.0.1:\(server.port)/icinga/cgi-bin/cmd.cgi", postData: [
            "cmd_typ": "7",
            "host": "web 01",
            "service": "Disk / Root"
        ]))
        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)

        XCTAssertNotNil(result.data)
        XCTAssertNil(result.error)
        XCTAssertEqual(request.contentType, "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(request.authorization, ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "testpass"))
        XCTAssertEqual(request.userAgent, "curl")
        XCTAssertEqual(form["cmd_typ"], "7")
        XCTAssertEqual(form["host"], "web 01")
        XCTAssertEqual(form["service"], "Disk / Root")
    }

    func testThrukProcessorAcknowledgeServiceUsesInheritedNagiosCommandWithThrukHTTPHeaders() throws {
        let server = try makeThrukServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Thruk)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().acknowledge([service], comment: "Handled in Thruk"))

        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(commandResult.result?.action, .acknowledge)
        XCTAssertEqual(commandResult.result?.itemCount, 1)
        XCTAssertNil(commandResult.error)
        XCTAssertEqual(request.authorization, ConnectionManager.sharedInstance.authorizationHeader(username: "testuser", password: "testpass"))
        XCTAssertEqual(request.userAgent, "curl")
        XCTAssertEqual(request.contentType, "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(form["cmd_typ"], "34")
        XCTAssertEqual(form["cmd_mod"], "2")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["service"], "Disk")
        XCTAssertEqual(form["com_data"], "Handled in Thruk")
        XCTAssertEqual(form["btnSubmit"], "Commit")
    }

    func testNagiosAcknowledgeHostPostsCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().acknowledge([host], comment: "Known outage"))

        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(commandResult.result?.action, .acknowledge)
        XCTAssertEqual(commandResult.result?.itemCount, 1)
        XCTAssertNil(commandResult.error)
        XCTAssertEqual(form["cmd_typ"], "33")
        XCTAssertEqual(form["cmd_mod"], "2")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["com_data"], "Known outage")
        XCTAssertEqual(form["btnSubmit"], "Commit")
        XCTAssertNil(form["service"])
        XCTAssertEqual(request.contentType, "application/x-www-form-urlencoded; charset=utf-8")
    }

    func testNagiosAcknowledgeFailureRejectsCommandResultWhenFakeServerRejectsAuth() throws {
        let server = try makeServer()
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-icinga",
            url: "http://127.0.0.1:\(server.port)/icinga/cgi-bin/",
            type: .Icinga,
            username: "testuser",
            password: "wrongpass",
            enabled: 1
        )
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().acknowledge([host], comment: "Known outage"))
        let requests = server.requests()

        XCTAssertNil(commandResult.result)
        XCTAssertNotNil(commandResult.error)
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/cmd.cgi") && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "POST" && $0.path.hasSuffix("/cmd.cgi") && $0.authorization != nil })
    }

    func testNagiosAcknowledgeServicePostsCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().acknowledge([service], comment: "Handled")

        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(form["cmd_typ"], "34")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["service"], "Disk")
        XCTAssertEqual(form["com_data"], "Handled")
    }

    func testNagiosScheduleHostDowntimePostsCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().scheduleDowntime([host], from: "30-06-2026 12:00:00", to: "30-06-2026 13:00:00", comment: "Maintenance", type: "1", hours: "1", minutes: "0")

        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(form["cmd_typ"], "55")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["start_time"], "30-06-2026 12:00:00")
        XCTAssertEqual(form["end_time"], "30-06-2026 13:00:00")
        XCTAssertEqual(form["fixed"], "1")
        XCTAssertEqual(form["hours"], "1")
        XCTAssertEqual(form["minutes"], "0")
        XCTAssertEqual(form["com_data"], "Maintenance")
    }

    func testNagiosRecheckServiceFetchesStartTimeAndPostsCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().recheck([service])

        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        let requests = server.requests()
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/cmd.cgi") && $0.query.contains("cmd_typ=55") })
        XCTAssertEqual(form["cmd_typ"], "7")
        XCTAssertEqual(form["cmd_mod"], "2")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["service"], "Disk")
        XCTAssertEqual(form["force_check"], "on")
        XCTAssertEqual(form["start_time"], "30-06-2026 12:00:00")
    }

    func testNagiosRecheckMixedHostAndServicePostsOneCommandPerItem() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().recheck([host, service]))

        let requests = authorizedPosts(pathSuffix: "/cmd.cgi")
        let forms = requests.map { formValues($0.body) }
        XCTAssertEqual(commandResult.result?.action, .recheck)
        XCTAssertEqual(commandResult.result?.itemCount, 2)
        XCTAssertNil(commandResult.error)
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.path.hasSuffix("/cmd.cgi") && $0.query.contains("cmd_typ=55") })
        XCTAssertTrue(forms.contains { $0["cmd_typ"] == "96" && $0["host"] == "web-01" && $0["service"] == nil && $0["force_check"] == "on" })
        XCTAssertTrue(forms.contains { $0["cmd_typ"] == "7" && $0["host"] == "web-01" && $0["service"] == "Disk" && $0["force_check"] == "on" })
    }

    func testIcinga2AcknowledgeServicePostsJSONCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().acknowledge([service], comment: "Known issue")

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/acknowledge-problem")
        let json = try jsonValues(request.body)
        XCTAssertEqual(request.query, "service=web-01!Disk")
        XCTAssertEqual(json["author"], "testuser")
        XCTAssertEqual(json["comment"], "Known issue")
        XCTAssertEqual(request.contentType, "application/json")
    }

    func testIcinga2AcknowledgeEncodesServiceQueryForSpecialCharacters() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let service = makeService(host: "web 01", service: "Disk / Root", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().acknowledge([service], comment: "Known issue")

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/acknowledge-problem")
        XCTAssertEqual(request.query, "service=web%2001!Disk%20%2F%20Root")
    }

    func testIcinga2RecheckEncodesHostQueryForSpecialCharacters() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "db / primary", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().recheck([host])

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/reschedule-check")
        XCTAssertEqual(request.query, "host=db%20%2F%20primary")
    }

    func testIcinga2RecheckHostPostsJSONCommandToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().recheck([host]))

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/reschedule-check")
        let json = try jsonValues(request.body)
        XCTAssertEqual(commandResult.result?.action, .recheck)
        XCTAssertEqual(commandResult.result?.itemCount, 1)
        XCTAssertNil(commandResult.error)
        XCTAssertEqual(request.query, "host=web-01")
        XCTAssertEqual(json["force_check"], "true")
        XCTAssertEqual(request.contentType, "application/json")
    }

    func testRecheckMenuActionShowsSuccessFeedbackAfterBackendAcceptsCommand() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let menuItem = NSMenuItem()
        menuItem.representedObject = [host]
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Recheck success feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }

        RecheckAction().action(menuItem)

        waitForExpectations(timeout: 5)
        let request = try waitForAuthorizedPost(pathSuffix: "/actions/reschedule-check")
        XCTAssertEqual(request.query, "host=web-01")
        XCTAssertEqual(presenter.successes.count, 1)
        XCTAssertEqual(presenter.successes.first?.action, .recheck)
        XCTAssertEqual(presenter.successes.first?.itemCount, 1)
        XCTAssertTrue(presenter.failures.isEmpty)
    }

    func testRecheckMenuActionShowsFailureFeedbackAfterBackendRejectsCommand() throws {
        let server = try makeServer()
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-icinga",
            url: "http://127.0.0.1:\(server.port)/icinga/cgi-bin/",
            type: .Icinga,
            username: "testuser",
            password: "wrongpass",
            enabled: 1
        )
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let menuItem = NSMenuItem()
        menuItem.representedObject = [host]
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Recheck failure feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }

        RecheckAction().action(menuItem)

        waitForExpectations(timeout: 5)
        let requests = server.requests()
        XCTAssertTrue(presenter.successes.isEmpty)
        XCTAssertEqual(presenter.failures.count, 1)
        XCTAssertEqual(presenter.failures.first?.action, .recheck)
        XCTAssertNotNil(presenter.failures.first?.error)
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/cmd.cgi") && $0.authorization == nil })
        XCTAssertTrue(requests.contains { $0.method == "GET" && $0.path.hasSuffix("/cmd.cgi") && $0.authorization != nil })
    }

    func testAcknowledgeMenuActionOpensWindowWithSelectedMonitoringItems() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let menuItem = NSMenuItem()
        menuItem.representedObject = [host]

        AcknowledgeAction().action(menuItem)

        let window = try XCTUnwrap(commandWindow(withIdentifier: CommandWindowAccessibility.acknowledgeWindowIdentifier))
        defer { window.close() }
        let comment = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.acknowledgeCommentIdentifier, in: window.contentView))
        XCTAssertEqual(comment.accessibilityLabel(), "Acknowledgement comment")
    }

    func testScheduleDowntimeMenuActionOpensWindowWithSelectedMonitoringItemsAndBackendTime() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let menuItem = NSMenuItem()
        menuItem.representedObject = [host]

        ScheduleDowntimeAction().action(menuItem)

        let window = try XCTUnwrap(commandWindow(withIdentifier: CommandWindowAccessibility.scheduleDowntimeWindowIdentifier))
        defer { window.close() }
        let startTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeStartTimeIdentifier, in: window.contentView))
        let endTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeEndTimeIdentifier, in: window.contentView))
        try waitForTextField(startTime, value: "30-06-2026 12:00:00")
        try waitForTextField(endTime, value: "30-06-2026 13:00:00")
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.path.hasSuffix("/cmd.cgi") && $0.query.contains("cmd_typ=55") })
    }

    func testAcknowledgeWindowSubmitPostsCommandToFakeServerAndShowsSuccessFeedback() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Acknowledge window success feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }
        let controller = AcknowledgeWindow(windowNibName: "AcknowledgeWindow")
        controller.monitoringItems = [host]
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        let comment = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.acknowledgeCommentIdentifier, in: window.contentView))
        comment.stringValue = "Window acknowledgement"

        controller.buttonClicked(NSButton())

        waitForExpectations(timeout: 5)
        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(form["cmd_typ"], "33")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["com_data"], "Window acknowledgement")
        XCTAssertEqual(presenter.successes.first?.action, .acknowledge)
        XCTAssertEqual(presenter.successes.first?.itemCount, 1)
        XCTAssertTrue(presenter.failures.isEmpty)
    }

    func testScheduleDowntimeWindowSubmitPostsCommandToFakeServerAndShowsSuccessFeedback() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Schedule downtime window success feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }
        let controller = ScheduleDowntimeWindow(windowNibName: "ScheduleDowntimeWindow")
        controller.monitoringItems = [host]
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        let comment = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeCommentIdentifier, in: window.contentView))
        let startTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeStartTimeIdentifier, in: window.contentView))
        let endTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeEndTimeIdentifier, in: window.contentView))
        try waitForTextField(startTime, value: "30-06-2026 12:00:00")
        try waitForTextField(endTime, value: "30-06-2026 13:00:00")
        comment.stringValue = "Window downtime"

        controller.buttonClicked(NSButton())

        waitForExpectations(timeout: 5)
        let request = try waitForAuthorizedPost(pathSuffix: "/cmd.cgi")
        let form = formValues(request.body)
        XCTAssertEqual(form["cmd_typ"], "55")
        XCTAssertEqual(form["host"], "web-01")
        XCTAssertEqual(form["start_time"], "30-06-2026 12:00:00")
        XCTAssertEqual(form["end_time"], "30-06-2026 13:00:00")
        XCTAssertEqual(form["fixed"], "1")
        XCTAssertEqual(form["com_data"], "Window downtime")
        XCTAssertEqual(presenter.successes.first?.action, .scheduleDowntime)
        XCTAssertEqual(presenter.successes.first?.itemCount, 1)
        XCTAssertTrue(presenter.failures.isEmpty)
    }

    func testIcinga2FlexibleDowntimePostsDurationToFakeServer() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        monitoringInstance.monitoringProcessor().command().scheduleDowntime([host], from: "30.06.2026, 12:00:00", to: "30.06.2026, 13:00:00", comment: "Maintenance", type: "0", hours: "2", minutes: "30")

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/schedule-downtime")
        let json = try jsonValues(request.body)
        XCTAssertEqual(request.query, "host=web-01")
        XCTAssertEqual(json["author"], "testuser")
        XCTAssertEqual(json["comment"], "Maintenance")
        XCTAssertEqual(json["fixed"], "0")
        XCTAssertEqual(json["duration"], "9000")
        XCTAssertNotNil(json["start_time"])
        XCTAssertNotNil(json["end_time"])
    }

    func testIcinga2FixedServiceDowntimePostsStartAndEndWithoutDuration() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let service = makeService(host: "web-01", service: "Disk", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().scheduleDowntime([service], from: "30.06.2026, 12:00:00", to: "30.06.2026, 13:00:00", comment: "Maintenance", type: "1", hours: "2", minutes: "30"))

        let request = try waitForAuthorizedPost(pathSuffix: "/actions/schedule-downtime")
        let json = try jsonValues(request.body)
        XCTAssertEqual(commandResult.result?.action, .scheduleDowntime)
        XCTAssertEqual(commandResult.result?.itemCount, 1)
        XCTAssertNil(commandResult.error)
        XCTAssertEqual(request.query, "service=web-01!Disk")
        XCTAssertEqual(json["author"], "testuser")
        XCTAssertEqual(json["comment"], "Maintenance")
        XCTAssertEqual(json["fixed"], "1")
        XCTAssertNotNil(json["start_time"])
        XCTAssertNotNil(json["end_time"])
        XCTAssertNil(json["duration"])
    }

    func testIcinga2CommandCapabilitiesExposeSupportedStatusPanelActions() throws {
        let server = try makeServer()
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)

        let capabilities = monitoringInstance.monitoringProcessor().command().capabilities()

        XCTAssertEqual(capabilities.count, 4)
        XCTAssertTrue(capabilities.contains { if case .acknowledge = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .openInBrowser = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .scheduleDowntime = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .recheck = $0 { return true } else { return false } })
    }

    func testIcinga2GetTimeLoadsStatusThroughFakeServer() throws {
        let programStart: Double = 1_782_800_000
        let uptime: Double = 3_600
        let server = try makeServer(icinga2Status: FakeIcingaServer.defaultIcinga2Status(programStart: programStart, uptime: uptime))
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let result = waitForTimeResult(monitoringInstance.monitoringProcessor().command().getTime([host]))

        XCTAssertEqual(result.start, formattedIcinga2CommandTime(programStart + uptime))
        XCTAssertEqual(result.end, formattedIcinga2CommandTime(programStart + uptime + 3_600))
        XCTAssertNil(result.error)
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.path.hasSuffix("/status") && $0.authorization != nil })
    }

    func testIcinga2GetTimeRejectsInvalidStatusJSON() throws {
        let server = try makeServer(icinga2Status: Data("not-json".utf8))
        let monitoringInstance = makeMonitoringInstance(server: server, type: .Icinga2)
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let result = waitForTimeResult(monitoringInstance.monitoringProcessor().command().getTime([host]))

        XCTAssertNil(result.start)
        XCTAssertNil(result.end)
        XCTAssertEqual(result.error?.localizedDescription, "Invalid JSON")
        XCTAssertTrue(server.requests().contains { $0.method == "GET" && $0.path.hasSuffix("/status") && $0.authorization != nil })
    }

    func testUnsupportedBackendCommandRejectsWithUserVisibleError() {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "checkmk",
            url: "https://monitoring.example/site/check_mk/",
            type: .Check_MK,
            username: "testuser",
            password: "testpass",
            enabled: 1
        )
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().recheck([host]))

        XCTAssertNil(commandResult.result)
        XCTAssertEqual(commandResult.error?.localizedDescription, "Commands are not supported for this monitoring backend")
    }

    func testUnsupportedBackendGetTimeRejectsWithUserVisibleError() {
        let monitoringInstance = unsupportedCommandMonitoringInstance()
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandError = waitForRejectedPromise(monitoringInstance.monitoringProcessor().command().getTime([host]))

        XCTAssertEqual(commandError?.localizedDescription, "Commands are not supported for this monitoring backend")
    }

    func testUnsupportedBackendAcknowledgeRejectsWithUserVisibleError() {
        let monitoringInstance = unsupportedCommandMonitoringInstance()
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().acknowledge([host], comment: "Seen"))

        XCTAssertNil(commandResult.result)
        XCTAssertEqual(commandResult.error?.localizedDescription, "Commands are not supported for this monitoring backend")
    }

    func testUnsupportedBackendScheduleDowntimeRejectsWithUserVisibleError() {
        let monitoringInstance = unsupportedCommandMonitoringInstance()
        let host = makeHost(name: "web-01", monitoringInstance: monitoringInstance)

        let commandResult = waitForCommandResult(monitoringInstance.monitoringProcessor().command().scheduleDowntime([host], from: "30.06.2026, 12:00:00", to: "30.06.2026, 13:00:00", comment: "Maintenance", type: "1", hours: "1", minutes: "0"))

        XCTAssertNil(commandResult.result)
        XCTAssertEqual(commandResult.error?.localizedDescription, "Commands are not supported for this monitoring backend")
    }

    func testAcknowledgeCommandActionDisplayNameIsStable() {
        XCTAssertEqual(CommandAction.acknowledge.displayName, "Acknowledge")
    }

    func testRecheckCommandActionDisplayNameIsStable() {
        XCTAssertEqual(CommandAction.recheck.displayName, "Recheck")
    }

    func testScheduleDowntimeCommandActionDisplayNameIsStable() {
        XCTAssertEqual(CommandAction.scheduleDowntime.displayName, "Schedule Downtime")
    }

    func testCommandFeedbackPresenterReceivesSuccessfulCommandResult() {
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Success feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }

        CommandFeedback.shared.observe(.acknowledge, promise: Promise<CommandResult>.value(CommandResult(action: .acknowledge, itemCount: 2)))

        waitForExpectations(timeout: 5)
        XCTAssertEqual(presenter.successes.count, 1)
        XCTAssertEqual(presenter.successes.first?.action, .acknowledge)
        XCTAssertEqual(presenter.successes.first?.itemCount, 2)
        XCTAssertTrue(presenter.failures.isEmpty)
    }

    func testCommandFeedbackPresenterReceivesFailedCommandResult() {
        let previousPresenter = CommandFeedback.shared.presenter
        let presenter = RecordingCommandFeedbackPresenter(expectation: expectation(description: "Failure feedback"))
        CommandFeedback.shared.presenter = presenter
        defer { CommandFeedback.shared.presenter = previousPresenter }
        let error = NSError(domain: "NagBarTests.CommandFeedback", code: 7, userInfo: [NSLocalizedDescriptionKey: "Rejected by backend"])

        CommandFeedback.shared.observe(.scheduleDowntime, promise: Promise<CommandResult> { seal in
            seal.reject(error)
        })

        waitForExpectations(timeout: 5)
        XCTAssertTrue(presenter.successes.isEmpty)
        XCTAssertEqual(presenter.failures.count, 1)
        XCTAssertEqual(presenter.failures.first?.action, .scheduleDowntime)
        XCTAssertEqual(presenter.failures.first?.error.localizedDescription, "Rejected by backend")
    }

    func testAlertCommandFeedbackPresenterBuildsSuccessAlertWithoutRunningModal() throws {
        var capturedAlert: NSAlert?
        AlertCommandFeedbackPresenter.presentAlert = { capturedAlert = $0 }

        AlertCommandFeedbackPresenter().showSuccess(CommandResult(action: .recheck, itemCount: 4))

        let alert = try XCTUnwrap(capturedAlert)
        XCTAssertEqual(alert.messageText, "Recheck accepted")
        XCTAssertEqual(alert.informativeText, "4 item(s) submitted to the monitoring backend.")
        XCTAssertEqual(alert.alertStyle, .informational)
        XCTAssertEqual(alert.buttons.map { $0.title }, ["OK"])
    }

    func testAlertCommandFeedbackPresenterBuildsFailureAlertWithoutRunningModal() throws {
        var capturedAlert: NSAlert?
        AlertCommandFeedbackPresenter.presentAlert = { capturedAlert = $0 }
        let error = NSError(domain: "NagBarTests.CommandFeedback", code: 7, userInfo: [NSLocalizedDescriptionKey: "Rejected by backend"])

        AlertCommandFeedbackPresenter().showFailure(action: .scheduleDowntime, error: error)

        let alert = try XCTUnwrap(capturedAlert)
        XCTAssertEqual(alert.messageText, "Schedule Downtime failed")
        XCTAssertEqual(alert.informativeText, "Rejected by backend")
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map { $0.title }, ["OK"])
    }

    private func fixtureData(name: String, type: String?) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: type))
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

    private func waitForCommandResult(_ promise: Promise<CommandResult>) -> (result: CommandResult?, error: Error?) {
        let expectation = self.expectation(description: "Command result")
        var commandResult: CommandResult?
        var commandError: Error?

        promise.done { result in
            commandResult = result
            expectation.fulfill()
        }.catch { error in
            commandError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return (commandResult, commandError)
    }

    private func waitForDataResult(_ promise: Promise<Data>) -> (data: Data?, error: Error?) {
        let expectation = self.expectation(description: "Data promise")
        var data: Data?
        var error: Error?

        promise.done { loadedData in
            data = loadedData
            expectation.fulfill()
        }.catch { loadedError in
            error = loadedError
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return (data, error)
    }

    private func waitForTimeResult(_ promise: Promise<(String, String)>) -> (start: String?, end: String?, error: Error?) {
        let expectation = self.expectation(description: "Time promise")
        var startTime: String?
        var endTime: String?
        var error: Error?

        promise.done { start, end in
            startTime = start
            endTime = end
            expectation.fulfill()
        }.catch { loadedError in
            error = loadedError
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return (startTime, endTime, error)
    }

    private func waitForRejectedPromise<T>(_ promise: Promise<T>) -> Error? {
        let expectation = self.expectation(description: "Rejected promise")
        var rejectedError: Error?

        promise.done { _ in
            expectation.fulfill()
        }.catch { error in
            rejectedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        return rejectedError
    }

    private func makeServer(icinga2Status: Data = FakeIcingaServer.defaultIcinga2Status()) throws -> FakeIcingaServer {
        let hostStatus = try fixtureData(name: "IcingaHostStatus", type: "htm")
        let serviceStatus = try fixtureData(name: "IcingaServiceStatus", type: "htm")
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass", icinga2Status: icinga2Status)
        self.server = server
        return server
    }

    private func makeThrukServer() throws -> FakeIcingaServer {
        let hostStatus = try fixtureData(name: "ThrukHostStatus", type: nil)
        let serviceStatus = try fixtureData(name: "ThrukServiceStatus", type: nil)
        let server = try FakeIcingaServer(hostStatus: hostStatus, serviceStatus: serviceStatus, username: "testuser", password: "testpass")
        self.server = server
        return server
    }

    private func makeMonitoringInstance(server: FakeIcingaServer, type: MonitoringInstanceType, password: String = "testpass") -> MonitoringInstance {
        let basePath = type == .Icinga2 ? "/v1" : "/icinga/cgi-bin/"
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "fake-\(type.rawValue)",
            url: "http://127.0.0.1:\(server.port)\(basePath)",
            type: type,
            username: "testuser",
            password: password,
            enabled: 1
        )
        ConnectionManager.sharedInstance.update()
        return monitoringInstance
    }

    private func storeEnabledMonitoringInstance(server: FakeIcingaServer, type: MonitoringInstanceType, password: String = "testpass") -> MonitoringInstance {
        let monitoringInstance = makeMonitoringInstance(server: server, type: type, password: password)
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: password)
        ConnectionManager.sharedInstance.update()
        return monitoringInstance
    }

    private func unsupportedCommandMonitoringInstance() -> MonitoringInstance {
        return MonitoringInstance().initDefault(
            name: "checkmk",
            url: "https://monitoring.example/site/check_mk/",
            type: .Check_MK,
            username: "testuser",
            password: "testpass",
            enabled: 1
        )
    }

    private func makeHost(name: String, monitoringInstance: MonitoringInstance) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.monitoringInstance = monitoringInstance
        return item
    }

    private func makeService(host: String, service: String, monitoringInstance: MonitoringInstance) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.monitoringInstance = monitoringInstance
        return item
    }

    private func waitForAuthorizedPost(pathSuffix: String, timeout: TimeInterval = 5) throws -> FakeIcingaServer.Request {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if let request = server?.requests().last(where: { $0.method == "POST" && $0.path.hasSuffix(pathSuffix) && $0.authorization != nil }) {
                return request
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline

        XCTFail("Timed out waiting for authorized POST ending with \(pathSuffix)")
        throw NSError(domain: "NagBarTests.FakeIcingaServer", code: 1, userInfo: nil)
    }

    private func authorizedPosts(pathSuffix: String, timeout: TimeInterval = 5, expectedCount: Int = 2) -> [FakeIcingaServer.Request] {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            let requests = server?.requests().filter { $0.method == "POST" && $0.path.hasSuffix(pathSuffix) && $0.authorization != nil } ?? []
            if requests.count >= expectedCount {
                return requests
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline

        XCTFail("Timed out waiting for \(expectedCount) authorized POSTs ending with \(pathSuffix)")
        return server?.requests().filter { $0.method == "POST" && $0.path.hasSuffix(pathSuffix) && $0.authorization != nil } ?? []
    }

    private func waitForTextField(_ textField: NSTextField, value: String, timeout: TimeInterval = 5) throws {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if textField.stringValue == value {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline

        XCTFail("Timed out waiting for text field value \(value); current value is \(textField.stringValue)")
        throw NSError(domain: "NagBarTests.CommandWindow", code: 1, userInfo: nil)
    }

    private func textField(withIdentifier identifier: String, in view: NSView?) -> NSTextField? {
        firstSubview(in: view, matching: { $0.accessibilityIdentifier() == identifier }) as? NSTextField
    }

    private func commandWindow(withIdentifier identifier: String) -> NSWindow? {
        NSApplication.shared.windows.first { $0.accessibilityIdentifier() == identifier }
    }

    private func firstSubview(in view: NSView?, matching predicate: (NSView) -> Bool) -> NSView? {
        guard let view = view else {
            return nil
        }

        if predicate(view) {
            return view
        }

        for subview in view.subviews {
            if let match = firstSubview(in: subview, matching: predicate) {
                return match
            }
        }

        return nil
    }

    private func formValues(_ body: String) -> [String: String] {
        let components = URLComponents(string: "http://localhost/?" + body)
        return Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func jsonValues(_ body: String) throws -> [String: String] {
        let data = Data(body.utf8)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(object as? [String: String])
    }

    private func formattedIcinga2CommandTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.YYYY, HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: timeInterval))
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

private final class RecordingCommandFeedbackPresenter: CommandFeedbackPresenting {
    private let expectation: XCTestExpectation
    var successes: [CommandResult] = []
    var failures: [(action: CommandAction, error: Error)] = []

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func showSuccess(_ result: CommandResult) {
        successes.append(result)
        expectation.fulfill()
    }

    func showFailure(action: CommandAction, error: Error) {
        failures.append((action, error))
        expectation.fulfill()
    }
}

private final class RecordingRefreshAction: DataRefreshAction {
    var processCount = 0
    var oldResults: [MonitoringItem] = []
    var newResults: [MonitoringItem] = []

    func process(_ oldResults: Array<MonitoringItem>, newResults: Array<MonitoringItem>) {
        processCount += 1
        self.oldResults = oldResults
        self.newResults = newResults
    }
}
