//
//  ServerLogin.swift
//  NagBar
//
//  Created by Volen Davidov on 12.11.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

enum LoginType : Int {
    case ssh = 0
    case sshiTerm = 1
    case rdp = 2
}

@objc class ServerLogin : NSObject {

    static var storageURLOverride: URL?
    private static let storageLock = NSLock()

    private var storageURL: URL {
        if let storageURLOverride = ServerLogin.storageURLOverride {
            return storageURLOverride
        }

        let applicationSupport = NagBarStorage.applicationSupportDirectory()
        return applicationSupport
            .appendingPathComponent("com.volendavidov.NagBar", isDirectory: true)
            .appendingPathComponent("server-login.json", isDirectory: false)
    }
    
    @objc
    func sshLogin(_ sender: NSMenuItem) {
        let monitoringItem = sender.representedObject as! MonitoringItem
        let loginMethod = SSHLogin()
        if self.getLoginType(monitoringItem) == nil {
            self.setLoginType(monitoringItem, loginType: .ssh)
        }
        
        self.login(monitoringItem, loginMethod: loginMethod)
    }
    
    @objc
    func sshITermLogin(_ sender: NSMenuItem) {
        let monitoringItem = sender.representedObject as! MonitoringItem
        let loginMethod = SSHITermLogin()
        if self.getLoginType(monitoringItem) == nil {
            self.setLoginType(monitoringItem, loginType: .sshiTerm)
        }
        
        self.login(monitoringItem, loginMethod: loginMethod)
    }
    
    @objc
    func rdpLogin(_ sender: NSMenuItem) {
        let monitoringItem = sender.representedObject as! MonitoringItem
        let loginMethod = RDPLogin()
        if self.getLoginType(monitoringItem) == nil {
            self.setLoginType(monitoringItem, loginType: .rdp)
        }
        
        self.login(monitoringItem, loginMethod: loginMethod)
    }
    
    private func login(_ monitoringItem: MonitoringItem, loginMethod: ServerLoginMethod) {
        
        var username: String?
        if let settingsUsername = self.getUsername(monitoringItem) {
            username = settingsUsername
        } else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("enterUsername", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))
            
            let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputTextField.placeholderString = NSLocalizedString("username", comment: "")
            
            alert.accessoryView = inputTextField
            
            let button = alert.runModal()
            
            if button == NSApplication.ModalResponse.alertFirstButtonReturn {
                username = inputTextField.stringValue
                self.setUsername(monitoringItem, username: inputTextField.stringValue)
            }
        }
        
        if let username = username {
            loginMethod.login(monitoringItem.host, username: username)
        }
    }
    
    @objc func removeLoginSettings(_ sender: NSMenuItem) {
        
        let monitoringItem = sender.representedObject as! MonitoringItem

        removeLoginSettings(forHost: monitoringItem.host)
    }
    
    func getUsername(_ monitoringItem: MonitoringItem) -> String? {
        guard let serverLoginItem = loginItem(forHost: monitoringItem.host), serverLoginItem.username != "" else {
            return nil
        }

        return serverLoginItem.username
    }
    
    func getLoginType(_ monitoringItem: MonitoringItem) -> LoginType? {
        guard let serverLoginItem = loginItem(forHost: monitoringItem.host) else {
            return nil
        }

        return LoginType(rawValue: serverLoginItem.loginType)
    }
    
    func setLoginType(_ monitoringItem: MonitoringItem, loginType: LoginType) {
        let serverLoginItem = loginItem(forHost: monitoringItem.host) ?? ServerLoginItem(host: monitoringItem.host)
        serverLoginItem.loginType = loginType.rawValue
        saveLoginItem(serverLoginItem)
    }
    
    func setUsername(_ monitoringItem: MonitoringItem, username: String) {
        let serverLoginItem = loginItem(forHost: monitoringItem.host) ?? ServerLoginItem(host: monitoringItem.host)
        serverLoginItem.username = username
        saveLoginItem(serverLoginItem)
    }

    func importLegacyItems(_ legacyItems: [ServerLoginItem]) {
        withStorageLock {
            if !loadLoginItemsWithoutLock().isEmpty {
                return
            }

            saveLoginItemsWithoutLock(legacyItems)
        }
    }

    func resetStorage() {
        withStorageLock {
            try? FileManager.default.removeItem(at: storageURL)
        }
    }

    private func loginItem(forHost host: String) -> ServerLoginItem? {
        return withStorageLock {
            loadLoginItemsWithoutLock().last { $0.host == host }
        }
    }

    private func saveLoginItem(_ serverLoginItem: ServerLoginItem) {
        withStorageLock {
            var serverLoginItems = loadLoginItemsWithoutLock().filter { $0.host != serverLoginItem.host }
            serverLoginItems.append(serverLoginItem)
            saveLoginItemsWithoutLock(serverLoginItems)
        }
    }

    private func removeLoginSettings(forHost host: String) {
        withStorageLock {
            let serverLoginItems = loadLoginItemsWithoutLock().filter { $0.host != host }
            saveLoginItemsWithoutLock(serverLoginItems)
        }
    }

    private func loadLoginItemsWithoutLock() -> [ServerLoginItem] {
        guard let data = try? Data(contentsOf: storageURL) else {
            return []
        }

        return (try? JSONDecoder().decode([ServerLoginItem].self, from: data)) ?? []
    }

    private func saveLoginItemsWithoutLock(_ serverLoginItems: [ServerLoginItem]) {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(serverLoginItems)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("Could not save server login settings: \(error)")
        }
    }

    private func withStorageLock<T>(_ action: () -> T) -> T {
        ServerLogin.storageLock.lock()
        defer { ServerLogin.storageLock.unlock() }
        return action()
    }
}

