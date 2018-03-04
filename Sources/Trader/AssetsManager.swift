//
//  AssetsManager.swift
//  Trader
//
//  Created by Dmitry Ryumin on 01/03/2018.
//

import Foundation

struct Asset: Codable {
    let pair: String
    let buyPrice: Double
    let quantity: Double
    let baseQuantity: Double
    let createdAt: Date
    let uid: String

    private enum CodingKeys: String, CodingKey {
        case pair
        case buyPrice
        case quantity
        case baseQuantity
        case createdAt
        case uid
    }

    static func == (lhs: Asset, rhs: Asset) -> Bool {
        return lhs.uid == rhs.uid
    }
}

extension Asset {

    init(info: OrderData) {
        self.pair = info.pair
        self.buyPrice = info.price
        self.quantity = info.quantity

        let baseQuantityValue = Settings.orderAmounts[Utils.baseCurrencyFrom(info.pair)]
        assert(baseQuantityValue != nil, "Base quantity in nil for \(info.pair)")
        self.baseQuantity = baseQuantityValue!

        self.createdAt = Date()
        self.uid = Asset.generateUID(pair: info.pair)
    }

    private static func generateUID(pair: String) -> String {
        return "\(Date().timeIntervalSince1970)-\(pair)"
    }

}

class AssetsManager {

    private(set) var assets = [Asset]()

    init() {
        loadAssets()
    }

    func addAsset(_ asset: Asset) {
        assets.append(asset)
        saveAssets()

        print("Added asset: \(asset)")
    }

    func removeAsset(_ asset: Asset) -> Bool {
        let index = assets.index(where: { $0 == asset })
        if let index = index {
            assets.remove(at: index)
            saveAssets()

            return true
        }

        return false
    }

    func assetWithUID(_ uid: String) -> Asset? {
        for asset in assets {
            if asset.uid == uid {
                return asset
            }
        }

        return nil
    }

    private func loadAssets() {
        let assetsData = try! Data(contentsOf: assetsFileURL())
        guard let savedAssets = try? JSONDecoder().decode([Asset].self, from: assetsData) else {
            print("Incorrect saved assets!")
            return
        }

        assets = savedAssets
    }

    private func saveAssets() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let dataJSON = try! encoder.encode(assets)
        try! dataJSON.write(to: assetsFileURL())
    }

    private func assetsFileURL() -> URL {
        return FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: "assets-data.json")
    }

    private func showResult(info: OrderData, asset: Asset) {
        let diffPercent = ((info.price - asset.buyPrice) / asset.buyPrice) * 100
        let diffPercentWithFee = diffPercent - Settings.feePercent*2
        let baseResult = asset.baseQuantity + (asset.baseQuantity / 100) * diffPercentWithFee
        let baseDiff = baseResult - asset.baseQuantity
        let baseCurrency = Utils.baseCurrencyFrom(info.pair)
        print("==== RESULT: \(info.pair), \(diffPercent)%, with fee: \(diffPercentWithFee)%, \(baseDiff) \(baseCurrency)")
    }

}

extension AssetsManager: OrdersMonitorDelegate {

    func ordersMonitor(_ monitor: OrdersMonitor, orderWasClose info: OrderData) {
        if info.type == .buy {
            let asset = Asset(info: info)
            addAsset(asset)
        } else {
            if let asset = assetWithUID(info.assetUID) {
                showResult(info: info, asset: asset)

                let removeResult = removeAsset(asset)
                if removeResult == false {
                    print("ERROR: we couldn't remove asset!")
                }
            } else {
                print("ERROR: can't find asset with UID \(info.assetUID) for removing!")
            }
        }
    }

}
