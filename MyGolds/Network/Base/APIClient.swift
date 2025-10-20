//
//  APIClient.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

import Foundation

protocol APIClientProtocol {
    func request<T: Decodable>(_ request: APIRequest) async throws -> T
}

final class APIClient: APIClientProtocol {
    
    let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(_ request: APIRequest) async throws -> T {
        let request = try request.asURLRequest()
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(NSError(domain: "Invalid response", code: -1))
        }
        
        try validateResponse(httpResponse)
        
        do {
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.httpError(response.statusCode)
        }
    }
}
