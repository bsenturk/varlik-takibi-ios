//
//  RatesRepository.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

protocol RatesRepositoryProtocol {
    func today(with request: APIRequest) async throws -> RatesResponse
}

final class RatesRepository: RatesRepositoryProtocol {
    
    private let client: APIClientProtocol
    
    init(client: APIClientProtocol) {
        self.client = client
    }
    
    func today(with request: APIRequest) async throws -> RatesResponse {
        try await client.request(request)
    }
}
