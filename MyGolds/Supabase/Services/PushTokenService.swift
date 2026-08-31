//
//  PushTokenService.swift
//  MyGolds
//
//  Syncs this device's FCM token to Supabase so a backend job can push
//  notifications to every device with notifications enabled. The app is
//  anonymous (no auth), so devices are identified by `identifierForVendor`.
//  Writes go through SECURITY DEFINER RPCs (not a direct table upsert) so
//  anon never gets table-level SELECT/INSERT/UPDATE on `device_tokens` —
//  that would otherwise leak every device's FCM token to anyone with the
//  public anon key.
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

private struct RegisterDeviceTokenParams: Encodable {
    let p_device_id: String
    let p_fcm_token: String
    let p_platform: String
    let p_notifications_enabled: Bool
}

private struct SetDeviceTokenEnabledParams: Encodable {
    let p_device_id: String
    let p_enabled: Bool
}

enum PushTokenService {
    /// Sunucuya en son BAŞARIYLA yazdığımız durum ("deviceId|token|enabled").
    /// `refresh` her foreground'da çağrıldığı için, değişmeyen durumu tekrar
    /// tekrar yazmayı engelliyor. Başarısız RPC işaretlenmez, bir sonraki
    /// foreground'da yeniden denenir.
    private static let lastSyncedKey = "push_token_last_synced_state"

    /// Elimizdeki FCM token'ını, izin durumunu sistemden okuyarak sunucuya yazar.
    ///
    /// Bu metot olmadan `notifications_enabled = true` yazan hiçbir yol yoktu:
    /// `syncToken` sadece FCM token *üretildiğinde/yenilendiğinde* tetikleniyor,
    /// ilk kurulumda da bu kullanıcı izni vermeden önce oluyordu. Kayıt
    /// `enabled = false` olarak kalıyor ve cihaz hiç bildirim almıyordu.
    /// Silip yeniden kurmada `identifierForVendor` de değiştiği için tertemiz
    /// (ve yine kapalı) bir satır açılıyordu — bildirimlerin gelmemesinin sebebi.
    static func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let enabled = settings.authorizationStatus == .authorized
            guard enabled else {
                // İzin yoksa token istemenin anlamı yok; yalnızca bayrağı düşür.
                setEnabled(false)
                return
            }
            Messaging.messaging().token { token, error in
                guard let token else {
                    Logger.log("📱 Push token alınamadı: \(error?.localizedDescription ?? "-")")
                    return
                }
                syncToken(token, enabled: true)
            }
        }
    }

    /// Registers/updates the current FCM token, e.g. when Firebase (re)issues one.
    static func syncToken(_ fcmToken: String, enabled: Bool) {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        let state = "\(deviceId)|\(fcmToken)|\(enabled)"
        guard UserDefaults.standard.string(forKey: lastSyncedKey) != state else { return }
        let params = RegisterDeviceTokenParams(
            p_device_id: deviceId,
            p_fcm_token: fcmToken,
            p_platform: "ios",
            p_notifications_enabled: enabled
        )
        Task {
            do {
                try await SupabaseManager.shared.client
                    .rpc("register_device_token", params: params)
                    .execute()
                UserDefaults.standard.set(state, forKey: lastSyncedKey)
                Logger.log("📱 Push token synced (enabled: \(enabled))")
            } catch {
                Logger.log("📱 Push token sync failed: \(error)")
            }
        }
    }

    /// Flips this device's `notifications_enabled` flag, e.g. when the user
    /// revokes notification permission. No-ops if no token was ever synced.
    static func setEnabled(_ enabled: Bool) {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        let params = SetDeviceTokenEnabledParams(p_device_id: deviceId, p_enabled: enabled)
        Task {
            do {
                try await SupabaseManager.shared.client
                    .rpc("set_device_token_enabled", params: params)
                    .execute()
                // Durum değişti; `syncToken`'ın dedupe önbelleği artık geçersiz.
                UserDefaults.standard.removeObject(forKey: lastSyncedKey)
                Logger.log("📱 Push token enabled flag set to \(enabled)")
            } catch {
                Logger.log("📱 Push token enable-flag update failed: \(error)")
            }
        }
    }
}
