//
//  MonitoringInstancesTest.swift
//  NagBar
//
//  Created by Volen Davidov on 18.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest

class MonitoringInstancesTest: XCTestCase {

    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
        NagBarStorage.applicationSupportDirectoryOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: true)
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
        MonitoringInstances.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("monitoring-instances.json")
        MonitoringInstances().resetStorage()
        FilterItems.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("filter-items.json")
        FilterItems().resetStorage()
        ServerLogin.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: false)
            .appendingPathExtension("server-login.json")
        ServerLogin().resetStorage()
        PasswordStore.sharedInstance.removeAll()
        (KeychainAccess().get() as? InMemoryKeychainClient)?.removeAll()
    }

    override func tearDown() {
        MonitoringInstances().resetStorage()
        MonitoringInstances.storageURLOverride = nil
        FilterItems().resetStorage()
        FilterItems.storageURLOverride = nil
        ServerLogin().resetStorage()
        ServerLogin.storageURLOverride = nil
        if let applicationSupportDirectory = NagBarStorage.applicationSupportDirectoryOverride {
            try? FileManager.default.removeItem(at: applicationSupportDirectory)
        }
        NagBarStorage.applicationSupportDirectoryOverride = nil
        super.tearDown()
    }

    func testInitDefaultStoresMonitoringType() {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "icinga-api",
            url: "https://monitoring.example/v1",
            type: .Icinga2,
            username: "api-user",
            password: "api-pass",
            enabled: 1
        )

        XCTAssertEqual(monitoringInstance.name, "icinga-api")
        XCTAssertEqual(monitoringInstance.url, "https://monitoring.example/v1")
        XCTAssertEqual(monitoringInstance.type, .Icinga2)
        XCTAssertEqual(monitoringInstance.username, "api-user")
        XCTAssertEqual(monitoringInstance.password, "api-pass")
        XCTAssertEqual(monitoringInstance.enabled, 1)
        XCTAssertTrue(monitoringInstance.monitoringProcessor() is Icinga2Processor)
    }

    func testMonitoringInstanceURLValidationRejectsEmptyURL() {
        let result = MonitoringInstance.validateURL("")

        XCTAssertEqual(result, .empty)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "Enter an http or https URL before enabling this monitoring instance.")
    }

    func testMonitoringInstanceURLValidationRejectsURLWithoutHost() {
        let result = MonitoringInstance.validateURL("https:///icinga/cgi-bin/")

        XCTAssertEqual(result, .invalid("https:///icinga/cgi-bin/"))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.title, "Invalid monitoring URL")
    }

    func testMonitoringInstanceURLValidationRejectsUnsupportedScheme() {
        let result = MonitoringInstance.validateURL("file:///tmp/status.cgi")

        XCTAssertEqual(result, .invalid("file:///tmp/status.cgi"))
        XCTAssertFalse(result.isValid)
    }

    func testMonitoringInstanceURLValidationRejectsQueryBaseURL() {
        let result = MonitoringInstance.validateURL("https://nagios.example/nagios/cgi-bin/?foo=bar")

        XCTAssertEqual(result, .invalid("https://nagios.example/nagios/cgi-bin/?foo=bar"))
        XCTAssertFalse(result.isValid)
    }

    func testMonitoringInstanceURLValidationRejectsFragmentBaseURL() {
        let result = MonitoringInstance.validateURL("https://nagios.example/nagios/cgi-bin/#status")

        XCTAssertEqual(result, .invalid("https://nagios.example/nagios/cgi-bin/#status"))
        XCTAssertFalse(result.isValid)
    }

    func testMonitoringInstanceURLValidationAcceptsHTTPAndHTTPSBackendURLs() {
        XCTAssertEqual(MonitoringInstance.validateURL("http://nagios.example/nagios/cgi-bin/"), .valid)
        XCTAssertEqual(MonitoringInstance.validateURL("https://icinga.example:5665/v1"), .valid)
        XCTAssertEqual(MonitoringInstance.validateURL(" https://checkmk.example/site/check_mk/ "), .valid)
        XCTAssertEqual(MonitoringInstance.validateURL("http://127.0.0.1:12345/icinga/cgi-bin/"), .valid)
        XCTAssertEqual(MonitoringInstance.validateURL("http://nagios.example/nagios/cgi-bin/status.cgi"), .valid)
    }

    func testEmptyConfigurationProvidesNonPersistedLocalIcingaFallbackInstance() throws {
        seedSavePassword(false)

        let enabled = MonitoringInstances().getAllEnabled()
        let fallback = try XCTUnwrap(enabled[LocalIcingaFallback.instanceName])
        let storageURL = try XCTUnwrap(MonitoringInstances.storageURLOverride)

        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(fallback.name, LocalIcingaFallback.instanceName)
        XCTAssertFalse(fallback.name.localizedCaseInsensitiveContains("demo"))
        XCTAssertTrue(fallback.url.hasPrefix("http://\(LocalIcingaFakeServer.host):"))
        XCTAssertTrue(fallback.url.hasSuffix("/icinga/cgi-bin/"))
        XCTAssertEqual(fallback.type, .Icinga)
        XCTAssertEqual(fallback.username, LocalIcingaFallback.username)
        XCTAssertEqual(fallback.password, LocalIcingaFallback.password)
        XCTAssertFalse(fallback.username.localizedCaseInsensitiveContains("demo"))
        XCTAssertFalse(fallback.password.localizedCaseInsensitiveContains("demo"))
        XCTAssertEqual(fallback.enabled, 1)
        XCTAssertTrue(fallback.monitoringProcessor() is IcingaProcessor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageURL.path))
        XCTAssertEqual(MonitoringInstances().getAll().count, 0)
        XCTAssertFalse(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testInvalidStoredMonitoringInstanceDoesNotSuppressLocalIcingaFallback() throws {
        seedSavePassword(false)
        let invalidRemote = MonitoringInstance().initDefault(
            name: "broken-remote",
            url: "not a url",
            type: .Nagios,
            username: "user",
            password: "",
            enabled: 1
        )
        MonitoringInstances().insert(key: invalidRemote.name, value: invalidRemote)

        let enabled = MonitoringInstances().getAllEnabled()
        let fallback = try XCTUnwrap(enabled[LocalIcingaFallback.instanceName])

        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(fallback.type, .Icinga)
        XCTAssertFalse(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testInvalidStoredMonitoringInstanceTypeIsRejectedInsteadOfCrashing() throws {
        seedSavePassword(false)
        try writeMonitoringInstancesJSON("""
        [
          {
            "name": "future-backend",
            "url": "https://future.example/status",
            "privateType": "FutureBackend",
            "username": "future-user",
            "enabled": 1
          }
        ]
        """)

        let all = MonitoringInstances().getAll()
        let enabled = MonitoringInstances().getAllEnabled()
        let fallback = try XCTUnwrap(enabled[LocalIcingaFallback.instanceName])

        XCTAssertTrue(all.isEmpty)
        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(fallback.type, .Icinga)
        XCTAssertFalse(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testInvalidStoredMonitoringInstanceTypeDoesNotHideValidStoredRemote() throws {
        seedSavePassword(false)
        try writeMonitoringInstancesJSON("""
        [
          {
            "name": "future-backend",
            "url": "https://future.example/status",
            "privateType": "FutureBackend",
            "username": "future-user",
            "enabled": 1
          },
          {
            "name": "valid-nagios",
            "url": "https://nagios.example/nagios/cgi-bin/",
            "privateType": "Nagios",
            "username": "nagios-user",
            "enabled": 1
          }
        ]
        """)

        let all = MonitoringInstances().getAll()
        let enabled = MonitoringInstances().getAllEnabled()
        let valid = try XCTUnwrap(enabled["valid-nagios"])

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all["valid-nagios"]?.type, .Nagios)
        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(valid.url, "https://nagios.example/nagios/cgi-bin/")
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
        XCTAssertTrue(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testConfiguredMonitoringInstanceSuppressesLocalIcingaFallbackEvenWhenDisabled() {
        seedSavePassword(false)
        _ = storedMonitoringInstance(name: "disabled-real-remote", enabled: 0)

        let enabled = MonitoringInstances().getAllEnabled()

        XCTAssertTrue(enabled.isEmpty)
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
        XCTAssertFalse(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testBlankNewMonitoringInstanceDoesNotSuppressLocalIcingaFallback() throws {
        seedSavePassword(false)
        let blankNew = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: blankNew.name, value: blankNew)

        let enabled = MonitoringInstances().getAllEnabled()
        let fallback = try XCTUnwrap(enabled[LocalIcingaFallback.instanceName])

        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(fallback.type, .Icinga)
        XCTAssertFalse(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testSettingsPlaceholderDoesNotSuppressLocalIcingaFallback() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )

        MonitoringInstances().insert(key: "New", value: placeholder)

        let storedPlaceholder = try XCTUnwrap(MonitoringInstances().getByKey("New"))
        let enabled = MonitoringInstances().getAllEnabled()
        let fallback = try XCTUnwrap(enabled[LocalIcingaFallback.instanceName])

        XCTAssertEqual(storedPlaceholder.name, "New")
        XCTAssertEqual(storedPlaceholder.url, "")
        XCTAssertEqual(storedPlaceholder.type, .Nagios)
        XCTAssertEqual(storedPlaceholder.username, "")
        XCTAssertEqual(storedPlaceholder.password, "")
        XCTAssertEqual(storedPlaceholder.enabled, 0)
        XCTAssertEqual(enabled.count, 1)
        XCTAssertEqual(fallback.type, .Icinga)
    }

    func testSettingsStoredRemoteReplacesLocalIcingaFallbackThroughEditableFields() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )

        MonitoringInstances().insert(key: "New", value: placeholder)
        MonitoringInstances().updateName(monitoringInstance: placeholder, name: "ops-icinga")
        MonitoringInstances().updateUrl(monitoringInstance: placeholder, url: "https://icinga.example/icinga/cgi-bin/")
        MonitoringInstances().updateType(monitoringInstance: placeholder, type: .Icinga)
        MonitoringInstances().updateUsername(monitoringInstance: placeholder, username: "icinga-user")
        MonitoringInstances().updatePassword(monitoringInstance: placeholder, password: "icinga-pass")
        MonitoringInstances().updateEnabled(monitoringInstance: placeholder, enabled: 1)

        let enabled = MonitoringInstances().getAllEnabled()
        let remote = try XCTUnwrap(enabled["ops-icinga"])

        XCTAssertEqual(enabled.count, 1)
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
        XCTAssertEqual(remote.url, "https://icinga.example/icinga/cgi-bin/")
        XCTAssertEqual(remote.type, .Icinga)
        XCTAssertEqual(remote.username, "icinga-user")
        XCTAssertEqual(remote.password, "icinga-pass")
        XCTAssertEqual(remote.enabled, 1)
        XCTAssertTrue(remote.monitoringProcessor() is IcingaProcessor)
    }

    func testMonitoringInstancesTableTextControlsPersistEditedRemoteFields() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let nameField = try XCTUnwrap(MINameTableColumn(identifier: NSUserInterfaceItemIdentifier("name")).createViewForRow(0) as? MINameTextField)
        XCTAssertEqual(nameField.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "name", row: 0))
        nameField.textDidBeginEditing(Notification(name: NSText.didBeginEditingNotification))
        nameField.stringValue = "ops-icinga-table"
        nameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let urlField = try XCTUnwrap(MIURLTableColumn(identifier: NSUserInterfaceItemIdentifier("url")).createViewForRow(0) as? MIURLTextField)
        XCTAssertEqual(urlField.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "url", row: 0))
        urlField.stringValue = "https://icinga-table.example/icinga/cgi-bin/"
        urlField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let usernameField = try XCTUnwrap(MIUsernameTableColumn(identifier: NSUserInterfaceItemIdentifier("username")).createViewForRow(0) as? MIUsernameTextField)
        XCTAssertEqual(usernameField.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "username", row: 0))
        usernameField.stringValue = "icinga-table-user"
        usernameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let passwordField = try XCTUnwrap(MIPasswordTableColumn(identifier: NSUserInterfaceItemIdentifier("password")).createViewForRow(0) as? MIPasswordTextField)
        XCTAssertEqual(passwordField.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "password", row: 0))
        passwordField.stringValue = "icinga-table-pass"
        passwordField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let stored = try XCTUnwrap(MonitoringInstances().getByKey("ops-icinga-table"))
        XCTAssertEqual(stored.url, "https://icinga-table.example/icinga/cgi-bin/")
        XCTAssertEqual(stored.username, "icinga-table-user")
        XCTAssertEqual(stored.password, "icinga-table-pass")
    }

    func testMonitoringInstancesNameFieldEndEditingWithoutBeginEditingDoesNotRename() throws {
        seedSavePassword(false)
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "alpha",
            url: "https://alpha.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        let nameField = try XCTUnwrap(MINameTableColumn(identifier: NSUserInterfaceItemIdentifier("name")).createViewForRow(0) as? MINameTextField)

        nameField.stringValue = "beta"
        nameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        XCTAssertNotNil(MonitoringInstances().getByKey("alpha"))
        XCTAssertNil(MonitoringInstances().getByKey("beta"))
    }

    func testMonitoringInstancesNameFieldSuccessfulRenamePostsRefreshNotification() throws {
        seedSavePassword(false)
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "zeta",
            url: "https://zeta.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        let renameExpectation = expectation(description: "Monitoring instance rename notification")
        let observer = Foundation.NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "MonitoringInstanceNameChanged"),
            object: nil,
            queue: nil
        ) { _ in
            renameExpectation.fulfill()
        }
        defer {
            Foundation.NotificationCenter.default.removeObserver(observer)
        }
        let nameField = try XCTUnwrap(MINameTableColumn(identifier: NSUserInterfaceItemIdentifier("name")).createViewForRow(0) as? MINameTextField)

        nameField.textDidBeginEditing(Notification(name: NSText.didBeginEditingNotification))
        nameField.stringValue = "alpha"
        nameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        waitForExpectations(timeout: 1)
        XCTAssertNil(MonitoringInstances().getByKey("zeta"))
        XCTAssertNotNil(MonitoringInstances().getByKey("alpha"))
        XCTAssertEqual(MonitoringInstances().getKeyById(0), "alpha")
    }

    func testMonitoringInstancesUpdateURLTrimsValidURL() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let didUpdate = MonitoringInstances().updateUrl(monitoringInstance: placeholder, url: " https://nagios.example/nagios/cgi-bin/ ")

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(placeholder.url, "https://nagios.example/nagios/cgi-bin/")
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.url, "https://nagios.example/nagios/cgi-bin/")
    }

    func testMonitoringInstancesUpdateURLRejectsInvalidNonEmptyURLAndKeepsPreviousValue() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "https://nagios.example/nagios/cgi-bin/",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let didUpdate = MonitoringInstances().updateUrl(monitoringInstance: placeholder, url: "not a url")

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(placeholder.url, "https://nagios.example/nagios/cgi-bin/")
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.url, "https://nagios.example/nagios/cgi-bin/")
    }

    func testMonitoringInstancesUpdateURLAllowsEmptyDisabledPlaceholderURL() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "https://nagios.example/nagios/cgi-bin/",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let didUpdate = MonitoringInstances().updateUrl(monitoringInstance: placeholder, url: "")

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(placeholder.url, "")
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.url, "")
    }

    func testMonitoringInstancesUpdateURLRejectsEmptyURLForEnabledRemote() throws {
        seedSavePassword(false)
        let remote = MonitoringInstance().initDefault(
            name: "production",
            url: "https://nagios.example/nagios/cgi-bin/",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 1
        )
        MonitoringInstances().insert(key: "production", value: remote)

        let didUpdate = MonitoringInstances().updateUrl(monitoringInstance: remote, url: "")

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(remote.url, "https://nagios.example/nagios/cgi-bin/")
        XCTAssertEqual(MonitoringInstances().getByKey("production")?.url, "https://nagios.example/nagios/cgi-bin/")
    }

    func testMonitoringInstancesRejectsEnablingRemoteWithEmptyURL() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let didUpdate = MonitoringInstances().updateEnabled(monitoringInstance: placeholder, enabled: 1)

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(placeholder.enabled, 0)
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.enabled, 0)
    }

    func testMonitoringInstancesAllowsEnablingRemoteWithValidURL() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "https://icinga.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let didUpdate = MonitoringInstances().updateEnabled(monitoringInstance: placeholder, enabled: 1)

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(placeholder.enabled, 1)
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.enabled, 1)
    }

    func testMonitoringInstancesTableTypeControlPersistsSelectedBackend() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "https://icinga-table.example/icinga/cgi-bin/",
            type: .Nagios,
            username: "icinga-table-user",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let typeColumn = MITypeTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        let typePopup = try XCTUnwrap(typeColumn.createViewForRow(0) as? NSPopUpButton)
        XCTAssertEqual(typePopup.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "type", row: 0))
        typePopup.selectItem(withTitle: MonitoringInstanceType.Icinga.rawValue)
        typeColumn.popupButtonClick(typePopup)

        XCTAssertEqual(MonitoringInstances().getByKey("New")?.type, .Icinga)
    }

    func testMonitoringInstancesStatusCellHasStableAccessibilityIdentifiers() throws {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "disabled",
            url: "",
            type: .Nagios,
            username: "",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)

        let statusView = MIStatusTableColumn(identifier: NSUserInterfaceItemIdentifier("status")).createViewForRow(0)
        let text = try XCTUnwrap(firstSubview(in: statusView, matching: { $0.accessibilityIdentifier() == MonitoringInstancesAccessibility.cellIdentifier(column: "status.text", row: 0) }) as? NSTextField)
        let image = try XCTUnwrap(firstSubview(in: statusView, matching: { $0.accessibilityIdentifier() == MonitoringInstancesAccessibility.cellIdentifier(column: "status.image", row: 0) }) as? NSImageView)

        XCTAssertEqual(statusView.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "status", row: 0))
        XCTAssertEqual(statusView.accessibilityLabel(), "Monitoring instance connection status")
        XCTAssertEqual(text.stringValue, "unknown")
        XCTAssertNotNil(image.image)
    }

    func testMonitoringInstancesStatusCellShowsOkForEnabledLocalIcingaRemote() throws {
        seedSavePassword(false)
        let monitoringInstance = LocalIcingaFallback.instance()
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: monitoringInstance.password)

        let statusView = MIStatusTableColumn(identifier: NSUserInterfaceItemIdentifier("status")).createViewForRow(0)
        let text = try XCTUnwrap(firstSubview(in: statusView, matching: { $0.accessibilityIdentifier() == MonitoringInstancesAccessibility.cellIdentifier(column: "status.text", row: 0) }) as? NSTextField)

        XCTAssertEqual(text.stringValue, "checking")
        try waitForTextField(text, value: "ok")
    }

    func testMonitoringInstancesStatusCellShowsErrorForEnabledUnreachableRemote() throws {
        seedSavePassword(false)
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "unreachable",
            url: "http://127.0.0.1:9/icinga/cgi-bin/",
            type: .Icinga,
            username: "local-fallback",
            password: "wrong",
            enabled: 1
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: monitoringInstance.password)

        let statusView = MIStatusTableColumn(identifier: NSUserInterfaceItemIdentifier("status")).createViewForRow(0)
        let text = try XCTUnwrap(firstSubview(in: statusView, matching: { $0.accessibilityIdentifier() == MonitoringInstancesAccessibility.cellIdentifier(column: "status.text", row: 0) }) as? NSTextField)

        XCTAssertEqual(text.stringValue, "checking")
        try waitForTextField(text, value: "error")
    }

    func testMonitoringInstancesTableDelegateCreatesViewThroughColumnEntrypoint() throws {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "delegate-row",
            url: "https://delegate.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "delegate-user",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        let table = NSTableView()
        let column = MIURLTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        table.addTableColumn(column)

        let view = try XCTUnwrap(MonitoringInstancesTableDelegate().tableView(table, viewFor: column, row: 0) as? MIURLTextField)

        XCTAssertEqual(view.stringValue, "https://delegate.example/icinga/cgi-bin/")
        XCTAssertEqual(view.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: "url", row: 0))
    }

    func testMonitoringInstancesEnabledCheckboxPersistsDisabledState() throws {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "enabled-toggle",
            url: "https://toggle.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "toggle-user",
            password: "",
            enabled: 1
        )
        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        let column = MIEnabledTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        let button = try XCTUnwrap(column.createViewForRow(0) as? NSButton)

        XCTAssertEqual(button.state, .on)

        button.state = .off
        column.checkButtonClick(button)

        XCTAssertEqual(MonitoringInstances().getByKey("enabled-toggle")?.enabled, 0)
    }

    func testMonitoringInstancesWindowXIBAddRowAndPersistAuthFieldsThroughTableControls() throws {
        seedSavePassword(false)
        let controller = MonitoringInstancesWindowController(windowNibName: "MonitoringInstancesWindow")
        let window = try XCTUnwrap(controller.window)
        let table = try XCTUnwrap(controller.monitoringInstancesTable)
        let segmentControl = try XCTUnwrap(firstSubview(
            in: window.contentView,
            matching: { ($0 as? NSSegmentedControl)?.identifier?.rawValue == MonitoringInstancesAccessibility.segmentControlIdentifier }
        ) as? NSSegmentedControl)

        XCTAssertEqual(window.accessibilityIdentifier(), MonitoringInstancesAccessibility.windowIdentifier)
        XCTAssertEqual(table.accessibilityIdentifier(), MonitoringInstancesAccessibility.tableIdentifier)
        XCTAssertTrue(table.delegate is MonitoringInstancesTableDelegate)
        XCTAssertTrue(table.dataSource is MonitoringInstancesTableDatasource)
        XCTAssertEqual(table.tableColumns.map { $0.identifier.rawValue }, ["name", "enabled", "status", "type", "url", "username", "password"])
        XCTAssertEqual(table.tableColumns.map { $0.headerCell.stringValue }, ["Name", "Enabled", "Status", "Type", "Base URL", "Auth Username", "Auth Password"])
        XCTAssertTrue(textFieldStrings(in: window.contentView).contains("Authentication is per monitoring instance. Saved passwords follow the Keychain setting in Preferences."))

        XCTAssertEqual(segmentControl.segmentCount, 2)
        XCTAssertEqual(segmentControl.label(forSegment: 0), "+")
        XCTAssertEqual(segmentControl.label(forSegment: 1), "-")

        let addControl = NSSegmentedControl(labels: ["+", "-"], trackingMode: .selectOne, target: nil, action: nil)
        addControl.selectedSegment = 0
        controller.segControlClicked(addControl)

        XCTAssertEqual(table.numberOfRows, 1)
        _ = try XCTUnwrap(MonitoringInstances().getByKey("New"))
        XCTAssertEqual(MonitoringInstances().getByKey("New")?.enabled, 0)

        let nameField = try XCTUnwrap(tableCell(for: "name", row: 0, table: table) as? MINameTextField)
        nameField.textDidBeginEditing(Notification(name: NSText.didBeginEditingNotification))
        nameField.stringValue = "xib-icinga"
        nameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let typePopup = try XCTUnwrap(tableCell(for: "type", row: 0, table: table) as? NSPopUpButton)
        XCTAssertEqual(typePopup.itemTitles, MonitoringInstanceType.allValues)
        typePopup.selectItem(withTitle: MonitoringInstanceType.Icinga.rawValue)
        (typePopup.target as? MITypeTableColumn)?.popupButtonClick(typePopup)

        let urlField = try XCTUnwrap(tableCell(for: "url", row: 0, table: table) as? MIURLTextField)
        urlField.stringValue = "https://xib.example/icinga/cgi-bin/"
        urlField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let usernameField = try XCTUnwrap(tableCell(for: "username", row: 0, table: table) as? MIUsernameTextField)
        usernameField.stringValue = "xib-user"
        usernameField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let passwordField = try XCTUnwrap(tableCell(for: "password", row: 0, table: table) as? MIPasswordTextField)
        passwordField.stringValue = "xib-pass"
        passwordField.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))

        let stored = try XCTUnwrap(MonitoringInstances().getByKey("xib-icinga"))
        XCTAssertEqual(stored.type, .Icinga)
        XCTAssertEqual(stored.url, "https://xib.example/icinga/cgi-bin/")
        XCTAssertEqual(stored.username, "xib-user")
        XCTAssertEqual(stored.password, "xib-pass")
        XCTAssertEqual(stored.enabled, 0)
    }

    func testMonitoringInstancesTypeControlListsEverySupportedBackend() throws {
        seedSavePassword(false)
        let placeholder = MonitoringInstance().initDefault(
            name: "New",
            url: "https://monitoring.example/",
            type: .Nagios,
            username: "monitoring-user",
            password: "",
            enabled: 0
        )
        MonitoringInstances().insert(key: "New", value: placeholder)

        let typePopup = try XCTUnwrap(MITypeTableColumn(identifier: NSUserInterfaceItemIdentifier("type")).createViewForRow(0) as? NSPopUpButton)

        XCTAssertEqual(typePopup.itemTitles, MonitoringInstanceType.allValues)
        XCTAssertTrue(typePopup.itemTitles.contains(MonitoringInstanceType.Check_MK.rawValue))
    }

    func testEnabledConfiguredMonitoringInstanceIsAvailableForPasswordPromptDecision() {
        seedSavePassword(false)
        _ = storedMonitoringInstance(name: "enabled-real-remote", enabled: 1)

        XCTAssertTrue(MonitoringInstances().hasEnabledConfiguredInstances())
    }

    func testSavingRealRemoteReplacesLocalIcingaFallbackInEnabledList() throws {
        seedSavePassword(false)
        let stored = storedMonitoringInstance(name: "enabled-real-remote", enabled: 1)

        let enabled = MonitoringInstances().getAllEnabled()
        let realRemote = try XCTUnwrap(enabled[stored.name])

        XCTAssertEqual(enabled.count, 1)
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
        XCTAssertEqual(realRemote.url, "https://monitoring.example")
        XCTAssertEqual(realRemote.type, .Nagios)
        XCTAssertEqual(realRemote.username, "user")
        XCTAssertEqual(realRemote.enabled, 1)
    }

    func testLocalIcingaFallbackUsesNormalIcingaCommandSurfaceAgainstLocalServer() {
        let capabilities = LocalIcingaFallback.instance().monitoringProcessor().command().capabilities()

        XCTAssertEqual(capabilities.count, 4)
        XCTAssertTrue(capabilities.contains { if case .acknowledge = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .openInBrowser = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .recheck = $0 { return true } else { return false } })
        XCTAssertTrue(capabilities.contains { if case .scheduleDowntime = $0 { return true } else { return false } })
    }

    func testLocalIcingaFallbackConnectsThroughNormalIcingaHTTPClient() {
        let expectation = self.expectation(description: "Local fake Icinga server accepts normal Icinga connection check")
        let instance = LocalIcingaFallback.instance()
        var checkResult = false

        instance.monitoringProcessor().httpClient().checkConnection().done { result in
            checkResult = result
            expectation.fulfill()
        }.catch { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3)

        XCTAssertTrue(checkResult)
    }

    func testCheckMKDoesNotAdvertiseUnsupportedCommands() {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "checkmk",
            url: "https://monitoring.example/site/check_mk/",
            type: .Check_MK,
            username: "site-user",
            password: "site-pass",
            enabled: 1
        )

        let capabilities = monitoringInstance.monitoringProcessor().command().capabilities()

        XCTAssertEqual(capabilities.count, 1)
        if case .openInBrowser = capabilities[0] {
        } else {
            XCTFail("Check_MK should only support opening items in the browser")
        }
    }

    func testCheckMKHTTPPostRejectsUnsupportedCommands() {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "checkmk",
            url: "https://monitoring.example/site/check_mk/",
            type: .Check_MK,
            username: "site-user",
            password: "site-pass",
            enabled: 1
        )
        let expectation = self.expectation(description: "Reject unsupported Check_MK POST")
        var rejectedError: NSError?

        CheckMKHTTPClient(monitoringInstance).post("https://monitoring.example/site/check_mk/unsupported.py", postData: ["cmd": "acknowledge"]).done { _ in
            expectation.fulfill()
        }.catch { error in
            rejectedError = error as NSError
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)

        XCTAssertEqual(rejectedError?.domain, "NagBar.CheckMKHTTPClient")
        XCTAssertEqual(rejectedError?.localizedDescription, "Check_MK commands are not supported")
    }

    func testUpdatePasswordStoresAndReloadsPasswordWhenSavingIsEnabled() {
        seedSavePassword(true)
        let monitoringInstance = storedMonitoringInstance(name: "saved-password")

        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: "stored-secret")
        PasswordStore.sharedInstance.removeAll()

        let reloaded = MonitoringInstances().getByKey("saved-password")

        XCTAssertEqual(reloaded?.password, "stored-secret")
    }

    func testUpdatePasswordDeletesPersistedPasswordWhenSavingIsDisabled() {
        seedSavePassword(true)
        let monitoringInstance = storedMonitoringInstance(name: "unsaved-password")
        let monitoringInstances = MonitoringInstances()
        monitoringInstances.updatePassword(monitoringInstance: monitoringInstance, password: "temporary-secret")

        seedSavePassword(false)
        monitoringInstances.updatePassword(monitoringInstance: monitoringInstance, password: "temporary-secret")
        PasswordStore.sharedInstance.removeAll()

        let reloaded = MonitoringInstances().getByKey("unsaved-password")

        XCTAssertEqual(reloaded?.password, "")
    }

    func testSavePasswordButtonOffDeletesPersistedPasswordsButKeepsRuntimeCache() {
        seedSavePassword(true)
        let monitoringInstance = storedMonitoringInstance(name: "button-unsaved-password")
        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: "runtime-secret")
        let button = savePasswordButton(state: .off)

        button.performAction()

        XCTAssertFalse(Settings().boolForKey("savePassword"))
        XCTAssertEqual(PasswordStore.sharedInstance.get("button-unsaved-password"), "runtime-secret")

        PasswordStore.sharedInstance.removeAll()
        seedSavePassword(true)
        XCTAssertEqual(MonitoringInstances().getByKey("button-unsaved-password")?.password, "")
    }

    func testSavePasswordButtonOnPersistsRuntimePasswords() {
        seedSavePassword(false)
        _ = storedMonitoringInstance(name: "button-saved-password")
        PasswordStore.sharedInstance.set("button-saved-password", password: "runtime-secret")
        let button = savePasswordButton(state: .on)

        button.performAction()

        XCTAssertTrue(Settings().boolForKey("savePassword"))
        PasswordStore.sharedInstance.removeAll()
        XCTAssertEqual(MonitoringInstances().getByKey("button-saved-password")?.password, "runtime-secret")
    }

    func testAcceptInvalidCertificatesButtonStoresSettingAndRefreshesConnectionManager() {
        let button = AcceptInvalidCertificatesButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        button.identifier = NSUserInterfaceItemIdentifier("acceptInvalidCertificates")
        button.state = .on

        button.performAction()

        XCTAssertTrue(Settings().boolForKey("acceptInvalidCertificates"))
    }

    func testMonitoringInstanceCollectionUpdatesFiltersAndRemovesBySortedId() {
        seedSavePassword(false)
        let disabled = storedMonitoringInstance(name: "beta-disabled", enabled: 0)
        let enabled = storedMonitoringInstance(name: "alpha-enabled", enabled: 1)
        let monitoringInstances = MonitoringInstances()

        monitoringInstances.updateName(monitoringInstance: disabled, name: "gamma-renamed")
        monitoringInstances.updateUrl(monitoringInstance: enabled, url: "https://changed.example")
        monitoringInstances.updateType(monitoringInstance: enabled, type: .Icinga2)
        monitoringInstances.updateEnabled(monitoringInstance: disabled, enabled: 1)
        monitoringInstances.updateUsername(monitoringInstance: enabled, username: "changed-user")

        XCTAssertEqual(monitoringInstances.count(), 2)
        XCTAssertEqual(monitoringInstances.getAllEnabled().count, 2)
        XCTAssertEqual(monitoringInstances.getByKey("alpha-enabled")?.url, "https://changed.example")
        XCTAssertEqual(monitoringInstances.getByKey("alpha-enabled")?.type, .Icinga2)
        XCTAssertEqual(monitoringInstances.getByKey("alpha-enabled")?.username, "changed-user")
        XCTAssertEqual(monitoringInstances.getKeyById(0), "alpha-enabled")
        XCTAssertEqual(monitoringInstances.getKeyById(1), "gamma-renamed")

        monitoringInstances.removeById(0)

        XCTAssertNil(monitoringInstances.getByKey("alpha-enabled"))
        XCTAssertEqual(monitoringInstances.count(), 1)
    }

    func testRemovingMonitoringInstanceDeletesPersistedPassword() {
        seedSavePassword(true)
        let monitoringInstance = storedMonitoringInstance(name: "with-password")
        let monitoringInstances = MonitoringInstances()

        monitoringInstances.updatePassword(monitoringInstance: monitoringInstance, password: "secret")
        monitoringInstances.removeById(0)
        PasswordStore.sharedInstance.removeAll()

        XCTAssertNil(monitoringInstances.getByKey("with-password"))
        XCTAssertNil((KeychainAccess().get() as? InMemoryKeychainClient)?.password(forService: "NagBar", account: "with-password"))
    }

    func testMonitoringInstanceJSONStorageDoesNotPersistPassword() throws {
        seedSavePassword(false)
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "json-instance",
            url: "https://monitoring.example",
            type: .Check_MK,
            username: "site-user",
            password: "runtime-secret",
            enabled: 1
        )

        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)

        let storageURL = try XCTUnwrap(MonitoringInstances.storageURLOverride)
        let rawJSON = try String(contentsOf: storageURL, encoding: .utf8)
        let reloaded = MonitoringInstances().getByKey("json-instance")

        XCTAssertFalse(rawJSON.contains("runtime-secret"))
        XCTAssertFalse(rawJSON.contains("password"))
        XCTAssertEqual(reloaded?.type, .Check_MK)
        XCTAssertEqual(reloaded?.password, "")
    }

    func testCurrentJSONAndKeychainConfigurationSurvivesInitConfigUpgradePath() throws {
        seedSavePassword(true)
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "surviving-remote",
            url: "https://survives.example/icinga/cgi-bin/",
            type: .Icinga,
            username: "icinga-user",
            password: "runtime-secret",
            enabled: 1
        )
        let filter = FilterItem().initDefault(host: "web-.*", service: "Disk", status: 24)
        let monitoringItem = HostMonitoringItem()
        monitoringItem.host = "web-01.example"

        MonitoringInstances().insert(key: monitoringInstance.name, value: monitoringInstance)
        MonitoringInstances().updatePassword(monitoringInstance: monitoringInstance, password: "keychain-secret")
        FilterItems().insert(key: FilterItems.generateKey(filter.host, service: filter.service), value: filter)
        ServerLogin().setUsername(monitoringItem, username: "deploy")
        ServerLogin().setLoginType(monitoringItem, loginType: .rdp)
        Settings().setString("45", forKey: "refreshInterval")
        PasswordStore.sharedInstance.removeAll()

        Settings().seedMissingDefaults()
        UpgradeCompatibility.writeReportIfNeeded()

        let reloadedRemote = try XCTUnwrap(MonitoringInstances().getByKey("surviving-remote"))
        let reloadedFilter = try XCTUnwrap(FilterItems().getByKey("web-.*Disk"))

        XCTAssertEqual(reloadedRemote.url, "https://survives.example/icinga/cgi-bin/")
        XCTAssertEqual(reloadedRemote.type, .Icinga)
        XCTAssertEqual(reloadedRemote.username, "icinga-user")
        XCTAssertEqual(reloadedRemote.password, "keychain-secret")
        XCTAssertEqual(reloadedRemote.enabled, 1)
        XCTAssertEqual(reloadedFilter.status, 24)
        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "deploy")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .rdp)
        XCTAssertEqual(Settings().integerForKey("refreshInterval"), 45)
        XCTAssertFalse(FileManager.default.fileExists(atPath: UpgradeCompatibility.reportURL().path))
    }

    func testLegacyRealmOnlyConfigurationWritesManualReconfigurationReport() throws {
        let applicationSupportDirectory = try XCTUnwrap(NagBarStorage.applicationSupportDirectoryOverride)
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        let legacyRealmURL = bundleDirectory.appendingPathComponent("default.realm", isDirectory: false)
        try Data("legacy realm placeholder".utf8).write(to: legacyRealmURL)

        let report = UpgradeCompatibility.writeReportIfNeeded()
        let reportData = try Data(contentsOf: UpgradeCompatibility.reportURL())
        let decodedReport = try JSONDecoder().decode(UpgradeCompatibilityReport.self, from: reportData)

        XCTAssertTrue(applicationSupportDirectory.path.hasSuffix("ApplicationSupport"))
        XCTAssertTrue(report.requiresManualReconfiguration)
        XCTAssertTrue(report.legacyRealmFiles.contains(legacyRealmURL.path))
        XCTAssertTrue(report.currentJSONFiles.isEmpty)
        XCTAssertTrue(report.message.contains("Reconfigure monitoring instances in Settings"))
        XCTAssertEqual(decodedReport.requiresManualReconfiguration, true)
        XCTAssertEqual(decodedReport.legacyRealmFiles, report.legacyRealmFiles)
        XCTAssertEqual(MonitoringInstances().getAll().count, 0)
        XCTAssertNotNil(MonitoringInstances().getAllEnabled()[LocalIcingaFallback.instanceName])
    }

    func testLegacyRealmDetectionCoversRawApplicationSupportLocation() throws {
        let applicationSupportDirectory = try XCTUnwrap(NagBarStorage.applicationSupportDirectoryOverride)
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let legacyRealmURL = applicationSupportDirectory.appendingPathComponent("default.realm", isDirectory: false)
        try Data("legacy realm placeholder".utf8).write(to: legacyRealmURL)

        let report = UpgradeCompatibility.writeReportIfNeeded()

        XCTAssertTrue(report.requiresManualReconfiguration)
        XCTAssertTrue(report.legacyRealmFiles.contains(legacyRealmURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: UpgradeCompatibility.reportURL().path))
    }

    func testLegacyRealmWithCurrentJSONUsesCurrentConfigurationAndReportsNoManualReconfiguration() throws {
        seedSavePassword(false)
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        let legacyRealmURL = bundleDirectory.appendingPathComponent("default.realm", isDirectory: false)
        try Data("legacy realm placeholder".utf8).write(to: legacyRealmURL)
        let currentRemote = storedMonitoringInstance(name: "current-json-remote", enabled: 1)

        let report = UpgradeCompatibility.writeReportIfNeeded()
        let enabled = MonitoringInstances().getAllEnabled()

        XCTAssertFalse(report.requiresManualReconfiguration)
        XCTAssertTrue(report.legacyRealmFiles.contains(legacyRealmURL.path))
        XCTAssertTrue(report.currentJSONFiles.contains(try XCTUnwrap(MonitoringInstances.storageURLOverride).path))
        XCTAssertEqual(enabled.count, 1)
        XCTAssertNotNil(enabled[currentRemote.name])
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
    }

    func testLegacyRealmWithMalformedCurrentMonitoringJSONRequiresManualReconfiguration() throws {
        seedSavePassword(false)
        let bundleDirectory = NagBarStorage.bundleStorageDirectory()
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        let legacyRealmURL = bundleDirectory.appendingPathComponent("default.realm", isDirectory: false)
        try Data("legacy realm placeholder".utf8).write(to: legacyRealmURL)
        let storageURL = try XCTUnwrap(MonitoringInstances.storageURLOverride)
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ malformed monitoring json".utf8).write(to: storageURL)

        let report = UpgradeCompatibility.writeReportIfNeeded()
        let enabled = MonitoringInstances().getAllEnabled()

        XCTAssertTrue(report.requiresManualReconfiguration)
        XCTAssertTrue(report.legacyRealmFiles.contains(legacyRealmURL.path))
        XCTAssertTrue(report.currentJSONFiles.contains(storageURL.path))
        XCTAssertTrue(report.message.contains("no valid current monitoring remote configuration"))
        XCTAssertNotNil(enabled[LocalIcingaFallback.instanceName])
    }

    func testMonitoringInstanceDuplicateNamesCollapseToLastStoredInstance() {
        seedSavePassword(false)
        let first = MonitoringInstance().initDefault(name: "duplicate", url: "https://first.example", type: .Nagios, username: "first", password: "", enabled: 1)
        let second = MonitoringInstance().initDefault(name: "duplicate", url: "https://second.example", type: .Icinga2, username: "second", password: "", enabled: 1)

        MonitoringInstances().insert(key: first.name, value: first)
        MonitoringInstances().insert(key: second.name, value: second)

        XCTAssertEqual(MonitoringInstances().count(), 1)
        XCTAssertEqual(MonitoringInstances().getByKey("duplicate")?.url, "https://second.example")
        XCTAssertEqual(MonitoringInstances().getByKey("duplicate")?.type, .Icinga2)
    }

    func testEnabledFilteringOnlyIncludesEnabledValueOne() {
        seedSavePassword(false)

        _ = storedMonitoringInstance(name: "disabled-zero", enabled: 0)
        _ = storedMonitoringInstance(name: "enabled-one", enabled: 1)
        _ = storedMonitoringInstance(name: "enabled-other", enabled: 2)

        let enabled = MonitoringInstances().getAllEnabled()

        XCTAssertEqual(enabled.count, 1)
        XCTAssertNotNil(enabled["enabled-one"])
        XCTAssertNil(enabled["disabled-zero"])
        XCTAssertNil(enabled["enabled-other"])
    }

    func testEnabledFilteringExcludesInvalidEnabledRemotesWhenConfiguredRemoteExists() {
        seedSavePassword(false)
        _ = storedMonitoringInstance(name: "valid-remote", enabled: 1)
        let invalidRemote = MonitoringInstance().initDefault(
            name: "invalid-remote",
            url: "not a url",
            type: .Nagios,
            username: "user",
            password: "",
            enabled: 1
        )
        MonitoringInstances().insert(key: invalidRemote.name, value: invalidRemote)

        let enabled = MonitoringInstances().getAllEnabled()

        XCTAssertEqual(enabled.count, 1)
        XCTAssertNotNil(enabled["valid-remote"])
        XCTAssertNil(enabled["invalid-remote"])
        XCTAssertNil(enabled[LocalIcingaFallback.instanceName])
    }

    func testServerLoginSettingsPersistUpdateAndRemoveByHost() {
        let monitoringItem = HostMonitoringItem()
        monitoringItem.host = "web-01.example"
        let menuItem = NSMenuItem()
        menuItem.representedObject = monitoringItem
        let serverLogin = ServerLogin()

        XCTAssertNil(serverLogin.getUsername(monitoringItem))
        XCTAssertNil(serverLogin.getLoginType(monitoringItem))

        serverLogin.setUsername(monitoringItem, username: "deploy")

        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "deploy")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .ssh)

        serverLogin.setLoginType(monitoringItem, loginType: .rdp)

        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "deploy")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .rdp)

        serverLogin.setUsername(monitoringItem, username: "ops")

        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "ops")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .rdp)

        ServerLogin().removeLoginSettings(menuItem)
        ServerLogin().removeLoginSettings(menuItem)

        XCTAssertNil(ServerLogin().getUsername(monitoringItem))
        XCTAssertNil(ServerLogin().getLoginType(monitoringItem))
    }

    func testServerLoginImportLegacyItemsSeedsEmptyStorage() {
        let monitoringItem = HostMonitoringItem()
        monitoringItem.host = "web-01.example"
        let legacyItem = ServerLoginItem(host: monitoringItem.host, username: "deploy", loginType: LoginType.rdp.rawValue)

        ServerLogin().importLegacyItems([legacyItem])

        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "deploy")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .rdp)
    }

    func testServerLoginImportLegacyItemsDoesNotOverwriteExistingStorage() {
        let currentItem = HostMonitoringItem()
        currentItem.host = "current.example"
        let legacyItem = HostMonitoringItem()
        legacyItem.host = "legacy.example"
        ServerLogin().setUsername(currentItem, username: "ops")
        ServerLogin().setLoginType(currentItem, loginType: .ssh)

        ServerLogin().importLegacyItems([
            ServerLoginItem(host: legacyItem.host, username: "deploy", loginType: LoginType.rdp.rawValue)
        ])

        XCTAssertEqual(ServerLogin().getUsername(currentItem), "ops")
        XCTAssertEqual(ServerLogin().getLoginType(currentItem), .ssh)
        XCTAssertNil(ServerLogin().getUsername(legacyItem))
        XCTAssertNil(ServerLogin().getLoginType(legacyItem))
    }

    func testServerLoginMalformedStorageReturnsEmptyAndRecoversOnSave() throws {
        let storageURL = try XCTUnwrap(ServerLogin.storageURLOverride)
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: storageURL)
        let monitoringItem = HostMonitoringItem()
        monitoringItem.host = "web-01.example"

        XCTAssertNil(ServerLogin().getUsername(monitoringItem))
        XCTAssertNil(ServerLogin().getLoginType(monitoringItem))

        ServerLogin().setUsername(monitoringItem, username: "deploy")

        XCTAssertEqual(ServerLogin().getUsername(monitoringItem), "deploy")
        XCTAssertEqual(ServerLogin().getLoginType(monitoringItem), .ssh)
    }

    private func storedMonitoringInstance(name: String, enabled: Int = 1) -> MonitoringInstance {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: name,
            url: "https://monitoring.example",
            type: .Nagios,
            username: "user",
            password: "",
            enabled: enabled
        )

        MonitoringInstances().insert(key: name, value: monitoringInstance)
        return monitoringInstance
    }

    private func writeMonitoringInstancesJSON(_ json: String) throws {
        let storageURL = try XCTUnwrap(MonitoringInstances.storageURLOverride)
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.data(using: .utf8)?.write(to: storageURL, options: .atomic)
    }

    private func seedSavePassword(_ enabled: Bool) {
        Settings().setBool(enabled, forKey: "savePassword")
    }

    private func savePasswordButton(state: NSControl.StateValue) -> SavePasswordButton {
        let button = SavePasswordButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        button.identifier = NSUserInterfaceItemIdentifier("savePassword")
        button.state = state
        return button
    }

    private func tableCell(for identifier: String, row: Int, table: NSTableView) -> NSView? {
        guard let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == identifier }),
              let tableColumn = table.tableColumns[columnIndex] as? MonitoringInstancesTableColumn else {
            return nil
        }

        let view = tableColumn.createViewForRow(row)
        XCTAssertEqual(view.accessibilityIdentifier(), MonitoringInstancesAccessibility.cellIdentifier(column: identifier, row: row))
        return view
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

    private func textFieldStrings(in view: NSView?) -> [String] {
        guard let view = view else {
            return []
        }

        return view.subviews.flatMap { subview -> [String] in
            let ownText = (subview as? NSTextField).map { [$0.stringValue] } ?? []
            return ownText + textFieldStrings(in: subview)
        }
    }

    private func waitForTextField(_ textField: NSTextField, value: String, timeout: TimeInterval = 5) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if textField.stringValue == value {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail("Timed out waiting for text field value \(value), current value: \(textField.stringValue)")
    }

