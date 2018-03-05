//
//  OrdersMonitor.swift
//  trader
//
//  Created by glassoff on 17/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

struct OrderData: Codable {
    let pair: String
    let orderId: Int
    let price: Double
    let quantity: Double
    let typeString: String
    let createdAt: Date
    let assetUID: String

    var type: OrderType {
        return OrderType(rawValue: typeString)!
    }

    private enum CodingKeys: String, CodingKey {
        case pair
        case orderId
        case price
        case quantity
        case typeString
        case createdAt
        case assetUID
    }

    init(order: Order, assetUID: String? = nil) {
        if order.type == .sell && assetUID == nil {
            assert(false, "ERROR: No asset UID for sell order!")
        }

        self.pair = order.pair
        self.orderId = order.orderId
        self.price = order.price
        self.quantity = order.quantity
        self.typeString = order.type.rawValue
        self.createdAt = Date()
        self.assetUID = assetUID ?? ""
    }
}

protocol OrdersMonitorDelegate: class {
    func ordersMonitor(_ monitor: OrdersMonitor, orderWasClose info: OrderData)
}

class OrdersMonitor {

    weak var delegate: OrdersMonitorDelegate!

    private var objects = [OrderData]()

    init(delegate: OrdersMonitorDelegate) {
        self.delegate = delegate

        loadObjects()
    }

    func start() {
        if #available(OSX 10.12, *) {
            _ = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] (timer) in
                self?.tick()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    private func addData(_ data: OrderData) {
        print("Add data: \(data)")

        objects.append(data)

        saveObjects()
    }

    private func tick() {
        guard let openOrders = Utils.currentOpenOrders() else {
            print("ERROR: open orders nil!")
            return
        }

        var objectsIdsForRemoving = [Int]()

        for (index, object) in objects.enumerated() {
            if let serverOrder = (openOrders.filter { $0.orderId == object.orderId }).first {
                if cancelOrderIfNeeded(object: object, withServerOrder: serverOrder) {
                    objectsIdsForRemoving.append(index)
                }
            } else {
                if objectWasClosed(object: object) {
                    print("Closing was successfull, delete...")
                    objectsIdsForRemoving.append(index)
                } else {
                    print("Closing error")
                }
            }
        }

        if objectsIdsForRemoving.count > 0 {
            objectsIdsForRemoving.forEach { objects.remove(at: $0) }
            saveObjects()
        }
    }

    private func cancelOrderIfNeeded(object: OrderData, withServerOrder serverOrder: Order) -> Bool {
        print("Yet exist \(object.type.rawValue) order \(object.orderId) for \(object.pair)")

        guard orderIsFullOpen(object: object, withServerOrder: serverOrder) == true else {
            return false
        }

        if object.type == .buy && Date().timeIntervalSince(object.createdAt) > Settings.cancelBuyOrderPeriod {
            print("Cancel buy order...")
            return Utils.cancelOrders([object.orderId])
        }

        return false
    }

    private func objectWasClosed(object: OrderData) -> Bool {
        print("Closed \(object.type.rawValue) order \(object.orderId) for \(object.pair)")

        delegate.ordersMonitor(self, orderWasClose: object)

        return true
    }

    private func orderIsFullOpen(object: OrderData, withServerOrder serverOrder: Order) -> Bool {
        print("Check order is full open...")
        print("\(serverOrder.quantity) <> \(object.quantity)")
        if serverOrder.quantity < object.quantity {
            return false
        }

        return true
    }

    private func saveObjects() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let dataJSON = try! encoder.encode(objects)
        try! dataJSON.write(to: objectsFileURL())
    }

    private func loadObjects() {
        let objectsData = try! Data(contentsOf: objectsFileURL())
        guard let savedObjects = try? JSONDecoder().decode([OrderData].self, from: objectsData) else {
            print("Incorrect saved monitor objects!")
            return
        }

        objects = savedObjects
    }

    private func objectsFileURL() -> URL {
        return FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: "order-monitor-data.json")
    }

}

extension OrdersMonitor {

    func addBuyOrder(_ order: Order) {
        let buyData = OrderData(order: order)
        addData(buyData)
    }

    func addSellOrder(_ order: Order, of asset: Asset) {
        let sellData = OrderData(order: order, assetUID: asset.uid)
        addData(sellData)
    }

}
