import SwiftUI

class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    enum Keys: String {
        case hasSeenOnboarding = "has_seen_onboarding"
        case darkModePreference = "dark_mode_preference"
        case didCreateDefaultPortfolios = "did_create_default_portfolios"
        case isPro = "is_pro"
        // Onboarding hand-off: after the intro pages, auto-open the Add-Asset flow
        // so the user's first action is adding a real asset (the "aha" moment),
        // then surface the paywall only once they've added it.
        case pendingFirstAssetAdd = "pending_first_asset_add"
        case pendingOnboardingPaywall = "pending_onboarding_paywall"
    }

    /// "Varlıkları gizle" (göz ikonu) — portföy bazlı. Gizlenen portföylerin id'leri
    /// virgülle ayrılmış tek bir string'de tutulur; ekranlar `@AppStorage` ile okur,
    /// böylece bir portföyün gözü kapatıldığında yalnızca o portföyün tutarları maskelenir.
    static let maskedPortfoliosKey = "masked_portfolio_ids"

    static func isPortfolioMasked(_ stored: String, _ portfolioID: UUID?) -> Bool {
        guard let portfolioID else { return false }
        return stored.split(separator: ",").contains(Substring(portfolioID.uuidString))
    }

    static func togglingPortfolioMask(_ stored: String, _ portfolioID: UUID) -> String {
        var ids = stored.split(separator: ",").map(String.init)
        let key = portfolioID.uuidString
        if let index = ids.firstIndex(of: key) { ids.remove(at: index) } else { ids.append(key) }
        return ids.joined(separator: ",")
    }

    /// Local "Varlık Pro" entitlement flag. Real StoreKit purchases will set this later.
    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: Keys.isPro.rawValue)
        }
    }
    
    enum DarkModePreference: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var displayName: String {
            switch self {
            case .system: return "Sistem"
            case .light: return "Açık"
            case .dark: return "Koyu"
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
        
        var iconName: String {
            switch self {
            case .system: return "iphone"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }
    
    @Published var darkModePreference: DarkModePreference {
        didSet {
            UserDefaults.standard.set(darkModePreference.rawValue, forKey: Keys.darkModePreference.rawValue)
        }
    }
    
    private init() {
        let savedPreference = UserDefaults.standard.string(forKey: Keys.darkModePreference.rawValue)
        self.darkModePreference = DarkModePreference(rawValue: savedPreference ?? DarkModePreference.system.rawValue) ?? .system
        self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro.rawValue)
    }
    
    func setValue(value: Bool, key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    func getValue(for key: Keys) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
    }
}
