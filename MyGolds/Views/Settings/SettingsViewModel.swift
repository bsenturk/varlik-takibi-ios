//
//  SettingsViewModel.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 4.05.2024.
//

import SwiftUI
import StoreKit

final class SettingsViewModel: ObservableObject {
    
    @Environment(\.requestReview) var requestReview
    
    enum SectionType: CaseIterable {
        case support
        case appDetails
        
        var title: String {
            switch self {
            case .support:
                return "DESTEK"
            case .appDetails:
                return "UYGULAMA HAKKINDA"
            }
        }
        
        var rows: [RowType] {
            switch self {
            case .support:
                return [.writeReview, .sendFeedback, .shareApp]
            case .appDetails:
                return [.privacyPolicy]
            }
        }
    }
    
    enum RowType {
        case sendFeedback
        case writeReview
        case shareApp
        case privacyPolicy
        
        var title: String {
            switch self {
            case .sendFeedback:
                return "Geri Bildirim Gönder"
            case .writeReview:
                return "Uygulamaya Puan Ver"
            case .shareApp:
                return "Uygulamayı Paylaş"
            case .privacyPolicy:
                return "Gizlilik Politikası"
            }
        }
        
        var image: String {
            switch self {
            case .sendFeedback: return "envelope.circle.fill"
            case .writeReview: return "star.circle.fill"
            case .shareApp: return "square.and.arrow.up.circle.fill"
            case .privacyPolicy: return "doc.circle.fill"
            }
        }
    }
    
    var sections: [SectionType] {
        SectionType.allCases
    }
    
    func getAppVersion() -> String {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return "" }
        return appVersion
    }
    
    var getAppStoreUrl: String {
        return Constants.URLs.appStoreUrl
    }
}
