//
//  NotificationManager.swift - Optimized Notification System
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import UserNotifications
import Foundation
import SwiftUI
import UIKit

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // UserDefaults Keys
    private let lastAppOpenDateKey = "last_app_open_date"
    private let nextNotificationDateKey = "next_notification_date"
    private let notificationBaseIdentifier = "portfolio_reminder"
    
    // Notification settings
    private let notificationHour = 10 // Sabah 10:00
    private let notificationMinute = 0
    private let intervalDays = 3 // Her 3 günde bir
    
    private init() {
        checkAuthorizationStatus()
        setupNotificationDelegate()
    }
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
                Logger.log("📱 Notification status: \(settings.authorizationStatus.rawValue)")

                if self.isAuthorized {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    PushTokenService.setEnabled(false)
                }
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    Logger.log("📱 Notification: Permission granted")
                    self?.isAuthorized = true
                    self?.authorizationStatus = .authorized
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    Logger.log("📱 Notification: Permission denied")
                    self?.isAuthorized = false
                    if let error = error {
                        Logger.log("📱 Notification Error: \(error.localizedDescription)")
                    }
                }
                
                // Status'u tekrar kontrol et
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    // MARK: - Smart Notification Scheduling
    
    func handleAppLaunch() {
        guard isAuthorized else {
            Logger.log("📱 Notification: Not authorized, skipping schedule")
            return
        }
        
        let now = Date()
        saveLastAppOpenDate(now)
        
        // Badge'i temizle (uygulama açıldığında)
        clearBadge()
        
        // Akıllı bildirim schedule et
        scheduleSmartNotification()
    }
    
    private func scheduleSmartNotification() {
        let now = Date()
        let calendar = Calendar.current
        
        // En son schedule edilen tarihi al
        if let lastScheduledDate = getNextNotificationDate() {
            // En son schedule edilen tarihten 3 gün sonrasını hesapla
            let nextNotificationDate = calendar.date(byAdding: .day, value: intervalDays, to: lastScheduledDate) ?? lastScheduledDate
            
            // Bu tarih için zaten bildirim var mı kontrol et
            checkAndScheduleIfNeeded(for: nextNotificationDate)
            
            Logger.log("📱 Notification: Last scheduled was \(lastScheduledDate), next will be \(nextNotificationDate)")
        } else {
            // İlk kez schedule ediliyor - bugünden 3 gün sonrası
            let todayAt10AM = calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: now) ?? now
            let firstNotificationDate = calendar.date(byAdding: .day, value: intervalDays, to: todayAt10AM) ?? todayAt10AM
            
            checkAndScheduleIfNeeded(for: firstNotificationDate)
            
            Logger.log("📱 Notification: First time scheduling for \(firstNotificationDate)")
        }
    }
    
    private func checkAndScheduleIfNeeded(for targetDate: Date) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            let calendar = Calendar.current
            let targetDateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            
            // Aynı günde pending bildirim var mı kontrol et
            let hasSameDayNotification = requests.contains { request in
                guard request.identifier.contains(self.notificationBaseIdentifier),
                      let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let triggerDate = trigger.nextTriggerDate() else {
                    return false
                }
                
                let triggerComponents = calendar.dateComponents([.year, .month, .day], from: triggerDate)
                return targetDateComponents.year == triggerComponents.year &&
                       targetDateComponents.month == triggerComponents.month &&
                       targetDateComponents.day == triggerComponents.day
            }
            
            if hasSameDayNotification {
                Logger.log("📱 Notification: Same day notification already exists for \(targetDate), skipping")
            } else {
                DispatchQueue.main.async {
                    self.scheduleNotification(for: targetDate)
                    self.saveNextNotificationDate(targetDate)
                    Logger.log("📱 Notification: Successfully scheduled new notification for \(targetDate)")
                }
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Varlık Takibi"
        content.body = getRandomNotificationMessage()
        content.sound = .default
        content.badge = 1
        
        // Unique identifier with day stamp
        let calendar = Calendar.current
        let dayStamp = calendar.dateComponents([.year, .month, .day], from: date)
        let identifier = "\(notificationBaseIdentifier)_\(dayStamp.year ?? 0)_\(dayStamp.month ?? 0)_\(dayStamp.day ?? 0)"
        
        // Trigger oluştur - Her gün sabah 10:00 için
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = notificationHour
        components.minute = notificationMinute
        components.second = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Request oluştur
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule et
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("📱 Notification Error: \(error.localizedDescription)")
            } else {
                Logger.log("📱 Notification: Successfully scheduled for \(date) at 10:00 AM with ID: \(identifier)")
            }
        }
    }
    
    // MARK: - Date Management
    
    private func saveLastAppOpenDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastAppOpenDateKey)
        Logger.log("📱 Notification: Last app open date saved: \(date)")
    }
    
    private func getLastAppOpenDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastAppOpenDateKey) as? Date
    }
    
    private func saveNextNotificationDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: nextNotificationDateKey)
        Logger.log("📱 Notification: Next notification date saved: \(date)")
    }
    
    private func getNextNotificationDate() -> Date? {
        return UserDefaults.standard.object(forKey: nextNotificationDateKey) as? Date
    }
    
    // MARK: - Badge Management
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                Logger.log("📱 Notification: Badge clear error - \(error.localizedDescription)")
            } else {
                Logger.log("📱 Notification: Badge cleared")
            }
        }
    }
    
    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                Logger.log("📱 Notification: Badge set error - \(error.localizedDescription)")
            } else {
                Logger.log("📱 Notification: Badge set to \(count)")
            }
        }
    }
    
    // MARK: - Notification Messages
    
    private func getRandomNotificationMessage() -> String {
        let messages = [
            "💰 Varlıklarınızı takip edin! Güncel değerlerini kontrol etmeyi unutmayın.",
            "📈 Güncel kurları görün! Piyasa hareketlerini kaçırmayın.",
            "🔔 Portföyünüzü güncellemek için harika bir zaman!",
            "💎 Altın ve döviz kurlarında değişiklikler var. Hemen kontrol edin!",
            "🏆 Yatırımlarınızın güncel durumunu kontrol etme zamanı!",
            "📊 Varlık portföyünüzde bugün hangi değişiklikler var?",
            "⭐ Güncel piyasa verilerini kaçırmayın, şimdi kontrol edin!",
            "🎯 Portföyünüzün performansını takip etmeyi unutmayın!"
        ]
        
        return messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Utility Methods
    
    func cancelAllPortfolioNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let portfolioNotificationIds = requests
                .filter { $0.identifier.contains(self.notificationBaseIdentifier) }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: portfolioNotificationIds)
            Logger.log("📱 Notification: Cancelled \(portfolioNotificationIds.count) portfolio notifications")
            
            // UserDefaults'u temizle
            UserDefaults.standard.removeObject(forKey: self.nextNotificationDateKey)
        }
    }
    
    func cleanupOldNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let now = Date()
            
            let expiredIds = requests.compactMap { request -> String? in
                guard request.identifier.contains(self.notificationBaseIdentifier),
                      let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let triggerDate = trigger.nextTriggerDate() else {
                    return nil
                }
                
                // Geçmiş tarihli bildirimleri temizle
                return triggerDate < now ? request.identifier : nil
            }
            
            if !expiredIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIds)
                Logger.log("📱 Notification: Cleaned up \(expiredIds.count) expired notifications")
            }
        }
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let portfolioRequests = requests.filter { $0.identifier.contains(self.notificationBaseIdentifier) }
                Logger.log("📱 Notification Debug: \(portfolioRequests.count) pending portfolio notifications")
                
                for request in portfolioRequests {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let nextTriggerDate = trigger.nextTriggerDate() {
                        Logger.log("📱 Notification: \(request.identifier) scheduled for: \(nextTriggerDate)")
                    }
                }
                
                if let nextDate = self.getNextNotificationDate() {
                    Logger.log("📱 Notification: Stored next date: \(nextDate)")
                }
            }
        }
    }
    
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Bildirimi"
        content.body = "Bu bir test bildirimidir."
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("📱 Test Notification Error: \(error.localizedDescription)")
            } else {
                Logger.log("📱 Test Notification: Scheduled for 5 seconds from now")
            }
        }
    }
    
    func debugNotificationStatus() {
        Logger.log("📱 === NOTIFICATION DEBUG STATUS ===")
        Logger.log("📱 Is Authorized: \(isAuthorized)")
        Logger.log("📱 Authorization Status: \(authorizationStatus)")
        
        if let lastOpen = getLastAppOpenDate() {
            Logger.log("📱 Last App Open Date: \(lastOpen)")
        } else {
            Logger.log("📱 Last App Open Date: Not set")
        }
        
        if let nextDate = getNextNotificationDate() {
            Logger.log("📱 Next Notification Date: \(nextDate)")
        } else {
            Logger.log("📱 Next Notification Date: Not set")
        }
        
        debugPendingNotifications()
        Logger.log("📱 === END NOTIFICATION DEBUG ===")
    }
    #endif
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Bildirim gösterilirken çağrılır (uygulama foreground'da)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.log("📱 Notification: Will present in foreground")
        completionHandler([.list, .banner, .sound, .badge])
    }
    
    // Bildirime tıklandığında çağrılır
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.log("📱 Notification: User tapped notification")
        
        // Badge'i temizle
        NotificationManager.shared.clearBadge()
        
        completionHandler()
    }
}

// MARK: - Environment Support

private struct NotificationManagerKey: EnvironmentKey {
    static let defaultValue = NotificationManager.shared
}

extension EnvironmentValues {
    var notificationManager: NotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
    }
}
