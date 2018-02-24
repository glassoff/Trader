//
//  OrderCancelRequest.swift
//  trader
//
//  Created by Dmitry Ryumin on 03/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class OrderCancelRequest: Request {

    let urlRequest: URLRequest?

    init(orderId: String) {
        guard let url = Settings.apiURL(method: "order_cancel") else {
            urlRequest = nil
            return
        }

        var request = URLRequest(url: url)
        request.addAuthParams(postDictionary: [
            "order_id": orderId
            ])

        self.urlRequest = request
    }

}

class OrderCancelResponse: Response {

    let result: Bool

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            self.result = false
            return
        }

//        let object = try? JSONSerialization.jsonObject(with: data, options: [])
//        print(object)

        let result = try? JSONDecoder().decode(ResultDecoder.self, from: data)

        self.result = result?.result ?? false
    }

}

private struct ResultDecoder: Decodable {

    let result: Bool

}
