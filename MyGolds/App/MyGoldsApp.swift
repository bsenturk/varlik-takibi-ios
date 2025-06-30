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
                .preferredColorScheme(userDefaults.darkModePreference.colorScheme) // Dark Mode desteği
                .onChange(of: lifecycleObserver.scenePhase) { newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        Logger.log("🚀 App: Initial setup")
        
        // Don't show banner immediately on first launch
        adManager.hideBanner()
        
        // Show banner after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            adManager.showBannerAd()
        }
        
        // Check notification status on app launch
        notificationManager.checkAuthorizationStatus()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        Logger.log("🔄 Scene phase changed to: \(newPhase)")
        lifecycleObserver.handleScenePhaseChange(newPhase)
        
        switch newPhase {
        case .active:
            Logger.log("🔄 App became active")
            
            // App Open Ad'ı burada tetikle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Logger.log("🔄 Attempting to show App Open Ad due to scene phase change")
                appOpenAdManager.showAdIfAvailable()
            }
            
            // Her uygulama açılışında bildirim schedule'ını güncelle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                notificationManager.scheduleNextNotificationOnAppLaunch()
            }
            
        case .inactive:
            Logger.log("🔄 App became inactive")
            
        case .background:
            Logger.log("🔄 App entered background")
            
        @unknown default:
            break
        }
    }
}
