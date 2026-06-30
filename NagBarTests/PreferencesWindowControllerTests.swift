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
    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
    }

    override func tearDown() {
        Settings().resetKnownSettings()
        super.tearDown()
    }

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

    func testPreferencesDefaultButtonInitializesFromSettingsAndPersistsToggle() throws {
        Settings().setBool(true, forKey: "showDockIcon")
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        _ = controller.window
        let button: DefaultButton = try view(withIdentifier: "showDockIcon", in: controller)

        XCTAssertEqual(button.state, .on)

        button.state = .off
        button.performAction()
        XCTAssertFalse(Settings().boolForKey("showDockIcon"))

        button.state = .on
        button.performAction()
        XCTAssertTrue(Settings().boolForKey("showDockIcon"))
    }

    func testPreferencesDefaultPopUpInitializesFromSettingsAndPersistsSelection() throws {
        Settings().setInteger(3, forKey: "flashStatusBarType")
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        _ = controller.window
        let popup: DefaultPopUpButton = try view(withIdentifier: "flashStatusBarType", in: controller)

        XCTAssertEqual(popup.titleOfSelectedItem, "Bright Flash")

        popup.selectItem(withTitle: "Shake")
        popup.performAction()
        XCTAssertEqual(Settings().integerForKey("flashStatusBarType"), 1)
    }

    func testPreferencesDefaultColorWellPersistsSelectedColor() {
        let colorWell = DefaultColorWell(frame: NSRect(x: 0, y: 0, width: 44, height: 23))
        colorWell.identifier = NSUserInterfaceItemIdentifier("criticalColor")
        colorWell.color = NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)

        colorWell.deactivate()

        XCTAssertEqual(Settings().stringForKey("criticalColor"), "0.400,0.500,0.600,1.0")
    }

    func testMonitoringInstancesTabInitializesRefreshIntervalControlsFromSettings() {
        Settings().setString("120", forKey: "refreshInterval")
        let controller = MonitoringInstancesTabController()
        let refreshInterval = NSTextField()
        let stepper = NSStepper()
        stepper.minValue = controller.refreshIntervalMinValue
        stepper.maxValue = controller.refreshIntervalMaxValue
        controller.refreshInterval = refreshInterval
        controller.stepper = stepper

        controller.awakeFromNib()

        XCTAssertEqual(refreshInterval.stringValue, "120")
        XCTAssertEqual(stepper.integerValue, 120)
    }

    func testMonitoringInstancesTabStepperPersistsRefreshIntervalWithinBounds() {
        let controller = MonitoringInstancesTabController()
        let refreshInterval = NSTextField()
        let stepper = NSStepper()
        stepper.minValue = controller.refreshIntervalMinValue
        stepper.maxValue = controller.refreshIntervalMaxValue
        stepper.integerValue = 300
        controller.refreshInterval = refreshInterval
        controller.stepper = stepper

        controller.stepperAction(stepper)

        XCTAssertEqual(stepper.minValue, 15)
        XCTAssertEqual(stepper.maxValue, 900)
        XCTAssertEqual(refreshInterval.integerValue, 300)
        XCTAssertEqual(Settings().stringForKey("refreshInterval"), "300")
    }

    func testCommandsTabInitializesDefaultCommentsFromSettings() {
        Settings().setString("ack default", forKey: "acknowledgementDefaultComment")
        Settings().setString("downtime default", forKey: "scheduleDowntimeDefaultComment")
        let controller = CommandsTabController()
        let acknowledgement = NSTextField()
        let downtime = NSTextField()
        controller.acknowledgementDefaultComment = acknowledgement
        controller.scheduleDowntimeDefaultComment = downtime

        controller.awakeFromNib()

        XCTAssertEqual(acknowledgement.stringValue, "ack default")
        XCTAssertEqual(downtime.stringValue, "downtime default")
    }

    func testCommandsTabPersistsEditedCommentByIdentifier() {
        let controller = CommandsTabController()
        let field = NSTextField()
        field.identifier = NSUserInterfaceItemIdentifier("acknowledgementDefaultComment")
        field.stringValue = "operator changed comment"

        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertEqual(Settings().stringForKey("acknowledgementDefaultComment"), "operator changed comment")
    }

    func testAudibleAlarmsTabSelectsDefaultSoundWhenNoCustomFileIsConfigured() {
        Settings().setString("", forKey: "audibleAlarmsCriticalSoundFile")
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["Default", "Custom"])
        controller.audibleAlarmsCriticalSoundFile = popup

        controller.setPopupState("audibleAlarmsCriticalSoundFile")

        XCTAssertEqual(popup.indexOfSelectedItem, 0)
        XCTAssertEqual(popup.titleOfSelectedItem, "Default")
    }

    func testAudibleAlarmsTabShowsStoredCustomSoundFile() {
        Settings().setString("/Library/Sounds/Basso.aiff", forKey: "audibleAlarmsCriticalSoundFile")
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["Default", "Custom"])
        controller.audibleAlarmsCriticalSoundFile = popup

        controller.setPopupState("audibleAlarmsCriticalSoundFile")

        XCTAssertEqual(popup.indexOfSelectedItem, 1)
        XCTAssertEqual(popup.titleOfSelectedItem, "Basso.aiff")
    }

    func testAudibleAlarmsPopupDefaultSelectionClearsCustomSoundFile() {
        Settings().setString("/Library/Sounds/Basso.aiff", forKey: "audibleAlarmsCriticalSoundFile")
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.identifier = NSUserInterfaceItemIdentifier("audibleAlarmsCriticalSoundFile")
        popup.addItems(withTitles: ["Default", "Basso.aiff"])
        popup.selectItem(withTitle: "Default")

        controller.popupButtonFileSelector(popup)

        XCTAssertEqual(popup.itemTitles, ["Default", "Custom"])
        XCTAssertEqual(Settings().stringForKey("audibleAlarmsCriticalSoundFile"), "")
    }

    private func textFieldStrings(in view: NSView) -> [String] {
        view.subviews.flatMap { subview -> [String] in
            let ownText = (subview as? NSTextField).map { [$0.stringValue] } ?? []
            return ownText + textFieldStrings(in: subview)
        }
    }

    private func view<T: NSView>(withIdentifier identifier: String, in controller: PreferencesWindowController) throws -> T {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return try XCTUnwrap(firstView(withIdentifier: identifier, in: contentView) as? T)
    }

    private func firstView(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }

        for subview in view.subviews {
            if let found = firstView(withIdentifier: identifier, in: subview) {
                return found
            }
        }

        return nil
    }
}
