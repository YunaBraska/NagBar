//
//  PreferencesWindowController.swift
//  NagBar
//
//  Created by Volen Davidov on 10.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class PreferencesWindowController: NSWindowController {
    
    var monitoringInstancesWindow: NSWindowController?
    var monitoringInstancesWindowFactory: (() -> NSWindowController)?

    override func windowDidLoad() {
        super.windowDidLoad()
        addAboutTabIfNeeded()
    }

    func selectAboutTab() {
        guard let tabView = findTabView(in: window?.contentView) else {
            return
        }

        addAboutTabIfNeeded()

        if let item = tabView.tabViewItems.first(where: AboutSettingsTabBuilder.isAboutTab) {
            tabView.selectTabViewItem(item)
        }
    }
    
    @IBAction func openDataFeed(_ sender: AnyObject) {
        guard let monitoringInstancesWindowFactory = monitoringInstancesWindowFactory else {
            return
        }

        monitoringInstancesWindow = nil
        monitoringInstancesWindow = monitoringInstancesWindowFactory()
        monitoringInstancesWindow?.showWindow(self)
    }

    func addAboutTabIfNeeded() {
        guard let tabView = findTabView(in: window?.contentView) else {
            return
        }

        AboutSettingsTabBuilder.addAboutTabIfNeeded(to: tabView)
    }

    func findTabView(in view: NSView?) -> NSTabView? {
        guard let view = view else {
            return nil
        }

        if let tabView = view as? NSTabView {
            return tabView
        }

        for subview in view.subviews {
            if let tabView = findTabView(in: subview) {
                return tabView
            }
        }

        return nil
    }

}
