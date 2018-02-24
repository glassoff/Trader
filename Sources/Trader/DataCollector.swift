//
//  DataCollector.swift
//  trader
//
//  Created by glassoff on 07/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation
import Dispatch

struct PriceData {
    let date: Date
    let price: Double
}

class DataCollector {

    private let pairs: [String]
    private let partOfHourInterval: Int = 4 // 1/partOfHourInterval (1/4 = 15 min)
    private let notCollect: Bool
    private let dataPath: String

    private var connection: Connection<TradesResponse>?

    init(pairs: [String], notCollect: Bool, dataPath: String) {
        self.pairs = pairs
        self.notCollect = notCollect
        self.dataPath = dataPath
    }

    func data(for pair: String) -> [PriceData] {
        let fileHandler = file(forPair: pair, type: .buy)
        let data = fileHandler.readDataToEndOfFile()
        guard let dataString = String(data: data, encoding: .utf8) else {
            return []
        }

        var result = [PriceData]()
        let items = dataString.split(separator: "\n")
        for itemString in items {
            let columns = itemString.split(separator: ",")

            guard columns.count > 1,
                let date = dateFormatterGMT.date(from: String(columns[0])),
                let value = priceFormatter.number(from: String(columns[1]))?.doubleValue else {
                    continue
            }

            result.append(PriceData(date: date, price: value))
        }

        return result
    }

    func startCollect() {
        guard notCollect == false else {
            print("Not collect mode")
            return
        }

        print("Check pairs data files...")
        for pair in pairs {
            if let lastItemDate = data(for: pair).last?.date {
                if Date().timeIntervalSince(lastItemDate) > Double((60*60/partOfHourInterval)*5) {
                    print("Delete old data for \(pair)")
                    let fileURL = createIfNeedsAndReturnFileURL(forPair: pair, type: .buy)
                    try! FileManager.default.removeItem(at: fileURL)
                }
            }
        }

        collect()
    }

    private func collect() {
        let minute = 60 / partOfHourInterval
        var minutes: [Int] = []
        var nextMinute = 0
        while nextMinute < 60 {
            minutes.append(nextMinute)
            nextMinute += minute
        }

        print("Minutes for collect data \(minutes)")

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        var closestMinute = 0
        for minute in minutes.reversed() {
            if components.minute! < minute {
                closestMinute = minute
            }
        }
        components.minute = closestMinute
        if closestMinute == 0 {
            components.hour! += 1
        }
        guard let startDate = Calendar.current.date(from: components) else {
            assert(false)
            return
        }
        let startInterval = startDate.timeIntervalSince(Date())

        print("Start collect after \(startInterval/60) minutes")

        DispatchQueue.main.asyncAfter(deadline: .now() + startInterval) {
            self.executeStep()
        }
    }

    private func executeStep() {
        connection = Connection<TradesResponse>(request: TradesRequest(pairs: pairs))
        connection?.execute { [weak self] (response) in
            guard let tradesInfos = response?.pairTradesInfos else {
                return
            }

            for tradesInfo in tradesInfos {
                self?.processData(tradesInfo: tradesInfo)
            }

            self?.collect()
        }
    }

    private func processData(tradesInfo: PairTradesInfo) {
        let pair = tradesInfo.pair

        let buyTrades = tradesInfo.trades.filter { $0.type == "buy" }.sorted { $0.date > $1.date }
        let avgBuyPriceValue = buyTrades.reduce(0, { $0 + $1.priceValue }) / Double(buyTrades.count)
        writeTrade(pair: pair, type: .buy, value: avgBuyPriceValue)

//        let sellTrades = tradesInfo.trades.filter { $0.type == "sell" }
    }

    // ETH_BTC-BUY-4.csv
    private func writeTrade(pair: String, type: OrderType, value: Double) {
        guard value > 0 else {
            return
        }

        let dateString = dateFormatterGMT.string(from: Date())
        let tradeDataString = "\(dateString),\(value)\n"
        let tradeData = tradeDataString.data(using: .utf8)!

        let fileHandler = file(forPair: pair, type: type)

        fileHandler.seekToEndOfFile()
        fileHandler.write(tradeData)
        fileHandler.closeFile()
    }

    private func createIfNeedsAndReturnFileURL(forPair pair: String, type: OrderType) -> URL {
        let fileName = "\(pair)-\(type.rawValue)-\(partOfHourInterval)".uppercased() + ".csv"

        return FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: fileName, dataPath: dataPath)
    }

    private func file(forPair pair: String, type: OrderType) -> FileHandle {
        return try! FileHandle(forUpdating: createIfNeedsAndReturnFileURL(forPair: pair, type: type))
    }

    private let dateFormatterGMT: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "Y-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "GMT")

        return formatter
    }()

    private let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."

        return formatter
    }()
    
}
