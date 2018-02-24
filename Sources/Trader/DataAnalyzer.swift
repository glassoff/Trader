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
    private let dataPath: String

    init(pairs: [String], collector: DataCollector, fakeEnter: Bool, dataPath: String) {
        self.pairs = pairs
        self.collector = collector
        self.fakeEnter = fakeEnter
        self.dataPath = dataPath
    }

    func findPairsForEnter() -> [TaskInitialData] {
        guard let pairOrderBooks = Connection<OrderBookResponse>(request: OrderBookRequest(pairs: pairs)).syncExecute()?.pairOrderBooks else {
            print("ERROR: no order book!")
            return []
        }

        guard fakeEnter == false else {
            print("Create fake enter data...")
            let orderBook = (pairOrderBooks.filter { $0.pair == "ETH_BTC" }).first!
            let price = bestCurrentPrice(from: orderBook.book, type: .buy)!
            return [createInitialData(pair: orderBook.pair, bestBuyPrice: price/4)]
        }

        var taskDatas = [TaskInitialData]()

        for pairOrderBook in pairOrderBooks {
            if let taskData = canEnterToPair(orderBook: pairOrderBook) {
                print("Can enter with \(taskData)")
                taskDatas.append(taskData)
            }
        }

        return taskDatas
    }

    private func canEnterToPair(orderBook pairOrderBook: PairOrderBook) -> TaskInitialData? {
        let pair = pairOrderBook.pair

        print("Check of entering to \(pair)...")

        guard let bestBuyPrice = bestCurrentPrice(from: pairOrderBook.book, type: .buy) else {
            print("ERROR: no best price!")
            return nil
        }

        guard let emaData = ema(for: pair), emaData.count > 0 else {
            print("ERROR: no EMA data!")
            return nil
        }

        let lastEMAPrice = emaData.last!.price

        if bestBuyPrice < lastEMAPrice && trendIsIncreasing(emaData: emaData) {
            print("bestBuyPrice: \(bestBuyPrice) < lastEMAPrice: \(lastEMAPrice)")

            let taskData = createInitialData(pair: pair, bestBuyPrice: bestBuyPrice)

            log(pair: pair, successfull: true)

            return taskData
        } else {
            log(pair: pair, successfull: false)

            return nil
        }
    }

    private func trendIsIncreasing(emaData: [PriceData]) -> Bool {
        let minimumChangePercent: Double = 0.02
        let consideredPeriod: Int = 4

        guard emaData.count > consideredPeriod else {
            print("A little of EMA data for recognizing trend.")
            return false
        }

        let lastValue = emaData.last!.price
        let prevValue = emaData[emaData.count - consideredPeriod].price

        let diffPercent = (lastValue - prevValue) / (prevValue/100)

        print("Diff \(diffPercent)%, need \(minimumChangePercent)")

        return diffPercent >= minimumChangePercent
    }

    private func createInitialData(pair: String, bestBuyPrice: Double) -> TaskInitialData {
        let buyPrice = calculateBuyPrice(fromBestBuyPrice: bestBuyPrice)
        let sellPrice = calculateSellPrice(fromBuyPrice: buyPrice)

        let amount: Double = 0.0016 //XXX
        let cleanBuyQuantity = amount / buyPrice
        let buyQuantityWithFee = cleanBuyQuantity - cleanBuyQuantity/100*Settings.feePercent
        let buyQuantity = Double(round(100000000*buyQuantityWithFee)/100000000)

        let cleanSellQuantity = buyQuantity
        let sellQuantityWithFee = cleanSellQuantity - cleanSellQuantity/100*Settings.feePercent
        let sellQuantity = Double(round(100000000*sellQuantityWithFee)/100000000)

        return TaskInitialData(pair: pair, buyPrice: buyPrice, buyQuantity: buyQuantity, sellPrice: sellPrice, sellQuantity: sellQuantity)
    }

    private func calculateBuyPrice(fromBestBuyPrice bestBuyPrice: Double) -> Double {
        let diffPercent = Settings.orderPriceDiffBuyPercent
        let diff = bestBuyPrice/100 * Double(diffPercent)
        let orderBuyPrice: Double = bestBuyPrice + diff

        return orderBuyPrice
    }

    private func calculateSellPrice(fromBuyPrice buyPrice: Double) -> Double {
        let diffPercent = Settings.minimalProfitPercent + Settings.feePercent * 2
        let diff = buyPrice/100 * Double(diffPercent)
        let orderSellPrice: Double = buyPrice + diff

        return orderSellPrice
    }

    private func bestCurrentPrice(from orderBook: OrderBook, type: OrderType) -> Double? {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."

        let bestPrice: Double?
        if type == .buy {
            bestPrice = formatter.number(from: orderBook.bid_top)?.doubleValue
        } else {
            bestPrice = formatter.number(from: orderBook.ask_top)?.doubleValue
        }

        return bestPrice
    }

    private func ema(for pair: String) -> [PriceData]? {
        let priceData = collector.data(for: pair)

        let emaPeriod = 30
        let minimumDataCount = emaPeriod * 2
        guard priceData.count >= minimumDataCount else {
            print("Not enough data count, only \(priceData.count), we need \(minimumDataCount)")
            return nil
        }

        return calculateEMA(data: priceData, step: emaPeriod)
    }

    private func log(pair: String, successfull: Bool) {
        let priceData = collector.data(for: pair)
        let emaData = ema(for: pair)!

        let priceDataSlice = Array(priceData[priceData.count - emaData.count ..< priceData.count])

        let filePrefix = successfull ? "SUCCESS" : "NOT"
        let fileName = "\(filePrefix)-\(pair)-\(dateFormatter.string(from: Date())).csv"
        let fileURL = FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: fileName, dataPath: dataPath)
        let fileHandler = try! FileHandle(forWritingTo: fileURL)

        for i in 0 ..< emaData.count {
            let dateString = dateFormatter.string(from: priceDataSlice[i].date)
            let string = "\(dateString),\(priceDataSlice[i].price),\(emaData[i].price)\n"

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
