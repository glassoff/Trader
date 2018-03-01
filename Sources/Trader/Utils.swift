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

    class func baseCurrencyFrom(_ pair: String) -> String {
        let currencies = pair.split(separator: "_")
        assert(currencies.count == 2, "Incorrect pair string: \(pair)")

        return String(currencies.last!)
    }

    class func ourRound(_ value: Double) -> Double {
        let base = pow(10, Double(Settings.afterPointDigits))
        return round(base * value) / base
    }

    static var doubleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = "|"
//        formatter.maximumFractionDigits = Settings.afterPointDigits
//        formatter.groupingSeparator = ""
//        formatter.thousandSeparator = ""
//        formatter.hasThousandSeparators = false
//        formatter.usesGroupingSeparator = false
//        formatter.alwaysShowsDecimalSeparator = false
//        formatter.currencyGroupingSeparator = ""
        formatter.numberStyle = .decimal

        return formatter
    }()

    static var doubleExcelFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = Settings.afterPointDigits
        formatter.groupingSeparator = ""
        formatter.thousandSeparator = ""
        formatter.hasThousandSeparators = false
        formatter.usesGroupingSeparator = false
        formatter.alwaysShowsDecimalSeparator = false
        formatter.currencyGroupingSeparator = ""
        formatter.numberStyle = .decimal

        return formatter
    }()

    static func checkFormatter(name: String, formatter: NumberFormatter, n: Double) {
        let str = formatter.string(from: NSNumber(value: n))!
        let ns = formatter.number(from: str)!.doubleValue
//        assert(n == ns, "\(name) is incorrect!, \(n) == \(ns), string: \(str)")//XXX
        print("\(n) == \(ns), string: \(str)")
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
