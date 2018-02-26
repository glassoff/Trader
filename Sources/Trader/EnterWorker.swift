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

    init(collector: DataCollector, monitor: OrdersMonitor, fakeEnter: Bool) {
        self.collector = collector
        self.monitor = monitor
        self.fakeEnter = fakeEnter
    }

    func work(data: [TickerItem]) {
        let analyzer = DataAnalyzer(pairs: Settings.pairs, collector: self.collector, fakeEnter: self.fakeEnter)
        var datasForEnter = analyzer.findPairsForEnter(tickData: data)
        datasForEnter.shuffle()

//        guard let openOrders = Utils.currentOpenOrders() else {//XXX test
//            print("ERROR: open orders is nil! Pass this entering.")
//            return
//        }
//
//        for dataForEnter in datasForEnter {
//            self.tryToEnter(withData: dataForEnter, currentOpenOrders: openOrders)
//        }
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

        if let order = Utils.placeOrder(pair: data.pair, type: data.type, orderPrice: data.price, quantity: data.quantity) {
            monitor.addBuyOrder(order, with: data)
        }
    }

}

extension EnterWorker: DataCollectorObserver {

    func dataCollector(_ dataCollector: DataCollector, didGetNewData data: [TickerItem]) {
        work(data: data)
    }

}
