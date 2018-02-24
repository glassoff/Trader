//
//  OrderCreateRequest.swift
//  trader
//
//  Created by Dmitry Ryumin on 03/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class OrderCreateRequest: Request {

    let urlRequest: URLRequest?

    init(pair: String, quantity: Double, price: Double, type: OrderType) {
        guard let url = Settings.apiURL(method: "order_create") else {
            urlRequest = nil
            return
        }

        var request = URLRequest(url: url)
        request.addAuthParams(postDictionary: [
            "pair": pair,
            "quantity": quantity,
            "price": price,
            "type": type.rawValue
            ])

        self.urlRequest = request
    }

}

class OrderCreateResponse: Response {

    let result: CreateResult?

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            result = nil
            return
        }
        let object = try? JSONSerialization.jsonObject(with: data, options: [])
        print(object ?? "")

        let resultObject = try? JSONDecoder().decode(CreateResult.self, from: data)

        result = resultObject
    }

}

struct CreateResult: Decodable {

    let result: Bool
    let order_id: Int

}
