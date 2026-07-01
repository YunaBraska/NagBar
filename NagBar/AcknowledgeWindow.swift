//
//  AcknowledgeWindow.swift
//  NagBar
//
//  Created by Volen Davidov on 31.08.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class AcknowledgeWindow: NSWindowController {

    @IBOutlet weak private var comment: NSTextField!
    
    var monitoringItems: Array<MonitoringItem> = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.comment.stringValue = Settings().stringForKey("acknowledgementDefaultComment") ?? ""
        applyAccessibilityMetadata()
    }

    func applyAccessibilityMetadata() {
        window?.setAccessibilityIdentifier(CommandWindowAccessibility.acknowledgeWindowIdentifier)
        window?.setAccessibilityLabel("Acknowledge monitoring problem")
        comment.setAccessibilityIdentifier(CommandWindowAccessibility.acknowledgeCommentIdentifier)
        comment.setAccessibilityLabel("Acknowledgement comment")
        applyButtonAccessibility(in: window?.contentView, identifier: "ok", accessibilityIdentifier: CommandWindowAccessibility.acknowledgeOKIdentifier, label: "Submit acknowledgement")
        applyButtonAccessibility(in: window?.contentView, identifier: "cancel", accessibilityIdentifier: CommandWindowAccessibility.acknowledgeCancelIdentifier, label: "Cancel acknowledgement")
    }
    
    @IBAction func buttonClicked(_ sender: NSButton) {
        if self.comment.stringValue == "" {
            NSSound.beep()
            return
        }
        
        guard let monitoringInstance = self.monitoringItems.first?.monitoringInstance else {
            return
        }
        
        let promise = monitoringInstance.monitoringProcessor().command().acknowledge(self.monitoringItems, comment: self.comment.stringValue)
        CommandFeedback.shared.observe(.acknowledge, promise: promise)

        self.close()
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        self.close()
    }
}
