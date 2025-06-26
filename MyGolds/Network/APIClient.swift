//
//  APIClient.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 17.02.2024.
//

import Foundation
import Combine

protocol APIClientProtocol: AnyObject {
    func call<T: Decodable>(request: APIRequest) -> AnyPublisher<T, HTTPErrors>
}

final class APIClient: APIClientProtocol {
    private let session = URLSession.shared
    
    func call<T>(request: APIRequest) -> AnyPublisher<T, HTTPErrors> where T: Decodable {
        guard var urlComponents = URLComponents(string: request.baseUrl) else {
            return Fail(error: HTTPErrors.invalidUrl).eraseToAnyPublisher()
        }
        urlComponents.scheme = request.scheme
        urlComponents.path = request.path
        urlComponents.queryItems = request.urlQueryItems
        
        guard let url =  urlComponents.url else {
            return Fail(error: HTTPErrors.invalidUrl).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body?.toJSONData()
        
        return session
            .dataTaskPublisher(for: urlRequest)
            .mapError { HTTPErrors(rawValue: $0.errorCode) ?? .unknown }
            .tryMap { [weak self] data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    try? self?.handleResponseError(httpResponse: httpResponse)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { $0 as? HTTPErrors ?? .unknown }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func handleResponseError(httpResponse: HTTPURLResponse) throws {
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else { throw HTTPErrors(rawValue: httpResponse.statusCode) ?? .unknown }
    }
}
