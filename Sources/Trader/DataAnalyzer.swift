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

    func findPairsForEnter(tickData: [TickerItem]) -> [TaskInitialData] {
        guard fakeEnter == false else {
            print("Create fake enter data...")
            let tick = (tickData.filter { $0.pair == "ETH_BTC" }).first!
            let price = tick.currentBestBuyPrice
            return [createInitialBuyData(pair: tick.pair, bestBuyPrice: price/4)!]
        }

        var taskDatas = [TaskInitialData]()

        for pairTickData in tickData {
            if let taskData = canEnterToPair(tickData: pairTickData) {
                print("Can enter with \(taskData)")
                taskDatas.append(taskData)
            }
        }

        return taskDatas
    }

    private func canEnterToPair(tickData: TickerItem) -> TaskInitialData? {
        let pair = tickData.pair

        print("Check of entering to \(pair)...")

        guard let emaData30 = ema(for: pair, period: 30), emaData30.count > 0 else {
            print("ERROR: no EMA 30 data!")
            return nil
        }

        guard let emaData7 = ema(for: pair, period: 7), emaData7.count > 0 else {
            print("ERROR: no EMA 7 data!")
            return nil
        }

        let priceData = collector.data(for: pair)

        if emaData7[emaData7.count - 2].price < emaData30[emaData30.count - 2].price && emaData7.last!.price > emaData30.last!.price {
            //penetration from down to up
            log(pair: pair, datas: ["ALL": priceData, "EMA7": emaData7, "EMA30": emaData30], type: .canBuy)
//            let buyTaskData = createInitialBuyData(pair: pair, bestBuyPrice: tickData.currentBestBuyPrice)
        } else if emaData7[emaData7.count - 2].price > emaData30[emaData30.count - 2].price && emaData7.last!.price < emaData30.last!.price {
            //penetration from up to down
            log(pair: pair, datas: ["ALL": priceData, "EMA7": emaData7, "EMA30": emaData30], type: .canSell)
        } else {
            //no changes
//            log(pair: pair, datas: ["ALL": priceData, "EMA7": emaData7, "EMA30": emaData30], type: .unknown)
        }

        return nil
    }

    private func createInitialBuyData(pair: String, bestBuyPrice: Double) -> TaskInitialData? {
        let buyPrice = calculateBuyPrice(fromBestBuyPrice: bestBuyPrice)

        let baseCurrency = Utils.baseCurrencyFrom(pair)
        guard let amount = Settings.orderAmounts[baseCurrency] else {
            print("ERROR: we don't have defined amount for \(baseCurrency)")
            return nil
        }

        let cleanBuyQuantity = amount / buyPrice
        let buyQuantityWithFee = cleanBuyQuantity - cleanBuyQuantity/100*Settings.feePercent
        let buyQuantity = Utils.ourRound(buyQuantityWithFee)

        return TaskInitialData(pair: pair, type: .buy, price: buyPrice, quantity: buyQuantity)
    }

//    private func createInitialSellData(pair: String, bestBuyPrice: Double) -> TaskInitialData {
//        let buyPrice = calculateBuyPrice(fromBestBuyPrice: bestBuyPrice)
//        let sellPrice = calculateSellPrice(fromBuyPrice: buyPrice)
//
//        let amount: Double = 0.0016 //XXX
//        let cleanBuyQuantity = amount / buyPrice
//        let buyQuantityWithFee = cleanBuyQuantity - cleanBuyQuantity/100*Settings.feePercent
//        let buyQuantity = Double(round(100000000*buyQuantityWithFee)/100000000)
//
//        let cleanSellQuantity = buyQuantity
//        let sellQuantityWithFee = cleanSellQuantity - cleanSellQuantity/100*Settings.feePercent
//        let sellQuantity = Double(round(100000000*sellQuantityWithFee)/100000000)
//
//        return TaskInitialData(pair: pair, buyPrice: buyPrice, buyQuantity: buyQuantity, sellPrice: sellPrice, sellQuantity: sellQuantity)
//    }

    private func calculateBuyPrice(fromBestBuyPrice bestBuyPrice: Double) -> Double {
        let diffPercent = Settings.orderPriceDiffBuyPercent
        let diff = bestBuyPrice/100 * Double(diffPercent)
        let orderBuyPrice: Double = bestBuyPrice + diff

        return orderBuyPrice
    }

    private func calculateSellPrice(fromBuyPrice buyPrice: Double) -> Double {//XXX need?
        let diffPercent = Settings.minimalProfitPercent + Settings.feePercent * 2
        let diff = buyPrice/100 * Double(diffPercent)
        let orderSellPrice: Double = buyPrice + diff

        return orderSellPrice
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
