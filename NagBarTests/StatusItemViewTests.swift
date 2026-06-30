//
//  StatusItemViewTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest

final class StatusItemViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ServerLogin.storageURLOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("NagBarTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
            .appendingPathExtension("server-login.json")
        ServerLogin().resetStorage()
        closeStatusPanelWindows()
        Settings().resetKnownSettings()
        Settings().setBool(false, forKey: "flashStatusBar")
        Settings().setBool(false, forKey: "showExtendedStatusInformation")
        disableOptionalStatusPanelColumns()
    }

    override func tearDown() {
        closeStatusPanelWindows()
        Settings().resetKnownSettings()
        ServerLogin().resetStorage()
        ServerLogin.storageURLOverride = nil
        super.tearDown()
    }

    func testStatusItemMenuContainsSingleEntrypointActions() {
        let target = StatusItemMenuTarget()

        let menu = StatusItemMenuBuilder.build(
            target: target,
            actions: StatusItemMenuActions(
                status: #selector(StatusItemMenuTarget.showStatus),
                about: #selector(StatusItemMenuTarget.showAbout),
                preferences: #selector(StatusItemMenuTarget.openPreferences),
                refresh: #selector(StatusItemMenuTarget.refresh)
            )
        )

        XCTAssertEqual(menu.items.map { $0.title }, ["Show Status", "", "About NagBar", "Preferences", "", "Refresh", "", "Quit"])
        XCTAssertEqual(menu.items[0].action, #selector(StatusItemMenuTarget.showStatus))
        XCTAssertTrue(menu.items[0].target === target)
        XCTAssertEqual(menu.items[0].accessibilityIdentifier(), StatusItemAccessibility.showStatusIdentifier)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].action, #selector(StatusItemMenuTarget.showAbout))
        XCTAssertTrue(menu.items[2].target === target)
        XCTAssertEqual(menu.items[2].accessibilityIdentifier(), StatusItemAccessibility.aboutIdentifier)
        XCTAssertEqual(menu.items[3].action, #selector(StatusItemMenuTarget.openPreferences))
        XCTAssertTrue(menu.items[3].target === target)
        XCTAssertEqual(menu.items[3].accessibilityIdentifier(), StatusItemAccessibility.preferencesIdentifier)
        XCTAssertTrue(menu.items[4].isSeparatorItem)
        XCTAssertEqual(menu.items[5].action, #selector(StatusItemMenuTarget.refresh))
        XCTAssertTrue(menu.items[5].target === target)
        XCTAssertEqual(menu.items[5].accessibilityIdentifier(), StatusItemAccessibility.refreshIdentifier)
        XCTAssertTrue(menu.items[6].isSeparatorItem)
        XCTAssertEqual(menu.items[7].action, #selector(NSApplication.terminate(_:)))
        XCTAssertTrue(menu.items[7].target === NSApplication.shared)
        XCTAssertEqual(menu.items[7].accessibilityIdentifier(), StatusItemAccessibility.quitIdentifier)
    }

    func testStatusItemMenuIncludesPreferencesWhenDockIconIsVisible() {
        Settings().resetKnownSettings()
        Settings().setBool(true, forKey: "showDockIcon")
        let target = StatusItemMenuTarget()

        let menu = StatusItemMenuBuilder.build(
            target: target,
            actions: StatusItemMenuActions(
                status: #selector(StatusItemMenuTarget.showStatus),
                about: #selector(StatusItemMenuTarget.showAbout),
                preferences: #selector(StatusItemMenuTarget.openPreferences),
                refresh: #selector(StatusItemMenuTarget.refresh)
            )
        )

        XCTAssertTrue(menu.items.contains { $0.title == "Preferences" })
    }

    func testStatusItemAccessibilityDescribesMenuEntrypoint() {
        XCTAssertEqual(StatusItemAccessibility.title, "NagBar status menu")
        XCTAssertEqual(StatusItemAccessibility.help, "Opens NagBar status, settings, refresh, and quit actions.")
        XCTAssertEqual(StatusItemAccessibility.failedTitle, "NagBar monitoring connection warnings")
        XCTAssertEqual(StatusItemAccessibility.failedHelp, "Opens monitoring instances that failed during refresh.")
        XCTAssertEqual(StatusItemAccessibility.statusItemButtonIdentifier, "nagbar.statusItem.button")
        XCTAssertEqual(StatusItemAccessibility.failedStatusItemButtonIdentifier, "nagbar.statusItem.failed.button")
        XCTAssertEqual(StatusItemAccessibility.showStatusIdentifier, "nagbar.statusItem.showStatus")
        XCTAssertEqual(StatusItemAccessibility.aboutIdentifier, "nagbar.statusItem.about")
        XCTAssertEqual(StatusItemAccessibility.preferencesIdentifier, "nagbar.statusItem.preferences")
        XCTAssertEqual(StatusItemAccessibility.refreshIdentifier, "nagbar.statusItem.refresh")
        XCTAssertEqual(StatusItemAccessibility.quitIdentifier, "nagbar.statusItem.quit")
        XCTAssertEqual(StatusItemAccessibility.statusPanelIdentifier, "nagbar.statusPanel")
        XCTAssertEqual(StatusItemAccessibility.statusPanelTableIdentifier, "nagbar.statusPanel.table")
    }

    func testStatusItemAccessibilityMetadataAppliesToMainAndFailureButtons() {
        let mainButton = NSButton()
        let failedButton = NSButton()

        StatusItemAccessibility.applyMainButtonMetadata(to: mainButton)
        StatusItemAccessibility.applyFailedButtonMetadata(to: failedButton)

        XCTAssertEqual(mainButton.accessibilityTitle(), "NagBar status menu")
        XCTAssertEqual(mainButton.accessibilityHelp(), "Opens NagBar status, settings, refresh, and quit actions.")
        XCTAssertEqual(mainButton.accessibilityIdentifier(), "nagbar.statusItem.button")
        XCTAssertEqual(failedButton.accessibilityTitle(), "NagBar monitoring connection warnings")
        XCTAssertEqual(failedButton.accessibilityHelp(), "Opens monitoring instances that failed during refresh.")
        XCTAssertEqual(failedButton.accessibilityIdentifier(), "nagbar.statusItem.failed.button")
    }

    func testStatusPanelRequestBeforeFirstRefreshRequestsRefreshWithoutOpeningPanel() {
        var refreshCount = 0
        var presentCount = 0

        let opened = StatusPanelEntrypoint.requestPresentation(hasResults: false, refresh: {
            refreshCount += 1
        }, present: {
            presentCount += 1
        })

        XCTAssertFalse(opened)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(presentCount, 0)
    }

    func testStatusPanelRequestWithResultsOpensPanelWithoutRefreshing() {
        var refreshCount = 0
        var presentCount = 0

        let opened = StatusPanelEntrypoint.requestPresentation(hasResults: true, refresh: {
            refreshCount += 1
        }, present: {
            presentCount += 1
        })

        XCTAssertTrue(opened)
        XCTAssertEqual(refreshCount, 0)
        XCTAssertEqual(presentCount, 1)
    }

    func testStatusItemRefreshActionUsesInjectedRefreshEntrypoint() {
        var refreshCount = 0

        StatusItemRefreshAction.perform {
            refreshCount += 1
        }

        XCTAssertEqual(refreshCount, 1)
    }

    func testStatusItemTitleFormatterWritesExtendedSummaryTitle() {
        let title = StatusItemTitleFormatter.title(for: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING"),
            host("router-01", status: "UNREACHABLE"),
            host("db-01", status: "DOWN"),
            host("api-01", status: "UP")
        ], showExtendedStatusInformation: true)

        XCTAssertEqual(title, "C:1 W:1 UR:1 D:1 UP:1")
    }

    func testStatusItemTitleFormatterWritesCompactCountTitle() {
        let title = StatusItemTitleFormatter.title(for: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            host("api-01", status: "UP")
        ], showExtendedStatusInformation: false)

        XCTAssertEqual(title, "Total Count: 2")
    }

    func testApplicationMenuPolicyRemovesAboutAndPreferencesEntrypoints() {
        let mainMenu = NSMenu(title: "Main")
        let appMenuItem = NSMenuItem(title: "NagBar", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "NagBar")
        appMenu.addItem(NSMenuItem(title: "About NagBar", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: Selector(("openPreferences:")), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit NagBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        mainMenu.addItem(appMenuItem)
        mainMenu.setSubmenu(appMenu, for: appMenuItem)

        ApplicationMenuPolicy.keepStatusItemAsProductEntrypoint(mainMenu: mainMenu)
        let cleanedMenu = mainMenu.item(at: 0)?.submenu
        let remainingActions = cleanedMenu?.items.compactMap(\.action).map(NSStringFromSelector) ?? []

        XCTAssertFalse(remainingActions.contains("orderFrontStandardAboutPanel:"))
        XCTAssertFalse(remainingActions.contains("openPreferences:"))
        XCTAssertTrue(remainingActions.contains(NSStringFromSelector(#selector(NSApplication.terminate(_:)))))
    }

    func testStatusPanelTableBuildsConfiguredColumnsAndDatasourceRows() {
        Settings().setBool(true, forKey: "monitoringInstance")
        Settings().setBool(true, forKey: "status")
        Settings().setBool(true, forKey: "duration")
        Settings().setBool(true, forKey: "lastCheck")
        Settings().setBool(true, forKey: "attempt")
        Settings().setBool(true, forKey: "statusInformation")

        let table = StatusPanelTable(frame: NSRect(x: 0, y: 0, width: 600, height: 200))

        table.initTable([
            service("web-01", service: "HTTP", status: "CRITICAL"),
            host("router-01", status: "DOWN")
        ])

        XCTAssertEqual(table.accessibilityIdentifier(), StatusItemAccessibility.statusPanelTableIdentifier)
        XCTAssertEqual(table.numberOfRows, 2)
        XCTAssertEqual(table.tableColumns.count, 9)
        XCTAssertTrue(table.tableColumns[0] is SPMonitoringInstanceTableColumn)
        XCTAssertTrue(table.tableColumns[1] is SPHostTableColumn)
        XCTAssertTrue(table.tableColumns[2] is SPServiceTableColumn)
        XCTAssertTrue(table.tableColumns[3] is SPAcknowledgedDowntimeTableColumn)
        XCTAssertTrue(table.tableColumns[4] is SPStatusTableColumn)
        XCTAssertTrue(table.allowsMultipleSelection)
        XCTAssertNil(table.headerView)
    }

    func testStatusPanelLoadCreatesAccessiblePanelWithTableDocumentView() throws {
        Settings().setBool(true, forKey: "status")
        let panel = StatusPanel(
            results: [
                service("web-01", service: "HTTP", status: "CRITICAL"),
                host("router-01", status: "DOWN")
            ],
            panelBounds: NSRect(x: 200, y: 700, width: 40, height: 22)
        )

        panel.load()
        defer { panel.panel?.close() }

        let loadedPanel = try XCTUnwrap(panel.panel)
        let contentView = try XCTUnwrap(loadedPanel.contentView)
        let scrollView = try XCTUnwrap(contentView.subviews.first as? NSScrollView)
        let table = try XCTUnwrap(scrollView.documentView as? StatusPanelTable)

        XCTAssertTrue(loadedPanel.canBecomeKey)
        XCTAssertTrue(loadedPanel.canBecomeMain)
        XCTAssertTrue(loadedPanel.hasShadow)
        XCTAssertEqual(loadedPanel.accessibilityIdentifier(), StatusItemAccessibility.statusPanelIdentifier)
        XCTAssertEqual(contentView.accessibilityIdentifier(), StatusItemAccessibility.statusPanelIdentifier + ".content")
        XCTAssertTrue(scrollView is UnscrollableScrollView)
        XCTAssertEqual(table.accessibilityIdentifier(), StatusItemAccessibility.statusPanelTableIdentifier)
        XCTAssertEqual(table.numberOfRows, 2)
        XCTAssertEqual(table.tableColumns.count, 4)
        XCTAssertEqual(loadedPanel.frame.height, 52)
    }

    func testStatusPanelLoadCapsTallPanelAndAddsScrollArrow() throws {
        let rows = (0..<30).map { index in
            service("web-\(index)", service: "HTTP", status: "WARNING")
        }
        let panel = StatusPanel(
            results: rows,
            panelBounds: NSRect(x: 1000, y: 900, width: 40, height: 22)
        )

        panel.load()
        defer { panel.panel?.close() }

        let loadedPanel = try XCTUnwrap(panel.panel)
        let contentView = try XCTUnwrap(loadedPanel.contentView)
        let scrollView = try XCTUnwrap(contentView.subviews.first as? NSScrollView)
        let table = try XCTUnwrap(scrollView.documentView as? StatusPanelTable)

        XCTAssertEqual(loadedPanel.frame.height, panel.maxPanelHeight)
        XCTAssertTrue(scrollView.subviews.contains { $0 is DrawArrow })
        XCTAssertEqual(table.numberOfRows, 30)
    }

    func testStatusPanelHostColumnSuppressesRepeatedHostOnlyWithinSameMonitoringInstance() {
        let firstInstance = monitoringInstance(name: "primary")
        let secondInstance = monitoringInstance(name: "secondary")
        let rows = [
            service("web-01", service: "HTTP", status: "CRITICAL", monitoringInstance: firstInstance),
            service("web-01", service: "Disk", status: "WARNING", monitoringInstance: firstInstance),
            service("web-01", service: "CPU", status: "WARNING", monitoringInstance: secondInstance),
            service("db-01", service: "Disk", status: "CRITICAL", monitoringInstance: secondInstance)
        ]
        let column = SPHostTableColumn(results: rows)

        XCTAssertEqual(textValue(in: column.createViewForRow(0)), "web-01")
        XCTAssertEqual(textValue(in: column.createViewForRow(1)), "")
        XCTAssertEqual(textValue(in: column.createViewForRow(2)), "web-01")
        XCTAssertEqual(textValue(in: column.createViewForRow(3)), "db-01")
    }

    func testStatusPanelAcknowledgedDowntimeColumnRendersGlyphCombinations() {
        let acknowledged = service("web-01", service: "HTTP", status: "WARNING")
        acknowledged.acknowledged = true
        let downtime = service("web-01", service: "Disk", status: "CRITICAL")
        downtime.downtime = true
        let both = service("web-01", service: "CPU", status: "UNKNOWN")
        both.acknowledged = true
        both.downtime = true
        let neither = service("web-01", service: "Memory", status: "OK")
        let column = SPAcknowledgedDowntimeTableColumn(results: [acknowledged, downtime, both, neither])

        XCTAssertEqual(textValue(in: column.createViewForRow(0)), "✓")
        XCTAssertEqual(textValue(in: column.createViewForRow(1)), "🕒")
        XCTAssertEqual(textValue(in: column.createViewForRow(2)), "✓🕒")
        XCTAssertEqual(textValue(in: column.createViewForRow(3)), "")
    }

    func testStatusPanelContextMenuBuildsIcingaCommandMenuForSingleSelection() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertEqual(menu.items.map(\.title), [
            "login",
            "",
            "openInBrowser",
            "recheck",
            "scheduleDowntime",
            "acknowledge",
            "",
            "addToFilter"
        ])
        XCTAssertNotNil(menu.item(withTitle: "login")?.submenu)
        XCTAssertTrue(menu.item(withTitle: "openInBrowser")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "recheck")?.target is RecheckAction)
        XCTAssertTrue(menu.item(withTitle: "scheduleDowntime")?.target is ScheduleDowntimeAction)
        XCTAssertTrue(menu.item(withTitle: "acknowledge")?.target is AcknowledgeAction)
        XCTAssertTrue(menu.item(withTitle: "addToFilter")?.target is AddToFilterAction)
        XCTAssertEqual(representedItems(menu.item(withTitle: "recheck")).first?.host, "web-01")
    }

    func testStatusPanelContextMenuDisablesSingleSelectionActionsForMultipleRows() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING")
        ])
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertFalse(menu.item(withTitle: "openInBrowser")?.isEnabled ?? true)
        XCTAssertTrue(menu.item(withTitle: "recheck")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "scheduleDowntime")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "acknowledge")?.isEnabled ?? false)
        XCTAssertEqual(representedItems(menu.item(withTitle: "acknowledge")).count, 2)
    }

    func testStatusPanelContextMenuSuppressesBackendCommandsForMixedInstances() throws {
        let firstInstance = monitoringInstance(name: "primary")
        let secondInstance = monitoringInstance(name: "secondary")
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL", monitoringInstance: firstInstance),
            service("db-01", service: "Disk", status: "WARNING", monitoringInstance: secondInstance)
        ])
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertNil(menu.item(withTitle: "login"))
        XCTAssertNil(menu.item(withTitle: "openInBrowser"))
        XCTAssertNil(menu.item(withTitle: "recheck"))
        XCTAssertNil(menu.item(withTitle: "scheduleDowntime"))
        XCTAssertNil(menu.item(withTitle: "acknowledge"))
        XCTAssertTrue(menu.items.first?.isSeparatorItem ?? false)
        XCTAssertTrue(menu.item(withTitle: "addToFilter")?.target is AddToFilterAction)
        XCTAssertEqual(representedItems(menu.item(withTitle: "addToFilter")).count, 2)
    }

    func testStatusPanelContextMenuUsesSavedLoginActionAndRemoveLoginSettingsItem() throws {
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        ServerLogin().setLoginType(row, loginType: .rdp)
        let table = initializedStatusPanelTable(rows: [row])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))
        let login = try XCTUnwrap(menu.item(withTitle: "login"))
        let remove = try XCTUnwrap(menu.item(withTitle: "removeLoginSettings"))

        XCTAssertNil(login.submenu)
        XCTAssertEqual(login.action, #selector(ServerLogin.rdpLogin(_:)))
        XCTAssertTrue(login.target is ServerLogin)
        XCTAssertEqual((login.representedObject as? MonitoringItem)?.host, "web-01")
        XCTAssertEqual(remove.action, #selector(ServerLogin.removeLoginSettings(_:)))
        XCTAssertTrue(remove.target is ServerLogin)
        XCTAssertEqual((remove.representedObject as? MonitoringItem)?.host, "web-01")
        XCTAssertEqual(menu.items.map(\.title), [
            "login",
            "removeLoginSettings",
            "",
            "openInBrowser",
            "recheck",
            "scheduleDowntime",
            "acknowledge",
            "",
            "addToFilter"
        ])
    }

    func testStatusPanelContextMenuOnlyShowsOpenInBrowserForUnsupportedCommandBackend() throws {
        let checkMK = monitoringInstance(name: "checkmk", type: .Check_MK)
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL", monitoringInstance: checkMK)
        ])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertNotNil(menu.item(withTitle: "login"))
        XCTAssertNotNil(menu.item(withTitle: "openInBrowser"))
        XCTAssertNil(menu.item(withTitle: "recheck"))
        XCTAssertNil(menu.item(withTitle: "scheduleDowntime"))
        XCTAssertNil(menu.item(withTitle: "acknowledge"))
        XCTAssertNotNil(menu.item(withTitle: "addToFilter"))
    }

    func testStatusPanelContextMenuRightClickWithoutPriorSelectionUsesClickedRow() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("db-01", service: "Disk", status: "WARNING")
        ])

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent(location: NSPoint(x: 5, y: table.bounds.height - 5))))

        XCTAssertEqual(representedItems(menu.item(withTitle: "recheck")).first?.host, "web-01")
        XCTAssertNotNil(menu.item(withTitle: "login"))
        XCTAssertNotNil(menu.item(withTitle: "openInBrowser"))
        XCTAssertNotNil(menu.item(withTitle: "recheck"))
    }

    func testStatusPanelContextMenuReturnsNilWhenRightClickIsOutsideRows() {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])

        let menu = table.menu(for: rightClickEvent(location: NSPoint(x: 5, y: 150)))

        XCTAssertNil(menu)
    }

    func testStatusPanelLoginSubmenuContainsSSHAndRDPWithoutSavedLogin() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))
        let loginSubmenu = try XCTUnwrap(menu.item(withTitle: "login")?.submenu)
        let ssh = try XCTUnwrap(loginSubmenu.item(withTitle: "SSH"))
        let rdp = try XCTUnwrap(loginSubmenu.item(withTitle: "RDP"))

        XCTAssertEqual(ssh.action, #selector(ServerLogin.sshLogin(_:)))
        XCTAssertTrue(ssh.target is ServerLogin)
        XCTAssertEqual((ssh.representedObject as? MonitoringItem)?.host, "web-01")
        XCTAssertEqual(rdp.action, #selector(ServerLogin.rdpLogin(_:)))
        XCTAssertTrue(rdp.target is ServerLogin)
        XCTAssertEqual((rdp.representedObject as? MonitoringItem)?.host, "web-01")
        if let iTerm = loginSubmenu.item(withTitle: "SSH (iTerm)") {
            XCTAssertEqual(iTerm.action, #selector(ServerLogin.sshITermLogin(_:)))
            XCTAssertTrue(iTerm.target is ServerLogin)
            XCTAssertEqual((iTerm.representedObject as? MonitoringItem)?.host, "web-01")
        }
    }

    private func host(_ name: String, status: String) -> HostMonitoringItem {
        let item = HostMonitoringItem()
        item.host = name
        item.status = status
        item.monitoringInstance = monitoringInstance(name: "default")
        return item
    }

    private func service(_ host: String, service: String, status: String, monitoringInstance: MonitoringInstance? = nil) -> ServiceMonitoringItem {
        let item = ServiceMonitoringItem()
        item.host = host
        item.service = service
        item.status = status
        item.duration = "1m"
        item.lastCheck = "30-06-2026 12:00:00"
        item.attempt = "1/3"
        item.statusInformation = "\(status) output"
        item.monitoringInstance = monitoringInstance ?? self.monitoringInstance(name: "default")
        return item
    }

    private func monitoringInstance(name: String) -> MonitoringInstance {
        return monitoringInstance(name: name, type: .Icinga)
    }

    private func monitoringInstance(name: String, type: MonitoringInstanceType) -> MonitoringInstance {
        return MonitoringInstance().initDefault(
            name: name,
            url: "https://monitoring.example/\(name)/",
            type: type,
            username: "user",
            password: "password",
            enabled: 1
        )
    }

    private func initializedStatusPanelTable(rows: [MonitoringItem]) -> StatusPanelTable {
        let table = StatusPanelTable(frame: NSRect(x: 0, y: 0, width: 600, height: 200))
        table.initTable(rows)
        return table
    }

    private func rightClickEvent() -> NSEvent {
        return rightClickEvent(location: NSPoint(x: 5, y: 5))
    }

    private func rightClickEvent(location: NSPoint) -> NSEvent {
        return NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func representedItems(_ menuItem: NSMenuItem?) -> [MonitoringItem] {
        return menuItem?.representedObject as? [MonitoringItem] ?? []
    }

    private func textValue(in view: NSView) -> String {
        if let textField = view as? NSTextField {
            return textField.stringValue
        }

        for subview in view.subviews {
            let value = textValue(in: subview)
            if !value.isEmpty {
                return value
            }
        }

        return ""
    }

    private func disableOptionalStatusPanelColumns() {
        let settings = Settings()
        [
            "monitoringInstance",
            "status",
            "duration",
            "lastCheck",
            "attempt",
            "statusInformation"
        ].forEach { settings.setBool(false, forKey: $0) }
    }

    private func closeStatusPanelWindows() {
        for window in NSApplication.shared.windows where window.accessibilityIdentifier() == StatusItemAccessibility.statusPanelIdentifier {
            window.close()
        }
    }
}

private final class StatusItemMenuTarget: NSObject {
    @objc func showStatus() {
    }

    @objc func showAbout() {
    }

    @objc func openPreferences() {
    }

    @objc func refresh() {
    }
}
