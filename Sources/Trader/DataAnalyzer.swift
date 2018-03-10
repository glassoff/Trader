//
//  DataAnalyzer.swift
//  trader
//
//  Created by glassoff on 14/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

class DataAnalyzer {

    private let pairs: [String]
    private let collector: DataCollector
    private let fakeEnter: Bool

    init(pairs: [String], collector: DataCollector, fakeEnter: Bool) {
        self.pairs = pairs
        self.collector = collector
        self.fakeEnter = fakeEnter
    }

    func findPairsForActions(tickData: [TickerItem]) -> [ActionInitialData] {
        guard fakeEnter == false else {
            print("Create fake enter data...")
            let tick = (tickData.filter { $0.pair == "ETH_BTC" }).first!
            let price = tick.currentBestBuyPrice

            return [ActionInitialData(pair: tick.pair, type: .buy, price: price/4)]
        }

        var taskDatas = [ActionInitialData]()

        for pairTickData in tickData {
            if let taskData = canMakeActionForPair(tickData: pairTickData) {
                taskDatas.append(taskData)
            }
        }

        return taskDatas
    }

    private func canMakeActionForPair(tickData: TickerItem) -> ActionInitialData? {
        let kSlowEMAPeriod = 100
        let kFastEMAPeriod = 25

        let pair = tickData.pair

        guard let emaDataSlow = ema(for: pair, period: kSlowEMAPeriod), emaDataSlow.count > 0 else {
            print("ERROR: no EMA \(kSlowEMAPeriod) data for \(pair)!")
            return nil
        }

        guard let emaDataFast = ema(for: pair, period: kFastEMAPeriod), emaDataFast.count > 0 else {
            print("ERROR: no EMA \(kFastEMAPeriod) data for \(pair)!")
            return nil
        }

        let priceData = collector.data(for: pair)

        if emaDataFast[emaDataFast.count - 2].price < emaDataSlow[emaDataSlow.count - 2].price && emaDataFast.last!.price > emaDataSlow.last!.price
            && isTrendUp(data: emaDataSlow) {
            //penetration from down to up
            log(pair: pair, datas: ["ALL": priceData, "EMA\(kFastEMAPeriod)": emaDataFast, "EMA\(kSlowEMAPeriod)": emaDataSlow], type: .canBuy)
            let buyActionData = ActionInitialData(pair: pair, type: .buy, price: tickData.currentBestSellPrice)

            return buyActionData
        } else if emaDataFast[emaDataFast.count - 2].price > emaDataSlow[emaDataSlow.count - 2].price && emaDataFast.last!.price < emaDataSlow.last!.price {
            //penetration from up to down
            log(pair: pair, datas: ["ALL": priceData, "EMA\(kFastEMAPeriod)": emaDataFast, "EMA\(kSlowEMAPeriod)": emaDataSlow], type: .canSell)
            let sellActionData = ActionInitialData(pair: pair, type: .sell, price: tickData.currentBestBuyPrice)

            return sellActionData
        } else {
            //no changes
        }

        return nil
    }

    private func isTrendUp(data: [PriceData]) -> Bool {
        let considerLength = 4

        guard data.count >= considerLength else {
            return false
        }

        let lastValue = data.last!.price
        let prevValue = data[data.count - considerLength].price

        let diff = (lastValue - prevValue) / prevValue * 100

        print("Check trend is up: diff \(diff)")

        return diff >= Settings.trandUpPercent
    }

    private func sma(for pair: String, period: Int) -> [PriceData]? {
        let priceData = collector.data(for: pair)

        let minimumDataCount = period * 2
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count for SMA, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateSMA(data: priceData, step: period)
    }

    private func ema(for pair: String, period: Int) -> [PriceData]? {
        let priceData = collector.data(for: pair)

        let minimumDataCount = period * 2
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count for EMA, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateEMA(data: priceData, step: period)
    }

    private enum LogType: String {
        case canBuy = "canBuy", canSell = "canSell", unknown = "unknown"
    }

    private func log(pair: String, datas: [String: [PriceData]], type: LogType) {
        var minDataCount = Int.max
        for (_, data) in datas {
            if data.count < minDataCount {
                minDataCount = data.count
            }
        }

        var slicedDatas = [[PriceData]]()
        for (_, data) in datas {
            let range = (data.count - minDataCount) ..< data.count
            slicedDatas.append(Array(data[range]))
        }

        let filePrefix = type.rawValue.uppercased()
        let keysString = datas.keys.joined(separator: "-")
        let fileName = "\(filePrefix)-\(pair)-\(keysString)-\(dateFormatter.string(from: Date())).csv"
        let fileURL = FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: fileName, folder: "logs")
        let fileHandler = try! FileHandle(forWritingTo: fileURL)

        for i in 0 ..< minDataCount {
            let dateString = dateFormatter.string(from: slicedDatas[0][i].date)
            var string = dateString

            for l in 0 ..< datas.count {
                string += ";" + Utils.doubleExcelFormatter.string(from: NSNumber(value: slicedDatas[l][i].price))!
            }

            string += "\n"

            fileHandler.seekToEndOfFile()
            fileHandler.write(string.data(using: .utf8)!)
        }

        fileHandler.closeFile()
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "Y-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "GMT")

        return formatter
    }()

}

private func calculateSMA(data: [PriceData], step: Int) -> [PriceData] {
    assert(data.count >= step, "Can't calculate SMA, data count is small")
    var smaData = [PriceData]()

    for i in (0..<data.count).reversed() {
        let startSliceIndex = i - step + 1
        guard startSliceIndex >= 0 else {
            continue
        }
        let slice = data[startSliceIndex ... i]
        let value = slice.reduce(0, { $0 + $1.price }) / Double(step)
        smaData.append(PriceData(date: data[i].date, price: value))
    }

    let result = Array(smaData.reversed())

    return result
}

private func calculateEMA(data: [PriceData], step: Int) -> [PriceData] {
    assert(data.count >= step, "Can't calculate EMA, data count is small")
    let k: Double = 2 / (Double(step) + 1)

    let smaSlice = data[0 ..< step]
    var prevValue = calculateSMA(data: Array(smaSlice), step: step).last!.price

    var emaData: [PriceData] = [PriceData(date: data[step - 1].date, price: prevValue)]

    for i in step ..< data.count {
        let value = data[i].price * k + prevValue * (1 - k)
        emaData.append(PriceData(date: data[i].date, price: value))
        prevValue = value
    }

    return emaData
}
