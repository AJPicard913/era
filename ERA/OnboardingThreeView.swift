//
//  OnboardingThreeView.swift
//  ERA
//
//  Created by AJ Picard on 8/30/25.
//

import SwiftUI
import UserNotifications

struct OnboardingThreeView: View {
    // Typing states for gradient "Era"
    @State private var typedPrefix: String = ""
    @State private var typedEraCount: Int = 0
    @State private var showQuestionMark: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    // Header pieces
    private let headerPrefix: String = "Want me to be notified when to take a moment to breath with "
    private let headerEra: String = "Era"
    private var fullHeaderString: String { headerPrefix + headerEra + "?" }
    @State private var glowRotation: Angle = .degrees(0)
    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]
    private let ringSizes: [CGFloat] = [24, 36, 48, 60]
    private let ringOpacities: [Double] = [0.70, 0.5, 0.3, 0.15]
    @State private var ringsAnimated = false
    @State private var navigateToFour = false
    @State private var navigateHome = false
    @State private var groupScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Small circles in the top-left
                ZStack {
                    ForEach(ringSizes.indices, id: \.self) { i in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "CBAACB", opacity: ringOpacities[i]),
                                             Color(hex: "FFB5A7", opacity: ringOpacities[i])],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: ringSizes[i], height: ringSizes[i])
                            .scaleEffect(ringScales[i])
                            .zIndex(Double(-i))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 14)
                .padding(.leading, 14)
                .onAppear {
                    if !ringsAnimated {
                        ringsAnimated = true
                        Task { await animateRings() }
                    }
                }
                
                VStack(spacing: 30) {
                    // Typing header with gradient "Era" — leading typing, centered block
                    ZStack(alignment: .leading) {
                        // Invisible full string to fix the width and center the block
                        Text(fullHeaderString)
                            .font(.system(size: 22, weight: .semibold))
                            .opacity(0)
                        // Visible typed content aligns from the leading edge inside the fixed width
                        (
                            Text(typedPrefix)
                                .foregroundColor(.black)
                            +
                            Text(String(headerEra.prefix(typedEraCount)))
                                .foregroundStyle(
                                    LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                            +
                            Text(showQuestionMark ? "?" : "")
                                .foregroundColor(.black)
                        )
                        .font(.system(size: 22, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 32)
                    
                    // Notify Button with ContentView's glowing capsule + rotating angular gradient and drop shadow
                    ZStack {
                        Capsule()
                            .fill(Color.clear)
                            .overlay(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "CBAACB"),
                                        Color(hex: "FFB5A7"),
                                        Color(hex: "CBAACB")
                                    ]),
                                    center: .center
                                )
                                .rotationEffect(glowRotation)
                                .mask(Capsule().stroke(lineWidth: 10))
                                .blur(radius: 8)
                                .opacity(0.6)
                            )
                            .allowsHitTesting(false)
                        
                        Button {
                            requestNotifications()
                        } label: {
                            Text("Notify")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                                )
                        }
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 40)
                    .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
       
                VStack {
                    Spacer()
                    Button {
                        hasCompletedOnboarding = true
                        navigateToFour = false
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
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                
                // Navigation
                NavigationLink(destination: OnboardingFourView()
                                .navigationBarBackButtonHidden(true),
                               isActive: $navigateToFour) { EmptyView() }
                NavigationLink(destination: ContentView()
                                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                                .navigationBarBackButtonHidden(true),
                               isActive: $navigateHome) { EmptyView() }
            }
            .onAppear {
                // start header typing
                Task { await typeHeaderGradient() }
                // start rotating glow for button
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    glowRotation = .degrees(360)
                }
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
                    navigateHome = false
                    navigateToFour = true
                } else {
                    hasCompletedOnboarding = true
                    navigateToFour = false
                    navigateHome = true
                }
            }
        }
    }
    
    private func typeHeaderGradient() async {
        // Type the prefix first
        if typedPrefix.isEmpty {
            for ch in headerPrefix {
                try? await Task.sleep(nanoseconds: 28_000_000) // ~0.028s per character
                await MainActor.run { typedPrefix.append(ch) }
            }
        }
        // Then type "Era" with gradient, letter by letter
        while typedEraCount < headerEra.count {
            try? await Task.sleep(nanoseconds: 90_000_000) // slightly slower for emphasis
            await MainActor.run { typedEraCount += 1 }
        }
        // Finally, show the question mark
        try? await Task.sleep(nanoseconds: 150_000_000)
        await MainActor.run { showQuestionMark = true }
    }
}