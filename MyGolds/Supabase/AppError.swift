//
//  AppError.swift
//  MyGolds
//
//  Unified error type for the network + persistence layers.
//

import Foundation

/// App-wide error type surfaced by the service / repository layers. Conforms to
/// `LocalizedError` so it can be shown directly in alerts.
enum AppError: LocalizedError {
    /// A network / transport failure while talking to Supabase.
    case network(underlying: Error)
    /// The response could not be decoded into the expected model.
    case decoding(underlying: Error)
    /// A local SwiftData persistence failure (save/fetch/delete).
    case persistence(underlying: Error)
    /// The operation succeeded but returned no data where some was expected.
    case empty
    /// Any other, unclassified failure.
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Bağlantı hatası. İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .decoding:
            return "Veriler işlenirken bir sorun oluştu."
        case .persistence:
            return "Veriler kaydedilirken bir sorun oluştu."
        case .empty:
            return "Gösterilecek veri bulunamadı."
        case .unknown:
            return "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
        }
    }

    /// Maps an arbitrary thrown error into a well-typed `AppError` (network/decoding).
    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is DecodingError { return .decoding(underlying: error) }
        if let urlError = error as? URLError { return .network(underlying: urlError) }
        return .unknown(underlying: error)
    }
}
