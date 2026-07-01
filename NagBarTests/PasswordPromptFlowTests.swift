//
//  PasswordPromptFlowTests.swift
//  NagBarTests
//
//  Created by NagBar maintainers.
//

import XCTest
import Cocoa
@testable import NagBar

final class PasswordPromptFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PasswordStore.sharedInstance.removeAll()
    }

    override func tearDown() {
        PasswordStore.sharedInstance.removeAll()
        super.tearDown()
    }

    func testPasswordPromptFlowSelectsFirstEnabledInstanceBySortedName() throws {
        let next = try XCTUnwrap(PasswordPromptFlow.next(currentName: nil, enabledInstances: instances(["zeta", "alpha"])))

        XCTAssertEqual(next.name, "alpha")
    }

    func testPasswordPromptFlowAdvancesToNextEnabledInstanceBySortedName() throws {
        let next = try XCTUnwrap(PasswordPromptFlow.next(currentName: "alpha", enabledInstances: instances(["zeta", "alpha"])))

        XCTAssertEqual(next.name, "zeta")
    }

    func testPasswordPromptFlowReturnsNilAfterLastInstance() {
        let next = PasswordPromptFlow.next(currentName: "zeta", enabledInstances: instances(["zeta", "alpha"]))

        XCTAssertNil(next)
    }

    func testPasswordPromptFlowReturnsNilForUnknownCurrentInstance() {
        let next = PasswordPromptFlow.next(currentName: "missing", enabledInstances: instances(["zeta", "alpha"]))

        XCTAssertNil(next)
    }

    func testPasswordPromptFlowBuildsPromptMessageWithInstanceName() {
        let message = PasswordPromptFlow.promptMessage(for: instance("edge"))

        XCTAssertEqual(message, "Please enter the password for monitoring instance\nedge")
    }

    func testPasswordPromptFlowBuildsEmptyPromptMessage() {
        XCTAssertEqual(PasswordPromptFlow.emptyPromptMessage(), "No monitoring instances require a password.")
    }

    func testPasswordPromptFlowMapsIncorrectPasswordError() {
        XCTAssertEqual(PasswordPromptFlow.errorText(forCode: -999), "Incorrect password")
    }

    func testPasswordPromptFlowMapsTimeoutError() {
        XCTAssertEqual(PasswordPromptFlow.errorText(forCode: -1001), "Connection timed out")
    }

    func testPasswordPromptFlowMapsConnectionRefusedError() {
        XCTAssertEqual(PasswordPromptFlow.errorText(forCode: -1004), "Could not connect to the server")
    }

    func testPasswordPromptFlowMapsUnknownError() {
        XCTAssertEqual(PasswordPromptFlow.errorText(forCode: 500), "Unknown error")
    }

    func testPasswordPromptControllerSuccessStoresPasswordAdvancesAndRefreshesAfterLastInstance() throws {
        let controller = makeController(instances: instances(["zeta", "alpha"]))
        _ = controller.window
        let passwordField = try securePasswordField(in: controller)
        let textField = try promptTextField(in: controller)
        var requestedInstances: [String] = []
        var storedPasswords: [(String, String)] = []
        var refreshCount = 0
        controller.requestConnection = { monitoringInstance, _, completion in
            requestedInstances.append(monitoringInstance.name)
            completion(.success(Self.response()))
        }
        controller.storePassword = { name, password in
            storedPasswords.append((name, password))
        }
        controller.refreshStatusData = {
            refreshCount += 1
        }

        passwordField.stringValue = "alpha-secret"
        let firstSuccess = expectation(description: "Store first password")
        controller.checkConnection(NSButton())
        waitUntil { storedPasswords.count == 1 } completion: { firstSuccess.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedInstances, ["alpha"])
        XCTAssertEqual(textField.stringValue, "Please enter the password for monitoring instance\nzeta")
        XCTAssertEqual(storedPasswords.first?.0, "alpha")
        XCTAssertEqual(storedPasswords.first?.1, "alpha-secret")
        XCTAssertEqual(refreshCount, 0)

        passwordField.stringValue = "zeta-secret"
        let secondSuccess = expectation(description: "Refresh after last password")
        controller.checkConnection(NSButton())
        waitUntil { refreshCount == 1 } completion: { secondSuccess.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedInstances, ["alpha", "zeta"])
        XCTAssertEqual(storedPasswords.map { $0.0 }, ["alpha", "zeta"])
        XCTAssertEqual(storedPasswords.last?.1, "zeta-secret")
    }

    func testPasswordPromptControllerFailureStopsCheckingWithoutSkippingWhenRetryIsDeclined() throws {
        let controller = makeController(instances: instances(["alpha", "zeta"]))
        _ = controller.window
        let okButton = try okButton(in: controller)
        let passwordField = try securePasswordField(in: controller)
        let textField = try promptTextField(in: controller)
        var requestedInstances: [String] = []
        var retryErrors: [NSError] = []
        var storedPasswords: [(String, String)] = []
        controller.requestConnection = { monitoringInstance, _, completion in
            requestedInstances.append(monitoringInstance.name)
            completion(.failure(NSError(domain: "NagBarTests", code: -999)))
        }
        controller.retryAfterFailure = { error in
            retryErrors.append(error)
            return false
        }
        controller.storePassword = { name, password in
            storedPasswords.append((name, password))
        }

        passwordField.stringValue = "wrong"
        let failureHandled = expectation(description: "Retry declined")
        controller.checkConnection(okButton)
        waitUntil { retryErrors.count == 1 } completion: { failureHandled.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedInstances, ["alpha"])
        XCTAssertEqual(retryErrors.first?.code, -999)
        XCTAssertTrue(okButton.isEnabled)
        XCTAssertEqual(textField.stringValue, "Please enter the password for monitoring instance\nalpha")
        XCTAssertTrue(storedPasswords.isEmpty)
    }

    func testPasswordPromptControllerFailureSkipAdvancesToNextInstance() throws {
        let controller = makeController(instances: instances(["alpha", "zeta"]))
        _ = controller.window
        let passwordField = try securePasswordField(in: controller)
        let textField = try promptTextField(in: controller)
        var requestedInstances: [String] = []
        var requestResults: [Result<HTTPResponse, Error>] = [
            .failure(NSError(domain: "NagBarTests", code: -1004)),
            .success(Self.response())
        ]
        var storedPasswords: [(String, String)] = []
        var retryCount = 0
        controller.requestConnection = { monitoringInstance, _, completion in
            requestedInstances.append(monitoringInstance.name)
            completion(requestResults.removeFirst())
        }
        controller.retryAfterFailure = { _ in
            retryCount += 1
            return true
        }
        controller.storePassword = { name, password in
            storedPasswords.append((name, password))
        }

        controller.checkConnection(NSButton())
        let skipped = expectation(description: "Failure skipped")
        waitUntil { retryCount == 1 } completion: { skipped.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(textField.stringValue, "Please enter the password for monitoring instance\nzeta")

        passwordField.stringValue = "zeta-secret"
        let success = expectation(description: "Next instance succeeds")
        controller.checkConnection(NSButton())
        waitUntil { storedPasswords.count == 1 } completion: { success.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedInstances, ["alpha", "zeta"])
        XCTAssertEqual(storedPasswords.first?.0, "zeta")
        XCTAssertEqual(storedPasswords.first?.1, "zeta-secret")
    }

    func testPasswordPromptControllerFailureSkipLastInstanceClosesWithoutRefresh() {
        let controller = makeController(instances: instances(["alpha"]))
        _ = controller.window
        var retryCount = 0
        var refreshCount = 0
        controller.requestConnection = { _, _, completion in
            completion(.failure(NSError(domain: "NagBarTests", code: -1001)))
        }
        controller.retryAfterFailure = { _ in
            retryCount += 1
            return true
        }
        controller.refreshStatusData = {
            refreshCount += 1
        }

        let handled = expectation(description: "Terminal retry handled")
        controller.checkConnection(NSButton())
        waitUntil { retryCount == 1 } completion: { handled.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(refreshCount, 0)
    }

    func testPasswordPromptControllerEmptyEnabledInstancesDoesNotCrashOrRequestConnection() throws {
        let controller = makeController(instances: [:])
        _ = controller.window
        let okButton = try okButton(in: controller)
        let textField = try promptTextField(in: controller)
        var requestCount = 0
        controller.requestConnection = { _, _, _ in
            requestCount += 1
        }

        controller.checkConnection(okButton)

        XCTAssertFalse(okButton.isEnabled)
        XCTAssertEqual(textField.stringValue, "No monitoring instances require a password.")
        XCTAssertEqual(requestCount, 0)
    }

    private func instances(_ names: Array<String>) -> Dictionary<String, MonitoringInstance> {
        var result: Dictionary<String, MonitoringInstance> = [:]
        for name in names {
            result[name] = instance(name)
        }
        return result
    }

    private func instance(_ name: String) -> MonitoringInstance {
        return MonitoringInstance().initDefault(
            name: name,
            url: "https://\(name).example/status.cgi",
            type: .Icinga,
            username: "user",
            password: "",
            enabled: 1
        )
    }

    private func makeController(instances: Dictionary<String, MonitoringInstance>) -> PasswordPromptController {
        let controller = PasswordPromptController(windowNibName: "PasswordPrompt")
        controller.enabledInstancesProvider = { instances }
        return controller
    }

    private func securePasswordField(in controller: PasswordPromptController) throws -> NSSecureTextField {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return try XCTUnwrap(firstView(where: { $0 is NSSecureTextField }, in: contentView) as? NSSecureTextField)
    }

    private func promptTextField(in controller: PasswordPromptController) throws -> NSTextField {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return try XCTUnwrap(firstView(where: { view in
            guard let textField = view as? NSTextField else { return false }
            return !(textField is NSSecureTextField) && !textField.isEditable
        }, in: contentView) as? NSTextField)
    }

    private func okButton(in controller: PasswordPromptController) throws -> NSButton {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return try XCTUnwrap(firstView(where: { view in
            guard let button = view as? NSButton else { return false }
            return button.title == "OK"
        }, in: contentView) as? NSButton)
    }

    private func firstView(where matches: (NSView) -> Bool, in view: NSView) -> NSView? {
        if matches(view) {
            return view
        }

        for subview in view.subviews {
            if let found = firstView(where: matches, in: subview) {
                return found
            }
        }

        return nil
    }

    private func waitUntil(_ predicate: @escaping () -> Bool, completion: @escaping () -> Void) {
        if predicate() {
            completion()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.waitUntil(predicate, completion: completion)
        }
    }

    private static func response() -> HTTPResponse {
        return HTTPResponse(
            data: Data(),
            response: HTTPURLResponse(url: URL(string: "https://monitoring.example")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}
