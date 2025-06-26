//
//  FontExtension.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 3.03.2024.
//

import SwiftUI

extension Font {
    
    static func workSansBold(size: CGFloat) -> Font {
        return .custom("WorkSans-Bold", size: size)
    }
    
    static func workSansRegular(size: CGFloat) -> Font {
        return .custom("WorkSans-Regular", size: size)
    }
    
    static func workSansSemiBold(size: CGFloat) -> Font {
        return .custom("WorkSans-SemiBold", size: size)
    }
    
    static func workSansMedium(size: CGFloat) -> Font {
        return .custom("WorkSans-Medium", size: size)
    }
}
