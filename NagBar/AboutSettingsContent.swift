//
//  AboutSettingsContent.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa

struct AboutSettingsRow {
    let title: String
    let value: String
}

struct AboutSettingsContent {
    static let supportURL = "https://github.com/volendavidov/NagBar/issues"
    static let licenseName = "Apache License 2.0"

    let rows: [AboutSettingsRow]
    let summary: String

    static func make(bundle: Bundle = .main) -> AboutSettingsContent {
        let version = nonEmpty(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unversioned"
        let build = nonEmpty(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Local build"
        let identifier = nonEmpty(bundle.bundleIdentifier) ?? "com.volendavidov.NagBar"

        return AboutSettingsContent(
            rows: [
                AboutSettingsRow(title: "Version", value: version),
                AboutSettingsRow(title: "Build", value: build),
                AboutSettingsRow(title: "Bundle", value: identifier),
                AboutSettingsRow(title: "License", value: licenseName),
                AboutSettingsRow(title: "Support", value: supportURL)
            ],
            summary: "NagBar is a native macOS status bar client for Nagios-compatible monitoring systems."
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        return value
    }
}

enum AboutSettingsTabBuilder {
    static let tabIdentifier = "about"
    static let tabLabel = "About"
    static let title = "NagBar"
    static let viewIdentifier = "nagbar.preferences.about"
    static let titleIdentifier = "nagbar.preferences.about.title"
    static let summaryIdentifier = "nagbar.preferences.about.summary"

    static func addAboutTabIfNeeded(to tabView: NSTabView, content: AboutSettingsContent = .make()) {
        guard !containsAboutTab(in: tabView) else {
            return
        }

        tabView.addTabViewItem(makeTabItem(content: content, frame: tabView.contentRect))
    }

    static func containsAboutTab(in tabView: NSTabView) -> Bool {
        tabView.tabViewItems.contains(where: isAboutTab)
    }

    static func isAboutTab(_ item: NSTabViewItem) -> Bool {
        String(describing: item.identifier ?? "") == tabIdentifier
    }

    static func makeTabItem(content: AboutSettingsContent = .make(), frame: NSRect) -> NSTabViewItem {
        let tabItem = NSTabViewItem(identifier: tabIdentifier)
        tabItem.label = tabLabel
        tabItem.view = makeView(content: content, frame: frame)
        return tabItem
    }

    private static func makeView(content: AboutSettingsContent, frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        view.setAccessibilityIdentifier(viewIdentifier)
        view.setAccessibilityLabel("About NagBar")

        let titleLabel = label(text: title, font: .boldSystemFont(ofSize: 18))
        titleLabel.frame = NSRect(x: 24, y: frame.height - 58, width: frame.width - 48, height: 24)
        titleLabel.setAccessibilityIdentifier(titleIdentifier)
        titleLabel.setAccessibilityLabel(title)
        view.addSubview(titleLabel)

        let summary = label(text: content.summary, font: .systemFont(ofSize: 13))
        summary.frame = NSRect(x: 24, y: frame.height - 92, width: frame.width - 48, height: 36)
        summary.lineBreakMode = .byWordWrapping
        summary.cell?.wraps = true
        summary.setAccessibilityIdentifier(summaryIdentifier)
        summary.setAccessibilityLabel(content.summary)
        view.addSubview(summary)

        var y = frame.height - 138
        for row in content.rows {
            let rowTitle = label(text: row.title, font: .boldSystemFont(ofSize: 12))
            rowTitle.frame = NSRect(x: 24, y: y, width: 90, height: 18)
            rowTitle.setAccessibilityIdentifier(rowIdentifier(row.title, suffix: "title"))
            rowTitle.setAccessibilityLabel(row.title)
            view.addSubview(rowTitle)

            let rowValue = label(text: row.value, font: .systemFont(ofSize: 12))
            rowValue.frame = NSRect(x: 122, y: y, width: frame.width - 146, height: 18)
            rowValue.lineBreakMode = .byTruncatingMiddle
            rowValue.setAccessibilityIdentifier(rowIdentifier(row.title, suffix: "value"))
            rowValue.setAccessibilityLabel("\(row.title): \(row.value)")
            view.addSubview(rowValue)

            y -= 28
        }

        return view
    }

    static func rowIdentifier(_ title: String, suffix: String) -> String {
        "nagbar.preferences.about.\(title.lowercased()).\(suffix)"
    }

    private static func label(text: String, font: NSFont) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = .labelColor
        field.backgroundColor = .clear
        field.isBordered = false
        field.isEditable = false
        field.isSelectable = true
        return field
    }
}
