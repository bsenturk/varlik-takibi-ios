//
//  NotificationPermissionView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//
//  Onboarding'in bildirim adımı: sistem izin diyalogundan önce gösterilen
//  ön-bilgilendirme ekranı.
//

import SwiftUI
import UIKit
import UserNotifications

struct NotificationPermissionView: View {
    let onPermissionGranted: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            NotificationBannerMock()
                .frame(maxWidth: .infinity)
                .frame(height: 280)

            Spacer()

            VStack(spacing: 14) {
                Text("Piyasa Hareketlerinden\nHaberdar Ol")
                    .font(.system(size: 26, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text("Altın, döviz ve BIST sert hareket ettiğinde anında bildirim al. Fiyatı sürekli kontrol etmene gerek kalmasın.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 40)

            Button(action: requestNotificationPermission) {
                Text("Bildirimleri Aç")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)

            // İzin verme de sistem diyalogunu açar; reddi kullanıcı orada verir,
            // böylece "notDetermined" durumu ekranda takılı kalmaz.
            Button(action: requestNotificationPermission) {
                Text("İzin Verme")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 12)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func requestNotificationPermission() {
        NotificationManager.shared.requestNotificationPermission(completion: onPermissionGranted)
    }
}

// MARK: - Mock illustration

/// Sunucunun gönderdiği gerçek bildirimin (bkz. supabase/functions/market-alert)
/// iOS banner görünümü.
private struct NotificationBannerMock: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            appIcon
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("VARLIK TAKİBİ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 8)
                    Text("şimdi")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text("Piyasalarda hareketlilik")
                    .font(.system(size: 15, weight: .semibold))
                Text("📈 Piyasalarda hareketlilik var, portföyünüzü kontrol etmeyi unutmayın.")
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = UIImage.appIcon {
            Image(uiImage: icon).resizable()
        } else {
            Color.accentColor
        }
    }
}

private extension UIImage {
    /// Asset catalog'daki app icon'u bundle üzerinden okur (Image("AppIcon") çalışmaz).
    static let appIcon: UIImage? = {
        let plistNames = (Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
            .flatMap { $0["CFBundlePrimaryIcon"] as? [String: Any] }
            .flatMap { $0["CFBundleIconFiles"] as? [String] } ?? []
        return (plistNames.reversed() + ["AppIcon60x60", "AppIcon"])
            .lazy.compactMap { UIImage(named: $0) }.first
    }()
}
