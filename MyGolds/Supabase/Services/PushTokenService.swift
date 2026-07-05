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
    /// Registers/updates the current FCM token, e.g. when Firebase (re)issues one.
    static func syncToken(_ fcmToken: String, enabled: Bool) {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
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
                Logger.log("📱 Push token enabled flag set to \(enabled)")
            } catch {
                Logger.log("📱 Push token enable-flag update failed: \(error)")
            }
        }
    }
}
