//
//  OrderBookRequest.swift
//  trader
//
//  Created by glassoff on 04/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class OrderBookRequest: Request {

    let urlRequest: URLRequest?

    init(pairs: [String]) {
        guard let url = Settings.apiURL(method: "order_book", args: "pair=\(pairs.joined(separator: ","))") else {
            urlRequest = nil
            return
        }

        urlRequest = URLRequest(url: url)
    }

}

class OrderBookResponse: Response {

    let pairOrderBooks: [PairOrderBook]?

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            pairOrderBooks = nil
            return
        }

        let decoderObject = try? JSONDecoder().decode(OrderBookDecoder.self, from: data)
        pairOrderBooks = decoderObject?.pairOrderBooks
    }

}

struct OrderBookDecoder: Decodable {

    let pairOrderBooks: [PairOrderBook]?

    struct CodingKeys: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?

        init?(intValue: Int) {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var mutablePairOrderBooks = [PairOrderBook]()

        for key in container.allKeys {
            let orderBook = try container.decode(OrderBook.self, forKey: key)
            let pairOrderBook = PairOrderBook(pair: key.stringValue, book: orderBook)
            mutablePairOrderBooks.append(pairOrderBook)
        }

        pairOrderBooks = mutablePairOrderBooks
    }

}

struct PairOrderBook {

    let pair: String
    let book: OrderBook

}

struct OrderBook: Decodable {

    let ask_top: String
    let bid_top: String

}
