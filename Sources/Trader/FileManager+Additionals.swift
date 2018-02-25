//
//  FileManager+Additionals.swift
//  trader
//
//  Created by glassoff on 14/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

extension FileManager {

    func createIfNeedsAndReturnFileURLForTradeData(fileName: String) -> URL {
        let dir = URL(fileURLWithPath: application.dataPath)

        let tradeDirURL = dir.appendingPathComponent("trade_data")
        let fileURL = dir.appendingPathComponent("trade_data/" + fileName)

        var isDirectory = ObjCBool(true)
        if !fileExists(atPath: tradeDirURL.path, isDirectory: &isDirectory) {
            try! createDirectory(at: tradeDirURL, withIntermediateDirectories: false, attributes: nil)
        }
        if !fileExists(atPath: fileURL.path) {
            _ = createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        return fileURL
    }

}
