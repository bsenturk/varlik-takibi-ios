//
//  AssetFormDisplayModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI

struct AssetFormDisplayModel: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let iconColor: Color
    let sellRate: String
}
