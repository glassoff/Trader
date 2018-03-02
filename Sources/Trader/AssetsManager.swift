//
//  AssetsManager.swift
//  Trader
//
//  Created by Dmitry Ryumin on 01/03/2018.
//

import Foundation

struct Asset: Codable {
    let pair: String
    let quantity: Double
    let createdAt: Date
    //XXX
    //по какой цене был куплен
    //сколько изначальнйо моенты было потрачено на покупку (чтобы рассчитать профит)
    


    private enum CodingKeys: String, CodingKey {
        case pair
        case quantity
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

    private var assets = [Asset]()

    init() {
        loadAssets()
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

    private func addAsset(info: TaskData) {
        let asset = Asset(info: info)
        assets.append(asset)
        saveAssets()

        print("Added asset: \(asset)")
    }

}

extension AssetsManager: OrdersMonitorDelegate {

    func ordersMonitor(_ monitor: OrdersMonitor, orderWasClose info: TaskData) {
        if info.type == .buy {
            addAsset(info: info)
        }
    }

}
