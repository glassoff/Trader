//
//  ActionMaker.swift
//  trader
//
//  Created by glassoff on 17/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class ActionMaker {

    private let collector: DataCollector
    private let monitor: OrdersMonitor
    private let assetsManager: AssetsManager
    private let fakeEnter: Bool

    init(collector: DataCollector, monitor: OrdersMonitor, assetsManager: AssetsManager, fakeEnter: Bool) {
        self.collector = collector
        self.monitor = monitor
        self.assetsManager = assetsManager
        self.fakeEnter = fakeEnter
    }

    func work(data: [TickerItem]) {
        let analyzer = DataAnalyzer(pairs: Settings.pairs, collector: self.collector, fakeEnter: self.fakeEnter)
        var datasForActions = analyzer.findPairsForActions(tickData: data)
        datasForActions.shuffle()

        guard let openOrders = Utils.currentOpenOrders() else {
            print("ERROR: open orders is nil! Pass make actions!.")
            return
        }

        for dataForAction in datasForActions {
            self.tryMakeAction(withData: dataForAction, currentOpenOrders: openOrders)
        }
    }

    private func tryMakeAction(withData data: ActionInitialData, currentOpenOrders: [Order]) {
        print("Try make action with \(data)")

        let pairOpenSellOrders = currentOpenOrders.filter { $0.pair == data.pair && $0.type == .sell }
        if pairOpenSellOrders.count > 0 {
            print("We have sell order(s) for \(data.pair) - can't make action.")
            return
        }

        let pairOpenBuyOrders = currentOpenOrders.filter { $0.pair == data.pair && $0.type == .buy }
        if pairOpenBuyOrders.count > 0 {// think that OrdersMonitor will cancel its
            print("We have buy order(s) for \(data.pair) - can't make action.")
            return
        }

        let asset = assetsManager.assetForPair(data.pair)

        switch data.type {
        case .buy:
            if asset != nil {
                print("We have \(data.pair) asset - can't make buy action.")
                return
            }

            let baseCurrency = Utils.baseCurrencyFrom(data.pair)
            guard let amount = Settings.orderAmounts[baseCurrency] else {
                print("ERROR: we don't have defined amount for \(baseCurrency)")
                return
            }

            let cleanBuyQuantity = amount / data.price
            let buyQuantityWithFee = cleanBuyQuantity - cleanBuyQuantity/100*Settings.feePercent
            let buyQuantity = Utils.ourRound(buyQuantityWithFee)

            if let order = Utils.placeOrder(pair: data.pair, type: data.type, orderPrice: data.price, quantity: buyQuantity) {
                monitor.addBuyOrder(order)
            }
        case .sell:
            if let asset = asset {
                if let order = Utils.placeOrder(pair: data.pair, type: data.type, orderPrice: data.price, quantity: asset.quantity) {
                    monitor.addSellOrder(order, of: asset)
                }
            } else {
                print("We don't have \(data.pair) asset - can't make sell action.")
                return
            }
        }
    }

}

extension ActionMaker: DataCollectorObserver {

    func dataCollector(_ dataCollector: DataCollector, didGetNewData data: [TickerItem]) {
        work(data: data)
    }

}
