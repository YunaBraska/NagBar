//
//  CommandInterface.swift
//  NagBar
//
//  Created by Volen Davidov on 07.08.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Foundation
import Cocoa

struct CommandResult {
    let action: CommandAction
    let itemCount: Int
}

enum CommandAction: Equatable {
    case acknowledge
    case recheck
    case scheduleDowntime

    var displayName: String {
        switch self {
        case .acknowledge:
            return NSLocalizedString("acknowledge", comment: "")
        case .recheck:
            return NSLocalizedString("recheck", comment: "")
        case .scheduleDowntime:
            return NSLocalizedString("scheduleDowntime", comment: "")
        }
    }
}

protocol CommandFeedbackPresenting {
    func showSuccess(_ result: CommandResult)
    func showFailure(action: CommandAction, error: Error)
}

final class CommandFeedback {
    static let shared = CommandFeedback()

    var presenter: CommandFeedbackPresenting = AlertCommandFeedbackPresenter()

    private init() {
    }

    func observe(_ action: CommandAction, promise: Promise<CommandResult>) {
        promise.done { result in
            DispatchQueue.main.async {
                self.presenter.showSuccess(result)
            }
        }.catch { error in
            DispatchQueue.main.async {
                self.presenter.showFailure(action: action, error: error)
            }
        }
    }
}

final class AlertCommandFeedbackPresenter: CommandFeedbackPresenting {
    static var presentAlert: (NSAlert) -> Void = { alert in
        alert.runModal()
    }

    func showSuccess(_ result: CommandResult) {
        let alert = NSAlert()
        alert.messageText = "\(result.action.displayName) accepted"
        alert.informativeText = "\(result.itemCount) item(s) submitted to the monitoring backend."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        Self.presentAlert(alert)
    }

    func showFailure(action: CommandAction, error: Error) {
        let alert = NSAlert()
        alert.messageText = "\(action.displayName) failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        Self.presentAlert(alert)
    }
}

enum CommandWindowAccessibility {
    static let acknowledgeWindowIdentifier = "nagbar.command.acknowledge.window"
    static let acknowledgeCommentIdentifier = "nagbar.command.acknowledge.comment"
    static let acknowledgeOKIdentifier = "nagbar.command.acknowledge.ok"
    static let acknowledgeCancelIdentifier = "nagbar.command.acknowledge.cancel"

    static let scheduleDowntimeWindowIdentifier = "nagbar.command.scheduleDowntime.window"
    static let scheduleDowntimeCommentIdentifier = "nagbar.command.scheduleDowntime.comment"
    static let scheduleDowntimeStartTimeIdentifier = "nagbar.command.scheduleDowntime.startTime"
    static let scheduleDowntimeEndTimeIdentifier = "nagbar.command.scheduleDowntime.endTime"
    static let scheduleDowntimeTypeIdentifier = "nagbar.command.scheduleDowntime.type"
    static let scheduleDowntimeHoursIdentifier = "nagbar.command.scheduleDowntime.hours"
    static let scheduleDowntimeMinutesIdentifier = "nagbar.command.scheduleDowntime.minutes"
    static let scheduleDowntimeOKIdentifier = "nagbar.command.scheduleDowntime.ok"
    static let scheduleDowntimeCancelIdentifier = "nagbar.command.scheduleDowntime.cancel"
}

func applyButtonAccessibility(in view: NSView?, identifier: String, accessibilityIdentifier: String, label: String) {
    guard let view = view else {
        return
    }

    for subview in view.subviews {
        if let button = subview as? NSButton, button.identifier?.rawValue == identifier {
            button.setAccessibilityIdentifier(accessibilityIdentifier)
            button.setAccessibilityLabel(label)
        }

        applyButtonAccessibility(in: subview, identifier: identifier, accessibilityIdentifier: accessibilityIdentifier, label: label)
    }
}

protocol CommandInterface {
    func getTime(_ monitoringItems: Array<MonitoringItem>) -> Promise<(String,String)>
    @discardableResult func recheck(_ monitoringItems: Array<MonitoringItem>) -> Promise<CommandResult>
    @discardableResult func scheduleDowntime(_ monitoringItems: Array<MonitoringItem>, from: String, to: String, comment: String, type: String, hours: String, minutes: String) -> Promise<CommandResult>
    @discardableResult func acknowledge(_ monitoringItems: Array<MonitoringItem>, comment: String) -> Promise<CommandResult>
    func capabilities() -> Array<CommandTypes>
}

enum CommandTypes {
    case openInBrowser
    case recheck
    case acknowledge
    case scheduleDowntime
}
