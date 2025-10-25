//
//  APIRequest.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

import Foundation

protocol APIRequest {
    var baseURL: String { get }
    var path: String { get }
    var method: APIMethod { get }
    var headers: [String: String]? { get }
    var parameters: [String: Any]? { get }
    var body: Data? { get }
}

extension APIRequest {
    var baseURL: String {
        "https://finans.truncgil.com/v3"
    }
    
    var headers: [String: String]? { nil }
    var parameters: [String: Any]? { nil }
    var body: Data? { nil }
    
    func asURLRequest() throws -> URLRequest {
        var urlString = baseURL + path
        
        if let parameters {
            var components = URLComponents(string: urlString)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            guard let url = components?.url else {
                throw APIError.invalidURL
            }
            urlString = url.absoluteString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Headers ekle
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body ekle
        if method != .get, let parameters = parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        } else if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}
