//
//  InitConfig.swift
//  NagBar
//
//  Created by Volen Davidov on 10.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation

class InitConfig {
    
    func initConfig() {
        let settings = Settings()

        settings.seedMissingDefaults()

        if settings.integerForKey("flashStatusBarType") == 1 {
            settings.setInteger(2, forKey: "flashStatusBarType")
        }
    }
}
