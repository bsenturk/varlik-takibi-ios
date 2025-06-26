//
//  ColorExtension.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 24.02.2024.
//

import SwiftUI

extension Color {
    static var primaryBrown: Color {
        Color(red: 38/255, green: 32/255, blue: 21/255)
    }
    
    static var secondaryBrown: Color {
        Color(red: 70/255, green: 57/255, blue: 39/255)
    }
    
    static var tertiaryBrown: Color {
        Color(red: 204/255, green: 173/255, blue: 143/255)
    }
    
    static var primaryOrange: Color {
        Color(red: 216/255, green: 127/255, blue: 35/255)
    }
}

extension UIColor {
    static var primaryBrown: UIColor {
        UIColor(red: 38/255, green: 32/255, blue: 21/255, alpha: 1)
    }
    
    static var secondaryBrown: UIColor {
        UIColor(red: 70/255, green: 57/255, blue: 39/255, alpha: 1)
    }
    
    static var primaryOrange: UIColor {
        UIColor(red: 216/255, green: 127/255, blue: 35/255, alpha: 1)
    }
}
