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
    private var actionMaker: ActionMaker!
    private var assetsManager: AssetsManager!
    private var lossStopper: LossStopper!

    func main(dataPath: String, onlyCollect: Bool, withoutCollect: Bool, fakeEnter: Bool) {
        self.dataPath = dataPath

        print("Data path: \(dataPath)")

        collector = DataCollector(pairs: Settings.pairs, notCollect: withoutCollect)
        collector.startCollect()

        if fakeEnter {
            print("Fake enter mode")
        }

        if onlyCollect {
            print("Only Collect mode")
        } else {
            assetsManager = AssetsManager()

            monitor = OrdersMonitor(delegate: assetsManager)
            monitor.start()

            actionMaker = ActionMaker(collector: collector, monitor: monitor, assetsManager: assetsManager, fakeEnter: fakeEnter)
            collector.addObserver(actionMaker)

            lossStopper = LossStopper(assetsManager: assetsManager, ordersMonitor: monitor)
            collector.addObserver(lossStopper)
        }
    }

}
