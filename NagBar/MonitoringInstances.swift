//
//  MonitoringInstances.swift
//  NagBar
//
//  Created by Volen Davidov on 31.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class MonitoringInstances {

    static var storageURLOverride: URL?
    private static let storageLock = NSLock()

    private var storageURL: URL {
        if let storageURLOverride = MonitoringInstances.storageURLOverride {
            return storageURLOverride
        }

        let applicationSupport = NagBarStorage.applicationSupportDirectory()
        return applicationSupport
            .appendingPathComponent("com.volendavidov.NagBar", isDirectory: true)
            .appendingPathComponent("monitoring-instances.json", isDirectory: false)
    }
    
    func getAll() -> MIDictionary {
        var monitoringInstances: MIDictionary = [:]
        for monitoringInstance in loadItems().filter({ $0.hasSupportedType }) {
            monitoringInstance.password = self.getPassword(monitoringInstance.name)
            monitoringInstances[monitoringInstance.name] = monitoringInstance
        }
        return monitoringInstances
    }
    
    func getAllEnabled() -> MIDictionary {
        let items = loadItems().filter { $0.hasSupportedType }
        if !items.contains(where: { $0.isConfiguredRemote }) {
            let fallback = LocalIcingaFallback.instance()
            return [fallback.name: fallback]
        }

        var monitoringInstances: MIDictionary = [:]
        for monitoringInstance in items.filter({ $0.enabled == 1 && $0.isConfiguredRemote }) {
            monitoringInstance.password = self.getPassword(monitoringInstance.name)
            monitoringInstances[monitoringInstance.name] = monitoringInstance
        }
        return monitoringInstances
    }
    
    func getByKey(_ key: String) -> MonitoringInstance? {
        return getAll()[key]
    }

    func hasEnabledConfiguredInstances() -> Bool {
        return loadItems().contains { $0.enabled == 1 && $0.isConfiguredRemote }
    }
    
    func getKeyById(_ id: Int) -> String {
        return getAll().keys.sorted(){$0.lowercased() < $1.lowercased()}[id]
    }
    
    func getById(_ id: Int) -> MonitoringInstance {
        let key = self.getKeyById(id)
        let result = getAll()[key]
        
        result!.password = getPassword(key)

        return result!
    }
    
    func count() -> Int {
        return getAll().count
    }
    
    func updateName(monitoringInstance: MonitoringInstance, name: String) {
        let originalName = monitoringInstance.name
        withStorageLock {
            let monitoringInstances = loadItemsWithoutLock()
            if let index = monitoringInstances.lastIndex(where: { $0.name == originalName }) {
                monitoringInstances[index].name = name
                saveItemsWithoutLock(monitoringInstances)
            }
        }
        monitoringInstance.name = name
    }
    
    @discardableResult
    func updateUrl(monitoringInstance: MonitoringInstance, url: String) -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty && monitoringInstance.enabled == 1 {
            return false
        }

        if !trimmedURL.isEmpty && !MonitoringInstance.validateURL(trimmedURL).isValid {
            return false
        }

        update(monitoringInstance: monitoringInstance) { stored in
            stored.url = trimmedURL
        }
        monitoringInstance.url = trimmedURL
        return true
    }
    
    func updateType(monitoringInstance: MonitoringInstance, type: MonitoringInstanceType) {
        update(monitoringInstance: monitoringInstance) { stored in
            stored.type = type
        }
        monitoringInstance.type = type
    }
    
    @discardableResult
    func updateEnabled(monitoringInstance: MonitoringInstance, enabled: Int) -> Bool {
        if enabled == 1 && !monitoringInstance.canBeEnabled {
            return false
        }

        update(monitoringInstance: monitoringInstance) { stored in
            stored.enabled = enabled
        }
        monitoringInstance.enabled = enabled
        return true
    }
    
    func updateUsername(monitoringInstance: MonitoringInstance, username: String) {
        update(monitoringInstance: monitoringInstance) { stored in
            stored.username = username
        }
        monitoringInstance.username = username
    }
    
    func updatePassword(monitoringInstance: MonitoringInstance, password: String) {
        // update the password in the cache and in the keychain
        PasswordStore.sharedInstance.set(monitoringInstance.name, password: password)
        if Settings().boolForKey("savePassword") {
            KeychainAccess().get().setPassword(password, forService: "NagBar", account: monitoringInstance.name)
        } else {
            KeychainAccess().get().deletePassword(forService: "NagBar", account: monitoringInstance.name)
        }
    }
    
    private func getPassword(_ account: String) -> String {
        
        // get the password from the cache to avoid multiple calls to the keychain
        // NOTE: if the save password option is disabled, the password is set in the
        // cache during startup
        if let password = PasswordStore.sharedInstance.get(account) {
            return password
        }
        
        // continue only if the save password option is enabled
        if !Settings().boolForKey("savePassword") {
            return ""
        }
        
        if let password = KeychainAccess().get().password(forService: "NagBar", account: account) {
            PasswordStore.sharedInstance.set(account, password: password)
            return password
        } else {
            return ""
        }
    }
    
    func removeById(_ id: Int) {
        let key = getKeyById(id)
        self.deletePassword(key)
        
        withStorageLock {
            var monitoringInstances = loadItemsWithoutLock()
            if let index = monitoringInstances.lastIndex(where: { $0.name == key }) {
                monitoringInstances.remove(at: index)
                saveItemsWithoutLock(monitoringInstances)
            }
        }
    }
    
    func insert(key: String, value: MonitoringInstance) {
        withStorageLock {
            var monitoringInstances = loadItemsWithoutLock()
            monitoringInstances.append(value)
            saveItemsWithoutLock(monitoringInstances)
        }
    }

    func importLegacyItems(_ legacyItems: [MonitoringInstance]) {
        withStorageLock {
            if !loadItemsWithoutLock().isEmpty {
                return
            }

            saveItemsWithoutLock(legacyItems)
        }
    }

    func resetStorage() {
        withStorageLock {
            try? FileManager.default.removeItem(at: storageURL)
        }
    }
    
    private func deletePassword(_ account: String) {
        KeychainAccess().get().deletePassword(forService: "NagBar", account: account)
    }

    private func update(monitoringInstance: MonitoringInstance, apply: (MonitoringInstance) -> Void) {
        withStorageLock {
            let monitoringInstances = loadItemsWithoutLock()
            if let index = monitoringInstances.lastIndex(where: { $0.name == monitoringInstance.name }) {
                apply(monitoringInstances[index])
                saveItemsWithoutLock(monitoringInstances)
            }
        }
    }

    private func loadItems() -> [MonitoringInstance] {
        return withStorageLock {
            loadItemsWithoutLock()
        }
    }

    private func loadItemsWithoutLock() -> [MonitoringInstance] {
        guard let data = try? Data(contentsOf: storageURL) else {
            return []
        }

        return (try? JSONDecoder().decode([MonitoringInstance].self, from: data)) ?? []
    }

    private func saveItemsWithoutLock(_ monitoringInstances: [MonitoringInstance]) {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(monitoringInstances)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NagBarDiagnostics.logStorageError("monitoringInstancesSaveFailed", error: error)
        }
    }

    private func withStorageLock<T>(_ action: () -> T) -> T {
        MonitoringInstances.storageLock.lock()
        defer { MonitoringInstances.storageLock.unlock() }
        return action()
    }
}
