//
//  AudibleAlarmsTabController.swift
//  NagBar
//
//  Created by Volen Davidov on 08.02.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers

class AudibleAlarmsTabController: NSWindowController {
    var soundFilePicker: () -> [URL] = {
        let fileSelectDialog = AudibleAlarmsTabController.soundFilePanel()

        if fileSelectDialog.runModal() == NSApplication.ModalResponse.OK {
            return fileSelectDialog.urls
        }

        return []
    }

    static func soundFilePanel() -> NSOpenPanel {
        let fileSelectDialog = NSOpenPanel()
        fileSelectDialog.canChooseFiles = true
        fileSelectDialog.canChooseDirectories = false
        fileSelectDialog.allowsMultipleSelection = false
        fileSelectDialog.allowedContentTypes = ["aiff", "wav", "mp3"].compactMap { UTType(filenameExtension: $0) }
        return fileSelectDialog
    }
    
    @IBOutlet weak var enableAudibleAlarms: NSButton!
    @IBOutlet weak var enableAudibleAlarmsCritical: NSButton!
    @IBOutlet weak var enableAudibleAlarmsWarning: NSButton!
    @IBOutlet weak var enableAudibleAlarmsDown: NSButton!
    @IBOutlet weak var enableAudibleAlarmsUnreachable: NSButton!
    @IBOutlet weak var enableAudibleAlarmsRecovery: NSButton!
    
    @IBOutlet weak var audibleAlarmsCriticalSoundFile: NSPopUpButton!
    @IBOutlet weak var audibleAlarmsWarningSoundFile: NSPopUpButton!
    @IBOutlet weak var audibleAlarmsDownSoundFile: NSPopUpButton!
    @IBOutlet weak var audibleAlarmsUnreachableSoundFile: NSPopUpButton!
    @IBOutlet weak var audibleAlarmsRecoverySoundFile: NSPopUpButton!
    
    func setPopupState(_ propertyName: String) {
        let popUpButton = self.value(forKey: propertyName) as! NSPopUpButton
        
        let filePath = Settings().valueForKey(propertyName) as! String
        
        if filePath == "" {
            popUpButton.selectItem(at: 0)
        } else {
            popUpButton.removeItem(at: 1)
            let fileStringArray = filePath.components(separatedBy: "/")
            popUpButton.insertItem(withTitle: fileStringArray.last!, at: 1)
            popUpButton.selectItem(at: 1)
        }
    }
    
    @IBAction func popupButtonFileSelector(_ sender: NSPopUpButton) {
        if sender.titleOfSelectedItem != "Default" {
            let files = soundFilePicker()
            if !files.isEmpty {
                sender.removeItem(at: 1)
                sender.insertItem(withTitle: files[0].lastPathComponent, at: 1)
                sender.selectItem(at: 1)

                Settings().setString(files[0].path, forKey: sender.identifier!.rawValue)
            }
        } else {
            sender.removeItem(at: 1)
            sender.insertItem(withTitle: "Custom", at: 1)
            Settings().setString("", forKey: sender.identifier!.rawValue)
        }
    }
}
