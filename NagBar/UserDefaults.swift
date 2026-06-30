//
//  UserDefaults.swift
//  NagBar
//
//  Created by Volen Davidov on 18.10.15.
//  Copyright (c) 2015 Volen Davidov. All rights reserved.
//

import Foundation
import Security

class ExternalServiceProvider {
    func isTestEnvironment() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        let isTestEnvironment = environment["TESTS_RUNNING"]
        
        if isTestEnvironment == "YES" {
            return true
        } else {
            return false
        }
    }
}

protocol KeychainClient {
    func password(forService service: String, account: String) -> String?
    @discardableResult func setPassword(_ password: String, forService service: String, account: String) -> Bool
    @discardableResult func deletePassword(forService service: String, account: String) -> Bool
}

final class InMemoryKeychainClient: KeychainClient {
    private var passwords: [String: String] = [:]

    func password(forService service: String, account: String) -> String? {
        return passwords[key(service: service, account: account)]
    }

    @discardableResult func setPassword(_ password: String, forService service: String, account: String) -> Bool {
        passwords[key(service: service, account: account)] = password
        return true
    }

    @discardableResult func deletePassword(forService service: String, account: String) -> Bool {
        passwords.removeValue(forKey: key(service: service, account: account))
        return true
    }

    func removeAll() {
        passwords.removeAll()
    }

    private func key(service: String, account: String) -> String {
        return "\(service):\(account)"
    }
}

final class SecurityKeychainClient: KeychainClient {
    func password(forService service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    @discardableResult func setPassword(_ password: String, forService service: String, account: String) -> Bool {
        deletePassword(forService: service, account: account)

        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = Data(password.utf8)

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult func deletePassword(forService service: String, account: String) -> Bool {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

class KeychainAccess : ExternalServiceProvider {
    private static let testClient = InMemoryKeychainClient()
    private static let securityClient = SecurityKeychainClient()

    func get() -> KeychainClient {
        if self.isTestEnvironment() {
            return KeychainAccess.testClient
        } else {
            return KeychainAccess.securityClient
        }
    }
}
