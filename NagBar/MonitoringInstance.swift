//
//  MonitoringInstance.swift
//  NagBar
//
//  Created by Volen Davidov on 17.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Foundation

enum MonitoringInstanceURLValidationResult: Equatable {
    case valid
    case empty
    case invalid(String)

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .empty, .invalid:
            return false
        }
    }

    var title: String {
        return "Invalid monitoring URL"
    }

    var message: String {
        switch self {
        case .valid:
            return ""
        case .empty:
            return "Enter an http or https URL before enabling this monitoring instance."
        case .invalid(let value):
            return "Enter an absolute http or https URL with a host: \(value)"
        }
    }
}

enum MonitoringInstanceType: String {
    case Nagios = "Nagios"
    case Icinga = "Icinga"
    case Icinga2 = "Icinga2"
    case Thruk = "Thruk"
    case Check_MK = "Check_MK"
    
    static let allKeys = [Nagios, Icinga, Icinga2, Thruk, Check_MK]
    static let allValues = allKeys.map { $0.rawValue }
}

typealias MIDictionary = Dictionary<String, MonitoringInstance>

class MonitoringInstance : Codable, Hashable {
    
    var name: String = ""
    var url: String = ""
    private var privateType = MonitoringInstanceType.Nagios.rawValue
    var type: MonitoringInstanceType {
        get {
            return MonitoringInstanceType(rawValue: privateType) ?? .Nagios
        }
        set {
            privateType = newValue.rawValue
        }
    }
    var hasSupportedType: Bool {
        return MonitoringInstanceType(rawValue: privateType) != nil
    }
    var username: String = ""
    var password: String = ""
    var enabled: Int = 0
    var isConfiguredRemote: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hasSupportedType
            && MonitoringInstance.validateURL(url).isValid
    }
    var canBeEnabled: Bool {
        return hasSupportedType && MonitoringInstance.validateURL(url).isValid
    }

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case privateType
        case username
        case enabled
    }
    
    func initDefault(name: String, url: String, type: MonitoringInstanceType, username: String, password: String, enabled: Int) -> MonitoringInstance {
        self.name = name
        self.url = url
        self.type = type
        self.username = username
        self.password = password
        self.enabled = enabled
        
        return self
    }
    
    func monitoringProcessor() -> MonitoringProcessor {
        switch self.type {
        case .Nagios:
            return NagiosProcessor(self)
        case .Icinga:
            return IcingaProcessor(self)
        case .Icinga2:
            return Icinga2Processor(self)
        case .Thruk:
            return ThrukProcessor(self)
        case .Check_MK:
            return CheckMKProcessor(self)
        }
    }

    static func validateURL(_ value: String) -> MonitoringInstanceURLValidationResult {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            return .empty
        }

        guard let components = URLComponents(string: trimmedValue),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              components.query == nil,
              components.fragment == nil else {
            return .invalid(value)
        }

        return .valid
    }

    static func == (lhs: MonitoringInstance, rhs: MonitoringInstance) -> Bool {
        return lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
