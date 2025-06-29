//
//  ColorExtension.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

extension Color {
    init(_ name: String) {
        switch name {
        case "yellow": self = .yellow
        case "green": self = .green
        case "blue": self = .blue
        case "purple": self = .purple
        case "orange": self = .orange
        case "red": self = .red
        default: self = .gray
        }
    }
}
