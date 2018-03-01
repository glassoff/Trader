//
//  OpenOrdersRequest.swift
//  trader
//
//  Created by Dmitry Ryumin on 03/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class OpenOrdersRequest: Request {

    let urlRequest: URLRequest?

    init() {
        guard let url = Settings.apiURL(method: "user_open_orders") else {
            urlRequest = nil
            return
        }

        var request = URLRequest(url: url)
        request.addAuthParams(postDictionary: [:])

        self.urlRequest = request
    }

}

class OpenOrdersResponse: Response {

    let orders: [Order]?

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            orders = nil
            return
        }

//        let object = try? JSONSerialization.jsonObject(with: data, options: [])
//        print(object)

        let result: ResponseDecoder? = try? JSONDecoder().decode(ResponseDecoder.self, from: data)

        orders = result?.orders.flatMap { Order(serverOrder: $0) }
    }

}

private struct ResponseDecoder: Decodable {

    let orders: [OrderDecoder]

    struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var mutableOrders = [OrderDecoder]()

        for key in container.allKeys {
            let orders = try container.decode([OrderDecoder].self, forKey: key)
            mutableOrders += orders
        }

        orders = mutableOrders
    }

}

private struct OrderDecoder: Decodable {
    let order_id: String
    let pair: String
    let quantity: String
    let type: String
}

private extension Order {

    init?(serverOrder: OrderDecoder) {
        guard let orderId = Int(serverOrder.order_id),
            let quantity = Utils.doubleFormatter.number(from: serverOrder.quantity)?.doubleValue,
            let type = OrderType(rawValue: serverOrder.type) else {
            return nil
        }
        self.orderId = orderId
        self.pair = serverOrder.pair
        self.quantity = quantity
        self.type = type
    }

}
