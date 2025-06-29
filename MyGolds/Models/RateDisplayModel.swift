//
//  RateDisplayModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI

struct RateDisplayModel: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let iconColor: Color
    let buyRate: String
    let sellRate: String
    let change: String
    let isChangeRatePositive: Bool
}
