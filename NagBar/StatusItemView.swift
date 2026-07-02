//
//  StatusItemView.swift
//  NagBar
//
//  Created by Volen Davidov on 05.03.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class StatusItemView: NSStatusBarButton {
    static var performStatusItemClick: (NSStatusItem, NSButton, NSMenu, StatusItemView) -> Void = { statusItem, button, menu, view in
        statusItem.menu = menu
        button.performClick(view)
    }
    static var popUpContextMenu: (NSMenu, NSEvent, StatusItemView) -> Void = { menu, event, view in
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
    static var popUpMenu: (NSMenu, NSPoint, StatusItemView) -> Void = { menu, point, view in
        menu.popUp(positioning: nil, at: point, in: view)
    }
    static var refreshStatusData: () -> Void = {
        LoadMonitoringData().refreshStatusData()
    }

    let StatusItemViewPaddingWidth = CGFloat(6)
    let StatusItemViewPaddingHeight = CGFloat(3)
    
//    var title: String?
    var statusItem: NSStatusItem?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        StatusItemAccessibility.applyMainButtonMetadata(to: self)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let origin = NSMakePoint(StatusItemViewPaddingWidth, StatusItemViewPaddingHeight);
        title.draw(at: origin, withAttributes: titleAttributes())
    }
    
    private func titleAttributes() -> Dictionary<NSAttributedString.Key, AnyObject> {
        let font = NSFont.menuBarFont(ofSize: 0)
        
        var color = NSColor.black
        
        // check if dark mode is enabled
        let dict = Foundation.UserDefaults.standard.persistentDomain(forName: Foundation.UserDefaults.globalDomain)
        let style = dict!["AppleInterfaceStyle"]
        
        if let style = style as? String {
            if ComparisonResult.orderedSame == style.caseInsensitiveCompare("dark") {
                color = NSColor.white
            }
        }
        
        // fix for Big Sur
        if self.statusItem?.button?.effectiveAppearance.name.rawValue == "NSAppearanceNameVibrantDark" {
            color = NSColor.white
        }
        
        return [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: color]
    }
    
    override func rightMouseDown(with theEvent: NSEvent) {
        openStatusItemMenu(with: theEvent)
    }

    func statusItemMenu() -> NSMenu {
        return StatusItemMenuBuilder.build(
            target: statusItemMenuTarget(),
            actions: StatusItemMenuActions(
                status: #selector(AppDelegate.showStatusFromStatusItem),
                update: #selector(AppDelegate.openAvailableUpdateFromStatusItem),
                about: #selector(AppDelegate.showAboutFromStatusItem),
                preferences: #selector(AppDelegate.openPreferencesFromStatusItem),
                refresh: #selector(AppDelegate.refreshFromStatusItem)
            )
        )
    }

    private func statusItemMenuTarget() -> AnyObject {
        return (NSApplication.shared.delegate as AnyObject?) ?? self
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        openStatusItemMenu(with: theEvent)
    }

    override func accessibilityPerformPress() -> Bool {
        openStatusItemMenu()
        return true
    }

    @objc func showStatus(_ sender: AnyObject) {
        StatusBar.get().onClick()
    }
    
    @objc func refresh(_ sender: AnyObject) {
        Self.refreshStatusData()
    }

    @objc func showAbout(_ sender: AnyObject) {
        (NSApplication.shared.delegate as? AppDelegate)?.openAbout(self)
    }

    @objc func openPreferences(_ sender: AnyObject) {
        (NSApplication.shared.delegate as? AppDelegate)?.openPreferences(self)
    }

    func setStatusItemTitle(_ newTitle: String) {
        if self.title == newTitle {
            return
        }
        
        self.title = newTitle
        
        let titleBounds = self.titleBoundingRect()
        let newWidth = titleBounds.size.width + (2 * StatusItemViewPaddingWidth)
        self.statusItem?.length = newWidth
        self.needsDisplay = true
    }
    
    func titleBoundingRect() -> NSRect {
        return title.boundingRect(with: NSMakeSize(0, 0), options: .usesFontLeading, attributes: self.titleAttributes())
    }

    private func openStatusItemMenu(with event: NSEvent? = nil) {
        let menu = statusItemMenu()
        if let statusItem = statusItem, let button = statusItem.button {
            Self.performStatusItemClick(statusItem, button, menu, self)
            return
        }

        if let event = event {
            Self.popUpContextMenu(menu, event, self)
            return
        }
        Self.popUpMenu(menu, NSPoint(x: 0, y: bounds.minY), self)
    }
}
