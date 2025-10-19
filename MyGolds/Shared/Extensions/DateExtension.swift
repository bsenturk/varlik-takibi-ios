//
//  DateExtension.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 19.10.2025.
//

import Foundation

extension Date {
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: self)
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: self).uppercased()
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: self)
    }
}
