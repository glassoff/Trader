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
    private let maxNumberOfDataLines = 700
    private let notCollect: Bool

    private var connection: Connection<TickerResponse>?

    init(pairs: [String], notCollect: Bool) {
        self.pairs = pairs
        self.notCollect = notCollect
    }

    func data(for pair: String) -> [PriceData] {
        let fileHandler = file(forPair: pair)
        let data = fileHandler.readDataToEndOfFile()
        guard let dataString = String(data: data, encoding: .utf8) else {
            return []
        }

        var result = [PriceData]()
        let items = dataString.split(separator: "\n")
        for itemString in items {
            let columns = itemString.split(separator: ";")

            guard columns.count > 1,
                let date = dateFormatterGMT.date(from: String(columns[0])),
                let value = Utils.doubleExcelFormatter.number(from: String(columns[1]))?.doubleValue else {
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
                    let fileURL = createIfNeedsAndReturnFileURL(forPair: pair)
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
        connection = Connection<TickerResponse>(request: TickerRequest())
        connection?.execute { [weak self] (response) in
            guard let `self` = self else {
                return
            }
            guard let tickers = response?.items else {
                print("ERROR: tickers are nil")
                return
            }

            let filteredItems = tickers.filter { self.pairs.contains($0.pair) }

            guard filteredItems.count > 0 else {
                print("ERROR: no our pairs in tickers")
                return
            }

            for tickerItem in filteredItems {
                self.writeData(pair: tickerItem.pair, value: tickerItem.lastTradePrice)
            }

            self.observers.forEach { $0.observer?.dataCollector(self, didGetNewData: filteredItems) }

            self.collect()
        }
    }

    // ETH_BTC-4.csv
    private func writeData(pair: String, value: Double) {
        guard value > 0 else {
            return
        }

        let dateString = dateFormatterGMT.string(from: Date())
        let valueString = Utils.doubleExcelFormatter.string(from: NSNumber(value: value))!
        let tradeDataString = "\(dateString);\(valueString)\n"

        let fileHandler = file(forPair: pair)

        let dataString: String

        let existData = fileHandler.readDataToEndOfFile()
        if let existDataString = String(data: existData, encoding: .utf8) {
            let lines = existDataString.split(separator: "\n")
            if lines.count > maxNumberOfDataLines {
                let newRange = (lines.count - maxNumberOfDataLines) ... (lines.count - 1)
                let newLines = Array(lines[newRange])
                dataString = newLines.joined(separator: "\n") + "\n" + tradeDataString
                fileHandler.truncateFile(atOffset: 0)
            } else {
                dataString = tradeDataString
                fileHandler.seekToEndOfFile()
            }
        } else {
            dataString = tradeDataString
            fileHandler.seekToEndOfFile()
        }

        let tradeData = dataString.data(using: .utf8)!
        fileHandler.write(tradeData)
        fileHandler.closeFile()
    }

    private func createIfNeedsAndReturnFileURL(forPair pair: String) -> URL {
        let fileName = "\(pair)-\(partOfHourInterval)".uppercased() + ".csv"

        return FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: fileName)
    }

    private func file(forPair pair: String) -> FileHandle {
        return try! FileHandle(forUpdating: createIfNeedsAndReturnFileURL(forPair: pair))
    }

    private let dateFormatterGMT: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "Y-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "GMT")

        return formatter
    }()

    private var observers = [ObserverWrapper]()
    
}

protocol DataCollectorObserver: class {
    func dataCollector(_ dataCollector: DataCollector, didGetNewData data: [TickerItem])
}

private struct ObserverWrapper {
    weak var observer: DataCollectorObserver?
}

extension DataCollector {

    func addObserver(_ observer: DataCollectorObserver) {
        guard observers.contains(where: { $0.observer === observer }) == false else {
            return
        }
        observers.append(ObserverWrapper(observer: observer))
    }

    func removeObserver(_ observer: DataCollectorObserver) {
        if let index = observers.index(where: { $0.observer === observer }) {
            observers.remove(at: index)
        }
    }

}
