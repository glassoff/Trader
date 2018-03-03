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

    private enum CodingKeys: String, CodingKey {
        case pair
        case buyPrice
        case quantity
        case baseQuantity
        case createdAt
    }
}

extension Asset {

    init(info: TaskData) {
        self.pair = info.pair
        self.quantity = info.quantity
        self.createdAt = Date()
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

}

extension AssetsManager: OrdersMonitorDelegate {

    func ordersMonitor(_ monitor: OrdersMonitor, orderWasClose info: TaskData) {
        if info.type == .buy {
            let asset = Asset(info: info)
            addAsset(asset)
        }
    }

}
