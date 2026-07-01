//
//  PreferencesWindowControllerTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest
import UniformTypeIdentifiers
@testable import NagBar

final class PreferencesWindowControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
    }

    override func tearDown() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.preferencesWindow?.close()
            appDelegate.preferencesWindow = nil
            appDelegate.passwordWindow?.close()
            appDelegate.passwordWindow = nil
        }
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

    func testAppDelegateOpenPreferencesUsesExistingPreferencesWindow() throws {
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        appDelegate.preferencesWindow = controller

        appDelegate.openPreferences(NSButton())

        XCTAssertTrue(appDelegate.preferencesWindow === controller)
        XCTAssertTrue(controller.window?.isVisible ?? false)
    }

    func testAppDelegateOpenPreferencesFromStatusItemUsesSameWindowEntrypoint() throws {
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        appDelegate.preferencesWindow = controller

        appDelegate.openPreferencesFromStatusItem()

        XCTAssertTrue(appDelegate.preferencesWindow === controller)
        XCTAssertTrue(controller.window?.isVisible ?? false)
    }

    func testAppDelegateOpenAboutSelectsAboutTabInExistingPreferencesWindow() throws {
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        appDelegate.preferencesWindow = controller

        appDelegate.openAbout(NSButton())

        let tabView = try XCTUnwrap(controller.findTabView(in: controller.window?.contentView))
        let selectedItem = try XCTUnwrap(tabView.selectedTabViewItem)
        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(selectedItem))
    }

    func testAppDelegateAboutStatusItemEntrypointsReuseAboutSelection() throws {
        let appDelegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        let controller = PreferencesWindowController(windowNibName: "PreferencesWindow")
        appDelegate.preferencesWindow = controller

        appDelegate.showAbout(NSButton())
        appDelegate.showAboutFromStatusItem()

        let tabView = try XCTUnwrap(controller.findTabView(in: controller.window?.contentView))
        let selectedItem = try XCTUnwrap(tabView.selectedTabViewItem)
        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(selectedItem))
    }

    func testAppDelegateRefreshEntrypointsUseRefreshStatusData() {
        let appDelegate = RecordingAppDelegate()

        appDelegate.refresh(NSButton())
        appDelegate.refreshFromStatusItem()

        XCTAssertEqual(appDelegate.refreshCount, 2)
    }

    func testAppDelegateShowPasswordPromptCreatesOneWindowAndRefreshesThroughDelegate() throws {
        let appDelegate = RecordingAppDelegate()

        appDelegate.showPasswordPrompt()
        let firstWindow = try XCTUnwrap(appDelegate.passwordWindow)
        appDelegate.showPasswordPrompt()

        XCTAssertTrue(appDelegate.passwordWindow === firstWindow)
        firstWindow.refreshStatusData()
        XCTAssertEqual(appDelegate.refreshCount, 1)
        firstWindow.close()
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

    func testPreferencesControllerNoopsWithoutWindowContentOrFactory() {
        let controller = PreferencesWindowController()

        controller.selectAboutTab()
        controller.addAboutTabIfNeeded()
        controller.openDataFeed(NSButton())

        XCTAssertNil(controller.monitoringInstancesWindow)
        XCTAssertNil(controller.findTabView(in: nil))
    }

    func testPreferencesControllerFindsDirectAndNestedTabViews() throws {
        let controller = PreferencesWindowController()
        let directTabView = NSTabView()
        let container = NSView()
        let nestedTabView = NSTabView()
        container.addSubview(NSView())
        container.addSubview(nestedTabView)

        XCTAssertTrue(controller.findTabView(in: directTabView) === directTabView)
        XCTAssertTrue(controller.findTabView(in: container) === nestedTabView)
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

    func testDefaultButtonWithoutIdentifierIgnoresAction() {
        let button = DefaultButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        button.state = .on

        button.performAction()

        XCTAssertNil(button.identifier)
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

    func testDefaultPopUpPersistsEachKnownSelectionAndIgnoresUnknownIdentifier() {
        let popup = DefaultPopUpButton(frame: NSRect(x: 0, y: 0, width: 120, height: 24), pullsDown: false)
        popup.identifier = NSUserInterfaceItemIdentifier("sortColumn")
        popup.addItems(withTitles: ["None", "Host", "Service", "Status", "Last Check", "Attempt", "Duration"])
        popup.selectItem(withTitle: "Duration")

        popup.performAction()

        XCTAssertEqual(Settings().integerForKey("sortColumn"), 6)

        popup.identifier = NSUserInterfaceItemIdentifier("unknownPopup")
        popup.selectItem(withTitle: "Host")
        popup.performAction()

        XCTAssertEqual(Settings().integerForKey("sortColumn"), 6)
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

    func testAudibleAlarmsTabMapsEverySoundFileSettingToItsPopup() {
        let cases: [(String, WritableKeyPath<AudibleAlarmsTabController, NSPopUpButton?>, String)] = [
            ("audibleAlarmsCriticalSoundFile", \.audibleAlarmsCriticalSoundFile, "critical.aiff"),
            ("audibleAlarmsWarningSoundFile", \.audibleAlarmsWarningSoundFile, "warning.aiff"),
            ("audibleAlarmsDownSoundFile", \.audibleAlarmsDownSoundFile, "down.aiff"),
            ("audibleAlarmsUnreachableSoundFile", \.audibleAlarmsUnreachableSoundFile, "unreachable.aiff"),
            ("audibleAlarmsRecoverySoundFile", \.audibleAlarmsRecoverySoundFile, "recovery.aiff"),
        ]

        for (settingKey, popupKeyPath, fileName) in cases {
            Settings().setString("/Library/Sounds/\(fileName)", forKey: settingKey)
            var controller = AudibleAlarmsTabController()
            let popup = NSPopUpButton()
            popup.addItems(withTitles: ["Default", "Custom"])
            controller[keyPath: popupKeyPath] = popup

            controller.setPopupState(settingKey)

            XCTAssertEqual(popup.indexOfSelectedItem, 1, settingKey)
            XCTAssertEqual(popup.titleOfSelectedItem, fileName, settingKey)
        }
    }

    func testAudibleAlarmsTabMapsEveryEmptySoundFileSettingToDefaultSelection() {
        let cases: [(String, WritableKeyPath<AudibleAlarmsTabController, NSPopUpButton?>)] = [
            ("audibleAlarmsCriticalSoundFile", \.audibleAlarmsCriticalSoundFile),
            ("audibleAlarmsWarningSoundFile", \.audibleAlarmsWarningSoundFile),
            ("audibleAlarmsDownSoundFile", \.audibleAlarmsDownSoundFile),
            ("audibleAlarmsUnreachableSoundFile", \.audibleAlarmsUnreachableSoundFile),
            ("audibleAlarmsRecoverySoundFile", \.audibleAlarmsRecoverySoundFile),
        ]

        for (settingKey, popupKeyPath) in cases {
            Settings().setString("", forKey: settingKey)
            var controller = AudibleAlarmsTabController()
            let popup = NSPopUpButton()
            popup.addItems(withTitles: ["Default", "Custom"])
            popup.selectItem(withTitle: "Custom")
            controller[keyPath: popupKeyPath] = popup

            controller.setPopupState(settingKey)

            XCTAssertEqual(popup.indexOfSelectedItem, 0, settingKey)
            XCTAssertEqual(popup.titleOfSelectedItem, "Default", settingKey)
        }
    }

    func testAudibleAlarmsTabIgnoresUnknownSoundFilePopupKey() {
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["Default", "Custom"])
        popup.selectItem(withTitle: "Custom")
        controller.audibleAlarmsCriticalSoundFile = popup

        controller.setPopupState("unknownSoundFile")

        XCTAssertEqual(popup.itemTitles, ["Default", "Custom"])
        XCTAssertEqual(popup.titleOfSelectedItem, "Custom")
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

    func testAudibleAlarmsPopupWithoutIdentifierDoesNotPersistSoundFile() {
        Settings().setString("", forKey: "audibleAlarmsCriticalSoundFile")
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["Default", "Custom"])
        popup.selectItem(withTitle: "Custom")
        controller.soundFilePicker = { [URL(fileURLWithPath: "/Library/Sounds/Basso.aiff")] }

        controller.popupButtonFileSelector(popup)

        XCTAssertEqual(popup.titleOfSelectedItem, "Custom")
        XCTAssertEqual(Settings().stringForKey("audibleAlarmsCriticalSoundFile"), "")
    }

    func testAudibleAlarmsPopupCustomSelectionStoresPickedSoundFile() throws {
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.identifier = NSUserInterfaceItemIdentifier("audibleAlarmsCriticalSoundFile")
        popup.addItems(withTitles: ["Default", "Custom"])
        popup.selectItem(withTitle: "Custom")
        let selectedURL = URL(fileURLWithPath: "/Library/Sounds/Submarine.aiff")
        controller.soundFilePicker = { [selectedURL] }

        controller.popupButtonFileSelector(popup)

        XCTAssertEqual(popup.itemTitles, ["Default", "Submarine.aiff"])
        XCTAssertEqual(popup.titleOfSelectedItem, "Submarine.aiff")
        XCTAssertEqual(Settings().stringForKey("audibleAlarmsCriticalSoundFile"), selectedURL.path)
    }

    func testAudibleAlarmsPopupCustomSelectionDisplaysUnescapedFileName() throws {
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.identifier = NSUserInterfaceItemIdentifier("audibleAlarmsCriticalSoundFile")
        popup.addItems(withTitles: ["Default", "Custom"])
        popup.selectItem(withTitle: "Custom")
        let selectedURL = URL(fileURLWithPath: "/Library/Sounds/Warning Bell.aiff")
        controller.soundFilePicker = { [selectedURL] }

        controller.popupButtonFileSelector(popup)

        XCTAssertEqual(popup.titleOfSelectedItem, "Warning Bell.aiff")
    }

    func testAudibleAlarmsSoundFilePanelAllowsSupportedAudioContentTypesOnly() throws {
        let panel = AudibleAlarmsTabController.soundFilePanel()
        let contentTypeIdentifiers = Set(panel.allowedContentTypes.map { $0.identifier })

        XCTAssertTrue(contentTypeIdentifiers.contains(try XCTUnwrap(UTType(filenameExtension: "aiff")).identifier))
        XCTAssertTrue(contentTypeIdentifiers.contains(try XCTUnwrap(UTType(filenameExtension: "wav")).identifier))
        XCTAssertTrue(contentTypeIdentifiers.contains(try XCTUnwrap(UTType(filenameExtension: "mp3")).identifier))
        XCTAssertFalse(contentTypeIdentifiers.contains(try XCTUnwrap(UTType(filenameExtension: "txt")).identifier))
    }

    func testAudibleAlarmsSoundFilePanelRejectsDirectoriesAndMultipleSelection() {
        let panel = AudibleAlarmsTabController.soundFilePanel()

        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
    }

    func testAudibleAlarmsPopupCustomSelectionCancelLeavesExistingSoundFile() {
        Settings().setString("/Library/Sounds/Basso.aiff", forKey: "audibleAlarmsCriticalSoundFile")
        let controller = AudibleAlarmsTabController()
        let popup = NSPopUpButton()
        popup.identifier = NSUserInterfaceItemIdentifier("audibleAlarmsCriticalSoundFile")
        popup.addItems(withTitles: ["Default", "Basso.aiff"])
        popup.selectItem(withTitle: "Basso.aiff")
        controller.soundFilePicker = { [] }

        controller.popupButtonFileSelector(popup)

        XCTAssertEqual(popup.itemTitles, ["Default", "Basso.aiff"])
        XCTAssertEqual(Settings().stringForKey("audibleAlarmsCriticalSoundFile"), "/Library/Sounds/Basso.aiff")
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

private final class RecordingAppDelegate: AppDelegate {
    var refreshCount = 0

    override func refreshStatusData() {
        refreshCount += 1
    }
}
