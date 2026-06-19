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

        // Configure RevenueCat, then start observing entitlements / offerings.
        PurchaseManager.configure()
        Logger.log("🔧 RevenueCat configured")
        Task { @MainActor in PurchaseManager.shared.start() }

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
    @StateObject private var interstitialAdManager = InterstitialAdManager.shared
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
            AssetPriceHistory.self,
            AssetTransactionHistory.self,
            Portfolio.self,
            PortfolioSnapshot.self
        ])
        let persistent = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // 1) Normal persistent store.
        do {
            return try ModelContainer(for: schema, configurations: [persistent])
        } catch {
            Logger.log("⚠️ ModelContainer failed (\(error)). Attempting store reset.")
            Crashlytics.crashlytics().record(error: error)
        }

        // 2) Migration/corruption recovery: delete the on-disk store (and its
        //    -shm/-wal sidecars) and retry once, so an incompatible schema change
        //    can't hard-crash existing users.
        let storeBase = URL.applicationSupportDirectory.appending(path: "default.store")
        for path in [storeBase.path, storeBase.path + "-shm", storeBase.path + "-wal"] {
            try? FileManager.default.removeItem(atPath: path)
        }
        if let recovered = try? ModelContainer(for: schema, configurations: [persistent]) {
            Logger.log("✅ ModelContainer recovered after store reset.")
            return recovered
        }

        // 3) Last resort: in-memory store so the app still launches (data not persisted).
        Logger.log("⚠️ Falling back to in-memory ModelContainer.")
        do {
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            Crashlytics.crashlytics().record(error: error)
            fatalError("Could not create even an in-memory ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            coordinator.start()
                .environmentObject(coordinator)
                .environmentObject(adManager)
                .environmentObject(appOpenAdManager)
                .environmentObject(interstitialAdManager)
                .environmentObject(lifecycleObserver)
                .environmentObject(notificationManager)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(userDefaults.darkModePreference.colorScheme)
                .onChange(of: lifecycleObserver.scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase, newPhase)
                }
                .onChange(of: notificationManager.isAuthorized) { oldValue, newValue in
                    if newValue && !hasHandledInitialAuth {
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

        // Track distinct-day engagement for the rating prompt.
        RatingManager.shared.recordAppOpen()

        // Create default portfolios & migrate pre-v3.0.0 assets into "Portföyüm"
        PortfolioStore.ensureDefaults(context: sharedModelContainer.mainContext)

        // Backfill `symbol` on legacy rows added before the symbol-based model.
        backfillSymbols()

        // "Time Machine": rebuild any missing daily portfolio snapshots so charts
        // stay continuous. Best-effort & offline-safe (no-ops if prices unavailable).
        Task { @MainActor in
            let repository = PortfolioRepository(context: sharedModelContainer.mainContext)
            let calculator = PortfolioCalculatorService(
                context: sharedModelContainer.mainContext,
                repository: repository,
                marketData: MarketDataService()
            )
            await calculator.reconstructAllPortfolios()
        }

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
        
        // Record daily snapshots for all assets
        recordDailySnapshots()
        
        hasInitialSetupCompleted = true
    }
    
    /// One-time backfill: legacy `Asset` / history rows created before the
    /// symbol-based model have an empty `symbol`. Derive it from the stored
    /// `AssetType` so symbol-keyed lookups work for existing data.
    private func backfillSymbols() {
        let context = sharedModelContainer.mainContext
        var changed = false

        if let assets = try? context.fetch(FetchDescriptor<Asset>()) {
            for asset in assets where asset.symbol.isEmpty {
                asset.symbol = asset.type.supabaseSymbol
                changed = true
            }
        }
        if let history = try? context.fetch(FetchDescriptor<AssetPriceHistory>()) {
            for row in history where row.symbol.isEmpty {
                row.symbol = row.assetType.supabaseSymbol
                changed = true
            }
        }
        if let txns = try? context.fetch(FetchDescriptor<AssetTransactionHistory>()) {
            for row in txns where row.symbol.isEmpty {
                row.symbol = row.assetType.supabaseSymbol
                changed = true
            }
        }

        if changed {
            try? context.save()
            Logger.log("🔁 Backfilled symbol on legacy rows")
        }
    }

    private func recordDailySnapshots() {
        Logger.log("📸 App: Recording daily snapshots")
        
        // Fetch all assets
        let descriptor = FetchDescriptor<Asset>()
        guard let assets = try? sharedModelContainer.mainContext.fetch(descriptor) else {
            Logger.log("📸 App: No assets found to record")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Record snapshot for each asset
        for asset in assets {
            var shouldRecordDailySnapshot = true
            let assetAddedDate = calendar.startOfDay(for: asset.dateAdded)
            
            // 1. Price History kontrolü - Yoksa initial oluştur
            let priceHistory = AssetHistoryManager.shared.getHistory(
                for: asset.symbol,
                context: sharedModelContainer.mainContext
            )
            
            if priceHistory.isEmpty {
                Logger.log("📸 App: No price history for \(asset.name), creating initial price history with original date")
                
                // Mevcut varlık için initial price history oluştur - ORIGINAL DATE KULLAN
                let initialPrice = PortfolioManager.shared.assetPurchasePrices[asset.id] ?? asset.currentPrice
                
                AssetHistoryManager.shared.createInitialSnapshot(
                    for: asset,
                    purchasePrice: initialPrice,
                    modelContext: sharedModelContainer.mainContext
                )
                
                // Eğer varlık bugün eklendiyse, daily snapshot'ı tekrar çağırma
                if assetAddedDate == today {
                    shouldRecordDailySnapshot = false
                    Logger.log("📸 App: Asset \(asset.name) was added today, skipping daily snapshot")
                }
            }
            
            // 2. Transaction history kontrolü - Yoksa initial oluştur
            let transactions = AssetHistoryManager.shared.getTransactionHistory(
                for: asset.symbol,
                context: sharedModelContainer.mainContext
            )
            
            if transactions.isEmpty {
                Logger.log("📝 App: No transaction history for \(asset.name), creating initial transaction with original date")
                
                // Mevcut varlık için initial transaction oluştur - ORIGINAL DATE KULLAN
                let initialPrice = PortfolioManager.shared.assetPurchasePrices[asset.id] ?? asset.currentPrice
                
                // Initial transaction için asset.dateAdded tarihini kullan
                let initialTransaction = AssetTransactionHistory(
                    assetType: asset.type,
                    symbol: asset.symbol,
                    date: asset.dateAdded, // BURADA ORIGINAL DATE KULLANILIYOR
                    transactionType: .initial,
                    amount: asset.amount,
                    totalAmount: asset.amount,
                    price: initialPrice
                )
                
                sharedModelContainer.mainContext.insert(initialTransaction)
                
                // Save transaction
                do {
                    try sharedModelContainer.mainContext.save()
                    Logger.log("📝 App: Created initial transaction for \(asset.name) with date: \(asset.dateAdded)")
                } catch {
                    Logger.log("❌ App: Failed to save initial transaction - \(error)")
                }
            }
            
            // 3. Daily snapshot kaydet (sadece gerekirse)
            if shouldRecordDailySnapshot {
                AssetHistoryManager.shared.recordDailySnapshot(
                    for: asset,
                    modelContext: sharedModelContainer.mainContext
                )
            }
        }
        
        Logger.log("📸 App: Recorded snapshots for \(assets.count) assets")
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
        
        // Record daily snapshots when returning from background
        recordDailySnapshots()
        
        // App Open Ad'ı göster (arka plandan dönüşte)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Logger.log("🔄 Attempting to show App Open Ad due to background return")
            appOpenAdManager.showAdIfAvailable()
        }
    }
}
