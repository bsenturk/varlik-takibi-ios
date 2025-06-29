//
//  AppLifecycleObserver.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

import SwiftUI

class AppLifecycleObserver: ObservableObject {
    static let shared = AppLifecycleObserver()
    
    @Published var isActive = true
    private let appOpenAdManager = AppOpenAdManager.shared
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        DispatchQueue.main.async {
            self.isActive = true
        }
        
        // Show app open ad when app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.appOpenAdManager.showAdIfAvailable()
        }
    }
    
    @objc private func appWillResignActive() {
        DispatchQueue.main.async {
            self.isActive = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
