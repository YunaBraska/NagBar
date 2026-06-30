//
//  CheckMKParserTests.swift
//  NagBar
//
//  Created by Volen Davidov on 16.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import XCTest

class CheckMKParserTests: XCTestCase {
    
    func testGetHostMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "Check_MKHostStatus", ofType: "")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        
        let parser = CheckMKParser(monitoringInstance)
        
        let test = parser.parse(urlType: .hosts, data: data!)
        
        XCTAssertEqual(test.count, 18)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "Bienenstock-Waage")
        XCTAssertEqual(test[0].status, "UP")
        XCTAssertEqual(test[0].lastCheck, "0 sec")
        XCTAssertEqual(test[0].duration, "2015-11-23 00:00:05")
        XCTAssertEqual(test[0].statusInformation, "Packet received via smart PING")
        XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/test/check_mk/view.py?host=Bienenstock-Waage&site=test&view_name=host")
    }
    
    func testGetServiceMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "Check_MKServiceStatus", ofType: "")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        
        let parserServices = CheckMKParser(monitoringInstance)
        
        let test = parserServices.parse(urlType: .services, data: data!) as! Array<ServiceMonitoringItem>
        
        XCTAssertEqual(test.count, 12)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "google.de")
        XCTAssertEqual(test[0].service, "PING")
        XCTAssertEqual(test[0].status, "CRITICAL")
        XCTAssertEqual(test[0].lastCheck, "52 sec")
        XCTAssertEqual(test[0].attempt, "1/1")
        XCTAssertEqual(test[0].duration, "2016-04-05 03:41:27")
        XCTAssertEqual(test[0].statusInformation, "CRITICAL - 173.194.112.120: rta nan, lost 100%")
        XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/test/check_mk/view.py?host=google.de&service=PING&site=test&view_name=service")
    }

    func testEmptyJSONArrayReturnsNoHostItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        let parser = CheckMKParser(monitoringInstance)
        let data = Data("[]".utf8)

        let items = parser.parse(urlType: .hosts, data: data)

        XCTAssertEqual(items.count, 0)
    }

    func testMalformedServiceRowsDoNotCrashAndUseEmptyDefaults() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        let parser = CheckMKParser(monitoringInstance)
        let data = Data(#"[["host","service"],["web-01"]]"#.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].host, "web-01")
        XCTAssertEqual(items[0].service, "")
        XCTAssertEqual(items[0].status, "N/A")
        XCTAssertEqual(items[0].statusInformation, "")
    }

    func testRootCheckMKURLUsesEmptySiteInsteadOfCheckMKPathSegment() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        let parser = CheckMKParser(monitoringInstance)
        let data = Data(#"[["host","service","unused","state","last","duration","attempt","output"],["web-01","PING","","OK","1 sec","2 min","1/1","OK"]]"#.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].itemUrl, "http://testmonitoring/check_mk/view.py?host=web-01&service=PING&site=&view_name=service")
    }

    func testHostStatusVariantsMapSupportedCheckMKStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        let parser = CheckMKParser(monitoringInstance)
        let data = Data("""
        [
          ["host","unused","last","duration","unused","state","output"],
          ["h-warn","","1 sec","1 min","","WARN","warning"],
          ["h-critical","","1 sec","1 min","","CRIT","critical"],
          ["h-unknown","","1 sec","1 min","","UNKN","unknown"],
          ["h-pending","","1 sec","1 min","","PEND","pending"],
          ["h-unreachable","","1 sec","1 min","","UNREACH","unreachable"],
          ["h-ok","","1 sec","1 min","","OK","ok"],
          ["h-down","","1 sec","1 min","","DOWN","down"],
          ["h-up","","1 sec","1 min","","UP","up"],
          ["h-invalid","","1 sec","1 min","","BOOM","invalid"]
        ]
        """.utf8)

        let items = parser.parse(urlType: .hosts, data: data)

        XCTAssertEqual(items.map { $0.status }, ["WARNING", "CRITICAL", "UNKNOWN", "PENDING", "UNREACHABLE", "OK", "DOWN", "UP", "N/A"])
    }

    func testServiceStatusVariantsMapSupportedCheckMKStates() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/test/check_mk", type: .Check_MK, username: "testuser", password: "testpass", enabled: 1)
        let parser = CheckMKParser(monitoringInstance)
        let data = Data("""
        [
          ["host","service","unused","state","last","duration","attempt","output"],
          ["web-01","warn","","WARN","1 sec","1 min","1/3","warning"],
          ["web-01","critical","","CRIT","1 sec","1 min","1/3","critical"],
          ["web-01","unknown","","UNKN","1 sec","1 min","1/3","unknown"],
          ["web-01","pending","","PEND","1 sec","1 min","1/3","pending"],
          ["web-01","unreachable","","UNREACH","1 sec","1 min","1/3","unreachable"],
          ["web-01","ok","","OK","1 sec","1 min","1/3","ok"],
          ["web-01","down","","DOWN","1 sec","1 min","1/3","down"],
          ["web-01","up","","UP","1 sec","1 min","1/3","up"],
          ["web-01","invalid","","BOOM","1 sec","1 min","1/3","invalid"]
        ]
        """.utf8)

        let items = parser.parse(urlType: .services, data: data) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.map { $0.status }, ["WARNING", "CRITICAL", "UNKNOWN", "PENDING", "UNREACHABLE", "OK", "DOWN", "UP", "N/A"])
    }
}
