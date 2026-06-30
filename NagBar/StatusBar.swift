//
//  StatusBar.swift
//  NagBar
//
//  Created by Volen Davidov on 28.02.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class StatusBar : NSObject {
    
    // only a single instance of the status bar is needed
    private static let statusBar = StatusBar()
    
    class func get() -> StatusBar {
        return self.statusBar
    }
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var statusItemFailed: NSStatusItem?
    
    private var observer: AnyObject?
    
    private var results: Array<MonitoringItem>?
    private var oldResults: Array<MonitoringItem>?
    
    private var statusPanel: StatusPanel?

    var refreshStatusData: () -> Void = {
        LoadMonitoringData().refreshStatusData()
    }
    
    func load(_ results: Array<MonitoringItem>, failedMonitoringInstances: FailedMonitoringInstances) {
        
        self.results = results
        
        // reload the status panel in case it is opened
        self.refreshStatusPanel()
        
        // show the failed monitoring instances status bar
        self.failedMonitoringInstancesView(failedMonitoringInstances)
        
        self.statusItem.length = NSStatusItem.variableLength
        self.statusItem.button?.title = statusItemTitle(for: results)
        StatusItemAccessibility.applyMainButtonMetadata(to: self.statusItem.button)
        self.statusItem.menu = statusItemMenu()
        
        // finally animate the status bar (shake, change color and etc.)
        self.animateStatusBar()
        
        oldResults = results
    }
    
    private func failedMonitoringInstancesView(_ failedMonitoringInstances: FailedMonitoringInstances) {
        
        if failedMonitoringInstances.count > 0 {
            self.statusItemFailed = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        } else {
            self.statusItemFailed = nil
            return
        }
        
        // we want to use the default NSCaution image, but we have to change its size
        
        let cautionImage = NSImage(named: "NSCaution")
        cautionImage?.size = CGSize(width: 18, height: 18)
        
        statusItemFailed!.button?.image = cautionImage
        StatusItemAccessibility.applyFailedButtonMetadata(to: statusItemFailed!.button)
        
        let menu = NSMenu()
        
        for (failedInstance, reason) in failedMonitoringInstances {
            
            var menuText: String?
            
            switch reason {
            case .wrongCredentials:
                menuText = String(format: NSLocalizedString("monitoringInstanceFailedWrongCredentials", comment: ""), failedInstance.name)
            case .ssl:
                menuText = String(format: NSLocalizedString("monitoringInstanceFailedSSL", comment: ""), failedInstance.name)
            default:
                menuText = String(format: NSLocalizedString("monitoringInstanceFailedUnknown", comment: ""), failedInstance.name)
            }
            menu.addItem(withTitle: menuText!, action: nil, keyEquivalent: "")
        }
        
        statusItemFailed!.menu = menu
    }
    
    func onClick() {
        NSApp.activate(ignoringOtherApps: true)
        _ = self.showStatusPanel()
    }

    @objc func showStatus() {
        onClick()
    }

    @objc func refresh() {
        StatusItemRefreshAction.perform(refresh: refreshStatusData)
    }

    @objc func showAbout() {
        (NSApplication.shared.delegate as? AppDelegate)?.openAbout(self)
    }

    @objc func openPreferences() {
        (NSApplication.shared.delegate as? AppDelegate)?.openPreferences(self)
    }

    @discardableResult
    func showStatusPanel() -> Bool {
        guard let results = self.results else {
            return StatusPanelEntrypoint.requestPresentation(
                hasResults: false,
                refresh: refreshStatusData,
                present: {}
            )
        }

        guard let frameOrigin = self.statusItemFrame() else {
            return false
        }

        return StatusPanelEntrypoint.requestPresentation(
            hasResults: true,
            refresh: {},
            present: {
                self.loadStatusPanel(results: results, panelBounds: frameOrigin)
            }
        )
    }
    
    private func refreshStatusPanel() {
        // refresh the status panel if it is opened, it won't be opened if self.statusPanel is nil
        if self.statusPanel != nil {
            _ = self.showStatusPanel()
        }
    }
    
    private func loadStatusPanel(results: Array<MonitoringItem>, panelBounds: NSRect) {
        // If there is an existing panel (this will be the case when the
        // panel is already opened and is just being refreshed or if the panel is again
        // already opened and the status bar is clicked on second time), close it
        self.statusPanel?.panel?.close()
        self.statusPanel = nil
        
        self.statusPanel = StatusPanel(results: results, panelBounds: panelBounds)
        if let observer = self.observer as? NSObjectProtocol {
            Foundation.NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        observer = Foundation.NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: nil, using: {_ in
            // dismiss the panel only if another application is in foreground
            // otherwise the panel will be dismissed also on functions which open a modal inside the app
            // (e.g. acknowledge, schedule downtime) and when submitting the modal, the error
            // "sent to deallocated instance" will occur because the StatusPanel keeps reference to
            // these modals
            guard let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                  let bundleIdentifier = Bundle.main.bundleIdentifier else {
                return
            }

            if frontmostBundleIdentifier != bundleIdentifier {
                self.statusPanel?.panel?.close()
                self.statusPanel = nil
                if let observer = self.observer as? NSObjectProtocol {
                    Foundation.NotificationCenter.default.removeObserver(observer)
                    self.observer = nil
                }
            }
            }
        )
        
        self.statusPanel!.load()
    }

    private func statusItemFrame() -> NSRect? {
        if let frame = self.statusItem.button?.window?.frame {
            return frame
        }

        if let window = self.statusItem.value(forKey: "window") as? NSWindow {
            return window.frame
        }

        return NSScreen.main?.visibleFrame
    }

    private func statusItemMenu() -> NSMenu {
        return StatusItemMenuBuilder.build(
            target: self,
            actions: StatusItemMenuActions(
                status: #selector(StatusBar.showStatus),
                about: #selector(StatusBar.showAbout),
                preferences: #selector(StatusBar.openPreferences),
                refresh: #selector(StatusBar.refresh)
            )
        )
    }

    private func statusItemTitle(for results: Array<MonitoringItem>) -> String {
        return StatusItemTitleFormatter.title(
            for: results,
            showExtendedStatusInformation: Settings().boolForKey("showExtendedStatusInformation")
        )
    }
    
    private func animateStatusBar() {
        
        if !Settings().boolForKey("flashStatusBar") {
            return
        }
        
        let animateType = Settings().integerForKey("flashStatusBarType")
        
        let animateTypes = [2: LightFlashStatusBar(), 3: DarkFlashStatusBar()]
        
        animateTypes[animateType]?.animate(oldResults: self.oldResults, newResults: self.results)
    }
}
