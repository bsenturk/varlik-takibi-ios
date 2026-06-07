//
//  OnboardingView.swift
//  MyGolds
//
//  Redesigned onboarding (v3.0.0): 3 paged screens → ATT → Paywall → app.
//

import SwiftUI
import AppTrackingTransparency

struct OnboardingView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var page = 0
    @State private var phase: Phase = .pages

    private enum Phase { case pages, att, paywall }

    private let pageCount = 3

    var body: some View {
        switch phase {
        case .att:
            ATTPermissionView(onPermissionGranted: { _ in
                withAnimation { phase = .paywall }
            })
        case .paywall:
            PaywallView(onClose: { coordinator.onboardingCompleted() })
        case .pages:
            pagesView
        }
    }

    private var pagesView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Atla") { finishPages() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                OnboardingPage(
                    mock: AnyView(WelcomeMock()),
                    title: "Varlıklarını Tek Yerde Topla",
                    description: "Altın, döviz ve daha fazlasını tek bir uygulamada kolayca takip edin."
                ).tag(0)

                OnboardingPage(
                    mock: AnyView(FolderMock()),
                    title: "Farklı Amaçlar,\nFarklı Portföyler",
                    description: "Emeklilik, ev peşinatı ya da günlük takip. Hedeflerinize göre sınırsız portföy oluşturun."
                ).tag(1)

                OnboardingPage(
                    mock: AnyView(ChartMock()),
                    title: "Detaylı Analiz ile\nBüyümeyi Takip Et",
                    description: "Dağılım grafikleri ve zaman bazlı analizlerle varlıklarınızın seyrini yakından izleyin."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pageCount, index: page)
                .padding(.bottom, 20)

            Button(action: advance) {
                Text("Devam Et")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            finishPages()
        }
    }

    private func finishPages() {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            withAnimation { phase = .att }
        } else {
            withAnimation { phase = .paywall }
        }
    }
}

// MARK: - Page scaffold

private struct OnboardingPage: View {
    let mock: AnyView
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            mock
                .frame(maxWidth: .infinity)
                .frame(height: 280)
            Spacer()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: index)
            }
        }
    }
}

// MARK: - Mock illustrations

private let onboardGradient = LinearGradient(
    colors: [Color(hex: "#007AFF"), Color(hex: "#AF52DE")],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

private struct WelcomeMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Toplam Bakiye").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.85))
            Text("₺1.250.430").font(.system(size: 30, weight: .heavy)).foregroundColor(.white)
            HStack(spacing: 6) {
                Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold))
                Text("%0,29 · Bugün").font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.2)).clipShape(Capsule())
        }
        .padding(22)
        .frame(width: 270, alignment: .leading)
        .background(onboardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 18, x: 0, y: 12)
        .rotationEffect(.degrees(-4))
    }
}

private struct FolderMock: View {
    var body: some View {
        // Symmetric fan: one card angled left, one angled right, the front card centered lower
        // so both back cards' icons + names stay visible above it.
        ZStack {
            folderCard(name: "Araba", amount: "₺420B", colorHex: "#FF9500")
                .scaleEffect(0.88)
                .rotationEffect(.degrees(-18), anchor: .bottom)
                .offset(x: -66, y: -34)
            folderCard(name: "Emeklilik", amount: "₺2,84M", colorHex: "#AF52DE")
                .scaleEffect(0.88)
                .rotationEffect(.degrees(18), anchor: .bottom)
                .offset(x: 66, y: -34)
            folderCard(name: "Ev Peşinatı", amount: "₺684B", colorHex: "#007AFF")
                .offset(y: 82)
        }
    }

    private func folderCard(name: String, amount: String, colorHex: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: colorHex).opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "folder.fill").foregroundColor(Color(hex: colorHex)))
            Text(name).font(.system(size: 17, weight: .bold))
            Text(amount).font(.system(size: 14)).foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 176, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)
    }
}

private struct ChartMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toplam Değer").font(.system(size: 12)).foregroundColor(.secondary)
                    Text("₺1.250.430").font(.system(size: 20, weight: .heavy))
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.up.fill").font(.system(size: 9))
                    Text("%46,2").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.green)
            }
            SparklineView(
                values: [10, 12, 11, 14, 16, 15, 19, 22, 21, 26, 30, 34],
                lineColor: Color(hex: "#FF2D55")
            )
            .frame(height: 90)
        }
        .padding(20)
        .frame(width: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
    }
}
