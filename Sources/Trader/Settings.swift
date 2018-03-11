//
//  Settings.swift
//  trader
//
//  Created by glassoff on 02/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

struct Settings {

    static func apiURL(method: String, args: String = "") -> URL? {
        let urlString = "https://api.exmo.me/v1/\(method)?\(args)"
        return URL(string: urlString)
    }

    static let userApiKey = "K-cc72c6d63eb0f6476b3f8f7438fb74764077e373"
    static let userApiSecretKey = "S-89bc12d72448e8711bdc9e612b0bb484bfc051c7"

    static let partOfHourInterval: Int = 4

    static let feePercent: Double = 0.2
    static let stopLossPercent: Double = 1
    static let trandUpPercent: Double = 0.02

    static let pairs = ["BCH_BTC", "DASH_BTC", "ETH_BTC", "ETC_BTC", "LTC_BTC", "ZEC_BTC", "XMR_BTC", "WAVES_BTC", "KICK_BTC", "XRP_BTC", "BTC_USD", "BCH_USD", "DASH_USD", "ETH_USD", "ETC_USD", "LTC_USD", "ZEC_USD", "XRP_USD", "XMR_USD"]

    static let orderAmounts: [String: Double] = ["BTC": 0.0016, "USD": 15]

    static let cancelBuyOrderPeriod: TimeInterval = 60*5

    static let afterPointDigits: Int = 8

}
