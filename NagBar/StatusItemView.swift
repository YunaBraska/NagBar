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
            target: self,
            actions: StatusItemMenuActions(
                status: #selector(StatusItemView.showStatus),
                about: #selector(StatusItemView.showAbout),
                preferences: #selector(StatusItemView.openPreferences),
                refresh: #selector(StatusItemView.refresh)
            )
        )
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        openStatusItemMenu(with: theEvent)
    }

    override func accessibilityPerformPress() -> Bool {
        openStatusItemMenu()
        return true
    }

    @objc func showStatus() {
        StatusBar.get().onClick()
    }
    
    @objc func refresh() {
        LoadMonitoringData().refreshStatusData()
    }

    @objc func showAbout() {
        (NSApplication.shared.delegate as? AppDelegate)?.openAbout(self)
    }

    @objc func openPreferences() {
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
            statusItem.menu = menu
            button.performClick(self)
            return
        }

        if let event = event {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.minY), in: self)
    }
}
