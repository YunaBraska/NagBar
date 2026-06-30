//
//  PasswordPromptController.swift
//  NagBar
//
//  Created by Volen Davidov on 02.05.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

class PasswordPromptController : NSWindowController {
    
    @IBOutlet weak fileprivate var okButton: NSButton!
    @IBOutlet weak fileprivate var passwordField: NSSecureTextField!
    @IBOutlet weak fileprivate var progressIndicator: NSProgressIndicator!
    @IBOutlet weak fileprivate var textField: NSTextField!

    private var currentMonitoringInstance: MonitoringInstance?

    var enabledInstancesProvider: () -> Dictionary<String, MonitoringInstance> = {
        return MonitoringInstances().getAllEnabled()
    }
    var requestConnection: (MonitoringInstance, String, @escaping (Result<HTTPResponse, Error>) -> Void) -> Void = { monitoringInstance, password, completion in
        ConnectionManager.sharedInstance.request(monitoringInstance.url, method: "HEAD", username: monitoringInstance.username, password: password, validateStatus: true, completion: completion)
    }
    var storePassword: (String, String) -> Void = { name, password in
        PasswordStore.sharedInstance.set(name, password: password)
    }
    var refreshStatusData: () -> Void = {}
    var retryAfterFailure: (NSError) -> Bool = { error in
        let informativeText = String(format:NSLocalizedString("skipMonitoringInstance", comment: ""), PasswordPromptFlow.errorText(forCode: error.code))
        let alert = NSAlert()
        alert.addButton(withTitle: NSLocalizedString("no", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("yes", comment: ""))
        alert.messageText = NSLocalizedString("connectionFailed", comment: "")
        alert.informativeText = informativeText
        alert.alertStyle = .warning

        return alert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn
    }
    
    override func awakeFromNib() {
        if self.nextMonitoringInstance() {
            self.textField.stringValue = PasswordPromptFlow.promptMessage(for: self.currentMonitoringInstance!)
        } else {
            self.textField.stringValue = PasswordPromptFlow.emptyPromptMessage()
            self.okButton.isEnabled = false
        }
    }
    
    /**
     * Set the next monitoring instance. Return false if there is no next monitoring instance.
     */
    private func nextMonitoringInstance() -> Bool {
        
        guard let monitoringInstance = PasswordPromptFlow.next(currentName: self.currentMonitoringInstance?.name, enabledInstances: self.enabledInstancesProvider()) else {
            return false
        }

        self.currentMonitoringInstance = monitoringInstance
        return true
    }
    
    private func startChecking() {
        self.okButton.isEnabled = false
        self.progressIndicator.startAnimation(nil)
    }
    
    private func stopChecking() {
        self.okButton.isEnabled = true
        self.progressIndicator.stopAnimation(nil)
    }
    
    @IBAction func checkConnection(_ sender: NSButton) {
        guard let currentMonitoringInstance = self.currentMonitoringInstance else {
            return
        }

        // disable the button and start the progress indicator
        self.startChecking()
        
        // make the request
        self.requestConnection(currentMonitoringInstance, self.passwordField.stringValue) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self.stopChecking()
                    self.retryModal(error as NSError)
                } else {
                    // on success - set the password for the course of the app's life
                    self.storePassword(self.currentMonitoringInstance!.name, self.passwordField.stringValue)

                    // if the passwords for all monitoring instances are set, and there is no next one
                    // then close the window and refresh
                    if !self.nextMonitoringInstance() {
                        self.window!.close()
                        self.refreshStatusData()
                    } else {
                        self.stopChecking()
                        self.textField.stringValue = PasswordPromptFlow.promptMessage(for: self.currentMonitoringInstance!)
                    }
                }
            }
        }
    }
    
    private func retryModal(_ error: NSError) {
        if self.retryAfterFailure(error) {
            if self.nextMonitoringInstance() {
                self.textField.stringValue = PasswordPromptFlow.promptMessage(for: self.currentMonitoringInstance!)
            } else {
                self.window!.close()
            }
        }
    }
    
}
