//
//  Utils.swift
//  trader
//
//  Created by glassoff on 17/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class Utils {

    class func currentOpenOrders() -> [Order]? {
        return Connection<OpenOrdersResponse>(request: OpenOrdersRequest()).syncExecute()?.orders
    }

    class func cancelOrders(_ ordersIds: [Int]) -> Bool {
        print("Cancel orders...")

        for orderId in ordersIds {
            if Connection<OrderCancelResponse>(request: OrderCancelRequest(orderId: String(orderId))).syncExecute()?.result != true {
                print("ERROR: cancelling order error!")
                return false
            }
            print("Order \(orderId) cancelled")
        }

        return true
    }

    // quantity: buy - quantity of buying currency; sell - quantity of selling currency
    class func placeOrder(pair: String, type: OrderType, orderPrice: Double, quantity: Double) -> Order? {
        print("Start create \(type.rawValue) order for \(pair)...")

        print("Data for create order: pair \(pair), quantity \(quantity), price \(orderPrice), type \(type)")

        let creationResult = Connection<OrderCreateResponse>(request: OrderCreateRequest(pair: pair, quantity: quantity, price: orderPrice, type: type)).syncExecute()?.result

        if let creationResult = creationResult {
            print("Order created with id: \(creationResult.order_id)")
            return Order(orderId: creationResult.order_id, pair: pair, quantity: quantity, type: type)
        } else {
            print("ERROR: creation order error!")
            return nil
        }
    }

}

extension Array {

    mutating func shuffle() {
        for _ in 0..<10 {
            sort { (_,_) in getRandomNum(0, 100) < getRandomNum(0, 100) }
        }
    }

}

private func getRandomNum(_ min: Int, _ max: Int) -> Int {
    #if os(Linux)
        return Int(random() % max) + min
    #else
        return Int(arc4random_uniform(UInt32(max)) + UInt32(min))
    #endif
}
