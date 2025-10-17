//
//  StringExtension.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

extension String {
    func parseToDouble() -> Double? {
        let cleanString = self
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
        return Double(cleanString)
    }
}
