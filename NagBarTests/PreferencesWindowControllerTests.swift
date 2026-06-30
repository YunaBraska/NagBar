//
//  PreferencesWindowControllerTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest

final class PreferencesWindowControllerTests: XCTestCase {
    func testSelectAboutTabLoadsPreferencesWindowAndSelectsAboutContent() throws {
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        _ = controller.window

        controller.selectAboutTab()

        let tabView = try XCTUnwrap(controller.findTabView(in: controller.window?.contentView))
        let selectedItem = try XCTUnwrap(tabView.selectedTabViewItem)
        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(selectedItem))
        XCTAssertEqual(selectedItem.label, "About")

        let view = try XCTUnwrap(selectedItem.view)
        let labels = textFieldStrings(in: view)
        XCTAssertTrue(labels.contains("NagBar"))
        XCTAssertTrue(labels.contains("License"))
        XCTAssertTrue(labels.contains("Apache License 2.0"))
        XCTAssertTrue(labels.contains("Support"))
        XCTAssertTrue(labels.contains(AboutSettingsContent.supportURL))
    }

    func testOpenDataFeedUsesFactoryAndKeepsMonitoringInstancesWindow() throws {
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        _ = controller.window
        let monitoringWindow = MonitoringInstancesWindowController(windowNibName: "MonitoringInstancesWindow")
        var factoryCallCount = 0
        controller.monitoringInstancesWindowFactory = {
            factoryCallCount += 1
            return monitoringWindow
        }

        controller.openDataFeed(NSButton())

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertTrue(controller.monitoringInstancesWindow === monitoringWindow)
        XCTAssertNotNil(monitoringWindow.window)
        XCTAssertEqual((monitoringWindow.window as NSWindow?)?.accessibilityIdentifier(), MonitoringInstancesAccessibility.windowIdentifier)
    }

    private func textFieldStrings(in view: NSView) -> [String] {
        view.subviews.flatMap { subview -> [String] in
            let ownText = (subview as? NSTextField).map { [$0.stringValue] } ?? []
            return ownText + textFieldStrings(in: subview)
        }
    }
}
