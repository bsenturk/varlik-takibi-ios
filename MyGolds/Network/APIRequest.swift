//
//  APIRequest.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 17.02.2024.
//

import Foundation

protocol APIRequest {
    var scheme: String { get }
    var baseUrl: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var body: Encodable? { get }
    var header: [String: String] { get }
    var queryItems: [String: Any?]? { get }
    var urlQueryItems: [URLQueryItem]? { get }
}

extension APIRequest {
    var scheme: String {
        "https"
    }
    
    var baseUrl: String {
        "Constants.API.baseUrl"
    }
    
    var body: Encodable? {
        nil
    }
    
    var header: [String: String] {
        [
            "content-type": "application/json",
            "authorization": "apikey \("Constants.API.apiKey")"
        ]
    }
    
    var queryItems: [String: Any?]? {
        nil
    }
    
    var urlQueryItems: [URLQueryItem]? {
        queryItems?.map { URLQueryItem(name: $0, value: $1 as? String) }
    }
}

extension Encodable {
    func toJSONData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
