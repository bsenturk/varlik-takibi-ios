//
//  NotificationManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//
//  Handles notification permission + remote (push) registration. Actual
//  notifications are server-triggered (see PushTokenService / Supabase
//  `send-push-notification`) — this app has no local-notification scheduling.
//

import UserNotifications
import Foundation
import SwiftUI
import UIKit

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

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

                // Eskiden yalnızca `false` yazılabiliyordu: izin verildiğinde
                // APNs'e kaydolunuyor ama sunucudaki `notifications_enabled`
                // bayrağını true'ya çeviren hiçbir yol yoktu, cihaz kapalı
                // kalıyordu. `refresh` izni sistemden okuyup token'la birlikte
                // doğru durumu yazar (tekrarlarda RPC atmaz).
                if self.isAuthorized {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                PushTokenService.refresh()
            }
        }
    }

    func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                defer { completion?(granted) }

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
