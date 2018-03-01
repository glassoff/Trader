//
//  main.swift
//  trader
//
//  Created by glassoff on 02/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

print("Check formatter...")

let testFormatter = NumberFormatter()
testFormatter.locale = Locale(identifier: "en_US_POSIX")
testFormatter.decimalSeparator = "."
testFormatter.numberStyle = .decimal
testFormatter.allowsFloats = true
testFormatter.minimumFractionDigits = 8
testFormatter.hasThousandSeparators = false
testFormatter.usesGroupingSeparator = false

Utils.checkFormatter(name: "TEST", formatter: testFormatter, n: Double(0.00000343))
Utils.checkFormatter(name: "TEST", formatter: testFormatter, n: Double(12340.00000343))


Utils.checkFormatter(name: "Double formatter", formatter: Utils.doubleFormatter, n: Double(0.00000343))
Utils.checkFormatter(name: "Double formatter", formatter: Utils.doubleFormatter, n: Double(12340.00000343))
Utils.checkFormatter(name: "Excel formatter", formatter: Utils.doubleExcelFormatter, n: Double(0.00000343))
Utils.checkFormatter(name: "Excel formatter", formatter: Utils.doubleExcelFormatter, n: Double(12340.00000343))
print("done!")
assert(false)//XXX

let application = Application()

print("Start...")

private var argOnlyCollect = false
private var argWithoutCollect = false
private var argFakeEnter = false
private var dataPath: String!

for argument in CommandLine.arguments {
    let argParts = argument.split(separator: "=")
    let argName = String(argParts[0])
    var argValue: String?
    if argParts.count > 1 {
        argValue = String(argParts[1])
    }

    if argName == "--only-collect" {
        argOnlyCollect = true
    }
    if argName == "--without-collect" {
        argWithoutCollect = true
    }
    if argName == "--fake-enter" {
        argFakeEnter = true
    }
    if argName == "--data-path" {
        dataPath = argValue!
    }
}

assert(dataPath != nil, "You should set --data-path")
assert(!(argOnlyCollect && argWithoutCollect), "--only-collect and --without-collect in one time")

application.main(dataPath: dataPath, onlyCollect: argOnlyCollect, withoutCollect: argWithoutCollect, fakeEnter: argFakeEnter)

while true {
    _ = RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
}
