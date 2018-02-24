//
//  TradesRequest.swift
//  trader
//
//  Created by glassoff on 02/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class TradesRequest: Request {

    let urlRequest: URLRequest?

    init(pairs: [String]) {
        guard let url = Settings.apiURL(method: "trades", args: "pair=\(pairs.joined(separator: ","))") else {
            urlRequest = nil
            return
        }

        urlRequest = URLRequest(url: url)
    }

}

class TradesResponse: Response {

    let pairTradesInfos: [PairTradesInfo]?

    required init(data: Data?, error: Error?) {
        guard let data = data else {
            pairTradesInfos = nil
            return
        }

//        let object = try? JSONSerialization.jsonObject(with: data, options: [])
//        print(object)

        let tradeInfoObject = try? JSONDecoder().decode(TradesInfo.self, from: data)

        pairTradesInfos = tradeInfoObject?.pairTradesInfos
    }

}

struct TradesInfo: Decodable {

    var pairTradesInfos: [PairTradesInfo]

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

        var pairTradesInfosMutable = [PairTradesInfo]()

        for key in container.allKeys {
            let tradeItems = try container.decode([PairTradeItem].self, forKey: key)
            pairTradesInfosMutable.append(PairTradesInfo(pair: key.stringValue, trades: tradeItems))
        }

        pairTradesInfos = pairTradesInfosMutable

    }

}

struct PairTradesInfo {
    let pair: String
    let trades: [PairTradeItem]
}

class PairTradeItem: Decodable {
    let trade_id: Int
    let type: String
    let price: String
    let quantity: String
    let amount: String
    let date: Int

    lazy var priceValue: Double = {
        return priceFormatter.number(from: price)!.doubleValue
    }()

    private lazy var priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."

        return formatter
    }()
}
