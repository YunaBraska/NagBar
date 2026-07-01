//
//  IcingaParserTests.swift
//  NagBar
//
//  Created by Volen Davidov on 11.02.17.
//  Copyright © 2017 Volen Davidov. All rights reserved.
//

import XCTest
@testable import NagBar

class IcingaParserTests: XCTestCase {
    
    func testGetHostMonitoringItems() {
     let filePath = Bundle(for: type(of: self)).path(forResource: "IcingaHostStatus", ofType: "htm")
     XCTAssertNotNil(filePath)
     
     let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
     
     let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
     
     let parser = IcingaParser(monitoringInstance)
     
     let test = parser.parse(urlType: .hosts, data: data!)
     
     XCTAssertEqual(test.count, 3)
     
     XCTAssertEqual(test[0].monitoringInstance!.name, "test")
     XCTAssertEqual(test[0].host, "hplj2605dn")
     XCTAssertEqual(test[0].status, "DOWN")
     XCTAssertEqual(test[0].lastCheck, "02-11-2017 19:58:45")
     XCTAssertEqual(test[0].duration, "0d  0h 33m 25s")
     XCTAssertEqual(test[0].statusInformation, "CRITICAL - Network Unreachable (192.168.1.30)")
     XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/icinga/cgi-bin/extinfo.cgi?type=1&host=hplj2605dn")
     }
    
    func testGetServiceMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "IcingaServiceStatus", ofType: "htm")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        
        let parserServices = IcingaParser(monitoringInstance)
        
        let test = parserServices.parse(urlType: .services, data: data!) as! Array<ServiceMonitoringItem>
        
        XCTAssertEqual(test.count, 15)
        
        XCTAssertEqual(test[14].monitoringInstance!.name, "test")
        XCTAssertEqual(test[14].host, "localhost")
        XCTAssertEqual(test[14].status, "WARNING")
        XCTAssertEqual(test[14].service, "Total Processes")
        XCTAssertEqual(test[14].lastCheck, "02-11-2017 19:18:16")
        XCTAssertEqual(test[14].duration, "0d  0h  6m 50s")
        XCTAssertEqual(test[14].attempt, "4/4 ")
        XCTAssertEqual(test[14].statusInformation, "PROCS WARNING: 97 processes with STATE = RSZDT")
        XCTAssertEqual(test[14].itemUrl, "http://testmonitoring/icinga/cgi-bin/extinfo.cgi?type=2&host=localhost&service=Total+Processes")
    }

    func testEmptyHostHTMLReturnsNoHostItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)

        let items = parser.parse(urlType: .hosts, data: Data("<html><body></body></html>".utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testEmptyServiceHTMLReturnsNoServiceItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)

        let items = parser.parse(urlType: .services, data: Data("<html><body></body></html>".utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testHostStatusVariantsPreserveIcingaStatusText() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = icingaHostStatusHTML([
            ("host-up", "UP"),
            ("host-down", "DOWN"),
            ("host-unreachable", "UNREACHABLE"),
            ("host-pending", "PENDING"),
        ])

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.map { $0.status }, ["UP", "DOWN", "UNREACHABLE", "PENDING"])
    }

    func testServiceStatusVariantsPreserveIcingaStatusText() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = icingaServiceStatusHTML([
            ("ping", "OK"),
            ("disk", "WARNING"),
            ("load", "UNKNOWN"),
            ("cpu", "CRITICAL"),
            ("memory", "PENDING"),
        ])

        let items = parser.parse(urlType: .services, data: Data(html.utf8)) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.map { $0.status }, ["OK", "WARNING", "UNKNOWN", "CRITICAL", "PENDING"])
    }

    func testMalformedHostHTMLWithEmptyAnchorDoesNotCrash() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = """
        <html><body><form id="tableformhost"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01"></a></td></tr></table></td></tr></table></td>
            <td>UP</td><td>now</td><td>1m</td><td>1/1</td><td>output</td>
          </tr>
        </table></div></form></body></html>
        """

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testMalformedServiceHTMLWithEmptyAnchorDoesNotCrash() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = """
        <html><body><form id="tableformservice"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=ping"></a></td></tr></table></td></tr></table></td>
            <td>OK</td><td>now</td><td>1m</td><td>1/1</td><td>output</td>
          </tr>
        </table></div></form></body></html>
        """

        let items = parser.parse(urlType: .services, data: Data(html.utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testHostIconColumnsMapAcknowledgedAndDowntimeFlagsIndependently() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = """
        <html><body><form id="tableformhost"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=ack-host">ack-host</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>now</td><td>1m</td><td>1/1</td><td>acknowledged</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=down-host">down-host</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>now</td><td>1m</td><td>1/1</td><td>downtime</td>
          </tr>
        </table></div></form></body></html>
        """

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map { $0.acknowledged }, [true, false])
        XCTAssertEqual(items.map { $0.downtime }, [false, true])
    }

    func testServiceIconColumnsMapAcknowledgedAndDowntimeFlagsIndependently() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/icinga/cgi-bin/", type: .Icinga, username: "testuser", password: "testpass", enabled: 1)
        let parser = IcingaParser(monitoringInstance)
        let html = """
        <html><body><form id="tableformservice"><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=ping">ping</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>WARNING</td><td>now</td><td>1m</td><td>1/1</td><td>acknowledged</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=disk">disk</a></td></tr></table></td><td><table><tr><td><a><img src="/icinga/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>CRITICAL</td><td>now</td><td>1m</td><td>1/1</td><td>downtime</td>
          </tr>
        </table></div></form></body></html>
        """

        let items = parser.parse(urlType: .services, data: Data(html.utf8)) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map { $0.acknowledged }, [true, false])
        XCTAssertEqual(items.map { $0.downtime }, [false, true])
    }

    private func icingaHostStatusHTML(_ rows: [(String, String)]) -> String {
        let body = rows.map { host, status in
            """
            <tr>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=\(host)">\(host)</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
              <td>\(status)</td><td>01-01-2026 00:00:00</td><td>0d 0h 1m 0s</td><td></td><td>\(status) output</td>
            </tr>
            """
        }.joined(separator: "\n")

        return "<html><body><form id=\"tableformhost\"><div><table>\(body)</table></div></form></body></html>"
    }

    private func icingaServiceStatusHTML(_ rows: [(String, String)]) -> String {
        let body = rows.map { service, status in
            """
            <tr>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=\(service)">\(service)</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
              <td>\(status)</td><td>01-01-2026 00:00:00</td><td>0d 0h 1m 0s</td><td>1/1</td><td>\(status) output</td>
            </tr>
            """
        }.joined(separator: "\n")

        return "<html><body><form id=\"tableformservice\"><div><table>\(body)</table></div></form></body></html>"
    }
}
