//
//  FileManager+Additionals.swift
//  trader
//
//  Created by glassoff on 14/01/2018.
//  Copyright © 2018 glassoff. All rights reserved.
//

import Foundation

extension FileManager {

    func createIfNeedsAndReturnFileURLForTradeData(fileName: String, folder: String? = nil) -> URL {
        let mainDir = URL(fileURLWithPath: application.dataPath)

        var tradeDirURL = mainDir.appendingPathComponent("trade_data")
        if let folder = folder {
            tradeDirURL = tradeDirURL.appendingPathComponent(folder)
        }
        let fileURL = tradeDirURL.appendingPathComponent(fileName)

        var isDirectory = ObjCBool(true)
        if !fileExists(atPath: tradeDirURL.path, isDirectory: &isDirectory) {
            try! createDirectory(at: tradeDirURL, withIntermediateDirectories: true, attributes: nil)
        }
        if !fileExists(atPath: fileURL.path) {
            _ = createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        return fileURL
    }

}
