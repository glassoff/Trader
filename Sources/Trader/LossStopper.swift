//
//  LossStopper.swift
//  Trader
//
//  Created by glassoff on 01/03/2018.
//

import Foundation

class LossStopper {

    private let assetsManager: AssetsManager
    private let ordersMonitor: OrdersMonitor

    init(assetsManager: AssetsManager, ordersMonitor: OrdersMonitor) {
        self.assetsManager = assetsManager
        self.ordersMonitor = ordersMonitor
    }

    private func process(data: [TickerItem]) {
        for asset in assetsManager.assets {
            guard let tickData = (data.filter { $0.pair == asset.pair }).first else {
                print("WARNING: no tick data for \(asset.pair)")
                continue
            }
            stopLossIfNeeded(asset: asset, tickData: tickData)
        }
    }

    private func stopLossIfNeeded(asset: Asset, tickData: TickerItem) {
        let stopPrice = asset.buyPrice - asset.buyPrice / 100 * Settings.stopLossPercent

        if tickData.currentBestSellPrice <= stopPrice {
            print("NEED STOP LOSS of \(asset.pair) :((")
        }

        let sellPrice = tickData.currentBestSellPrice

        if let order = Utils.placeOrder(pair: asset.pair, type: .sell, orderPrice: sellPrice, quantity: asset.quantity) {
            ordersMonitor.addSellOrder(order, of: asset)
        } else {
            print("ERROR: couldn't place stop loss sell order!")
        }
    }

}

extension LossStopper: DataCollectorObserver {

    func dataCollector(_ dataCollector: DataCollector, didGetNewData data: [TickerItem]) {
        process(data: data)
    }

}
