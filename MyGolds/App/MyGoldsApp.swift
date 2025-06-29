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
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start()
        return true
    }
}

@main
struct VarlikDefterimApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var adManager = AdMobManager.shared
    
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
                .modelContainer(sharedModelContainer)
                .onAppear {
                    adManager.showBannerAd()
                }
        }
    }
}

