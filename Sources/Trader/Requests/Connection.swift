//
//  Connection.swift
//  trader
//
//  Created by Dmitry Ryumin on 03/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation
import Dispatch

private let applicationUrlSession = URLSession(configuration: .default)

protocol Request: class {
    var urlRequest: URLRequest? { get }
}

protocol Response: class {
    init(data: Data?, error: Error?)
}

class Connection<R: Response> {

    var maxRepeatCount: Int = 10
    var repeatTimeout: TimeInterval = 10

    let request: URLRequest?

    private var currentRepeatCount: Int = 0
    private var resultResponse: R?
    private var semaphore: DispatchSemaphore?

    init(request: Request) {
        self.request = request.urlRequest
    }

    func execute(completion: @escaping (R?) -> Void) {
        createAndExecuteTask { [weak self] in
            completion(self?.resultResponse)
        }
    }

    func syncExecute() -> R? {
        semaphore = DispatchSemaphore(value: 0)

        createAndExecuteTask()

        _ = semaphore?.wait(timeout: .distantFuture)

        return resultResponse
    }

    private func createAndExecuteTask(completion: (() -> Void)? = nil) {
        let onDone = { [weak self] in
            self?.semaphore?.signal()
            completion?()
        }

        guard let request = request else {
            onDone()
            return
        }

        let session = applicationUrlSession
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let `self` = self else {
                return
            }

            if error != nil && self.currentRepeatCount < self.maxRepeatCount {
                print(error!)
                print("ERROR - try repeat...")
                self.currentRepeatCount += 1
                wait(for: self.repeatTimeout)
                self.createAndExecuteTask()
                return
            }

            self.resultResponse = R(data: data, error: error)
            onDone()
        }

        task.resume()
    }

}

private func wait(for interval: TimeInterval) {
    let date = Date()
    while Date().timeIntervalSince(date) < interval { }
}
