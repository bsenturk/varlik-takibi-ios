//
//  PrivacyPolicyView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gizlilik Politikası")
                            .font(.title.bold())
                        
                        Text("Son güncelleme: 27 Haziran 2024")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 20) {
                        privacySection(
                            title: "Veri Toplama",
                            content: "Varlık Takibi uygulaması, sadece sizin eklediğiniz varlık bilgilerini cihazınızda saklar. Hiçbir kişisel bilginiz sunucularımıza gönderilmez."
                        )
                        
                        privacySection(
                            title: "Veri Güvenliği",
                            content: "Tüm verileriniz cihazınızda şifrelenerek saklanır. Verilerinize sadece siz erişebilirsiniz ve hiçbir üçüncü tarafla paylaşılmaz."
                        )
                        
                        privacySection(
                            title: "Kur Bilgileri",
                            content: "Güncel kur bilgileri, kur.doviz.com ve altin.doviz.com sitelerinden anonim olarak çekilir. Bu işlem sırasında hiçbir kişisel bilginiz paylaşılmaz."
                        )
                        
                        privacySection(
                            title: "Analitik",
                            content: "Uygulama performansını iyileştirmek için anonim kullanım istatistikleri toplanabilir. Bu veriler kişisel kimlik bilgilerinizle ilişkilendirilmez."
                        )
                        
                        privacySection(
                            title: "İletişim",
                            content: "Gizlilik politikamızla ilgili sorularınız için buraksenturktr@icloud.com adresinden bizimle iletişime geçebilirsiniz."
                        )
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
