//
//  AssetsViewModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class AssetsViewModel: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: RatesRepositoryProtocol
    
    init(repository: RatesRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchRates() {
        Task {
            let request = RatesRequest.today
            do {
                let rates = try await repository.today(with: request)
                print(rates)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    var totalValue: Double {
        assets.reduce(0) { $0 + $1.totalValue }
    }
    
    var percentageChange: Double {
        Double.random(in: -5...5)
    }
}
