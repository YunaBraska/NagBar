//
//  AboutSettingsContentTests.swift
//  NagBarTests
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import XCTest
import Cocoa
@testable import NagBar

final class AboutSettingsContentTests: XCTestCase {
    func testAboutSettingsContentContainsVersionBuildLicenseAndSupport() {
        let bundle = Bundle(for: AboutSettingsContentTests.self)

        let content = AboutSettingsContent.make(bundle: bundle)
        let titles = content.rows.map { $0.title }

        XCTAssertEqual(titles, ["Version", "Build", "Bundle", "License", "Support"])
        XCTAssertFalse(content.rows[0].value.isEmpty)
        XCTAssertFalse(content.rows[1].value.isEmpty)
        XCTAssertFalse(content.rows[2].value.isEmpty)
        XCTAssertEqual(content.rows[3].value, "Apache License 2.0")
        XCTAssertEqual(content.rows[4].value, "https://github.com/volendavidov/NagBar/issues")
        XCTAssertTrue(content.summary.contains("macOS status bar client"))
    }

    func testAboutSettingsContentUsesFallbacksForMissingBundleMetadata() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        let content = AboutSettingsContent.make(bundle: bundle)

        XCTAssertEqual(content.rows[0].value, "Unversioned")
        XCTAssertEqual(content.rows[1].value, "Local build")
        XCTAssertEqual(content.rows[2].value, "com.volendavidov.NagBar")
    }

    func testAboutSettingsTabContainsExpectedIdentifierLabelAndVisibleText() throws {
        let content = AboutSettingsContent(
            rows: [
                AboutSettingsRow(title: "Version", value: "1.2.3"),
                AboutSettingsRow(title: "Build", value: "456"),
                AboutSettingsRow(title: "Bundle", value: "com.example.NagBar"),
                AboutSettingsRow(title: "License", value: "Apache License 2.0"),
                AboutSettingsRow(title: "Support", value: "https://example.test/support")
            ],
            summary: "Fixture summary"
        )

        let item = AboutSettingsTabBuilder.makeTabItem(
            content: content,
            frame: NSRect(x: 0, y: 0, width: 500, height: 320)
        )

        XCTAssertTrue(AboutSettingsTabBuilder.isAboutTab(item))
        XCTAssertEqual(item.label, "About")

        let view = try XCTUnwrap(item.view)
        let labels = textFieldStrings(in: view)

        XCTAssertEqual(view.accessibilityIdentifier(), AboutSettingsTabBuilder.viewIdentifier)
        XCTAssertEqual(view.accessibilityLabel(), "About NagBar")
        XCTAssertEqual(labels, [
            "NagBar",
            "Fixture summary",
            "Version",
            "1.2.3",
            "Build",
            "456",
            "Bundle",
            "com.example.NagBar",
            "License",
            "Apache License 2.0",
            "Support",
            "https://example.test/support"
        ])

        let titleLabel = try XCTUnwrap(textField(withIdentifier: AboutSettingsTabBuilder.titleIdentifier, in: view))
        let summaryLabel = try XCTUnwrap(textField(withIdentifier: AboutSettingsTabBuilder.summaryIdentifier, in: view))
        let versionTitle = try XCTUnwrap(textField(withIdentifier: AboutSettingsTabBuilder.rowIdentifier("Version", suffix: "title"), in: view))
        let versionValue = try XCTUnwrap(textField(withIdentifier: AboutSettingsTabBuilder.rowIdentifier("Version", suffix: "value"), in: view))
        let supportValue = try XCTUnwrap(textField(withIdentifier: AboutSettingsTabBuilder.rowIdentifier("Support", suffix: "value"), in: view))

        XCTAssertEqual(titleLabel.accessibilityLabel(), "NagBar")
        XCTAssertEqual(summaryLabel.accessibilityLabel(), "Fixture summary")
        XCTAssertEqual(versionTitle.accessibilityLabel(), "Version")
        XCTAssertEqual(versionValue.accessibilityLabel(), "Version: 1.2.3")
        XCTAssertEqual(supportValue.accessibilityLabel(), "Support: https://example.test/support")
    }

    func testAboutSettingsTabIsAddedOnlyOnce() {
        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 500, height: 320))
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        tabView.addTabViewItem(generalItem)

        AboutSettingsTabBuilder.addAboutTabIfNeeded(to: tabView)
        AboutSettingsTabBuilder.addAboutTabIfNeeded(to: tabView)

        XCTAssertEqual(tabView.tabViewItems.map(\.label), ["General", "About"])
        XCTAssertEqual(tabView.tabViewItems.filter(AboutSettingsTabBuilder.isAboutTab).count, 1)
    }

    private func textFieldStrings(in view: NSView) -> [String] {
        view.subviews.flatMap { subview -> [String] in
            let ownText = (subview as? NSTextField).map { [$0.stringValue] } ?? []
            return ownText + textFieldStrings(in: subview)
        }
    }

    private func textField(withIdentifier identifier: String, in view: NSView) -> NSTextField? {
        for subview in view.subviews {
            if let textField = subview as? NSTextField, textField.accessibilityIdentifier() == identifier {
                return textField
            }

            if let nested = textField(withIdentifier: identifier, in: subview) {
                return nested
            }
        }

        return nil
    }
}
