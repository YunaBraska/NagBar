//
//  ThrukParserTests.swift
//  NagBar
//
//  Created by Volen Davidov on 02.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import XCTest

class ThrukParserTests: XCTestCase {
    
    func testGetHostMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "ThrukHostStatus", ofType: "")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        
        let parser = ThrukParser(monitoringInstance)
        
        let test = parser.parse(urlType: .hosts, data: data!)
        
        XCTAssertEqual(test.count, 3)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "linksys-srw224p")
        XCTAssertEqual(test[0].status, "UNREACHABLE")
        XCTAssertEqual(test[0].lastCheck, parser.unixToTimestamp(1467441459))
        XCTAssertDuration(test[0].duration, matches: 1467441467)
        XCTAssertEqual(test[0].statusInformation, "fsdf")
        XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/thruk/cgi-bin/extinfo.cgi?type=1&host=linksys-srw224p")
    }
    
    func testGetServiceMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "ThrukServiceStatus", ofType: "")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        
        let parserServices = ThrukParser(monitoringInstance)
        
        let test = parserServices.parse(urlType: .services, data: data!) as! Array<ServiceMonitoringItem>
        
        XCTAssertEqual(test.count, 9)
        
        XCTAssertEqual(test[1].monitoringInstance!.name, "test")
        XCTAssertEqual(test[1].host, "localhost")
        XCTAssertEqual(test[1].service, "Current Users")
        XCTAssertEqual(test[1].status, "UNKNOWN")
        XCTAssertEqual(test[1].lastCheck, parserServices.unixToTimestamp(1467447798))
        XCTAssertEqual(test[1].attempt, "4/4 #1432")
        XCTAssertDuration(test[1].duration, matches: 1405166941)
        XCTAssertEqual(test[1].statusInformation, "(null)")
        XCTAssertEqual(test[1].itemUrl, "http://testmonitoring/thruk/cgi-bin/extinfo.cgi?type=2&host=localhost&service=Current Users")
    }

    func testMissingHostStateDoesNotCrashAndUsesEmptyDefaults() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = ThrukParser(monitoringInstance)
        let data = Data(#"[{"display_name":"web-01","last_check":1467441459,"last_state_change":0}]"#.utf8)

        let items = parser.parse(urlType: .hosts, data: data)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].host, "web-01")
        XCTAssertEqual(items[0].status, "")
        XCTAssertEqual(items[0].duration, "N/A")
        XCTAssertEqual(items[0].statusInformation, "")
    }

    func testMalformedJSONReturnsNoHostOrServiceItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = ThrukParser(monitoringInstance)
        let data = Data(#"[{"display_name":"web-01""#.utf8)

        XCTAssertEqual(parser.parse(urlType: .hosts, data: data).count, 0)
        XCTAssertEqual(parser.parse(urlType: .services, data: data).count, 0)
    }

    func testHostStatusVariantsMapSupportedThrukStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = ThrukParser(monitoringInstance)
        let data = Data("""
        [
          {"display_name":"host-up","state":0,"last_check":1467441459,"last_state_change":1467441467,"plugin_output":"up"},
          {"display_name":"host-down","state":1,"last_check":1467441459,"last_state_change":1467441467,"plugin_output":"down"},
          {"display_name":"host-unreachable","state":2,"last_check":1467441459,"last_state_change":1467441467,"plugin_output":"unreachable"},
          {"display_name":"host-invalid","state":99,"last_check":1467441459,"last_state_change":1467441467,"plugin_output":"invalid"}
        ]
        """.utf8)

        let items = parser.parse(urlType: .hosts, data: data)

        XCTAssertEqual(items.map { $0.status }, ["UP", "DOWN", "UNREACHABLE", ""])
    }

    func testServiceStatusVariantsMapSupportedThrukStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = ThrukParser(monitoringInstance)
        let data = Data("""
        [
          {"host_name":"web-01","description":"ping","state":0,"last_check":1467441459,"last_state_change":1467441467,"current_attempt":1,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"ok"},
          {"host_name":"web-01","description":"disk","state":1,"last_check":1467441459,"last_state_change":1467441467,"current_attempt":2,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"warning"},
          {"host_name":"web-01","description":"cpu","state":2,"last_check":1467441459,"last_state_change":1467441467,"current_attempt":3,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"critical"},
          {"host_name":"web-01","description":"load","state":3,"last_check":1467441459,"last_state_change":1467441467,"current_attempt":4,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"unknown"},
          {"host_name":"web-01","description":"memory","state":99,"last_check":1467441459,"last_state_change":1467441467,"current_attempt":1,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"invalid"}
        ]
        """.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.map { $0.status }, ["OK", "WARNING", "CRITICAL", "UNKNOWN", ""])
    }

    func testLastCheckZeroMarksHostAndServiceStatusAsNA() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = ThrukParser(monitoringInstance)
        let hostData = Data(#"[{"display_name":"host-pending","state":0,"last_check":0,"last_state_change":0,"plugin_output":"pending"}]"#.utf8)
        let serviceData = Data(#"[{"host_name":"web-01","description":"ping","state":0,"last_check":0,"last_state_change":0,"current_attempt":1,"max_check_attempts":4,"current_notification_number":0,"plugin_output":"pending"}]"#.utf8)

        let hosts = parser.parse(urlType: .hosts, data: hostData)
        let services = parser.parse(urlType: .services, data: serviceData) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(hosts[0].status, "N/A")
        XCTAssertEqual(services[0].status, "N/A")
    }
    
    private func XCTAssertDuration(_ actual: String, matches timestamp: Double, file: StaticString = #file, line: UInt = #line) {
        let expected = durationSince(timestamp)
        let expectedPlusOne = durationSince(timestamp - 1)
        let expectedMinusOne = durationSince(timestamp + 1)
        XCTAssertTrue([expectedMinusOne, expected, expectedPlusOne].contains(actual), "Expected duration near \(expected), got \(actual)", file: file, line: line)
    }

    private func durationSince(_ timeLeftSeconds: Double?) -> String {
        
        guard let timeLeftSeconds = timeLeftSeconds else {
            return ""
        }
        
        if timeLeftSeconds == 0.0 {
            return "N/A"
        }
        
        let currentDate = Date().timeIntervalSince1970
        let diff = Int(currentDate - timeLeftSeconds)
        
        let secondsInMinute = 60
        let secondsInHour = 60 * secondsInMinute
        let secondsInDay = 24 * secondsInHour
        
        let days = diff / secondsInDay
        let hours = (diff - secondsInDay * days) / secondsInHour
        let minutes = (diff - secondsInDay * days - secondsInHour * hours) / secondsInMinute
        let seconds = (diff - secondsInDay * days - secondsInHour * hours - secondsInMinute * minutes)
        
        var timeLeftString: String?
        
        if days > 0 {
            timeLeftString = String.init(format: "%ud %uh %um %us", days, hours, minutes, seconds)
        } else if hours > 0 {
            timeLeftString = String.init(format: "%uh %um %us", hours, minutes, seconds)
        } else if minutes > 0 {
            timeLeftString = String.init(format: "%um %us", minutes, seconds)
        } else {
            timeLeftString = String.init(format: "%us", seconds)
        }
        
        return timeLeftString!
    }
}
