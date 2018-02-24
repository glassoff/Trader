//
//  EnterWorker.swift
//  trader
//
//  Created by glassoff on 17/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class EnterWorker {

    private let collector: DataCollector
    private let monitor: OrdersMonitor
    private let fakeEnter: Bool
    private let dataPath: String

    init(collector: DataCollector, monitor: OrdersMonitor, fakeEnter: Bool, dataPath: String) {
        self.collector = collector
        self.monitor = monitor
        self.fakeEnter = fakeEnter
        self.dataPath = dataPath
    }

    func start() {
        let interval: TimeInterval = fakeEnter ? 5 : 60*10
        if #available(OSX 10.12, *) {
            _ = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] (timer) in
                guard let `self` = self else {
                    return
                }

                let analyzer = DataAnalyzer(pairs: Settings.pairs, collector: self.collector, fakeEnter: self.fakeEnter, dataPath: self.dataPath)
                var datasForEnter = analyzer.findPairsForEnter()
                datasForEnter.shuffle()

                guard let openOrders = Utils.currentOpenOrders() else {
                    print("ERROR: open orders is nil! Pass this entering.")
                    return
                }

                for dataForEnter in datasForEnter {
                    self.tryToEnter(withData: dataForEnter, currentOpenOrders: openOrders)
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }

    private func tryToEnter(withData data: TaskInitialData, currentOpenOrders: [Order]) {
        print("Try to enter with \(data)")

        let pairOpenSellOrders = currentOpenOrders.filter { $0.pair == data.pair && $0.type == .sell }
        if pairOpenSellOrders.count > 0 {
            print("We have sell order(s) for \(data.pair) - can't enter.")
            return
        }

        let pairOpenBuyOrders = currentOpenOrders.filter { $0.pair == data.pair && $0.type == .buy }
        if pairOpenBuyOrders.count > 0 {// think that OrdersMonitor will cancel its
            print("We have buy order(s) for \(data.pair) - can't enter.")
            return
        }

        if let order = Utils.placeOrder(pair: data.pair, type: .buy, orderPrice: data.buyPrice, quantity: data.buyQuantity) {
            monitor.addBuyOrder(order, with: data)
        }
    }

}
