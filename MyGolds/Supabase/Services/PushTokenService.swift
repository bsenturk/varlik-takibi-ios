//
//  PushTokenService.swift
//  MyGolds
//
//  Syncs this device's FCM token to Supabase so a backend job can push
//  notifications to every device with notifications enabled. The app is
//  anonymous (no auth), so devices are identified by `identifierForVendor`.
//

import Foundation
import UIKit

private struct DeviceTokenPayload: Encodable {
    let device_id: String
    let fcm_token: String
    let platform: String
    let notifications_enabled: Bool
}

enum PushTokenService {
    /// Upserts the current FCM token, e.g. when Firebase (re)issues one.
    static func syncToken(_ fcmToken: String, enabled: Bool) {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        let payload = DeviceTokenPayload(
            device_id: deviceId,
            fcm_token: fcmToken,
            platform: "ios",
            notifications_enabled: enabled
        )
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("device_tokens")
                    .upsert(payload, onConflict: "device_id")
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
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("device_tokens")
                    .update(["notifications_enabled": enabled])
                    .eq("device_id", value: deviceId)
                    .execute()
                Logger.log("📱 Push token enabled flag set to \(enabled)")
            } catch {
                Logger.log("📱 Push token enable-flag update failed: \(error)")
            }
        }
    }
}
