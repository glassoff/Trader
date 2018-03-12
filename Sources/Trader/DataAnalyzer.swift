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
        let kSlowMAPeriod = 100
        let kFastMAPeriod = 25

        let pair = tickData.pair

        guard let maDataSlow = dema(for: pair, period: kSlowMAPeriod), maDataSlow.count > 0 else {
            print("ERROR: no MA \(kSlowMAPeriod) data for \(pair)!")
            return nil
        }

        guard let maDataFast = dema(for: pair, period: kFastMAPeriod), maDataFast.count > 0 else {
            print("ERROR: no MA \(kFastMAPeriod) data for \(pair)!")
            return nil
        }

        let priceData = collector.data(for: pair)

        if maDataFast[maDataFast.count - 2].price < maDataSlow[maDataSlow.count - 2].price && maDataFast.last!.price > maDataSlow.last!.price
            && isTrendUp(data: maDataSlow) {
            //penetration from down to up
            log(pair: pair, datas: ["ALL": priceData, "MA\(kFastMAPeriod)": maDataFast, "MA\(kSlowMAPeriod)": maDataSlow], type: .canBuy)
            let buyActionData = ActionInitialData(pair: pair, type: .buy, price: tickData.currentBestSellPrice)

            return buyActionData
        } else if maDataFast[maDataFast.count - 2].price > maDataSlow[maDataSlow.count - 2].price && maDataFast.last!.price < maDataSlow.last!.price {
            //penetration from up to down
            log(pair: pair, datas: ["ALL": priceData, "MA\(kFastMAPeriod)": maDataFast, "MA\(kSlowMAPeriod)": maDataSlow], type: .canSell)
            let sellActionData = ActionInitialData(pair: pair, type: .sell, price: tickData.currentBestBuyPrice)

            return sellActionData
        } else {
            //no changes
//            log(pair: pair, datas: ["ALL": priceData, "MA\(kFastMAPeriod)": maDataFast, "MA\(kSlowMAPeriod)": maDataSlow], type: .unknown)
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

        let minimumDataCount = period + 4
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count for SMA, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateSMA(data: priceData, step: period)
    }

    private func ema(for pair: String, period: Int) -> [PriceData]? {
        let priceData = collector.data(for: pair)

        let minimumDataCount = period + 4
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count for EMA, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateEMA(data: priceData, step: period)
    }

    private func dema(for pair: String, period: Int) -> [PriceData]? {
        let priceData = collector.data(for: pair)

        let minimumDataCount = period * 2 + 4
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count for DEMA, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateDEMA(data: priceData, step: period)
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
    func calculateEMAItem(price: Double, prevEMAValue: Double, step: Int) -> Double {
        let k: Double = 2 / (Double(step) + 1)
        let result = price * k + prevEMAValue * (1 - k)

        return result
    }

    assert(data.count >= step, "Can't calculate EMA, data count is small")

    let smaSlice = data[0 ..< step]
    var prevValue = calculateSMA(data: Array(smaSlice), step: step).last!.price

    var emaData: [PriceData] = [PriceData(date: data[step - 1].date, price: prevValue)]

    for i in step ..< data.count {
        let value = calculateEMAItem(price: data[i].price, prevEMAValue: prevValue, step: step)
        emaData.append(PriceData(date: data[i].date, price: value))
        prevValue = value
    }

    return emaData
}

private func calculateDEMA(data: [PriceData], step: Int) -> [PriceData] {
    let EMAData = calculateEMA(data: data, step: step)
    let EMAEMAData = calculateEMA(data: EMAData, step: step)

    let EMADataSlice = Array(EMAData[EMAData.count - EMAEMAData.count ..< EMAData.count])

    var DEMAData = [PriceData]()

    for i in 0 ..< EMAEMAData.count {
        assert(EMAEMAData[i].date == EMADataSlice[i].date)
        let value = 2 * EMADataSlice[i].price - EMAEMAData[i].price
        DEMAData.append(PriceData(date: EMAEMAData[i].date, price: value))
    }

    return DEMAData
}