//    func testGetMonitoringInstances() {
//        monitoringInstances.setPassword("testname", password: "testpass")
//        var monitoringInstancesList = self.monitoringInstances.getMonitoringInstances()
//        
//        XCTAssertEqual(monitoringInstancesList.first?.url, "http://testmonitoring/cgi-bin/")
//        XCTAssertEqual(monitoringInstancesList.first?.hostUrl, "http://testmonitoring/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=5&hostprops=10242&limit=0")
//        XCTAssertEqual(monitoringInstancesList.first?.serviceUrl, "http://testmonitoring/cgi-bin/status.cgi?service=all&hoststatustypes=2&servicestatustypes=9&sorttype=3&serviceprops=7&serviceprops=262152&limit=0")
//        XCTAssertEqual(monitoringInstancesList.first?.username, "testuser")
//        XCTAssertEqual(monitoringInstancesList.first?.password, "testpass")
//        XCTAssertEqual(monitoringInstancesList.first?.type, MonitoringInstanceType.Nagios)
//        XCTAssertEqual(monitoringInstancesList.first?.enabled, 1)
//        
//        // test with wrong password
//        monitoringInstances.setPassword("testname", password: "testpass2")
//        monitoringInstancesList = self.monitoringInstances.getMonitoringInstances()
//        XCTAssertNotEqual(monitoringInstancesList.first?.password, "testpass")
//    }
}
