//
//  PromiseTests.swift
//  NagBarTests
//
//  Created by NagBar maintainers.
//

import XCTest

class PromiseTests: XCTestCase {
    func testValueCallsDoneWithImmediateValue() {
        let expectation = self.expectation(description: "value resolved")

        Promise<String>.value("ok").done { value in
            XCTAssertEqual(value, "ok")
            expectation.fulfill()
        }.catch { error in
            XCTFail("Unexpected error: \(error)")
        }

        waitForExpectations(timeout: 1)
    }

    func testAsyncFulfillCallsDone() {
        let expectation = self.expectation(description: "async resolved")
        let promise = Promise<String> { seal in
            DispatchQueue.global().async {
                seal.fulfill("done")
            }
        }

        promise.done { value in
            XCTAssertEqual(value, "done")
            expectation.fulfill()
        }.catch { error in
            XCTFail("Unexpected error: \(error)")
        }

        waitForExpectations(timeout: 1)
    }

    func testRejectCallsCatch() {
        let expectation = self.expectation(description: "rejected")
        let promise = Promise<String> { seal in
            seal.reject(NSError(domain: "NagBar.PromiseTests", code: 42))
        }

        promise.done { _ in
            XCTFail("Rejected promise should not call done")
        }.catch { error in
            XCTAssertEqual((error as NSError).code, 42)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testThenTransformsResolvedValueInOrder() {
        let expectation = self.expectation(description: "then resolved")
        var steps: [String] = []

        Promise<String>.value("first").then { value -> Promise<String> in
            steps.append(value)
            return Promise<String>.value("second")
        }.done { value in
            steps.append(value)
            XCTAssertEqual(steps, ["first", "second"])
            expectation.fulfill()
        }.catch { error in
            XCTFail("Unexpected error: \(error)")
        }

        waitForExpectations(timeout: 1)
    }

    func testRecoverContinuesAsSuccessfulVoidPromise() {
        let expectation = self.expectation(description: "recover resolved")
        let promise = Promise<String> { seal in
            seal.reject(NSError(domain: "NagBar.PromiseTests", code: 7))
        }

        promise.recover { error in
            XCTAssertEqual((error as NSError).code, 7)
        }.done {
            expectation.fulfill()
        }.catch { error in
            XCTFail("Recover should continue as success: \(error)")
        }

        waitForExpectations(timeout: 1)
    }

    func testDoubleResolutionKeepsFirstValue() {
        let expectation = self.expectation(description: "first value kept")
        let promise = Promise<String> { seal in
            seal.fulfill("first")
            seal.fulfill("second")
            seal.reject(NSError(domain: "NagBar.PromiseTests", code: 9))
        }

        promise.done { value in
            XCTAssertEqual(value, "first")
            expectation.fulfill()
        }.catch { error in
            XCTFail("Unexpected error: \(error)")
        }

        waitForExpectations(timeout: 1)
    }
}
