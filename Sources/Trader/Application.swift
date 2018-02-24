//
//  Application.swift
//  trader
//
//  Created by glassoff on 21/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class Application {

    private(set) var dataPath: String!

    private var collector: DataCollector!
    private var monitor: OrdersMonitor!
    private var enterWorker: EnterWorker!

    func main(dataPath: String, onlyCollect: Bool, withoutCollect: Bool, fakeEnter: Bool) {
        self.dataPath = dataPath

        print("Data path: \(dataPath)")

        collector = DataCollector(pairs: Settings.pairs, notCollect: withoutCollect, dataPath: dataPath)
        collector.startCollect()

        if fakeEnter {
            print("Fake enter mode")
        }

        if onlyCollect {
            print("Only Collect mode")
        } else {
            monitor = OrdersMonitor(dataPath: dataPath)
            monitor.start()

            enterWorker = EnterWorker(collector: collector, monitor: monitor, fakeEnter: fakeEnter, dataPath: dataPath)
            enterWorker.start()
        }
    }

}
