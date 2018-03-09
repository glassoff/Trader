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

    private class func levelWithPrice(_ price: Double) -> Double {
        return price - price / 100 * Settings.stopLossPercent
    }

    private func process(data: [TickerItem]) {
        for asset in assetsManager.assets {
            guard let tickData = (data.filter { $0.pair == asset.pair }).first else {
                print("WARNING: no tick data for \(asset.pair)")
                continue
            }

            if !stopLossIfNeeded(asset: asset, tickData: tickData) {
                let newLastBidForStoploss = tickData.currentBestBuyPrice > asset.lastBidForStoploss ? tickData.currentBestBuyPrice : nil
                let newLastAskForStoploss = tickData.currentBestSellPrice > asset.lastAskForStoploss ? tickData.currentBestSellPrice : nil

                if newLastBidForStoploss != nil || newLastAskForStoploss != nil {
                    let updatedAsset = asset.createNewWithStoplossValues(newLastAskForStoploss: newLastAskForStoploss, newLastBidForStoploss: newLastBidForStoploss)

                    assetsManager.replaceAsset(asset, with: updatedAsset)

                    print("Changed stoploss levels for \(asset.pair)")
                }
            }
        }
    }

    private func stopLossIfNeeded(asset: Asset, tickData: TickerItem) -> Bool {
        if tickData.currentBestBuyPrice <= LossStopper.levelWithPrice(asset.lastBidForStoploss) {
            print("NEED STOP LOSS of \(asset.pair) :((")

            let sellPrice = tickData.currentBestBuyPrice

            if let order = Utils.placeOrder(pair: asset.pair, type: .sell, orderPrice: sellPrice, quantity: asset.quantity) {
                ordersMonitor.addSellOrder(order, of: asset)
            } else {
                print("ERROR: couldn't place stop loss sell order!")
            }

            return true
        }

        return false
    }

}

extension LossStopper: DataCollectorObserver {

    func dataCollector(_ dataCollector: DataCollector, didGetNewData data: [TickerItem]) {}

    func dataCollector(_ dataCollector: DataCollector, didGetNewIntermediateData data: [TickerItem]) {
        process(data: data)
    }

}

extension Asset {

    func createNewWithStoplossValues(newLastAskForStoploss: Double?, newLastBidForStoploss: Double?) -> Asset {
        return Asset(
            pair: pair,
            buyPrice: buyPrice,
            quantity: quantity,
            baseQuantity: baseQuantity,
            createdAt: createdAt,
            uid: uid,
            lastAskForStoploss: newLastAskForStoploss ?? lastAskForStoploss,
            lastBidForStoploss: newLastBidForStoploss ?? lastBidForStoploss
        )
    }

}
