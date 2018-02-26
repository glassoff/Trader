//
//  OrdersMonitor.swift
//  trader
//
//  Created by glassoff on 17/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

private struct TaskData: Codable {
    let pair: String
    let orderId: Int
    let quantity: Double
    let typeString: String
    let createdAt: Date

    var type: OrderType {
        return OrderType(rawValue: typeString)!
    }

    private enum CodingKeys: String, CodingKey {
        case pair
        case orderId
        case quantity
        case typeString
        case createdAt
    }

    init(order: Order, initialData: TaskInitialData?) {
        if order.type == .buy && initialData == nil {
            assert(false, "Initial data for buy order is nil!")
        }
        self.pair = order.pair
        self.orderId = order.orderId
        self.quantity = order.quantity
        self.typeString = order.type.rawValue
        self.createdAt = Date()
    }
}

class OrdersMonitor {

    private var objects = [TaskData]()

    init() {
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

    private func addData(_ data: TaskData) {
        print("Add data: \(data)")

        objects.append(data)

        saveObjects()
    }

    private func tick() {
        print("Check orders...")
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

    private func cancelOrderIfNeeded(object: TaskData, withServerOrder serverOrder: Order) -> Bool {
        print("Yet exist \(object.type.rawValue) order \(object.orderId) for \(object.pair)")

        guard orderIsFullOpen(object: object, withServerOrder: serverOrder) == true else {
            print("Order partially closed, we can't do anything.")
            return false
        }

        if object.type == .buy && Date().timeIntervalSince(object.createdAt) > Settings.cancelBuyOrderPeriod {
            print("Cancel buy order...")
            return Utils.cancelOrders([object.orderId])
        }

        return false
    }

    private func objectWasClosed(object: TaskData) -> Bool {
        print("Closed order \(object.orderId) for \(object.pair)")

        if object.type == .sell {
            print("SELL ORDER WAS CLOSED!!!")
            return true
        } else {
            print("Buy order was closed!")
            return true
        }
    }

    private func orderIsFullOpen(object: TaskData, withServerOrder serverOrder: Order) -> Bool {
        print("Check order is full open...")
        print("\(serverOrder.quantity) <> \(object.quantity)")
        if serverOrder.quantity < object.quantity {
            print("Partially closed")
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
        guard let savedObjects = try? JSONDecoder().decode([TaskData].self, from: objectsData) else {
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

    func addBuyOrder(_ order: Order, with initialData: TaskInitialData) {
        assert(order.pair == initialData.pair)
        let buyData = TaskData(order: order, initialData: initialData)
        addData(buyData)
    }

    func addSellOrder(_ order: Order) {
        let sellData = TaskData(order: order, initialData: nil)
        addData(sellData)
    }

}
