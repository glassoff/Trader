//
//  Model.swift
//  trader
//
//  Created by glassoff on 21/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

enum OrderType: String {
    case buy = "buy"
    case sell = "sell"
}

struct Order {
    let orderId: Int
    let pair: String
    let price: Double
    let quantity: Double
    let type: OrderType
}

struct TaskInitialData {
    let pair: String
    let type: OrderType

    let price: Double
    let quantity: Double
}
