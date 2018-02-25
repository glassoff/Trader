//
//  TickerRequest.swift
//  Trader
//
//  Created by glassoff on 25/02/2018.
//

import Foundation

class TickerRequest: Request {

    let urlRequest: URLRequest?

    init() {
        guard let url = Settings.apiURL(method: "ticker") else {
            urlRequest = nil
            return
        }

        urlRequest = URLRequest(url: url)
    }

}

class TickerResponse: Response {

    let items: [TickerItem]?

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            self.items = nil
            return
        }

        let decodedObject = try? JSONDecoder().decode(ResponseDecoder.self, from: data)

        self.items = decodedObject?.items
    }

}

private struct ResponseDecoder: Decodable {

    let items: [TickerItem]

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

        var mutableItems = [TickerItem]()

        for key in container.allKeys {
            let itemDecoder = try container.decode(TickerItemDecoder.self, forKey: key)
            let item = TickerItem(pair: key.stringValue, decodedObject: itemDecoder)
            mutableItems.append(item)
        }

        items = mutableItems
    }

}

private struct TickerItemDecoder: Decodable {
    let last_trade: String
}

struct TickerItem {
    let pair: String
    let lastTradePrice: Double

    fileprivate init(pair: String, decodedObject: TickerItemDecoder) {
        self.pair = pair
        self.lastTradePrice = Utils.doubleFormatter.number(from: decodedObject.last_trade)!.doubleValue
    }
}
