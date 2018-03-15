//
//  CCXT.swift
//  Trader
//
//  Created by Dmitry Ryumin on 15/03/2018.
//

import Foundation
import JavaScriptCore

class CCXT {

    private let js = JSContext()!

    init() {
        js.exceptionHandler = { context, exception in
            print("JS Error: \(exception?.description ?? "unknown error")")
        }

        let mainDir = URL(fileURLWithPath: application.dataPath)

//        js.evaluateScript(try! String(contentsOf: mainDir.appendingPathComponent("require.js")))

        js.evaluateScript(try! String(contentsOf: mainDir.appendingPathComponent("ccxt.browser.js")))

        let ccxtObject = js.objectForKeyedSubscript("ccxt")
//        let res = ccxtObject?.invokeMethod("exchanges", withArguments: nil)
    }

}
