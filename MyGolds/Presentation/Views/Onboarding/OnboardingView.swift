//
//  OnboardingView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import AppTrackingTransparency

struct OnboardingView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var currentStep = 0
    @State private var showATTPermission = false
    
    private let steps = [
        OnboardingStep(
            icon: "wallet.pass.fill",
            title: "Varlık Takibi'ne Hoş Geldiniz",
            description: "Altın, döviz ve diğer varlıklarınızı kolayca takip edin. Güncel kurlarla toplam değerinizi anında görün.",
            gradientColors: [.blue, .purple]
        ),
        OnboardingStep(
            icon: "plus.circle.fill",
            title: "Varlık Ekleyin",
            description: "Gram altın, çeyrek altın, dolar, euro gibi 12 farklı varlık türünü ekleyebilir ve miktarlarını girebilirsiniz.",
            gradientColors: [.green, .teal]
        ),
        OnboardingStep(
            icon: "chart.line.uptrend.xyaxis",
            title: "Kurları Takip Edin",
            description: "Güncel alış-satış kurlarını görün. Değişim oranlarını takip ederek piyasa hareketlerini kaçırmayın.",
            gradientColors: [.orange, .red]
        )
    ]
    
    var body: some View {
        if showATTPermission {
            ATTPermissionView(
                onPermissionGranted: { granted in
                    showATTPermission = false
                    coordinator.onboardingCompleted()
                }
            )
        } else {
            VStack {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: steps[currentStep].gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: steps[currentStep].gradientColors.first?.opacity(0.3) ?? .clear, radius: 20, x: 0, y: 10)
                    
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 40)
                
                // Content
                VStack(spacing: 16) {
                    Text(steps[currentStep].title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 60)
                
                // Step Indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? .blue : .gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: nextStep) {
                        Text(currentStep == steps.count - 1 ? "Devam Et" : "Devam Et")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.blue)
                            .cornerRadius(16)
                    }
                    
                    if currentStep < steps.count - 1 {
                        Button(action: {
                            showATTPermission = ATTrackingManager.trackingAuthorizationStatus == .notDetermined
                            if !showATTPermission {
                                coordinator.onboardingCompleted()
                            }
                        }) {
                            Text("Atla")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            showATTPermission = ATTrackingManager.trackingAuthorizationStatus == .notDetermined
            if !showATTPermission {
                coordinator.onboardingCompleted()
            }
        }
    }
}
