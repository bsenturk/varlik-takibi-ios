//
//  NotificationManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import UserNotifications
import Foundation
import SwiftUICore

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // UserDefaults Keys
    private let permissionGrantDateKey = "notification_permission_grant_date"
    private let lastScheduledNotificationDateKey = "last_scheduled_notification_date"
    private let notificationIdentifierKey = "portfolio_reminder_notification"
    
    // Notification settings
    private let notificationHour = 10 // Sabah 10:00
    private let notificationMinute = 0
    private let initialDelayDays = 2 // İzin verildikten 2 gün sonra
    private let recurringIntervalDays = 3 // Her 3 günde bir
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
                
                if self.isAuthorized {
                    // İzin varsa ve daha önce izin tarihi kaydedilmemişse, şimdi kaydet
                    self.savePermissionGrantDateIfNeeded()
                    // Her uygulama açılışında bildirim schedule'ını güncelle
                    self.scheduleNextNotificationOnAppLaunch()
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
                    
                    // İzin verildiği tarihi kaydet
                    self?.savePermissionGrantDate()
                    
                    // İlk bildirimi schedule et (2 gün sonra)
                    self?.scheduleInitialNotification()
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
    
    // MARK: - Date Management
    
    private func savePermissionGrantDate() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: permissionGrantDateKey)
        Logger.log("📱 Notification: Permission grant date saved: \(now)")
    }
    
    private func savePermissionGrantDateIfNeeded() {
        // Eğer daha önce kaydedilmemişse şimdi kaydet
        if UserDefaults.standard.object(forKey: permissionGrantDateKey) == nil {
            savePermissionGrantDate()
        }
    }
    
    private func getPermissionGrantDate() -> Date? {
        return UserDefaults.standard.object(forKey: permissionGrantDateKey) as? Date
    }
    
    private func getLastScheduledNotificationDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastScheduledNotificationDateKey) as? Date
    }
    
    private func saveLastScheduledNotificationDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastScheduledNotificationDateKey)
        Logger.log("📱 Notification: Last scheduled date saved: \(date)")
    }
    
    // MARK: - Scheduling Logic
    
    /// İlk bildirim - izin verildikten 2 gün sonra sabah 10:00
    private func scheduleInitialNotification() {
        guard let grantDate = getPermissionGrantDate() else {
            Logger.log("📱 Notification: No grant date found")
            return
        }
        
        // 2 gün sonraki sabah 10:00'ı hesapla
        let initialNotificationDate = calculateNotificationDate(from: grantDate, daysLater: initialDelayDays)
        
        // Mevcut bildirimleri temizle
        cancelAllNotifications()
        
        // Yeni bildirimi schedule et
        scheduleNotification(for: initialNotificationDate)
        
        // Schedule edilen tarihi kaydet
        saveLastScheduledNotificationDate(initialNotificationDate)
        
        Logger.log("📱 Notification: Initial notification scheduled for: \(initialNotificationDate)")
    }
    
    /// Her uygulama açılışında çağrılır - mevcut schedule'ın üzerine +3 gün ekler
    func scheduleNextNotificationOnAppLaunch() {
        guard isAuthorized else {
            Logger.log("📱 Notification: Not authorized, skipping schedule update")
            return
        }
        
        guard let lastScheduledDate = getLastScheduledNotificationDate() else {
            Logger.log("📱 Notification: No previous notification found, scheduling initial")
            scheduleInitialNotification()
            return
        }
        
        // Son schedule edilen tarihten 3 gün sonrasını hesapla
        let nextNotificationDate = calculateNotificationDate(from: lastScheduledDate, daysLater: recurringIntervalDays)
        
        // Eğer yeni tarih gelecekte ise schedule et
        if nextNotificationDate > Date() {
            // Mevcut bildirimleri temizle
            cancelAllNotifications()
            
            // Yeni bildirimi schedule et
            scheduleNotification(for: nextNotificationDate)
            
            // Yeni tarihi kaydet
            saveLastScheduledNotificationDate(nextNotificationDate)
            
            Logger.log("📱 Notification: Next notification scheduled for: \(nextNotificationDate)")
        } else {
            Logger.log("📱 Notification: Calculated date is in the past, rescheduling from now")
            // Eğer hesaplanan tarih geçmişte kaldıysa, bugünden itibaren yeniden hesapla
            let newDate = calculateNotificationDate(from: Date(), daysLater: recurringIntervalDays)
            
            cancelAllNotifications()
            scheduleNotification(for: newDate)
            saveLastScheduledNotificationDate(newDate)
            
            Logger.log("📱 Notification: Rescheduled notification for: \(newDate)")
        }
    }
    
    /// Belirli bir tarihten X gün sonraki sabah 10:00'ı hesaplar
    private func calculateNotificationDate(from baseDate: Date, daysLater: Int) -> Date {
        let calendar = Calendar.current
        
        // Base tarihten X gün sonrası
        guard let futureDate = calendar.date(byAdding: .day, value: daysLater, to: baseDate) else {
            return baseDate
        }
        
        // O günün sabah 10:00'ı
        let components = DateComponents(
            year: calendar.component(.year, from: futureDate),
            month: calendar.component(.month, from: futureDate),
            day: calendar.component(.day, from: futureDate),
            hour: notificationHour,
            minute: notificationMinute
        )
        
        return calendar.date(from: components) ?? futureDate
    }
    
    /// Belirli bir tarih için bildirim schedule eder
    private func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Varlık Takibi"
        content.body = getRandomNotificationMessage()
        content.sound = .default
        content.badge = 1
        
        // Trigger oluştur
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Request oluştur
        let request = UNNotificationRequest(
            identifier: notificationIdentifierKey,
            content: content,
            trigger: trigger
        )
        
        // Schedule et
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("📱 Notification Error: \(error.localizedDescription)")
            } else {
                Logger.log("📱 Notification: Successfully scheduled for \(date)")
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
    
    /// Tüm bildirimleri iptal eder
    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Logger.log("📱 Notification: All pending notifications cancelled")
    }
    
    /// Sadece kendi bildirimlerimizi iptal eder
    func cancelPortfolioNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifierKey])
        Logger.log("📱 Notification: Portfolio notifications cancelled")
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Debug için - pending notification'ları listeler
    func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                Logger.log("📱 Notification Debug: \(requests.count) pending notifications")
                for request in requests {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let nextTriggerDate = trigger.nextTriggerDate() {
                        Logger.log("📱 Notification: \(request.identifier) scheduled for: \(nextTriggerDate)")
                    }
                }
            }
        }
    }
    
    /// Debug için - manuel test bildirimi (5 saniye sonra)
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Bildirimi"
        content.body = "Bu bir test bildirimidir."
        content.sound = .default
        
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
    
    /// Debug için - bildirim durumunu yazdırır
    func debugNotificationStatus() {
        Logger.log("📱 === NOTIFICATION DEBUG STATUS ===")
        Logger.log("📱 Is Authorized: \(isAuthorized)")
        Logger.log("📱 Authorization Status: \(authorizationStatus)")
        
        if let grantDate = getPermissionGrantDate() {
            Logger.log("📱 Permission Grant Date: \(grantDate)")
        } else {
            Logger.log("📱 Permission Grant Date: Not set")
        }
        
        if let lastScheduled = getLastScheduledNotificationDate() {
            Logger.log("📱 Last Scheduled Date: \(lastScheduled)")
        } else {
            Logger.log("📱 Last Scheduled Date: Not set")
        }
        
        debugPendingNotifications()
        Logger.log("📱 === END NOTIFICATION DEBUG ===")
    }
    #endif
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
