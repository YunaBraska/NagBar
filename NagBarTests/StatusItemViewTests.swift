//
//  StatusItemViewTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest
@testable import NagBar

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
        StatusItemView.performStatusItemClick = { statusItem, button, menu, view in
            statusItem.menu = menu
            button.performClick(view)
        }
        StatusItemView.popUpContextMenu = { menu, event, view in
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
        StatusItemView.popUpMenu = { menu, point, view in
            menu.popUp(positioning: nil, at: point, in: view)
        }
        StatusItemView.refreshStatusData = {
            LoadMonitoringData().refreshStatusData()
        }
        super.tearDown()
    }

    func testStatusItemMenuContainsSingleEntrypointActions() {
        let target = StatusItemMenuTarget()

        let menu = StatusItemMenuBuilder.build(
            target: target,
            actions: StatusItemMenuActions(
                status: #selector(StatusItemMenuTarget.showStatus(_:)),
                about: #selector(StatusItemMenuTarget.showAbout(_:)),
                preferences: #selector(StatusItemMenuTarget.openPreferences(_:)),
                refresh: #selector(StatusItemMenuTarget.refresh(_:))
            )
        )

        XCTAssertEqual(menu.items.map { $0.title }, ["Show Status", "", "About NagBar", "Preferences", "", "Refresh", "", "Quit"])
        XCTAssertEqual(menu.items[0].action, #selector(StatusItemMenuTarget.showStatus(_:)))
        XCTAssertTrue(menu.items[0].target === target)
        XCTAssertEqual(menu.items[0].accessibilityIdentifier(), StatusItemAccessibility.showStatusIdentifier)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].action, #selector(StatusItemMenuTarget.showAbout(_:)))
        XCTAssertTrue(menu.items[2].target === target)
        XCTAssertEqual(menu.items[2].accessibilityIdentifier(), StatusItemAccessibility.aboutIdentifier)
        XCTAssertEqual(menu.items[3].action, #selector(StatusItemMenuTarget.openPreferences(_:)))
        XCTAssertTrue(menu.items[3].target === target)
        XCTAssertEqual(menu.items[3].accessibilityIdentifier(), StatusItemAccessibility.preferencesIdentifier)
        XCTAssertTrue(menu.items[4].isSeparatorItem)
        XCTAssertEqual(menu.items[5].action, #selector(StatusItemMenuTarget.refresh(_:)))
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
                status: #selector(StatusItemMenuTarget.showStatus(_:)),
                about: #selector(StatusItemMenuTarget.showAbout(_:)),
                preferences: #selector(StatusItemMenuTarget.openPreferences(_:)),
                refresh: #selector(StatusItemMenuTarget.refresh(_:))
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

    func testStatusItemViewAppliesAccessibilityWhenAttachedToWindow() {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))

        view.viewDidMoveToWindow()

        XCTAssertEqual(view.accessibilityTitle(), "NagBar status menu")
        XCTAssertEqual(view.accessibilityHelp(), "Opens NagBar status, settings, refresh, and quit actions.")
        XCTAssertEqual(view.accessibilityIdentifier(), "nagbar.statusItem.button")
    }

    func testStatusItemViewBuildsStatusItemMenuWithApplicationDelegateTarget() throws {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let target = try XCTUnwrap(NSApplication.shared.delegate as AnyObject?)

        let menu = view.statusItemMenu()

        XCTAssertEqual(menu.items.map { $0.title }, ["Show Status", "", "About NagBar", "Preferences", "", "Refresh", "", "Quit"])
        XCTAssertTrue(menu.items[0].target === target)
        XCTAssertEqual(menu.items[0].action, #selector(AppDelegate.showStatusFromStatusItem))
        XCTAssertTrue(menu.items[2].target === target)
        XCTAssertEqual(menu.items[2].action, #selector(AppDelegate.showAboutFromStatusItem))
        XCTAssertTrue(menu.items[3].target === target)
        XCTAssertEqual(menu.items[3].action, #selector(AppDelegate.openPreferencesFromStatusItem))
        XCTAssertTrue(menu.items[5].target === target)
        XCTAssertEqual(menu.items[5].action, #selector(AppDelegate.refreshFromStatusItem))
        XCTAssertTrue(menu.items[7].target === NSApplication.shared)
    }

    func testStatusItemViewSetStatusItemTitleUpdatesButtonAndStatusItemLength() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        view.statusItem = statusItem
        view.title = "Old"

        view.setStatusItemTitle("Total Count: 12")

        XCTAssertEqual(view.title, "Total Count: 12")
        XCTAssertGreaterThan(statusItem.length, 0)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testStatusItemViewSetStatusItemTitleDoesNothingWhenTitleIsUnchanged() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 42)
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        view.statusItem = statusItem
        view.title = "Total Count: 1"
        view.needsDisplay = false

        view.setStatusItemTitle("Total Count: 1")

        XCTAssertEqual(statusItem.length, 42)
        XCTAssertFalse(view.needsDisplay)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testStatusItemViewTitleBoundingRectUsesCurrentTitle() {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        view.title = "Total Count: 123"

        let bounds = view.titleBoundingRect()

        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testStatusItemViewDrawsCurrentTitleIntoCachedDisplay() throws {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        view.title = "Total Count: 3"
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))

        view.cacheDisplay(in: view.bounds, to: representation)

        XCTAssertGreaterThanOrEqual(representation.pixelsWide, 160)
        XCTAssertGreaterThanOrEqual(representation.pixelsHigh, 24)
    }

    func testStatusItemViewMouseDownPopsContextMenuThroughInjectedPresenter() throws {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        let event = try XCTUnwrap(leftClickEvent(location: NSPoint(x: 4, y: 4)))
        var capturedTitles: [String] = []
        StatusItemView.popUpContextMenu = { menu, _, capturedView in
            capturedTitles = menu.items.map { $0.title }
            XCTAssertTrue(capturedView === view)
        }

        view.mouseDown(with: event)

        XCTAssertEqual(capturedTitles.first, "Show Status")
    }

    func testStatusItemViewRightMouseDownPopsContextMenuThroughInjectedPresenter() throws {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        let event = try XCTUnwrap(leftClickEvent(location: NSPoint(x: 4, y: 4)))
        var capturedTitles: [String] = []
        StatusItemView.popUpContextMenu = { menu, _, capturedView in
            capturedTitles = menu.items.map { $0.title }
            XCTAssertTrue(capturedView === view)
        }

        view.rightMouseDown(with: event)

        XCTAssertEqual(capturedTitles.first, "Show Status")
    }

    func testStatusItemViewAccessibilityPressPopsMenuThroughInjectedPresenter() {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        var capturedPoint: NSPoint?
        var capturedTitles: [String] = []
        StatusItemView.popUpMenu = { menu, point, capturedView in
            capturedTitles = menu.items.map { $0.title }
            capturedPoint = point
            XCTAssertTrue(capturedView === view)
        }

        XCTAssertTrue(view.accessibilityPerformPress())

        XCTAssertEqual(capturedTitles.first, "Show Status")
        XCTAssertEqual(capturedPoint, NSPoint(x: 0, y: view.bounds.minY))
    }

    func testStatusItemViewStatusItemPathAttachesMenuThroughInjectedClick() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        view.statusItem = statusItem
        var capturedTitles: [String] = []
        StatusItemView.performStatusItemClick = { capturedItem, _, menu, capturedView in
            capturedItem.menu = menu
            capturedTitles = menu.items.map { $0.title }
            XCTAssertTrue(capturedItem === statusItem)
            XCTAssertTrue(capturedView === view)
        }

        view.accessibilityPerformPress()

        XCTAssertEqual(capturedTitles.first, "Show Status")
        XCTAssertTrue(statusItem.menu?.item(withTitle: "Refresh")?.action == #selector(AppDelegate.refreshFromStatusItem))
    }

    func testStatusItemViewRefreshUsesInjectedRefreshEntrypoint() {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        var refreshCount = 0
        StatusItemView.refreshStatusData = {
            refreshCount += 1
        }

        view.refresh(self)

        XCTAssertEqual(refreshCount, 1)
    }

    func testStatusItemViewDirectShowStatusActionOpensLoadedStatusPanel() {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let statusBar = StatusBar.get()
        statusBar.load([], failedMonitoringInstances: [:])

        view.showStatus(self)

        closeStatusPanelWindows()
    }

    func testAppDelegateShowStatusEntrypointsUseStatusBar() throws {
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        StatusBar.get().load([], failedMonitoringInstances: [:])

        appDelegate.showStatus(NSButton())
        appDelegate.showStatusFromStatusItem()

        closeStatusPanelWindows()
    }

    func testStatusItemViewDirectAboutAndPreferencesActionsUseApplicationDelegate() throws {
        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        defer {
            appDelegate.preferencesWindow?.close()
            appDelegate.preferencesWindow = nil
        }

        view.openPreferences(self)
        let preferencesWindow = try XCTUnwrap(appDelegate.preferencesWindow)
        view.showAbout(self)
        let tabView = try XCTUnwrap(preferencesWindow.findTabView(in: preferencesWindow.window?.contentView))
        let selectedItem = try XCTUnwrap(tabView.selectedTabViewItem)

        XCTAssertTrue(preferencesWindow === appDelegate.preferencesWindow)
        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(selectedItem))
    }

    func testStatusBarShowStatusPanelWithLoadedResultsOpensWithoutRefreshing() {
        let statusBar = StatusBar.get()
        var refreshCount = 0
        let previousRefresh = statusBar.refreshStatusData
        statusBar.refreshStatusData = {
            refreshCount += 1
        }
        statusBar.load([], failedMonitoringInstances: [:])

        let opened = statusBar.showStatusPanel()

        XCTAssertTrue(opened)
        XCTAssertEqual(refreshCount, 0)
        closeStatusPanelWindows()
        statusBar.refreshStatusData = previousRefresh
    }

    func testStatusBarRefreshMenuActionUsesInjectedRefreshEntrypoint() {
        let statusBar = StatusBar.get()
        var refreshCount = 0
        let previousRefresh = statusBar.refreshStatusData
        statusBar.refreshStatusData = {
            refreshCount += 1
        }

        statusBar.refresh(self)

        XCTAssertEqual(refreshCount, 1)
        statusBar.refreshStatusData = previousRefresh
    }

    func testStatusBarDirectShowStatusActionUsesLoadedPanelPath() {
        let statusBar = StatusBar.get()
        statusBar.load([], failedMonitoringInstances: [:])

        statusBar.showStatus(self)

        closeStatusPanelWindows()
    }

    func testStatusBarDirectPreferencesAndAboutActionsUseApplicationDelegate() throws {
        let statusBar = StatusBar.get()
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        defer {
            appDelegate.preferencesWindow?.close()
            appDelegate.preferencesWindow = nil
        }

        statusBar.openPreferences(self)
        let preferencesWindow = try XCTUnwrap(appDelegate.preferencesWindow)
        statusBar.showAbout(self)
        let tabView = try XCTUnwrap(preferencesWindow.findTabView(in: preferencesWindow.window?.contentView))
        let selectedItem = try XCTUnwrap(tabView.selectedTabViewItem)

        XCTAssertTrue(preferencesWindow === appDelegate.preferencesWindow)
        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(selectedItem))
    }

    func testStatusBarStatusPanelObserverHandlesResignKeyNotification() {
        let statusBar = StatusBar.get()
        statusBar.load([], failedMonitoringInstances: [:])

        XCTAssertTrue(statusBar.showStatusPanel())
        guard let statusPanel = NSApplication.shared.windows.first(where: { window in
            window.accessibilityIdentifier() == StatusItemAccessibility.statusPanelIdentifier
        }) else {
            XCTFail("Expected status panel window")
            return
        }
        Foundation.NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: statusPanel)

        closeStatusPanelWindows()
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

    func testStatusPanelDismissalPolicyIgnoresOwnAppAndSystemEventsAutomation() {
        XCTAssertFalse(StatusPanelDismissalPolicy.shouldDismiss(
            frontmostBundleIdentifier: "com.volendavidov.NagBar",
            bundleIdentifier: "com.volendavidov.NagBar"
        ))
        XCTAssertFalse(StatusPanelDismissalPolicy.shouldDismiss(
            frontmostBundleIdentifier: "com.apple.systemevents",
            bundleIdentifier: "com.volendavidov.NagBar"
        ))
        XCTAssertTrue(StatusPanelDismissalPolicy.shouldDismiss(
            frontmostBundleIdentifier: "com.apple.Terminal",
            bundleIdentifier: "com.volendavidov.NagBar"
        ))
    }

    func testStatusPanelFallbackFrameUsesTopRightVisibleScreenEdge() {
        let frame = StatusPanelFallbackFrame.statusItemFrame(
            visibleFrame: NSRect(x: 20, y: 40, width: 1200, height: 800)
        )

        XCTAssertEqual(frame.origin.x, 1219)
        XCTAssertEqual(frame.origin.y, 840)
        XCTAssertEqual(frame.width, 1)
        XCTAssertEqual(frame.height, 1)
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

    func testStatusBarLoadBuildsFailedMonitoringInstancesWarningMenu() throws {
        let statusBar = StatusBar.get()
        defer { statusBar.load([], failedMonitoringInstances: [:]) }
        let wrongCredentials = monitoringInstance(name: "wrong-credentials")
        let ssl = monitoringInstance(name: "bad-certificate")
        let unknown = monitoringInstance(name: "offline")

        statusBar.load([], failedMonitoringInstances: [
            wrongCredentials: .wrongCredentials,
            ssl: .ssl,
            unknown: .unknown
        ])

        let failedStatusItem = try XCTUnwrap(failedStatusItem(from: statusBar))
        let titles = failedStatusItem.menu?.items.map(\.title) ?? []
        XCTAssertTrue(titles.contains("Connection to monitoring instance \"wrong-credentials\" failed - incorrect credentials"))
        XCTAssertTrue(titles.contains("Connection to monitoring instance \"bad-certificate\" failed because of invalid certificate"))
        XCTAssertTrue(titles.contains("Connection to monitoring instance \"offline\" failed"))
        XCTAssertEqual(failedStatusItem.button?.accessibilityIdentifier(), StatusItemAccessibility.failedStatusItemButtonIdentifier)
    }

    func testStatusBarLoadClearsFailedMonitoringInstancesWarningMenuWhenFailuresRecover() {
        let statusBar = StatusBar.get()
        statusBar.load([], failedMonitoringInstances: [
            monitoringInstance(name: "offline"): .unknown
        ])

        statusBar.load([], failedMonitoringInstances: [:])

        XCTAssertNil(failedStatusItem(from: statusBar))
    }

    func testStatusBarAnimationTriggerIgnoresMissingOldResults() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: nil, newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])

        XCTAssertEqual(trigger, .none)
    }

    func testStatusBarAnimationTriggerIgnoresMissingNewResults() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: nil)

        XCTAssertEqual(trigger, .none)
    }

    func testStatusBarAnimationTriggerAlarmsWhenProblemCountIncreases() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            host("db-01", status: "DOWN")
        ])

        XCTAssertEqual(trigger, .alarm)
    }

    func testStatusBarAnimationTriggerRecoversWhenProblemCountDecreases() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            host("db-01", status: "DOWN")
        ], newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])

        XCTAssertEqual(trigger, .recovery)
    }

    func testStatusBarAnimationTriggerAlarmsWhenProblemIdentityChanges() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: [
            service("web-01", service: "Disk", status: "CRITICAL")
        ])

        XCTAssertEqual(trigger, .alarm)
    }

    func testStatusBarAnimationTriggerDoesNotAnimateUnchangedProblems() {
        let trigger = StatusBarAnimationTrigger.evaluate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])

        XCTAssertEqual(trigger, .none)
    }

    func testLightFlashStatusBarAddsAlarmAndRecoveryAnimationOverlays() throws {
        let button = try XCTUnwrap(StatusBar.get().statusItem.button)
        let originalSubviews = button.subviews
        defer {
            for subview in button.subviews where !originalSubviews.contains(subview) {
                subview.removeFromSuperview()
            }
        }
        let animator = LightFlashStatusBar()

        animator.animate(oldResults: [], newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        animator.animate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: [])

        XCTAssertGreaterThanOrEqual(button.subviews.count, originalSubviews.count + 2)
    }

    func testDarkFlashStatusBarAddsAlarmAndRecoveryAnimationOverlays() throws {
        let button = try XCTUnwrap(StatusBar.get().statusItem.button)
        let originalSubviews = button.subviews
        defer {
            for subview in button.subviews where !originalSubviews.contains(subview) {
                subview.removeFromSuperview()
            }
        }
        let animator = DarkFlashStatusBar()

        animator.animate(oldResults: [], newResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        animator.animate(oldResults: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ], newResults: [])

        XCTAssertGreaterThanOrEqual(button.subviews.count, originalSubviews.count + 2)
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

    func testStatusPanelOptionalColumnsRenderConfiguredValues() {
        let instance = monitoringInstance(name: "primary")
        let row = service("web-01", service: "HTTP", status: "CRITICAL", monitoringInstance: instance)
        row.duration = "12m"
        row.lastCheck = "30-06-2026 19:00:00"
        row.attempt = "2/3"
        row.statusInformation = "HTTP CRITICAL - connection refused"
        let rows = [row]

        XCTAssertEqual(textValue(in: SPMonitoringInstanceTableColumn(results: rows).createViewForRow(0)), "primary")
        XCTAssertEqual(textValue(in: SPDurationTableColumn(results: rows).createViewForRow(0)), "12m")
        XCTAssertEqual(textValue(in: SPLastCheckTableColumn(results: rows).createViewForRow(0)), "30-06-2026 19:00:00")
        XCTAssertEqual(textValue(in: SPAttemptTableColumn(results: rows).createViewForRow(0)), "2/3")
        XCTAssertEqual(textValue(in: SPStatusInformationTableColumn(results: rows).createViewForRow(0)), "HTTP CRITICAL - connection refused")
    }

    func testStatusPanelStatusInformationColumnCapsLongOutputWidth() {
        Settings().setString("200", forKey: "statusInformationLength")
        let short = service("web-01", service: "HTTP", status: "WARNING")
        short.statusInformation = "short"
        let long = service("web-01", service: "Disk", status: "CRITICAL")
        long.statusInformation = String(repeating: "long-output-", count: 20)

        let column = SPStatusInformationTableColumn(results: [short, long])

        XCTAssertLessThan(column.columnWidth(short, font: statusPanelFont()), CGFloat(200))
        XCTAssertEqual(column.columnWidth(long, font: statusPanelFont()), CGFloat(200))
    }

    func testStatusPanelUnknownStatusUsesWhiteCellBackground() throws {
        let row = service("web-01", service: "HTTP", status: "CUSTOM")
        let view = try XCTUnwrap(SPStatusTableColumn(results: [row]).createViewForRow(0) as? TableViewCellBackground)

        XCTAssertEqual(view.color, NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    }

    func testStatusPanelKnownStatusUsesConfiguredCellBackgroundColor() throws {
        Settings().setString("0.8,0.1,0.1,1.0", forKey: "criticalColor")
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        let view = try XCTUnwrap(SPStatusTableColumn(results: [row]).createViewForRow(0) as? TableViewCellBackground)

        XCTAssertEqual(view.color, NSColor(calibratedRed: 0.8, green: 0.1, blue: 0.1, alpha: 1.0))
        XCTAssertEqual(textValue(in: view), "CRITICAL")
    }

    func testStatusPanelBaseColumnRendersEmptyValueWithConfiguredBackground() throws {
        Settings().setString("0.2,0.3,0.4,1.0", forKey: "warningColor")
        let row = service("web-01", service: "HTTP", status: "WARNING")
        let column = SPTableColumn(results: [row])

        let view = try XCTUnwrap(column.createViewForRow(0) as? TableViewCellBackground)

        XCTAssertEqual(column.columnWidth(row, font: statusPanelFont()), 0)
        XCTAssertEqual(column.setValue(0), "")
        XCTAssertEqual(view.color, NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.4, alpha: 1.0))
        XCTAssertEqual(textValue(in: view), "")
    }

    func testStatusPanelTableDelegateCreatesCellAndCustomRowView() throws {
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        let column = SPHostTableColumn(results: [row])
        table.addTableColumn(column)
        let delegate = StatusPanelTableDelegate(results: [row])

        let cell = try XCTUnwrap(delegate.tableView(table, viewFor: column, row: 0))
        let rowView = try XCTUnwrap(delegate.tableView(table, rowViewForRow: 0))

        XCTAssertEqual(textValue(in: cell), "web-01")
        XCTAssertTrue(rowView is StatusTableRowView)
        XCTAssertEqual(table.intercellSpacing, NSMakeSize(0, 2))
    }

    func testStatusPanelCellBackgroundDrawsGradient() throws {
        let view = TableViewCellBackground(
            frame: NSRect(x: 0, y: 0, width: 80, height: 24),
            color: NSColor(calibratedRed: 0.5, green: 0.6, blue: 0.7, alpha: 1.0)
        )
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))

        view.cacheDisplay(in: view.bounds, to: representation)

        XCTAssertGreaterThanOrEqual(representation.pixelsWide, 80)
        XCTAssertGreaterThanOrEqual(representation.pixelsHigh, 24)
    }

    func testStatusPanelRowViewDrawsCustomSelection() {
        let image = NSImage(size: NSSize(width: 80, height: 24))
        let rowView = StatusTableRowView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))

        image.lockFocus()
        rowView.drawSelection(in: rowView.bounds)
        image.unlockFocus()

        XCTAssertEqual(image.size, NSSize(width: 80, height: 24))
    }

    func testStatusPanelDrawArrowRendersScrollIndicator() throws {
        let view = DrawArrow(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))

        view.cacheDisplay(in: view.bounds, to: representation)

        XCTAssertGreaterThanOrEqual(representation.pixelsWide, 180)
        XCTAssertGreaterThanOrEqual(representation.pixelsHigh, 20)
    }

    func testStatusPanelContextMenuBuildsIcingaCommandMenuForSingleSelection() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertEqual(menu.items.map(\.title), [
            "Login",
            "",
            "Open in browser",
            "Recheck",
            "Schedule Downtime",
            "Acknowledge",
            "",
            "Add to filter"
        ])
        XCTAssertNotNil(menu.item(withTitle: "Login")?.submenu)
        XCTAssertTrue(menu.item(withTitle: "Open in browser")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "Recheck")?.target is RecheckAction)
        XCTAssertTrue(menu.item(withTitle: "Schedule Downtime")?.target is ScheduleDowntimeAction)
        XCTAssertTrue(menu.item(withTitle: "Acknowledge")?.target is AcknowledgeAction)
        XCTAssertTrue(menu.item(withTitle: "Add to filter")?.target is AddToFilterAction)
        XCTAssertEqual(representedItems(menu.item(withTitle: "Recheck")).first?.host, "web-01")
    }

    func testStatusPanelContextMenuDisablesSingleSelectionActionsForMultipleRows() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("web-01", service: "Disk", status: "WARNING")
        ])
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertFalse(menu.item(withTitle: "Open in browser")?.isEnabled ?? true)
        XCTAssertTrue(menu.item(withTitle: "Recheck")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "Schedule Downtime")?.isEnabled ?? false)
        XCTAssertTrue(menu.item(withTitle: "Acknowledge")?.isEnabled ?? false)
        XCTAssertEqual(representedItems(menu.item(withTitle: "Acknowledge")).count, 2)
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

        XCTAssertNil(menu.item(withTitle: "Login"))
        XCTAssertNil(menu.item(withTitle: "Open in browser"))
        XCTAssertNil(menu.item(withTitle: "Recheck"))
        XCTAssertNil(menu.item(withTitle: "Schedule Downtime"))
        XCTAssertNil(menu.item(withTitle: "Acknowledge"))
        XCTAssertTrue(menu.items.first?.isSeparatorItem ?? false)
        XCTAssertTrue(menu.item(withTitle: "Add to filter")?.target is AddToFilterAction)
        XCTAssertEqual(representedItems(menu.item(withTitle: "Add to filter")).count, 2)
    }

    func testStatusPanelContextMenuUsesSavedLoginActionAndRemoveLoginSettingsItem() throws {
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        ServerLogin().setLoginType(row, loginType: .rdp)
        let table = initializedStatusPanelTable(rows: [row])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))
        let login = try XCTUnwrap(menu.item(withTitle: "Login"))
        let remove = try XCTUnwrap(menu.item(withTitle: "Remove login settings"))

        XCTAssertNil(login.submenu)
        XCTAssertEqual(login.action, #selector(ServerLogin.rdpLogin(_:)))
        XCTAssertTrue(login.target is ServerLogin)
        XCTAssertEqual((login.representedObject as? MonitoringItem)?.host, "web-01")
        XCTAssertEqual(remove.action, #selector(ServerLogin.removeLoginSettings(_:)))
        XCTAssertTrue(remove.target is ServerLogin)
        XCTAssertEqual((remove.representedObject as? MonitoringItem)?.host, "web-01")
        XCTAssertEqual(menu.items.map(\.title), [
            "Login",
            "Remove login settings",
            "",
            "Open in browser",
            "Recheck",
            "Schedule Downtime",
            "Acknowledge",
            "",
            "Add to filter"
        ])
    }

    func testStatusPanelContextMenuUsesSavedSSHLoginAction() throws {
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        ServerLogin().setLoginType(row, loginType: .ssh)
        let table = initializedStatusPanelTable(rows: [row])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))
        let login = try XCTUnwrap(menu.item(withTitle: "Login"))

        XCTAssertNil(login.submenu)
        XCTAssertEqual(login.action, #selector(ServerLogin.sshLogin(_:)))
        XCTAssertTrue(login.target is ServerLogin)
        XCTAssertEqual((login.representedObject as? MonitoringItem)?.host, "web-01")
    }

    func testStatusPanelContextMenuUsesSavedSSHiTermLoginAction() throws {
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        ServerLogin().setLoginType(row, loginType: .sshiTerm)
        let table = initializedStatusPanelTable(rows: [row])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))
        let login = try XCTUnwrap(menu.item(withTitle: "Login"))

        XCTAssertNil(login.submenu)
        XCTAssertEqual(login.action, #selector(ServerLogin.sshITermLogin(_:)))
        XCTAssertTrue(login.target is ServerLogin)
        XCTAssertEqual((login.representedObject as? MonitoringItem)?.host, "web-01")
    }

    func testStatusPanelTableMouseDownRemovesCustomRightClickHighlight() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL")
        ])
        table.reloadData()
        _ = table.view(atColumn: 0, row: 0, makeIfNecessary: true)
        _ = try XCTUnwrap(table.menu(for: rightClickEvent(location: NSPoint(x: 5, y: table.bounds.height - 5))))
        XCTAssertGreaterThan(selectedBackgroundCount(in: table), 0)

        table.mouseDown(with: leftClickEvent(location: NSPoint(x: 5, y: table.bounds.height - 5)))

        XCTAssertEqual(selectedBackgroundCount(in: table), 0)
    }

    func testUnscrollableStatusPanelScrollViewIgnoresScrollWheel() {
        let scrollView = UnscrollableScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        scrollView.scrollWheel(with: scrollWheelEvent())

        XCTAssertEqual(scrollView.bounds.origin, .zero)
    }

    func testSelectedTableViewCellBackgroundDrawsSelectionOverlay() throws {
        let view = SelectedTableViewCellBackground(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))

        view.cacheDisplay(in: view.bounds, to: representation)

        XCTAssertGreaterThanOrEqual(representation.pixelsWide, 40)
        XCTAssertGreaterThanOrEqual(representation.pixelsHigh, 20)
    }

    func testStatusPanelContextMenuOnlyShowsOpenInBrowserForUnsupportedCommandBackend() throws {
        let checkMK = monitoringInstance(name: "checkmk", type: .Check_MK)
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL", monitoringInstance: checkMK)
        ])
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent()))

        XCTAssertNotNil(menu.item(withTitle: "Login"))
        XCTAssertNotNil(menu.item(withTitle: "Open in browser"))
        XCTAssertNil(menu.item(withTitle: "Recheck"))
        XCTAssertNil(menu.item(withTitle: "Schedule Downtime"))
        XCTAssertNil(menu.item(withTitle: "Acknowledge"))
        XCTAssertNotNil(menu.item(withTitle: "Add to filter"))
    }

    func testOpenInBrowserActionOpensValidMonitoringItemURL() {
        var openedURLs: [URL] = []
        let originalOpenURL = OpenInBrowserAction.openURL
        OpenInBrowserAction.openURL = { openedURLs.append($0) }
        defer { OpenInBrowserAction.openURL = originalOpenURL }
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        row.itemUrl = "https://monitoring.example/cgi-bin/extinfo.cgi?host=web-01"
        let menuItem = NSMenuItem()
        menuItem.representedObject = [row]

        OpenInBrowserAction().action(menuItem)

        XCTAssertEqual(openedURLs.map(\.absoluteString), ["https://monitoring.example/cgi-bin/extinfo.cgi?host=web-01"])
    }

    func testOpenInBrowserActionPercentEncodesRecoverableURL() {
        var openedURLs: [URL] = []
        let originalOpenURL = OpenInBrowserAction.openURL
        OpenInBrowserAction.openURL = { openedURLs.append($0) }
        defer { OpenInBrowserAction.openURL = originalOpenURL }
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        row.itemUrl = "https://monitoring.example/cgi-bin/extinfo.cgi?query=[web 01]"
        let menuItem = NSMenuItem()
        menuItem.representedObject = [row]

        OpenInBrowserAction().action(menuItem)

        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertTrue(openedURLs[0].absoluteString.contains("%5Bweb%2001%5D"))
    }

    func testOpenInBrowserActionEscapesBracketURLBeforeOpeningBrowser() {
        var openedURLs: [URL] = []
        let originalOpenURL = OpenInBrowserAction.openURL
        OpenInBrowserAction.openURL = { openedURLs.append($0) }
        defer { OpenInBrowserAction.openURL = originalOpenURL }
        let row = service("web-01", service: "HTTP", status: "CRITICAL")
        row.itemUrl = "http://["
        let menuItem = NSMenuItem()
        menuItem.representedObject = [row]

        OpenInBrowserAction().action(menuItem)

        XCTAssertEqual(openedURLs.map(\.absoluteString), ["http://%5B"])
    }

    func testStatusPanelContextMenuRightClickWithoutPriorSelectionUsesClickedRow() throws {
        let table = initializedStatusPanelTable(rows: [
            service("web-01", service: "HTTP", status: "CRITICAL"),
            service("db-01", service: "Disk", status: "WARNING")
        ])

        let menu = try XCTUnwrap(table.menu(for: rightClickEvent(location: NSPoint(x: 5, y: table.bounds.height - 5))))

        XCTAssertEqual(representedItems(menu.item(withTitle: "Recheck")).first?.host, "web-01")
        XCTAssertNotNil(menu.item(withTitle: "Login"))
        XCTAssertNotNil(menu.item(withTitle: "Open in browser"))
        XCTAssertNotNil(menu.item(withTitle: "Recheck"))
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
        let loginSubmenu = try XCTUnwrap(menu.item(withTitle: "Login")?.submenu)
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

    private func leftClickEvent(location: NSPoint) -> NSEvent {
        return NSEvent.mouseEvent(
            with: .leftMouseDown,
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

    private func scrollWheelEvent() -> NSEvent {
        return leftClickEvent(location: NSPoint(x: 0, y: 0))
    }

    private func representedItems(_ menuItem: NSMenuItem?) -> [MonitoringItem] {
        return menuItem?.representedObject as? [MonitoringItem] ?? []
    }

    private func selectedBackgroundCount(in table: NSTableView) -> Int {
        var count = 0
        for row in 0..<table.numberOfRows {
            for column in 0..<table.numberOfColumns {
                guard let cell = table.view(atColumn: column, row: row, makeIfNecessary: false) else {
                    continue
                }
                count += cell.subviews.filter { $0 is SelectedTableViewCellBackground }.count
            }
        }
        return count
    }

    private func failedStatusItem(from statusBar: StatusBar) -> NSStatusItem? {
        let child = Mirror(reflecting: statusBar).children.first { $0.label == "statusItemFailed" }
        guard let value = child?.value else {
            return nil
        }

        let optional = Mirror(reflecting: value)
        if optional.displayStyle == .optional {
            return optional.children.first?.value as? NSStatusItem
        }

        return value as? NSStatusItem
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

    private func statusPanelFont() -> Dictionary<NSAttributedString.Key, NSFont> {
        return [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 16.0)]
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
    @objc func showStatus(_ sender: AnyObject) {
    }

    @objc func showAbout(_ sender: AnyObject) {
    }

    @objc func openPreferences(_ sender: AnyObject) {
    }

    @objc func refresh(_ sender: AnyObject) {
    }
}
