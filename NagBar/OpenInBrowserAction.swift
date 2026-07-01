//
//  OpenInBrowserAction.swift
//  NagBar
//
//  Created by Volen Davidov on 24.07.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class OpenInBrowserAction: NSObject, MenuAction {
    static var openURL: (URL) -> Void = { url in
        _ = NSWorkspace.shared.open(url)
    }
    
    func action(_ sender: NSMenuItem) {
        guard let monitoringItems = sender.representedObject as? Array<MonitoringItem>,
              let monitoringItem = monitoringItems.first else {
            return
        }

        var url = URL(string: monitoringItem.itemUrl)
        
        // the above sometimes fails with Thruk
        if url == nil {
            url = monitoringItem.itemUrl
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
                .flatMap { URL(string: $0) }
        }
        
        guard let parsedURL = url else {
            NSLog("Error parsing url with string " + monitoringItem.itemUrl)
            return
        }
        
        OpenInBrowserAction.openURL(parsedURL)
    }
}
