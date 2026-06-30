//
//  Promise.swift
//  NagBar
//
//  Created by NagBar maintainers.
//

import Foundation

final class Promise<Value> {
    final class Seal {
        private let resolver: (Result<Value, Error>) -> Void

        init(_ resolver: @escaping (Result<Value, Error>) -> Void) {
            self.resolver = resolver
        }

        func fulfill(_ value: Value) {
            self.resolver(.success(value))
        }

        func reject(_ error: Error) {
            self.resolver(.failure(error))
        }
    }

    private enum State {
        case pending
        case resolved(Result<Value, Error>)
    }

    private let queue = DispatchQueue(label: "NagBar.Promise")
    private var state: State = .pending
    private var callbacks: [(Result<Value, Error>) -> Void] = []

    init(_ body: (Seal) -> Void) {
        body(Seal { result in
            self.resolve(result)
        })
    }

    static func value(_ value: Value) -> Promise<Value> {
        return Promise<Value> { seal in
            seal.fulfill(value)
        }
    }

    func then<NextValue>(_ transform: @escaping (Value) -> Promise<NextValue>) -> Promise<NextValue> {
        return Promise<NextValue> { seal in
            self.observe { result in
                switch result {
                case .success(let value):
                    transform(value).observe { nextResult in
                        switch nextResult {
                        case .success(let nextValue):
                            seal.fulfill(nextValue)
                        case .failure(let error):
                            seal.reject(error)
                        }
                    }
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func done(_ action: @escaping (Value) -> Void) -> Promise<Void> {
        return Promise<Void> { seal in
            self.observe { result in
                switch result {
                case .success(let value):
                    action(value)
                    seal.fulfill(())
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func recover(_ action: @escaping (Error) -> Void) -> Promise<Void> {
        return Promise<Void> { seal in
            self.observe { result in
                switch result {
                case .success:
                    seal.fulfill(())
                case .failure(let error):
                    action(error)
                    seal.fulfill(())
                }
            }
        }
    }

    func `catch`(_ action: @escaping (Error) -> Void) {
        self.observe { result in
            if case .failure(let error) = result {
                action(error)
            }
        }
    }

    private func observe(_ callback: @escaping (Result<Value, Error>) -> Void) {
        var resolvedResult: Result<Value, Error>?

        self.queue.sync {
            switch self.state {
            case .pending:
                self.callbacks.append(callback)
            case .resolved(let result):
                resolvedResult = result
            }
        }

        if let resolvedResult = resolvedResult {
            callback(resolvedResult)
        }
    }

    private func resolve(_ result: Result<Value, Error>) {
        let callbacksToRun: [(Result<Value, Error>) -> Void] = self.queue.sync {
            if case .resolved = self.state {
                return []
            }

            self.state = .resolved(result)
            let callbacks = self.callbacks
            self.callbacks = []
            return callbacks
        }

        for callback in callbacksToRun {
            callback(result)
        }
    }
}
