//
//  OnboardingThreeView.swift
//  ERA
//
//  Created by AJ Picard on 8/30/25.
//

import SwiftUI
import UserNotifications

struct OnboardingThreeView: View {
    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]
    private let ringSizes: [CGFloat] = [44, 64, 86, 108]
    private let ringOpacities: [Double] = [0.70, 0.5, 0.3, 0.15]
    @State private var ringsAnimated = false
    @State private var navigateToFour = false
    @State private var navigateHome = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Animated Circles
                ZStack {
                    ForEach(ringSizes.indices, id: \.self) { i in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "CBAACB", opacity: ringOpacities[i]),
                                        Color(hex: "FFB5A7", opacity: ringOpacities[i])
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: ringSizes[i], height: ringSizes[i])
                            .scaleEffect(ringScales[i])
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                .onAppear {
                    if !ringsAnimated {
                        ringsAnimated = true
                        Task { await animateRings() }
                    }
                }
                
                VStack(spacing: 30) {
                    Spacer().frame(height: 140)
                    
                    (
                        Text("Want me to be notified when to take a moment to breath with ")
                            .foregroundColor(.black)
                        +
                        Text("Era")
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    
                    // Notify Button
                    Button {
                        requestNotifications()
                    } label: {
                        Text("Notify")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 40)
                    
                    // Skip Button
                    Button {
                        navigateHome = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                
                // Navigation
                NavigationLink(destination: OnboardingFourView(),
                               isActive: $navigateToFour) { EmptyView() }
                NavigationLink(destination: ContentView()
                                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext),
                               isActive: $navigateHome) { EmptyView() }
            }
        }
    }
    
    private func animateRings() async {
        for i in 0..<ringScales.count {
            Task {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    ringScales[i] = 1.1
                }
            }
        }
    }
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { success, _ in
            DispatchQueue.main.async {
                if success {
                    navigateToFour = true
                } else {
                    navigateHome = true
                }
            }
        }
    }
}
