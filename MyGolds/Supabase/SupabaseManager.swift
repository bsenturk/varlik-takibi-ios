//
//  SupabaseManager.swift
//  MyGolds
//
//  Single entry point to Supabase. In the hybrid architecture Supabase is used
//  ONLY to read live market prices — the app is fully anonymous (no auth) and
//  never writes user data to the backend.
//

import Foundation
import Supabase

/// Thread-safe singleton wrapping the configured `SupabaseClient`.
///
/// `SupabaseClient` is `Sendable` and the stored `client` is immutable, so this
/// type is safe to share across actors.
final class SupabaseManager: @unchecked Sendable {

    static let shared = SupabaseManager()

    /// The configured Supabase client. Prefer injecting the concrete services
    /// (e.g. `MarketDataService`) into view models rather than this singleton.
    let client: SupabaseClient

    // MARK: - Configuration

    // Project URL is public. The anon/publishable key is safe to ship (RLS only
    // allows SELECT on assets_prices) but should ideally come from a
    // non-committed xcconfig / Info.plist key rather than a hard-coded constant.
    // TODO: Paste the anon key from Dashboard → Settings → API Keys → "anon".
    private static let supabaseURL = URL(string: "https://bpiclzhpxkmnqxqvlnmu.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwaWNsemhweGttbnF4cXZsbm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4MTc5MDksImV4cCI6MjA5NjM5MzkwOX0.lgCoFANxEdZ2MCe0TM3VjCaCrwhPfETXPmc4UNtdxrU"

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(
                    encoder: Self.makeEncoder(),
                    decoder: Self.makeDecoder()
                )
            )
        )
    }

    // MARK: - JSON configuration

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Decoder that tolerates the timestamp formats PostgREST returns
    /// (with/without fractional seconds).
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatters: [ISO8601DateFormatter] = {
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return [withFractional, plain]
        }()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            for formatter in formatters {
                if let date = formatter.date(from: raw) { return date }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(raw)"
            )
        }
        return decoder
    }
}
