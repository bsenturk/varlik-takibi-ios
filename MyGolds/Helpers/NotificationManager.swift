//
//  NotificationManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import UserNotifications
import Foundation

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.scheduleNotifications()
                }
            }
        }
    }
    
    private func scheduleNotifications() {
        let messages = [
            "💰 Varlıklarınızı takip edin! Güncel değerlerini kontrol etmeyi unutmayın.",
            "📈 Güncel kurları görün! Piyasa hareketlerini kaçırmayın.",
            "🔔 Portföyünüzü güncellemek için harika bir zaman!",
            "💎 Altın ve döviz kurlarında değişiklikler var. Hemen kontrol edin!"
        ]
        
        for (index, message) in messages.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Varlık Defterim"
            content.body = message
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(5 + index * 86400 * 2), repeats: false)
            
            let request = UNNotificationRequest(identifier: "reminder_\(index)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
}
