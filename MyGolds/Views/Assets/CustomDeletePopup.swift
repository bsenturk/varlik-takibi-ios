//
//  CustomDeletePopup.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI

struct CustomDeletePopup: View {
    @Environment(\.colorScheme) var colorScheme
    let assetName: String
    @Binding var isPresented: Bool
    let onDelete: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 12) {
                    Text("Varlık Sil")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("\(assetName) varlığınızı silmek istediğinizden emin misiniz?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        dismissPopup()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onDelete()
                        }
                    }) {
                        Text("Sil")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismissPopup()
                    }) {
                        Text("Vazgeç")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                    .shadow(
                        color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            showPopup()
        }
    }
    
    private func showPopup() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scale = 1.0
            opacity = 1.0
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func dismissPopup() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.8
            opacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}
