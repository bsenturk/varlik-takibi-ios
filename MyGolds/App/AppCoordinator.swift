//
//  AppCoordinator.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

final class AppCoordinator: ObservableObject {
    @Published private var isOnboardingCompleted: Bool = false
    
    init() {
        self.isOnboardingCompleted = UserDefaultsManager.shared.getValue(for: .hasSeenOnboarding)
    }
    
    func start() -> some View {
        if !isOnboardingCompleted {
            return AnyView(OnboardingView())
        } else {
            return AnyView(MainTabView())
        }
    }
    
    func onboardingCompleted() {
        isOnboardingCompleted = true
        UserDefaultsManager.shared.setValue(value: true, key: .hasSeenOnboarding)
    }
}
