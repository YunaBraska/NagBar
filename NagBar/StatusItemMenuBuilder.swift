//
//  StatusItemMenuBuilder.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Cocoa

struct StatusItemTitleFormatter {
    static func title(for results: Array<MonitoringItem>, showExtendedStatusInformation: Bool) -> String {
        if showExtendedStatusInformation {
            return codes(for: results)
        }

        return localized("totalCount", fallback: "Total Count:") + " " + String(results.count)
    }

    static func codes(for results: Array<MonitoringItem>) -> String {
        var counts: Dictionary<String, Int> = [:]

        for item in results {
            counts[item.status, default: 0] += 1
        }

        let parts = [
            ("CRITICAL", "C"),
            ("WARNING", "W"),
            ("UNKNOWN", "U"),
            ("PENDING", "P"),
            ("OK", "O"),
            ("UNREACHABLE", "UR"),
            ("DOWN", "D"),
            ("UP", "UP")
        ].compactMap { status, code -> String? in
            guard let count = counts[status], count > 0 else {
                return nil
            }
            return code + ":" + String(count)
        }

        if parts.isEmpty {
            return localized("noAlarms", fallback: "No Alarms")
        }

        return parts.joined(separator: " ")
    }

    private static func localized(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
    }
}

struct StatusItemMenuActions {
    let status: Selector
    let about: Selector
    let preferences: Selector
    let refresh: Selector
}

struct StatusItemMenuBuilder {
    static func build(target: AnyObject, actions: StatusItemMenuActions) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(menuItem(title: "Show Status", identifier: StatusItemAccessibility.showStatusIdentifier, action: actions.status, target: target))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "About NagBar", identifier: StatusItemAccessibility.aboutIdentifier, action: actions.about, target: target))
        menu.addItem(menuItem(title: "Preferences", identifier: StatusItemAccessibility.preferencesIdentifier, action: actions.preferences, target: target))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "Refresh", identifier: StatusItemAccessibility.refreshIdentifier, action: actions.refresh, target: target))
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quitItem.target = NSApplication.shared
        quitItem.setAccessibilityIdentifier(StatusItemAccessibility.quitIdentifier)
        menu.addItem(quitItem)

        return menu
    }

    private static func menuItem(title: String, identifier: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.setAccessibilityIdentifier(identifier)
        return item
    }
}

struct StatusPanelDismissalPolicy {
    static func shouldDismiss(frontmostBundleIdentifier: String, bundleIdentifier: String) -> Bool {
        if frontmostBundleIdentifier == bundleIdentifier {
            return false
        }

        if frontmostBundleIdentifier == "com.apple.systemevents" {
            return false
        }

        return true
    }
}

struct StatusPanelFallbackFrame {
    static func statusItemFrame(visibleFrame: NSRect) -> NSRect {
        return NSRect(x: visibleFrame.maxX - 1, y: visibleFrame.maxY, width: 1, height: 1)
    }
}

struct StatusItemAccessibility {
    static let title = "NagBar status menu"
    static let help = "Opens NagBar status, settings, refresh, and quit actions."
    static let failedTitle = "NagBar monitoring connection warnings"
    static let failedHelp = "Opens monitoring instances that failed during refresh."
    static let statusItemButtonIdentifier = "nagbar.statusItem.button"
    static let failedStatusItemButtonIdentifier = "nagbar.statusItem.failed.button"
    static let showStatusIdentifier = "nagbar.statusItem.showStatus"
    static let aboutIdentifier = "nagbar.statusItem.about"
    static let preferencesIdentifier = "nagbar.statusItem.preferences"
    static let refreshIdentifier = "nagbar.statusItem.refresh"
    static let quitIdentifier = "nagbar.statusItem.quit"
    static let statusPanelIdentifier = "nagbar.statusPanel"
    static let statusPanelTableIdentifier = "nagbar.statusPanel.table"

    static func applyMainButtonMetadata(to button: NSButton?) {
        button?.setAccessibilityTitle(title)
        button?.setAccessibilityHelp(help)
        button?.setAccessibilityIdentifier(statusItemButtonIdentifier)
    }

    static func applyFailedButtonMetadata(to button: NSButton?) {
        button?.setAccessibilityTitle(failedTitle)
        button?.setAccessibilityHelp(failedHelp)
        button?.setAccessibilityIdentifier(failedStatusItemButtonIdentifier)
    }
}

struct StatusPanelEntrypoint {
    static func requestPresentation(hasResults: Bool, refresh: () -> Void, present: () -> Void) -> Bool {
        if !hasResults {
            refresh()
            return false
        }

        present()
        return true
    }
}

struct StatusItemRefreshAction {
    static func perform(refresh: () -> Void) {
        refresh()
    }
}

struct ApplicationMenuPolicy {
    private static let removedActions: Set<String> = [
        "orderFrontStandardAboutPanel:",
        "openPreferences:"
    ]

    static func keepStatusItemAsProductEntrypoint(mainMenu: NSMenu?) {
        guard let mainMenu = mainMenu else {
            return
        }

        removeProductEntrypoints(from: mainMenu)
    }

    private static func removeProductEntrypoints(from menu: NSMenu) {
        for item in menu.items.reversed() {
            if shouldRemove(item) {
                menu.removeItem(item)
            } else {
                removeProductEntrypoints(from: item.submenu)
            }
        }

        removeDuplicateSeparators(from: menu)
    }

    private static func removeProductEntrypoints(from menu: NSMenu?) {
        guard let menu = menu else {
            return
        }

        removeProductEntrypoints(from: menu)
    }

    private static func shouldRemove(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else {
            return false
        }

        return removedActions.contains(NSStringFromSelector(action))
    }

    private static func removeDuplicateSeparators(from menu: NSMenu) {
        for index in menu.items.indices.reversed() {
            let item = menu.items[index]
            guard isSeparator(item) else {
                continue
            }

            if index == 0 || index == menu.items.count - 1 {
                menu.removeItem(at: index)
            } else if isSeparator(menu.items[index + 1]) {
                menu.removeItem(at: index)
            }
        }
    }

    private static func isSeparator(_ item: NSMenuItem) -> Bool {
        return item.isSeparatorItem || (item.title.isEmpty && item.action == nil)
    }
}
