//
//  Request+Auth.swift
//  trader
//
//  Created by glassoff on 02/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation
import Cryptor

extension URLRequest {

    mutating func addAuthParams(postDictionary: [String: Any]) {
        var post: String = ""
        var i: Int = 0
        for (key, value) in postDictionary {
            if (i == 0) {
                post = "\(key)=\(value)"
            } else {
                post = "\(post)&\(key)=\(value)"
            }
            i += 1;
        }
        post = "\(post)&nonce=\(NonceStorage.shared.value)"
        NonceStorage.shared.value += 1

        let signedPost = hmacForKeyAndData(key: Settings.userApiSecretKey, data: post)
        setValue(signedPost, forHTTPHeaderField: "Sign")

        httpMethod = "POST"
        setValue(Settings.userApiKey, forHTTPHeaderField: "Key")

        let requestBodyData = post.data(using: .utf8)
        httpBody = requestBodyData
    }

}

class NonceStorage {

    private let storageFile = FileManager.default.createIfNeedsAndReturnFileURLForTradeData(fileName: "nonce-value", dataPath: "")

    static let shared = NonceStorage()

    var value: Int {
        get{
            if let strValue = try? String(contentsOf: storageFile, encoding: .utf8), let intValue = Int(strValue) {
                return intValue
            }

            return calculateInitialNonce()
        }
        set{
            try? String(newValue).write(to: storageFile, atomically: true, encoding: .utf8)
        }
    }

    private func calculateInitialNonce() -> Int {
        print("Calculate initial nonce...")

        let dataFormat = DateFormatter()
        dataFormat.dateFormat = "yyyy-MM-dd HH:mm:ss xxxx"
        let timeStamp = NSDate().timeIntervalSince(dataFormat.date(from: "2012-04-18 00:00:03 +0600")!)
        let currentNonce = NSNumber(value: timeStamp).intValue

        return currentNonce
    }

}

private func hmacForKeyAndData(key: String, data: String) -> String {
    let result = HMAC(using: HMAC.Algorithm.sha512, key: key).update(string: data)!.final()
    let hashString = CryptoUtils.hexString(from: result)

    return hashString
}
