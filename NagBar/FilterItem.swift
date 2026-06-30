
//  FilterItem.swift
//  NagBar
//
//  Created by Volen Davidov on 14.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

enum FilterItemValidationResult: Equatable {
    case valid
    case empty
    case invalidHostPattern(String)
    case invalidServicePattern(String)

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .empty, .invalidHostPattern, .invalidServicePattern:
            return false
        }
    }

    var title: String {
        return "Invalid filter"
    }

    var message: String {
        switch self {
        case .valid:
            return ""
        case .empty:
            return "Enter at least a host pattern or a service pattern."
        case .invalidHostPattern(let pattern):
            return "The host pattern is not a valid regular expression: \(pattern)"
        case .invalidServicePattern(let pattern):
            return "The service pattern is not a valid regular expression: \(pattern)"
        }
    }
}

class FilterItem: Codable {
    var host: String = ""
    var service: String = ""
    var status: Int = 0
    
    init() {
    }

    func initDefault(host: String, service: String, status: Int) -> FilterItem {
        self.host = host
        self.service = service
        self.status = status
        
        return self
    }

    static func validate(host: String, service: String) -> FilterItemValidationResult {
        if host.isEmpty && service.isEmpty {
            return .empty
        }

        if !host.isEmpty && !isValidRegularExpression(host) {
            return .invalidHostPattern(host)
        }

        if !service.isEmpty && !isValidRegularExpression(service) {
            return .invalidServicePattern(service)
        }

        return .valid
    }

    private static func isValidRegularExpression(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return true
        } catch {
            return false
        }
    }
}
