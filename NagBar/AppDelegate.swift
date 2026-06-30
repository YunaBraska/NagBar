//
//  AppDelegate.swift
//  NagBar
//
//  Created by Volen Davidov on 10.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var preferencesWindow: PreferencesWindowController?
    
    var passwordWindow: PasswordPromptController?
    
    @IBOutlet weak var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationMenuPolicy.keepStatusItemAsProductEntrypoint(mainMenu: NSApp.mainMenu)
        
        // init the configuration
        InitConfig().initConfig()
        NagBarDiagnostics.logStartup()
        
        // check if the Dock icon should be displayed
        if !Settings().boolForKey("showDockIcon") {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // check for new versions
        if Settings().boolForKey("newVersionCheck") {
            CheckNewVersion().checkNewVersion()
        }
        
        // ask for passwords in case they are not saved
        if !Settings().boolForKey("savePassword") && MonitoringInstances().hasEnabledConfiguredInstances() {
            self.showPasswordPrompt()
        }
        
        self.refreshStatusData()
        let timer = Timer(timeInterval: Settings().doubleForKey("refreshInterval"), target: self, selector: #selector(self.refreshStatusData), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
    }
    
    @IBAction func openPreferences(_ sender: AnyObject) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NagBarDiagnostics.logStatusItemEvent(message: "openPreferencesRequested")
        let preferencesWindow = currentPreferencesWindow()
        preferencesWindow.showWindow(self)
        preferencesWindow.window?.makeKeyAndOrderFront(self)
    }

    @objc(openPreferences) func openPreferencesFromStatusItem() {
        openPreferences(self)
    }

    @IBAction func openAbout(_ sender: AnyObject) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NagBarDiagnostics.logStatusItemEvent(message: "openAboutRequested")
        let preferencesWindow = currentPreferencesWindow()
        preferencesWindow.showWindow(self)
        preferencesWindow.window?.makeKeyAndOrderFront(self)
        preferencesWindow.selectAboutTab()
    }

    @IBAction func showAbout(_ sender: AnyObject) {
        openAbout(self)
    }

    @objc(showAbout) func showAboutFromStatusItem() {
        openAbout(self)
    }

    @IBAction func showStatus(_ sender: AnyObject) {
        StatusBar.get().onClick()
    }

    @objc(showStatus) func showStatusFromStatusItem() {
        StatusBar.get().onClick()
    }

    @IBAction func refresh(_ sender: AnyObject) {
        StatusItemRefreshAction.perform(refresh: refreshStatusData)
    }

    @objc(refresh) func refreshFromStatusItem() {
        StatusItemRefreshAction.perform(refresh: refreshStatusData)
    }
    
    @objc func refreshStatusData() {
        LoadMonitoringData().refreshStatusData()
    }
    
    func showPasswordPrompt() {
        if self.passwordWindow == nil {
            self.passwordWindow = PasswordPromptController(windowNibName: "PasswordPrompt")
            self.passwordWindow!.refreshStatusData = { [weak self] in
                self?.refreshStatusData()
            }
        }
        self.passwordWindow!.showWindow(self)
    }

    private func currentPreferencesWindow() -> PreferencesWindowController {
        if let preferencesWindow = preferencesWindow {
            return preferencesWindow
        }

        let preferencesWindow = PreferencesWindowController(windowNibName: "PreferencesWindow")
        preferencesWindow.monitoringInstancesWindowFactory = {
            MonitoringInstancesWindowController(windowNibName: "MonitoringInstancesWindow")
        }
        self.preferencesWindow = preferencesWindow
        return preferencesWindow
    }
}
