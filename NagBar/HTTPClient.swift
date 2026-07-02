//
//  HTTPClient.swift
//  NagBar
//
//  Created by Volen Davidov on 02.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

protocol HTTPClient {
    func get(_ url: String) async throws -> Data
    func checkConnection() async -> Bool
    func post(_ url: String, postData: Dictionary<String, String>) async throws -> Data
}
