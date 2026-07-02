//
//  Settings.swift
//  NagBar
//
//  Created by Volen Davidov on 18.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Foundation

enum SettingDefaults {
    static let values: [String: Any] = [
        "refreshInterval": 30,
        "monitoringInstance": true,
        "status": true,
        "lastCheck": true,
        "duration": true,
        "attempt": true,
        "statusInformation": true,
        "critical": true,
        "warning": true,
        "unknown": true,
        "pending": true,
        "down": true,
        "unreachable": true,
        "hostPending": true,
        "sortColumn": 1,
        "sortOrder": 1,
        "statusInformationLength": 200,
        "ok": false,
        "up": false,
        "scheduledDowntime": false,
        "acknowledged": false,
        "flapping": false,
        "checksDisabled": false,
        "disabledNotifications": false,
        "softState": false,
        "skipServicesOfHostsWithScD": false,
        "hostScheduledDowntime": false,
        "hostAcknowledged": false,
        "hostFlapping": false,
        "hostDisabledNotifications": false,
        "hostSoftState": false,
        "hostChecksDisabled": false,
        "showExtendedStatusInformation": true,
        "flashStatusBar": true,
        "flashStatusBarType": 2,
        "savePassword": true,
        "acceptInvalidCertificates": false,
        "enableAudibleAlarms": true,
        "enableAudibleAlarmsCritical": true,
        "enableAudibleAlarmsWarning": true,
        "enableAudibleAlarmsDown": true,
        "enableAudibleAlarmsUnreachable": true,
        "enableAudibleAlarmsRecovery": true,
        "audibleAlarmsCriticalSoundFile": "",
        "audibleAlarmsWarningSoundFile": "",
        "audibleAlarmsDownSoundFile": "",
        "audibleAlarmsUnreachableSoundFile": "",
        "audibleAlarmsRecoverySoundFile": "",
        "showDockIcon": true,
        "useNotifications": false,
        "newVersionCheck": true,
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
        if let number = defaults.object(forKey: defaultName) as? NSNumber {
            return number.doubleValue
        }
        return Double(stringValue(forKey: defaultName)) ?? 0.0
    }
    
    func stringForKey(_ defaultName: String) -> String? {
        return stringValue(forKey: defaultName)
    }
    
    func boolForKey(_ defaultName: String) -> Bool {
        if let bool = defaults.object(forKey: defaultName) as? Bool {
            return bool
        }
        if let number = defaults.object(forKey: defaultName) as? NSNumber {
            return number.intValue != 0
        }
        return stringValue(forKey: defaultName).toBool() ?? false
    }
    
    func integerForKey(_ defaultName: String) -> Int {
        if let number = defaults.object(forKey: defaultName) as? NSNumber {
            return number.intValue
        }
        return Int(stringValue(forKey: defaultName)) ?? 0
    }
    
    func setBool(_ value: Bool, forKey: String) {
        defaults.set(value, forKey: forKey)
    }
    
    func setInteger(_ value: Int, forKey: String) {
        defaults.set(value, forKey: forKey)
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
        if let string = defaults.string(forKey: key) {
            return string
        }
        if let number = defaults.object(forKey: key) as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "1" : "0"
            }
            return number.stringValue
        }
        if let fallback = SettingDefaults.values[key] as? NSNumber {
            if CFGetTypeID(fallback) == CFBooleanGetTypeID() {
                return fallback.boolValue ? "1" : "0"
            }
            return fallback.stringValue
        }
        return SettingDefaults.values[key] as? String ?? ""
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
