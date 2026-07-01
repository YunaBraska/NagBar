//
//  ScheduleDowntimeWindow.swift
//  NagBar
//
//  Created by Volen Davidov on 07.08.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class ScheduleDowntimeWindow : NSWindowController {
    
    @IBOutlet weak private var comment: NSTextField!
    @IBOutlet weak private var startTime: NSTextField!
    @IBOutlet weak private var endTime: NSTextField!
    @IBOutlet weak private var hours: NSTextField!
    @IBOutlet weak private var minutes: NSTextField!
    @IBOutlet weak private var type: NSPopUpButton!
    
    var monitoringItems: Array<MonitoringItem> = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        hours.isEnabled = false
        minutes.isEnabled = false
        
        if let monitoringInstance = self.monitoringItems.first?.monitoringInstance {
            let time = monitoringInstance.monitoringProcessor().command().getTime(self.monitoringItems)

            time.done { (arg) -> Void in
                let (startTime, endTime) = arg
                DispatchQueue.main.async {
                    self.startTime.stringValue = startTime
                    self.endTime.stringValue = endTime
                }
            }.catch { _ in
                
            }
        }
        
        let hourFormatter = HourNumberFormatter()
        hours.formatter = hourFormatter
        let minuteFormatter = MinuteNumberFormatter()
        minutes.formatter = minuteFormatter

        self.comment.stringValue = Settings().stringForKey("scheduleDowntimeDefaultComment") ?? ""
        applyAccessibilityMetadata()
    }

    func applyAccessibilityMetadata() {
        window?.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeWindowIdentifier)
        window?.setAccessibilityLabel("Schedule monitoring downtime")
        comment.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeCommentIdentifier)
        comment.setAccessibilityLabel("Downtime comment")
        startTime.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeStartTimeIdentifier)
        startTime.setAccessibilityLabel("Downtime start time")
        endTime.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeEndTimeIdentifier)
        endTime.setAccessibilityLabel("Downtime end time")
        type.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeTypeIdentifier)
        type.setAccessibilityLabel("Downtime type")
        hours.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeHoursIdentifier)
        hours.setAccessibilityLabel("Flexible downtime hours")
        minutes.setAccessibilityIdentifier(CommandWindowAccessibility.scheduleDowntimeMinutesIdentifier)
        minutes.setAccessibilityLabel("Flexible downtime minutes")
        applyButtonAccessibility(in: window?.contentView, identifier: "ok", accessibilityIdentifier: CommandWindowAccessibility.scheduleDowntimeOKIdentifier, label: "Submit downtime")
        applyButtonAccessibility(in: window?.contentView, identifier: "cancel", accessibilityIdentifier: CommandWindowAccessibility.scheduleDowntimeCancelIdentifier, label: "Cancel downtime")
    }
    
    @IBAction func buttonClicked(_ sender: NSButton) {
        
        if self.comment.stringValue == "" {
            NSSound.beep()
            return
        }
        
        guard let selectedType = self.type.selectedItem,
              let monitoringInstance = self.monitoringItems.first?.monitoringInstance else {
            return
        }

        let typeString = String(selectedType.tag)
        
        let promise = monitoringInstance.monitoringProcessor().command().scheduleDowntime(self.monitoringItems, from: self.startTime.stringValue, to: self.endTime.stringValue, comment: self.comment.stringValue, type: typeString, hours: self.hours.stringValue, minutes: self.minutes.stringValue)
        CommandFeedback.shared.observe(.scheduleDowntime, promise: promise)

        self.close()
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        self.close()
    }
    
    @IBAction func popupButtonClicked(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 1 {
            hours.isEnabled = true
            minutes.isEnabled = true
            hours.stringValue = "2"
            minutes.stringValue = "0"
        } else {
            hours.isEnabled = false
            minutes.isEnabled = false
            hours.stringValue = ""
            minutes.stringValue = ""
        }
    }
}

class HourNumberFormatter : NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        
        if partialString.count == 0 {
            return true
        }
        
        if partialString.count > 2 {
            NSSound.beep()
            return false
        }
        
        if let hourEntered = Int(partialString) {
            if hourEntered < 0 {
                NSSound.beep()
                return false
            }
        } else {
            NSSound.beep()
            return false
        }
        
        return true
    }
}

class MinuteNumberFormatter : NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        
        if partialString.count == 0 {
            return true
        }
        
        if partialString.count > 3 {
            NSSound.beep()
            return false
        }
        
        if let minutesEntered = Int(partialString) {
            if minutesEntered < 0 || minutesEntered > 59 {
                NSSound.beep()
                return false
            }
        } else {
            NSSound.beep()
            return false
        }
        
        return true
    }
}
