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
        NSApp.activate(ignoringOtherApps: true)
        let preferencesWindow = currentPreferencesWindow()
        preferencesWindow.showWindow(self)
    }

    @IBAction func openAbout(_ sender: AnyObject) {
        NSApp.activate(ignoringOtherApps: true)
        let preferencesWindow = currentPreferencesWindow()
        preferencesWindow.showWindow(self)
        preferencesWindow.selectAboutTab()
    }
    
    @objc func refreshStatusData() {
        LoadMonitoringData().refreshStatusData()
    }
    
    func showPasswordPrompt() {
        if self.passwordWindow == nil {
            self.passwordWindow = PasswordPromptController(windowNibName: "PasswordPrompt")
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
