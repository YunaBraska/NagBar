//
//  NagiosParserTests.swift
//  NagBar
//
//  Created by Volen Davidov on 03.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import XCTest

class NagiosParserTests: XCTestCase {
    
    func testGetHostMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "NagiosHostStatus", ofType: "html")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        
        let parser = NagiosParser(monitoringInstance)
        
        let test = parser.parse(urlType: .hosts, data: data!)
        
        XCTAssertEqual(test.count, 48)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "Firewall")
        XCTAssertEqual(test[0].status, "UP")
        XCTAssertEqual(test[0].lastCheck, "01-03-2016 19:16:38")
        XCTAssertEqual(test[0].duration, " 0d  0h 19m 36s+")
        XCTAssertEqual(test[0].statusInformation, "OK - 127.0.0.1: rta 0.025ms, lost 0% ")
        XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/nagios/cgi-bin/extinfo.cgi?type=1&host=Firewall")
    }
    
    func testGetServiceMonitoringItems() {
        let filePath = Bundle(for: type(of: self)).path(forResource: "NagiosServiceStatus", ofType: "html")
        XCTAssertNotNil(filePath)
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        
        let parserServices = NagiosParser(monitoringInstance)
        
        let test = parserServices.parse(urlType: .services, data: data!) as! Array<ServiceMonitoringItem>
        
        XCTAssertEqual(test.count, 100)
        
        XCTAssertEqual(test[0].monitoringInstance!.name, "test")
        XCTAssertEqual(test[0].host, "Log-Server.nagios.local")
        XCTAssertEqual(test[0].status, "OK")
        XCTAssertEqual(test[0].service, "/ Disk Usage")
        XCTAssertEqual(test[0].lastCheck, "12-04-2015 16:09:40")
        XCTAssertEqual(test[0].duration, "173d 15h 13m 53s")
        XCTAssertEqual(test[0].attempt, "1/1")
        XCTAssertEqual(test[0].statusInformation, "DISK OK - free space: / 4353 MB (26% inode=91%): ")
        XCTAssertEqual(test[0].itemUrl, "http://testmonitoring/nagios/cgi-bin/extinfo.cgi?type=2&host=Log-Server.nagios.local&service=%2F+Disk+Usage")
    }

    func testEmptyHostHTMLReturnsNoHostItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)

        let items = parser.parse(urlType: .hosts, data: Data("<html><body></body></html>".utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testEmptyServiceHTMLReturnsNoServiceItems() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)

        let items = parser.parse(urlType: .services, data: Data("<html><body></body></html>".utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testMalformedServiceHTMLWithEmptyAnchorDoesNotCrash() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = """
        <html><body>
          <table class="status"><tr>
            <td><table><tr><td><table><tr><td><a>web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a></a></td></tr></table></td></tr></table></td>
            <td>OK</td><td>now</td><td>1m</td><td>1/1</td><td>output</td>
          </tr></table>
        </body></html>
        """

        let items = parser.parse(urlType: .services, data: Data(html.utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testMalformedHostHTMLWithEmptyAnchorDoesNotCrash() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = """
        <html><body><div><table><tr>
          <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01"></a></td></tr></table></td></tr></table></td>
          <td>UP</td><td>now</td><td>1m</td><td>output</td>
        </tr></table></div></body></html>
        """

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.count, 0)
    }

    func testMissingCommandTimeFieldsReturnEmptyStrings() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let data = Data("<html><body><input name=\"other\" value=\"ignored\"></body></html>".utf8)

        XCTAssertEqual(parser.parseStartTime(data), "")
        XCTAssertEqual(parser.parseEndTime(data), "")
    }

    func testCommandTimeFieldsWithoutValueReturnEmptyStrings() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let data = Data("<html><body><input name=\"start_time\"><input name=\"end_time\"></body></html>".utf8)

        XCTAssertEqual(parser.parseStartTime(data), "")
        XCTAssertEqual(parser.parseEndTime(data), "")
    }

    func testCommandTimeFieldsReturnDecodedValues() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let data = Data("<html><body><input name='start_time' value='06-30-2026 10&#58;15&#58;00'><input name='end_time' value='06-30-2026 11&#58;45&#58;00'></body></html>".utf8)

        XCTAssertEqual(parser.parseStartTime(data), "06-30-2026 10:15:00")
        XCTAssertEqual(parser.parseEndTime(data), "06-30-2026 11:45:00")
    }

    func testHostStatusVariantsPreserveNagiosStatusText() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = nagiosHostStatusHTML([
            ("host-up", "UP"),
            ("host-down", "DOWN"),
            ("host-unreachable", "UNREACHABLE"),
            ("host-pending", "PENDING"),
        ])

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.map { $0.status }, ["UP", "DOWN", "UNREACHABLE", "PENDING"])
    }

    func testServiceStatusVariantsPreserveNagiosStatusText() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = nagiosServiceStatusHTML([
            ("ping", "OK"),
            ("disk", "WARNING"),
            ("load", "UNKNOWN"),
            ("cpu", "CRITICAL"),
            ("memory", "PENDING"),
        ])

        let items = parser.parse(urlType: .services, data: Data(html.utf8)) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.map { $0.status }, ["OK", "WARNING", "UNKNOWN", "CRITICAL", "PENDING"])
    }

    func testHostIconColumnsMapAcknowledgedAndDowntimeFlagsIndependently() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = """
        <html><body><div><table>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=ack-host">ack-host</a></td></tr></table></td><td><table><tr><td><a><img src="/nagios/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>now</td><td>1m</td><td>acknowledged</td>
          </tr>
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=down-host">down-host</a></td></tr></table></td><td><table><tr><td><a><img src="/nagios/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>DOWN</td><td>now</td><td>1m</td><td>downtime</td>
          </tr>
        </table></div></body></html>
        """

        let items = parser.parse(urlType: .hosts, data: Data(html.utf8))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map { $0.acknowledged }, [true, false])
        XCTAssertEqual(items.map { $0.downtime }, [false, true])
    }

    func testServiceRowsReusePreviousHostWhenHostCellIsEmpty() {
        let monitoringInstance = MonitoringInstance().initDefault(name: "test", url: "http://testmonitoring/nagios/cgi-bin/", type: .Nagios, username: "testuser", password: "testpass", enabled: 1)
        let parser = NagiosParser(monitoringInstance)
        let html = """
        <html><body><table class="status">
          <tr>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=Ping">Ping</a></td></tr></table></td><td><table><tr><td><a><img src="/nagios/images/ack.gif"></a></td></tr></table></td></tr></table></td>
            <td>OK</td><td>now</td><td>1m</td><td>1/1</td><td>ping ok</td>
          </tr>
          <tr>
            <td></td>
            <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=Disk">Disk&nbsp;Usage</a></td></tr></table></td><td><table><tr><td><a><img src="/nagios/images/downtime.gif"></a></td></tr></table></td></tr></table></td>
            <td>WARNING</td><td>later</td><td>2m</td><td>2/3</td><td>disk warning</td>
          </tr>
        </table></body></html>
        """

        let items = parser.parse(urlType: .services, data: Data(html.utf8)) as! Array<ServiceMonitoringItem>

        XCTAssertEqual(items.map { $0.host }, ["web-01", "web-01"])
        XCTAssertEqual(items.map { $0.service }, ["Ping", "Disk\u{00A0}Usage"])
        XCTAssertEqual(items.map { $0.acknowledged }, [true, false])
        XCTAssertEqual(items.map { $0.downtime }, [false, true])
    }

    private func nagiosHostStatusHTML(_ rows: [(String, String)]) -> String {
        let body = rows.map { host, status in
            """
            <tr>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=\(host)">\(host)</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
              <td>\(status)</td><td>01-01-2026 00:00:00</td><td>0d 0h 1m 0s</td><td>\(status) output</td>
            </tr>
            """
        }.joined(separator: "\n")

        return "<html><body><div><table>\(body)</table></div></body></html>"
    }

    private func nagiosServiceStatusHTML(_ rows: [(String, String)]) -> String {
        let body = rows.map { service, status in
            """
            <tr>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=1&amp;host=web-01">web-01</a></td></tr></table></td></tr></table></td>
              <td><table><tr><td><table><tr><td><a href="extinfo.cgi?type=2&amp;host=web-01&amp;service=\(service)">\(service)</a></td></tr></table></td><td><table><tr><td></td></tr></table></td></tr></table></td>
              <td>\(status)</td><td>01-01-2026 00:00:00</td><td>0d 0h 1m 0s</td><td>1/1</td><td>\(status) output</td>
            </tr>
            """
        }.joined(separator: "\n")

        return "<html><body><table class=\"status\">\(body)</table></body></html>"
    }
}
