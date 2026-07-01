//
//  Icinga2ParserTests.swift
//  NagBar
//
//  Created by Volen Davidov on 09.07.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import XCTest
@testable import NagBar

class Icinga2ParserTests: XCTestCase {
    
    override func setUp() {
        let appSettings = Settings()
        appSettings.resetKnownSettings()
        appSettings.setString("1", forKey: "sortColumn")
        appSettings.setString("2", forKey: "sortOrder")
    }
    
    func testGetHostMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "Icinga2HostStatus", ofType: "json")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        
        let parser = Icinga2Parser(monitoringInstance)
        
        let test = parser.parse(urlType: .hosts, data: data!)
        
        XCTAssertEqual(test.count, 2)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "c2-web-1")
        XCTAssertEqual(test[0].status, "DOWN")
        XCTAssertEqual(test[0].lastCheck, parser.unixToTimestamp(1499600203.880074))
        XCTAssertDuration(test[0].duration, matches: 1494759783)
        XCTAssertEqual(test[0].statusInformation, "PING CRITICAL - Packet loss = 100%")
        XCTAssertEqual(test[0].itemUrl, "https://testmonitoring/icingaweb2/monitoring/host/show?host=c2-web-1")
    }
    
    func testGetServiceMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "Icinga2ServiceStatus", ofType: "json")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        
        let parserServices = Icinga2Parser(monitoringInstance)
        
        let test = parserServices.parse(urlType: .services, data: data!) as! Array<ServiceMonitoringItem>
        
        XCTAssertEqual(test.count, 47)
        
        let disk = test.first { $0.host == "icinga2" && $0.service == "disk" }
        XCTAssertNotNil(disk)
        XCTAssertEqual(disk!.monitoringInstance!.name, "test")
        XCTAssertEqual(disk!.status, "CRITICAL")
        XCTAssertEqual(disk!.lastCheck, parserServices.unixToTimestamp(1499600208.763675))
        XCTAssertDuration(disk!.duration, matches: 1494759844)
        XCTAssertEqual(disk!.attempt, "1/5")
        XCTAssertEqual(disk!.statusInformation, "DISK CRITICAL - free space: / 48157 MB (94% inode=99%); /boot 314 MB (63% inode=99%); /home 186600 MB (99% inode=99%); /vagrant 4223 MB (7% inode=100%); /tmp/vagrant-puppet/modules-d9eafae9c04b462999be5fe46dd5a1e9 4223 MB (7% inode=100%); /tmp/vagrant-puppet/manifests-a11d1078b1b1f2e3bdea27312f6ba513 4223 MB (7% inode=100%);")
        XCTAssertEqual(disk!.itemUrl, "https://testmonitoring/icingaweb2/monitoring/service/show?host=icinga2&service=disk")
    }

    func testMissingServiceStateDoesNotCrashAndUsesEmptyDefaults() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        let parser = Icinga2Parser(monitoringInstance)
        let data = Data(#"{"results":[{"attrs":{"host_name":"web-01","name":"disk","check_attempt":1,"max_check_attempts":3,"last_check_result":{},"last_state_change":0}}]}"#.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].host, "web-01")
        XCTAssertEqual(items[0].service, "disk")
        XCTAssertEqual(items[0].status, "")
        XCTAssertEqual(items[0].duration, "N/A")
        XCTAssertEqual(items[0].statusInformation, "")
    }

    func testMalformedJSONReturnsNoHostOrServiceItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        let parser = Icinga2Parser(monitoringInstance)
        let data = Data(#"{"results":["#.utf8)

        XCTAssertEqual(parser.parse(urlType: .hosts, data: data).count, 0)
        XCTAssertEqual(parser.parse(urlType: .services, data: data).count, 0)
    }

    func testMissingHostAttrsDoesNotCrashAndUsesEmptyDefaults() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        let parser = Icinga2Parser(monitoringInstance)
        let data = Data(#"{"results":[{"name":"web-01"}]}"#.utf8)

        let items = parser.parse(urlType: .hosts, data: data)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].host, "web-01")
        XCTAssertEqual(items[0].status, "")
        XCTAssertEqual(items[0].lastCheck, "")
        XCTAssertEqual(items[0].duration, "")
        XCTAssertEqual(items[0].statusInformation, "")
    }

    func testHostStatusVariantsMapSupportedIcingaStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        let parser = Icinga2Parser(monitoringInstance)
        let data = Data("""
        {"results":[
          {"name":"host-up","attrs":{"state":0,"last_check_result":{"schedule_end":1499600203,"output":"up"},"last_state_change":1494759783}},
          {"name":"host-down","attrs":{"state":1,"last_check_result":{"schedule_end":1499600203,"output":"down"},"last_state_change":1494759783}},
          {"name":"host-unreachable","attrs":{"state":2,"last_check_result":{"schedule_end":1499600203,"output":"unreachable"},"last_state_change":1494759783}},
          {"name":"host-invalid","attrs":{"state":99,"last_check_result":{"schedule_end":1499600203,"output":"invalid"},"last_state_change":1494759783}}
        ]}
        """.utf8)

        let items = parser.parse(urlType: .hosts, data: data)
        let statusesByHost = Dictionary(uniqueKeysWithValues: items.map { ($0.host, $0.status) })

        XCTAssertEqual(statusesByHost["host-up"], "UP")
        XCTAssertEqual(statusesByHost["host-down"], "DOWN")
        XCTAssertEqual(statusesByHost["host-unreachable"], "UNREACHABLE")
        XCTAssertEqual(statusesByHost["host-invalid"], "")
    }

    func testServiceStatusVariantsMapSupportedIcingaStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "https://testmonitoring:5665/v1", type: .Icinga2, username: "testuser", password: "testpass", enabled: 1)
        let parser = Icinga2Parser(monitoringInstance)
        let data = Data("""
        {"results":[
          {"attrs":{"host_name":"web-01","name":"ping","state":0,"check_attempt":1,"max_check_attempts":3,"last_check_result":{"schedule_end":1499600203,"output":"ok"},"last_state_change":1494759783}},
          {"attrs":{"host_name":"web-01","name":"disk","state":1,"check_attempt":1,"max_check_attempts":3,"last_check_result":{"schedule_end":1499600203,"output":"warning"},"last_state_change":1494759783}},
          {"attrs":{"host_name":"web-01","name":"cpu","state":2,"check_attempt":2,"max_check_attempts":3,"last_check_result":{"schedule_end":1499600203,"output":"critical"},"last_state_change":1494759783}},
          {"attrs":{"host_name":"web-01","name":"load","state":3,"check_attempt":3,"max_check_attempts":3,"last_check_result":{"schedule_end":1499600203,"output":"unknown"},"last_state_change":1494759783}},
          {"attrs":{"host_name":"web-01","name":"memory","state":99,"check_attempt":1,"max_check_attempts":3,"last_check_result":{"schedule_end":1499600203,"output":"invalid"},"last_state_change":1494759783}}
        ]}
        """.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>
        let statusesByService = Dictionary(uniqueKeysWithValues: items.map { ($0.service, $0.status) })

        XCTAssertEqual(statusesByService["ping"], "OK")
        XCTAssertEqual(statusesByService["disk"], "WARNING")
        XCTAssertEqual(statusesByService["cpu"], "CRITICAL")
        XCTAssertEqual(statusesByService["load"], "UNKNOWN")
        XCTAssertEqual(statusesByService["memory"], "")
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