class ServerLoginItem : Codable {
    var host = ""
    var username = ""
    var loginType = 0

    init(host: String = "", username: String = "", loginType: Int = 0) {
        self.host = host
        self.username = username
        self.loginType = loginType
    }
}

protocol ServerLoginMethod {
    func login(_ host: String, username: String)
}

class SSHLogin : ServerLoginMethod {
    func login(_ host: String, username: String) {
        // We could just use open ssh://hostname, but it will open a new window of Terminal
        let source = NSString(format: "tell application \"System Events\"\nset processlist to (name of processes)\nif processlist contains \"Terminal\" then\nactivate application \"Terminal\"\ntell application \"System Events\" to keystroke \"t\" using command down\ntell application \"System Events\" to keystroke \"ssh %@@%@\"\ntell application \"System Events\" to keystroke return\nelse\ntell application \"Terminal\"\nreopen\nactivate\ntell application \"System Events\" to keystroke \"ssh %@@%@\"\ntell application \"System Events\" to keystroke return\nend tell\nend if\nend tell", username, host, username, host);
        
        let script = NSAppleScript(source: source as String)
        
        var err: NSDictionary? = nil
        script!.executeAndReturnError(&err)
        
        if err != nil {
            NSLog(String(describing: err))
        }
    }
}

class SSHITermLogin : ServerLoginMethod {
    func login(_ host: String, username: String) {
        
        let source = NSString(format: "tell application \"System Events\"\nset processlist to (name of processes)\nif processlist contains \"iTerm\" then\nactivate application \"iTerm\"\ntell application \"System Events\" to keystroke \"t\" using command down\ntell application \"System Events\" to keystroke \"ssh %@@%@\"\ntell application \"System Events\" to keystroke return\nelse\ntell application \"iTerm\"\nreopen\nactivate\ntell application \"System Events\" to keystroke \"ssh %@@%@\"\ntell application \"System Events\" to keystroke return\nend tell\nend if\nend tell", username, host, username, host)
        
        let script = NSAppleScript(source: source as String)
        
        var err: NSDictionary? = nil
        script!.executeAndReturnError(&err)
        
        if err != nil {
            NSLog(String(describing: err))
        }
    }
}

class RDPLogin : ServerLoginMethod {
    func login(_ host: String, username: String) {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        
        let url = NSString(format: "rdp://full%%20address=s:%@&username=s:%@", host, username)
        task.arguments = [url as String]
        
        task.launch()
    }
}
