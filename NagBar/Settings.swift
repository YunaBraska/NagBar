//
//  Settings.swift
//  NagBar
//
//  Created by Volen Davidov on 18.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Foundation

enum SettingDefaults {
    static let values = [
        "refreshInterval": "30",
        "monitoringInstance": "1",
        "status": "1",
        "lastCheck": "1",
        "duration": "1",
        "attempt": "1",
        "statusInformation": "1",
        "critical": "1",
        "warning": "1",
        "unknown": "1",
        "pending": "1",
        "down": "1",
        "unreachable": "1",
        "hostPending": "1",
        "sortColumn": "1",
        "sortOrder": "1",
        "statusInformationLength": "200",
        "ok": "0",
        "up": "0",
        "scheduledDowntime": "0",
        "acknowledged": "0",
        "flapping": "0",
        "checksDisabled": "0",
        "disabledNotifications": "0",
        "softState": "0",
        "skipServicesOfHostsWithScD": "0",
        "hostScheduledDowntime": "0",
        "hostAcknowledged": "0",
        "hostFlapping": "0",
        "hostDisabledNotifications": "0",
        "hostSoftState": "0",
        "hostChecksDisabled": "0",
        "showExtendedStatusInformation": "1",
        "flashStatusBar": "1",
        "flashStatusBarType": "2",
        "savePassword": "1",
        "acceptInvalidCertificates": "0",
        "enableAudibleAlarms": "1",
        "enableAudibleAlarmsCritical": "1",
        "enableAudibleAlarmsWarning": "1",
        "enableAudibleAlarmsDown": "1",
        "enableAudibleAlarmsUnreachable": "1",
        "enableAudibleAlarmsRecovery": "1",
        "audibleAlarmsCriticalSoundFile": "",
        "audibleAlarmsWarningSoundFile": "",
        "audibleAlarmsDownSoundFile": "",
        "audibleAlarmsUnreachableSoundFile": "",
        "audibleAlarmsRecoverySoundFile": "",
        "showDockIcon": "1",
        "useNotifications": "0",
        "newVersionCheck": "1",
        "newVersionLastCheck": "0",
        "availableReleaseVersion": "",
        "availableReleaseURL": "",
        "availableReleaseNotes": "",
        "acknowledgementDefaultComment": "",
        "scheduleDowntimeDefaultComment": "",
        "criticalColor": "1.0,0.804,0.804,1.0",
        "warningColor": "1.0,1.0,0.745,1.0",
        "unknownColor": "1.0,0.921,0.616,1.0",
        "pendingColor": "0.921,0.921,0.921,1.0",
        "downColor": "1.0,0.580,0.580,1.0",
        "unreachableColor": "1.0,0.886,0.384,1.0",
        "upColor": "0.588,0.886,0.502,1.0",
        "okColor": "0.588,0.886,0.502,1.0",
    ]
}

class Settings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        if let defaults = defaults {
            self.defaults = defaults
        } else if let suiteName = ProcessInfo.processInfo.environment["NAGBAR_USER_DEFAULTS_SUITE"],
                  let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = suiteDefaults
        } else {
            self.defaults = .standard
        }
    }
    
    func savePassword() -> Bool {
        return Settings().boolForKey("savePassword")
    }
    
    func doubleForKey(_ defaultName: String) -> Double {
        return Double(stringValue(forKey: defaultName)) ?? 0.0
    }
    
    func stringForKey(_ defaultName: String) -> String? {
        return stringValue(forKey: defaultName)
    }
    
    func valueForKey(_ key: String) -> Any? {
        return stringValue(forKey: key)
    }
    
    func boolForKey(_ defaultName: String) -> Bool {
        let resultMap = ["0": false, "1": true]
        
        return resultMap[stringValue(forKey: defaultName)] ?? false
    }
    
    func integerForKey(_ defaultName: String) -> Int {
        return Int(stringValue(forKey: defaultName)) ?? 0
    }
    
    func setBool(_ value: Bool, forKey: String) {
        let resultMap = [false: "0", true: "1"]
        
        defaults.set(resultMap[value] ?? "0", forKey: forKey)
    }
    
    func setInteger(_ value: Int, forKey: String) {
        defaults.set(String(value), forKey: forKey)
    }
    
    func setString(_ value: String, forKey: String) {
        defaults.set(value, forKey: forKey)
    }

    func seedMissingDefaults() {
        for (key, value) in SettingDefaults.values where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    func resetKnownSettings() {
        for key in SettingDefaults.values.keys {
            defaults.removeObject(forKey: key)
        }
    }

    func hasStoredValue(forKey key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }

    private func stringValue(forKey key: String) -> String {
        return defaults.string(forKey: key) ?? SettingDefaults.values[key] ?? ""
    }
}

class PasswordStore {
    static let sharedInstance = PasswordStore()
    private var passwordData: Dictionary<String, String> = [:]
    
    func getAll() -> Dictionary<String, String> {
        return self.passwordData
    }
    
    func get(_ account: String) -> String? {
        return self.passwordData[account]
    }
    
    func set(_ account: String, password: String) {
        self.passwordData[account] = password
    }

    func removeAll() {
        self.passwordData.removeAll()
    }
}
