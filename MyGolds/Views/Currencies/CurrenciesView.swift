//
//  CurrenciesView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 30.04.2024.
//

import SwiftUI

struct CurrenciesView: View {
    @StateObject private var viewModel = CurrenciesViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBrown
                ScrollView {
                    VStack {
                        CurrencyHeaderSectionView()
                        ForEach(viewModel.currencies, id: \.id) { currency in
                            CurrencyRow(currencyModel: currency)
                        }
                        Spacer()
                    }
                }
                .refreshable {
                    viewModel.viewOnAppear()
                }
                
                if viewModel.isLoaderShown {
                    LoaderView()
                }
            }
            
            .navigationTitle("Piyasalar")
            .navigationBarColor(.primaryBrown, .white)
            .onAppear {
                UIRefreshControl.appearance().tintColor = .white
                viewModel.viewOnAppear()
            }
        }
    }
}

#Preview {
    CurrenciesView()
}
