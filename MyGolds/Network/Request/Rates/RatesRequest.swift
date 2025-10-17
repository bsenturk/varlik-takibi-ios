//
//  RatesRequest.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

enum RatesRequest: APIRequest {
    case today
    
    var path: String {
        switch self {
        case .today: "/today.json"
        }
    }
    
    var method: APIMethod {
        switch self {
        case .today: .get
        }
    }
}
