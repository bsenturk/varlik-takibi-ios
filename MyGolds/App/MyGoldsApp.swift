//
//  MyGoldsApp.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 16.02.2024.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds
import FirebaseCrashlytics
import AppTrackingTransparency
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        Logger.log("🔧 Firebase configured")
        
        // Start AdMob (handled by AdMobManager)
        Logger.log("🔧 AdMob initialization will be handled by AdMobManager")
        
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        
        return true
    }
}

@main
struct VarlikDefterimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
    @StateObject private var lifecycleObserver = AppLifecycleObserver.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var userDefaults = UserDefaultsManager.shared
    
    // State tracking için
    @State private var lastScenePhase: ScenePhase = .active
    @State private var hasInitialSetupCompleted = false
    @State private var hasHandledInitialAuth = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Asset.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            coordinator.start()
                .environmentObject(coordinator)
                .environmentObject(adManager)
                .environmentObject(appOpenAdManager)
                .environmentObject(lifecycleObserver)
                .environmentObject(notificationManager)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(userDefaults.darkModePreference.colorScheme)
                .onChange(of: lifecycleObserver.scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase, newPhase)
                }
                .onChange(of: notificationManager.isAuthorized) { oldValue, newValue in
                    if newValue && !hasHandledInitialAuth {
                        Logger.log("🔔 Authorization granted, handling app launch")
                        notificationManager.handleAppLaunch()
                        hasHandledInitialAuth = true
                    }
                }
                .onAppear {
                    setupInitialState()
                }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        Logger.log("🚀 App: Initial setup")
        
        // Clear badge on app launch
        notificationManager.clearBadge()
        
        // Don't show banner immediately on first launch
        adManager.hideBanner()
        
        // Show banner after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            adManager.showBannerAd()
        }
        
        // Check notification status on app launch
        notificationManager.checkAuthorizationStatus()
        
        // Handle notification scheduling on app launch if already authorized
        if notificationManager.isAuthorized {
            notificationManager.handleAppLaunch()
            hasHandledInitialAuth = true
        }
        
        hasInitialSetupCompleted = true
    }
    
    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        
        guard hasInitialSetupCompleted else {
            lastScenePhase = newPhase
            return
        }
        
        switch (lastScenePhase, newPhase) {
        case (.active, .inactive):
            Logger.log("🔄 App: Active → Inactive")
            
        case (.inactive, .background):
            Logger.log("🔄 App: Inactive → Background")
            
        case (.background, .inactive):
            Logger.log("🔄 App: Background → Inactive (returning)")
            
        case (.inactive, .active):
            Logger.log("🔄 App: Inactive → Active (returning from background)")
            processAppReturn()
            
        case (.background, .active):
            Logger.log("🔄 App: Background → Active (direct return)")
            processAppReturn()
            
        default:
            Logger.log("🔄 App: Ignored transition \(lastScenePhase) → \(newPhase)")
        }
        
        lastScenePhase = newPhase
        lifecycleObserver.handleScenePhaseChange(newPhase)
    }
    
    private func processAppReturn() {
        Logger.log("🔄 App: Processing return from background")
        
        // Clear badge when app returns
        notificationManager.clearBadge()
        
        // Handle notification scheduling
        if notificationManager.isAuthorized {
            notificationManager.handleAppLaunch()
        }
        
        // App Open Ad'ı göster (arka plandan dönüşte)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Logger.log("🔄 Attempting to show App Open Ad due to background return")
            appOpenAdManager.showAdIfAvailable()
        }
    }
}
