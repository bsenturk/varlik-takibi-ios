//
//  ArrayExtension.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 2.05.2024.
//

extension Array where Element: Equatable {
    subscript (safe index: Int) -> Element? {
        return self.indices ~= index ? self[index] : nil
    }
}
