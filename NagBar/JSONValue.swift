//
//  JSONValue.swift
//  NagBar
//
//  Created by Volen Davidov on 30.06.26.
//  Copyright © 2026 Volen Davidov. All rights reserved.
//

import Foundation

struct JSONValue {
    private let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(data: Data) throws {
        self.value = try JSONSerialization.jsonObject(with: data)
    }

    subscript(key: String) -> JSONValue {
        guard let dictionary = value as? [String: Any] else {
            return JSONValue(nil)
        }

        return JSONValue(dictionary[key])
    }

    subscript(index: Int) -> JSONValue {
        guard let array = value as? [Any], array.indices.contains(index) else {
            return JSONValue(nil)
        }

        return JSONValue(array[index])
    }

    var array: [JSONValue]? {
        guard let array = value as? [Any] else {
            return nil
        }

        return array.map(JSONValue.init)
    }

    var string: String? {
        return value as? String
    }

    var int: Int? {
        if let int = value as? Int {
            return int
        }

        if let double = value as? Double {
            return Int(double)
        }

        return nil
    }

    var float: Float? {
        if let float = value as? Float {
            return float
        }

        if let double = value as? Double {
            return Float(double)
        }

        if let int = value as? Int {
            return Float(int)
        }

        return nil
    }

    var double: Double? {
        if let double = value as? Double {
            return double
        }

        if let int = value as? Int {
            return Double(int)
        }

        return nil
    }

    var boolValue: Bool {
        if let bool = value as? Bool {
            return bool
        }

        if let int = value as? Int {
            return int != 0
        }

        if let double = value as? Double {
            return double != 0
        }

        return false
    }
}
