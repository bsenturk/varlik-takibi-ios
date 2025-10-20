//
//  AppLifecycleObserver.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

import SwiftUI
import Combine

class AppLifecycleObserver: ObservableObject {
    static let shared = AppLifecycleObserver()
    
    @Published var isActive = true
    @Published var scenePhase: ScenePhase = .active
    
    private let appOpenAdManager = AppOpenAdManager.shared
    private var backgroundTime: Date?
    private let minimumBackgroundTime: TimeInterval = 1 // TEST İÇİN 1 SANİYE
    
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        DispatchQueue.main.async {
            self.isActive = true
            self.scenePhase = .active
        }
        
        // Check if app was in background long enough to show ad
        if let backgroundTime = backgroundTime {
            let backgroundDuration = Date().timeIntervalSince(backgroundTime)
            
            if backgroundDuration >= minimumBackgroundTime {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.appOpenAdManager.showAdIfAvailable()
                }
            } else {
                Logger.log("🔄 App: Background duration too short (\(backgroundDuration)s < \(minimumBackgroundTime)s)")
            }
        } else {
            appOpenAdManager.preloadAd()
        }
        
        self.backgroundTime = nil
    }
    
    @objc private func appWillResignActive() {
        DispatchQueue.main.async {
            self.isActive = false
            self.scenePhase = .inactive
        }
    }
    
    @objc private func appDidEnterBackground() {
        backgroundTime = Date()
        DispatchQueue.main.async {
            self.scenePhase = .background
        }
    }
    
    @objc private func appWillEnterForeground() {
        DispatchQueue.main.async {
            self.scenePhase = .inactive
        }
    }
    
    // MARK: - Public Methods
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        scenePhase = newPhase
        
        switch newPhase {
        case .active:
            isActive = true
        case .inactive:
            isActive = false
        case .background:
            backgroundTime = Date()
            isActive = false
        @unknown default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
