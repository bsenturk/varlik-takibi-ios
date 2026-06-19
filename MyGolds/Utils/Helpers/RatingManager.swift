//
//  RatingManager.swift
//  MyGolds
//
//  Decides *when* to ask for an App Store rating. Apple already caps the native
//  prompt to 3×/year; on top of that we ask at most once per app version, only
//  after real engagement (app opened on ≥3 distinct days AND the user holds ≥2
//  assets), at a calm moment, and never during onboarding or while a full-screen
//  ad is on screen.
//

import StoreKit
import UIKit

@MainActor
final class RatingManager {
    static let shared = RatingManager()
    private init() {}

    // MARK: - Tuning
    private let minDistinctOpenDays = 3
    private let minAssetCount = 2
    /// Extra safety gap on top of the per-version gate (days).
    private let minDaysBetweenPrompts = 120

    // MARK: - Storage
    private let ud = UserDefaults.standard
    private enum Key {
        static let distinctOpenDays = "rating_distinct_open_days"   // [String] "yyyy-MM-dd"
        static let lastPromptVersion = "rating_last_prompt_version"
        static let lastPromptDate    = "rating_last_prompt_date"
    }

    // MARK: - Engagement tracking

    /// Records that the app was opened today (deduped per calendar day). Call on
    /// each cold launch / foreground.
    func recordAppOpen() {
        let today = Self.dayKey(Date())
        var days = ud.stringArray(forKey: Key.distinctOpenDays) ?? []
        guard !days.contains(today) else { return }
        days.append(today)
        if days.count > 30 { days = Array(days.suffix(30)) } // keep bounded
        ud.set(days, forKey: Key.distinctOpenDays)
    }

    // MARK: - Prompt

    /// Asks for a review when every engagement + gating condition is met. Safe to
    /// call often (e.g. on the Portfolio screen appearing) — it self-gates.
    /// - Parameter assetCount: current number of assets the user holds.
    func requestReviewIfAppropriate(assetCount: Int) {
        // Engagement thresholds.
        let distinctDays = (ud.stringArray(forKey: Key.distinctOpenDays) ?? []).count
        guard distinctDays >= minDistinctOpenDays, assetCount >= minAssetCount else { return }

        // Not during onboarding.
        guard UserDefaultsManager.shared.getValue(for: .hasSeenOnboarding) else { return }

        // Not while a full-screen ad is on screen (calm moment only).
        guard !AppOpenAdManager.shared.isAdShowing,
              !InterstitialAdManager.shared.isAdShowing else { return }

        // At most once per app version.
        let version = Self.appVersion
        guard ud.string(forKey: Key.lastPromptVersion) != version else { return }

        // Safety gap between any two prompts.
        if let last = ud.object(forKey: Key.lastPromptDate) as? Date,
           Date().timeIntervalSince(last) < TimeInterval(minDaysBetweenPrompts) * 86_400 {
            return
        }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        ud.set(version, forKey: Key.lastPromptVersion)
        ud.set(Date(), forKey: Key.lastPromptDate)
        Logger.log("⭐️ Rating: requested review (version \(version), days \(distinctDays), assets \(assetCount))")
    }

    // MARK: - Helpers

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
