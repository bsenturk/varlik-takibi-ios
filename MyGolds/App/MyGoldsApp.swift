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
struct MyGoldsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var coreDataStack = CoreDataStack.shared
    @State private var selection = 0
    
    var body: some Scene {
        WindowGroup {
            TabView {
                AssetsView()
                    .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
                    .tabItem {
                        Label("Varlıklarım", systemImage: "bag.circle")
                    }
                    .tag(0)
                
                CurrenciesView()
                    .tabItem {
                        Label("Piyasalar", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Ayarlar", systemImage: "gearshape")
                    }
                    .tag(2)
            }
            .onAppear {
                UITabBar.appearance().unselectedItemTintColor = .gray
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithOpaqueBackground()
                tabBarAppearance.backgroundColor = .secondaryBrown
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                UITabBar.appearance().standardAppearance = tabBarAppearance
            }
            .tint(Color.white)
        }
    }
}
