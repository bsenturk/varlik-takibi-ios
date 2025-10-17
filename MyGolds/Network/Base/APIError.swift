//
//  APIError.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int)
    case unknown(Error)
    case unauthorized
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz URL"
        case .noData:
            return "Veri bulunamadı"
        case .decodingError(let error):
            return "Veri çözümleme hatası: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP Hatası: \(code)"
        case .unknown(let error):
            return "Bilinmeyen hata: \(error.localizedDescription)"
        case .unauthorized:
            return "Yetkilendirme hatası"
        case .serverError:
            return "Sunucu hatası"
        }
    }
}
