//
//  SubscriptionProduct.swift
//  MyGolds
//
//  Created by Claude on 27.10.2025.
//

import Foundation

struct SubscriptionProduct: Identifiable {
    let id: String
    let name: String
    let description: String
    let period: String
    let price: String
    let savings: String?
    let features: [String]
    let isPopular: Bool

    static let features = [
        "Reklamları Kaldır",
        "Sınırsız Varlık Ekleme",
        "Detaylı İstatistikler",
        "Öncelikli Destek"
    ]

    static func monthly(price: String = "₺49,99") -> SubscriptionProduct {
        SubscriptionProduct(
            id: RevenueCatManager.monthlyProductId,
            name: "Aylık Premium",
            description: "Her ay yenilenir",
            period: "Aylık",
            price: price,
            savings: nil,
            features: Self.features,
            isPopular: false
        )
    }

    static func yearly(price: String = "₺299,99", monthlySavings: String = "₺50") -> SubscriptionProduct {
        SubscriptionProduct(
            id: RevenueCatManager.yearlyProductId,
            name: "Yıllık Premium",
            description: "Yılda bir yenilenir",
            period: "Yıllık",
            price: price,
            savings: "Ayda \(monthlySavings) tasarruf",
            features: Self.features,
            isPopular: true
        )
    }
}
