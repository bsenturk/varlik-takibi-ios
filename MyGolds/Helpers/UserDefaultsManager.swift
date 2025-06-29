//
//  UserDefaultsManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI

class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    enum Keys: String {
        case hasSeenOnboarding = "has_seen_onboarding"
    }
    
    func setValue(value: Bool, key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    func getValue(for key: Keys) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
    }
}
