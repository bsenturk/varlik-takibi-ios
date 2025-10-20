//
//  Logger.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

class Logger {
    static func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}
