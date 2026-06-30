//
//  CommandWindowAccessibilityTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa
import XCTest

final class CommandWindowAccessibilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Settings().resetKnownSettings()
        Settings().setString("default acknowledgement", forKey: "acknowledgementDefaultComment")
        Settings().setString("default downtime", forKey: "scheduleDowntimeDefaultComment")
    }

    func testAcknowledgeWindowExposesStableAccessibilityIdentifiers() throws {
        let controller = AcknowledgeWindow(windowNibName: "AcknowledgeWindow")
        let window = try XCTUnwrap(controller.window)
        controller.applyAccessibilityMetadata()

        let comment = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.acknowledgeCommentIdentifier, in: window.contentView))
        let ok = try XCTUnwrap(button(withIdentifier: CommandWindowAccessibility.acknowledgeOKIdentifier, in: window.contentView))
        let cancel = try XCTUnwrap(button(withIdentifier: CommandWindowAccessibility.acknowledgeCancelIdentifier, in: window.contentView))

        XCTAssertEqual(window.accessibilityIdentifier(), CommandWindowAccessibility.acknowledgeWindowIdentifier)
        XCTAssertEqual(window.accessibilityLabel(), "Acknowledge monitoring problem")
        XCTAssertEqual(comment.accessibilityLabel(), "Acknowledgement comment")
        XCTAssertEqual(comment.stringValue, "default acknowledgement")
        XCTAssertEqual(ok.accessibilityLabel(), "Submit acknowledgement")
        XCTAssertEqual(cancel.accessibilityLabel(), "Cancel acknowledgement")
    }

    func testScheduleDowntimeWindowExposesStableAccessibilityIdentifiers() throws {
        let controller = ScheduleDowntimeWindow(windowNibName: "ScheduleDowntimeWindow")
        controller.monitoringItems = [makeHost()]
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        controller.applyAccessibilityMetadata()

        let comment = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeCommentIdentifier, in: window.contentView))
        let startTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeStartTimeIdentifier, in: window.contentView))
        let endTime = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeEndTimeIdentifier, in: window.contentView))
        let type = try XCTUnwrap(popUpButton(withIdentifier: CommandWindowAccessibility.scheduleDowntimeTypeIdentifier, in: window.contentView))
        let hours = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeHoursIdentifier, in: window.contentView))
        let minutes = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeMinutesIdentifier, in: window.contentView))
        let ok = try XCTUnwrap(button(withIdentifier: CommandWindowAccessibility.scheduleDowntimeOKIdentifier, in: window.contentView))
        let cancel = try XCTUnwrap(button(withIdentifier: CommandWindowAccessibility.scheduleDowntimeCancelIdentifier, in: window.contentView))

        XCTAssertEqual(window.accessibilityIdentifier(), CommandWindowAccessibility.scheduleDowntimeWindowIdentifier)
        XCTAssertEqual(window.accessibilityLabel(), "Schedule monitoring downtime")
        XCTAssertEqual(comment.accessibilityLabel(), "Downtime comment")
        XCTAssertEqual(comment.stringValue, "default downtime")
        XCTAssertEqual(startTime.accessibilityLabel(), "Downtime start time")
        XCTAssertEqual(endTime.accessibilityLabel(), "Downtime end time")
        XCTAssertEqual(type.accessibilityLabel(), "Downtime type")
        XCTAssertEqual(hours.accessibilityLabel(), "Flexible downtime hours")
        XCTAssertEqual(minutes.accessibilityLabel(), "Flexible downtime minutes")
        XCTAssertEqual(ok.accessibilityLabel(), "Submit downtime")
        XCTAssertEqual(cancel.accessibilityLabel(), "Cancel downtime")
    }

    func testHourFormatterAcceptsEmptyAndTwoDigitsAndRejectsInvalidInput() {
        let formatter = HourNumberFormatter()

        XCTAssertTrue(formatter.isPartialStringValid("", newEditingString: nil, errorDescription: nil))
        XCTAssertTrue(formatter.isPartialStringValid("0", newEditingString: nil, errorDescription: nil))
        XCTAssertTrue(formatter.isPartialStringValid("23", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("123", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("x", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("-1", newEditingString: nil, errorDescription: nil))
    }

    func testMinuteFormatterAcceptsZeroThroughFiftyNineAndRejectsInvalidInput() {
        let formatter = MinuteNumberFormatter()

        XCTAssertTrue(formatter.isPartialStringValid("", newEditingString: nil, errorDescription: nil))
        XCTAssertTrue(formatter.isPartialStringValid("0", newEditingString: nil, errorDescription: nil))
        XCTAssertTrue(formatter.isPartialStringValid("59", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("60", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("1234", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("x", newEditingString: nil, errorDescription: nil))
        XCTAssertFalse(formatter.isPartialStringValid("-1", newEditingString: nil, errorDescription: nil))
    }

    func testScheduleDowntimePopupSwitchesFlexibleDurationFields() throws {
        let controller = ScheduleDowntimeWindow(windowNibName: "ScheduleDowntimeWindow")
        controller.monitoringItems = [makeHost()]
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        controller.applyAccessibilityMetadata()
        let type = try XCTUnwrap(popUpButton(withIdentifier: CommandWindowAccessibility.scheduleDowntimeTypeIdentifier, in: window.contentView))
        let hours = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeHoursIdentifier, in: window.contentView))
        let minutes = try XCTUnwrap(textField(withIdentifier: CommandWindowAccessibility.scheduleDowntimeMinutesIdentifier, in: window.contentView))

        type.selectItem(at: 1)
        controller.popupButtonClicked(type)

        XCTAssertTrue(hours.isEnabled)
        XCTAssertTrue(minutes.isEnabled)
        XCTAssertEqual(hours.stringValue, "2")
        XCTAssertEqual(minutes.stringValue, "0")

        type.selectItem(at: 0)
        controller.popupButtonClicked(type)

        XCTAssertFalse(hours.isEnabled)
        XCTAssertFalse(minutes.isEnabled)
        XCTAssertEqual(hours.stringValue, "")
        XCTAssertEqual(minutes.stringValue, "")
    }

    private func makeHost() -> HostMonitoringItem {
        let monitoringInstance = MonitoringInstance().initDefault(
            name: "local",
            url: LocalIcingaFallback.instance().url,
            type: .Icinga,
            username: LocalIcingaFallback.username,
            password: LocalIcingaFallback.password,
            enabled: 1
        )
        let host = HostMonitoringItem()
        host.host = "localhost"
        host.monitoringInstance = monitoringInstance
        return host
    }

    private func textField(withIdentifier identifier: String, in view: NSView?) -> NSTextField? {
        firstSubview(in: view, matching: { $0.accessibilityIdentifier() == identifier }) as? NSTextField
    }

    private func button(withIdentifier identifier: String, in view: NSView?) -> NSButton? {
        firstSubview(in: view, matching: { $0.accessibilityIdentifier() == identifier }) as? NSButton
    }

    private func popUpButton(withIdentifier identifier: String, in view: NSView?) -> NSPopUpButton? {
        firstSubview(in: view, matching: { $0.accessibilityIdentifier() == identifier }) as? NSPopUpButton
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
}
