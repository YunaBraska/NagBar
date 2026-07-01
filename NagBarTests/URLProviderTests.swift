//
//  URLProviderTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import XCTest
@testable import NagBar

final class URLProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        seedSettings()
    }

    func testNagiosURLProviderBuildsHostServiceAndDowntimeUrls() {
        Settings().setBool(true, forKey: "skipServicesOfHostsWithScD")
        let instance = monitoringInstance(type: .Nagios, url: "http://example.test/nagios/cgi-bin/")

        let urls = NagiosURLProvider(instance).create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].urlType, .hosts)
        XCTAssertEqual(urls[0].url, "http://example.test/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=5&hostprops=10242&limit=0")
        XCTAssertEqual(urls[1].urlType, .services)
        XCTAssertEqual(urls[1].url, "http://example.test/nagios/cgi-bin/status.cgi?service=all&hoststatustypes=2&servicestatustypes=25&sorttype=3&sortoption=7&serviceprops=262152&limit=0")
        XCTAssertEqual(urls[2].urlType, .hostScheduledDowntime)
        XCTAssertEqual(urls[2].url, "http://example.test/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=15&hostprops=262145&limit=0")
    }

    func testNagiosURLProviderDoesNotAppendStatusCgiTwice() {
        let instance = monitoringInstance(type: .Nagios, url: "http://example.test/nagios/cgi-bin/status.cgi")

        let urls = NagiosURLProvider(instance).create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].url, "http://example.test/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=5&hostprops=10242&limit=0")
    }

    func testThrukURLProviderBuildsJsonStatusUrls() {
        let instance = monitoringInstance(type: .Thruk, url: "http://example.test/thruk/cgi-bin/")

        let urls = ThrukURLProvider(instance).create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].url, "http://example.test/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=5&hostprops=10242&view_mode=json")
        XCTAssertEqual(urls[1].url, "http://example.test/thruk/cgi-bin/status.cgi?service=all&hoststatustypes=2&servicestatustypes=25&sorttype=3&sortoption=7&serviceprops=262152&view_mode=json")
    }

    func testIcinga2URLProviderBuildsApiUrlsAndDowntimeUrl() {
        Settings().setBool(true, forKey: "skipServicesOfHostsWithScD")
        Settings().setBool(true, forKey: "hostAcknowledged")
        let instance = monitoringInstance(type: .Icinga2, url: "https://icinga.example:5665/v1")

        let urls = Icinga2URLProvider(instance).create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].urlType, .hosts)
        XCTAssertTrue(urls[0].url.hasPrefix("https://icinga.example:5665/v1/objects/hosts?attrs=name&attrs=address"))
        XCTAssertTrue(urls[0].url.contains("host.state==1.0"))
        XCTAssertTrue(urls[0].url.contains("host.acknowledgement==0.0"))
        XCTAssertEqual(urls[1].urlType, .services)
        XCTAssertTrue(urls[1].url.hasPrefix("https://icinga.example:5665/v1/objects/services?attrs=name"))
        XCTAssertTrue(urls[1].url.contains("service.state==2.0"))
        XCTAssertTrue(urls[1].url.contains("service.state==3.0"))
        XCTAssertEqual(urls[2].url, "https://icinga.example:5665/v1/objects/hosts?attrs=name&filter=host.last_in_downtime==true")
    }

    func testCheckMKURLProviderBuildsHostAndServiceUrls() {
        let instance = monitoringInstance(type: .Check_MK, url: "http://checkmk.example/site/check_mk/")

        let urls = CheckMKURLProvider(instance).create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].urlType, .hosts)
        XCTAssertTrue(urls[0].url.hasPrefix("http://checkmk.example/site/check_mk/view.py?view_name=nagstamon_hosts&output_format=json&"))
        XCTAssertTrue(urls[0].url.contains("hst0=&"))
        XCTAssertTrue(urls[0].url.contains("hst1=on&"))
        XCTAssertTrue(urls[0].url.contains("hst2=&"))
        XCTAssertTrue(urls[0].url.contains("hstp=on&"))
        XCTAssertTrue(urls[0].url.contains("is_host_scheduled_downtime_depth=0&"))
        XCTAssertTrue(urls[0].url.contains("is_host_notifications_enabled=1&"))
        XCTAssertFalse(urls[0].url.contains("is_host_acknowledged=0&"))
        XCTAssertEqual(urls[1].urlType, .services)
        XCTAssertTrue(urls[1].url.hasPrefix("http://checkmk.example/site/check_mk/view.py?view_name=nagstamon_svc&output_format=json&"))
        XCTAssertTrue(urls[1].url.contains("st0=&"))
        XCTAssertTrue(urls[1].url.contains("st1=&"))
        XCTAssertTrue(urls[1].url.contains("st2=on&"))
        XCTAssertTrue(urls[1].url.contains("st3=on&"))
        XCTAssertTrue(urls[1].url.contains("stp=on&"))
        XCTAssertTrue(urls[1].url.contains("is_service_acknowledged=0&"))
        XCTAssertTrue(urls[1].url.contains("is_service_state_type=1&"))
        XCTAssertFalse(urls[1].url.contains("is_in_downtime=0&"))
    }

    func testCheckMKURLProviderAcceptsSkipServicesOfHostsWithScheduledDowntimeSetting() {
        Settings().setBool(true, forKey: "skipServicesOfHostsWithScD")
        let instance = monitoringInstance(type: .Check_MK, url: "http://checkmk.example/site/check_mk/")

        let urls = CheckMKURLProvider(instance).create()

        XCTAssertEqual(urls.count, 2)
    }

    func testLocalIcingaFallbackURLProviderBuildsIcingaStatusUrlsForLocalServer() {
        Settings().setBool(true, forKey: "skipServicesOfHostsWithScD")
        let instance = LocalIcingaFallback.instance()

        let urls = instance.monitoringProcessor().urlProvider().create().sorted { $0.priority < $1.priority }

        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].urlType, .hosts)
        XCTAssertTrue(urls[0].url.hasPrefix(instance.url + "status.cgi?hostgroup=all"))
        XCTAssertEqual(urls[1].urlType, .services)
        XCTAssertTrue(urls[1].url.hasPrefix(instance.url + "status.cgi?service=all"))
        XCTAssertEqual(urls[2].urlType, .hostScheduledDowntime)
        XCTAssertTrue(urls[2].url.hasPrefix(instance.url + "status.cgi?hostgroup=all"))
    }

    func testLocalIcingaFallbackProcessorLoadsFakeServerThroughNormalIcingaPath() throws {
        let instance = LocalIcingaFallback.instance()
        let processor = instance.monitoringProcessor()
        let urls = processor.urlProvider().create()
        let hostURL = try XCTUnwrap(urls.first { $0.urlType == .hosts })
        let serviceURL = try XCTUnwrap(urls.first { $0.urlType == .services })
        let hostData = try fetchData(hostURL.url, client: processor.httpClient())
        let serviceData = try fetchData(serviceURL.url, client: processor.httpClient())

        let hosts = processor.parser().parse(urlType: .hosts, data: hostData).compactMap { $0 as? HostMonitoringItem }
        let services = processor.parser().parse(urlType: .services, data: serviceData).compactMap { $0 as? ServiceMonitoringItem }

        XCTAssertEqual(hosts.count, 6)
        XCTAssertEqual(hosts[0].monitoringInstance?.name, LocalIcingaFallback.instanceName)
        XCTAssertEqual(hosts[0].host, "web-de-smtp")
        XCTAssertEqual(hosts[0].status, "DOWN")
        XCTAssertEqual(hosts[0].statusInformation, "Connection refused")
        XCTAssertTrue(hosts.contains { $0.host == "google-www" && $0.status == "DOWN" && $0.acknowledged })
        XCTAssertTrue(hosts.contains { $0.host == "web-de-pop" && $0.status == "DOWN" && $0.downtime })
        XCTAssertTrue(hosts.contains { $0.host == "yahoo-www" && $0.status == "DOWN" && $0.statusInformation == "CRITICAL - DNS lookup returned no records" })
        XCTAssertEqual(services.count, 6)
        XCTAssertEqual(services[0].host, "secure.nagios.com")
        XCTAssertEqual(services[0].service, "Web Page Content")
        XCTAssertEqual(services[0].status, "CRITICAL")
        XCTAssertTrue(services.contains { $0.host == "secure.nagios.com" && $0.service == "SSL Certificate" && $0.acknowledged })
        XCTAssertTrue(services.contains { $0.host == "www.twitter.com" && $0.service == "DNS IP Match" && $0.status == "CRITICAL" })
        XCTAssertTrue(services.contains { $0.host == "NOAA" && $0.service == "Weather Strafford New Hampshire" && $0.downtime })
        XCTAssertTrue(services.contains { $0.host == "localhost" && $0.service == "XI Software Updates" && $0.attempt == "3/3" })
        XCTAssertTrue(services.contains { $0.host == "mail.example.net" && $0.service == "SMTP" && $0.status == "UNKNOWN" })
    }

    func testLocalIcingaFallbackDoesNotUseProductionDemoModeBranches() throws {
        let files = try productionSwiftFiles()
        let forbiddenTerms = ["Demo Mode", "demo mode"]
        let appSideSampleTerms = [
            "Connection refused",
            "CRITICAL - TCP socket timeout after 10 seconds",
            "HTTP CRITICAL: HTTP/1.1 200 OK - string not found",
            "CRITICAL - Certificate 'secure.nagios.com' expired",
            "DNS CRITICAL - expected '199.59.148.10,199.59.149.230'",
            "Weather Warning: Flood Watch, Winter Weather Advisory",
            "XI Updates CRITICAL: New XI version available",
            "check_smtp: Invalid onredirect option -- usage output follows",
        ]

        for file in files {
            let source = try String(contentsOf: file)
            for term in forbiddenTerms {
                XCTAssertFalse(source.contains(term), "\(term) must not appear in production source \(file.lastPathComponent)")
            }

            if file.lastPathComponent != "LocalIcingaFallback.swift" {
                for term in appSideSampleTerms {
                    XCTAssertFalse(source.contains(term), "\(term) must only live inside the local fake Icinga HTTP server")
                }
            }
        }
    }

    func testLocalIcingaFallbackHTTPClientUsesBasicAuthChallengeAndRejectsUnknownPaths() {
        let instance = LocalIcingaFallback.instance()
        let client = instance.monitoringProcessor().httpClient()

        let getResult = fetchResult(instance.url + "missing.cgi", client: client)

        XCTAssertNil(getResult.data)
        XCTAssertNotNil(getResult.error)
    }

    func testLocalIcingaFallbackServerHandlesNormalCGIAuthHeadAndCommandRequests() throws {
        let instance = LocalIcingaFallback.instance()
        let unauthorized = try rawRequest(url: instance.url + "status.cgi?hostgroup=all", method: "GET", authorization: nil)
        let head = try rawRequest(url: instance.url + "status.cgi?hostgroup=all", method: "HEAD", authorization: authorizationHeader())
        let commandTime = try rawRequest(url: instance.url + "cmd.cgi", method: "GET", authorization: authorizationHeader())
        let commandSubmit = try rawRequest(url: instance.url + "cmd.cgi", method: "POST", authorization: authorizationHeader(), body: Data("cmd_typ=7".utf8))

        XCTAssertEqual(unauthorized.statusCode, 401)
        XCTAssertEqual(head.statusCode, 200)
        XCTAssertTrue(head.body.isEmpty)
        XCTAssertEqual(commandTime.statusCode, 200)
        XCTAssertTrue(String(decoding: commandTime.body, as: UTF8.self).contains("start_time"))
        XCTAssertEqual(commandSubmit.statusCode, 200)
        XCTAssertEqual(String(decoding: commandSubmit.body, as: UTF8.self), "OK")
    }

    private func monitoringInstance(type: MonitoringInstanceType, url: String) -> MonitoringInstance {
        let instance = MonitoringInstance().initDefault(
            name: "test-\(type.rawValue)",
            url: url,
            type: type,
            username: "user",
            password: "pass",
            enabled: 1
        )
        return instance
    }

    private func fetchData(_ url: String, client: HTTPClient) throws -> Data {
        let result = fetchResult(url, client: client)
        XCTAssertNil(result.error)
        return try XCTUnwrap(result.data)
    }

    private func fetchResult(_ url: String, client: HTTPClient) -> (data: Data?, error: NSError?) {
        let expectation = self.expectation(description: "Fetch data")
        var resultData: Data?
        var resultError: NSError?

        client.get(url).done { data in
            resultData = data
            expectation.fulfill()
        }.catch { error in
            resultError = error as NSError
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        return (resultData, resultError)
    }

    private func authorizationHeader() -> String {
        return "Basic " + Data("\(LocalIcingaFallback.username):\(LocalIcingaFallback.password)".utf8).base64EncodedString()
    }

    private func rawRequest(url: String, method: String, authorization: String?, body: Data? = nil) throws -> (statusCode: Int, body: Data) {
        let expectation = self.expectation(description: "\(method) \(url)")
        var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
        request.httpMethod = method
        request.httpBody = body
        if let authorization = authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        var statusCode = -1
        var responseBody = Data()
        var responseError: Error?

        URLSession.shared.dataTask(with: request) { data, response, error in
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            responseBody = data ?? Data()
            expectation.fulfill()
        }.resume()

        waitForExpectations(timeout: 3)
        if let responseError = responseError {
            throw responseError
        }
        return (statusCode, responseBody)
    }

    private func productionSwiftFiles() throws -> [URL] {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDirectory = testsDirectory.deletingLastPathComponent().appendingPathComponent("NagBar", isDirectory: true)
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(at: sourceDirectory, includingPropertiesForKeys: Array(resourceKeys))
        let urls = enumerator?.compactMap { $0 as? URL } ?? []

        return try urls.filter { url in
            let values = try url.resourceValues(forKeys: resourceKeys)
            return values.isRegularFile == true && url.pathExtension == "swift"
        }
    }

    private func seedSettings() {
        let settings = [
            "critical": "1",
            "warning": "0",
            "unknown": "1",
            "pending": "1",
            "ok": "0",
            "down": "1",
            "unreachable": "0",
            "hostPending": "1",
            "up": "0",
            "scheduledDowntime": "0",
            "acknowledged": "1",
            "flapping": "0",
            "checksDisabled": "0",
            "disabledNotifications": "0",
            "softState": "1",
            "hostScheduledDowntime": "1",
            "hostAcknowledged": "0",
            "hostFlapping": "1",
            "hostDisabledNotifications": "1",
            "hostSoftState": "0",
            "hostChecksDisabled": "0",
            "sortColumn": "7",
            "sortOrder": "3",
            "skipServicesOfHostsWithScD": "0",
        ]

        let appSettings = Settings()
        appSettings.resetKnownSettings()
        for (key, value) in settings {
            appSettings.setString(value, forKey: key)
        }
    }
}
