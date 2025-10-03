//
//  ContentView.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    // Route-free; we present BreathingView full-screen
    @State private var showBreathingView = false
    @State private var showAnalytics = false
    @State private var sessionJustCompleted = false
    @State private var showNotificationsSettings = false
    @State private var showPaywall = false

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var pm: PurchaseManager
    @EnvironmentObject private var access: AccessGate

    // Sort with string key to avoid key-path compile issues
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "endedAt", ascending: false)],
        animation: .default
    ) private var sessions: FetchedResults<BreathingSession>

    // First‑run rings (match OnboardingTwo)
    private let ringSizes: [CGFloat] = [12, 20, 32, 44]
    private let ringOpacities: [Double] = [0.70, 0.5, 0.3, 0.15]
    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]
    @State private var ringsAnimated = false
    @State private var groupPulse: CGFloat = 1.0

    // Animated glow around Start button
    @State private var glowRotation: Angle = .degrees(0)

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading) {
                    // Title row
                    HStack {
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
                                    .scaleEffect(ringScales[i] * groupPulse)
                                    .zIndex(Double(-i))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .onAppear {
                            if !ringsAnimated {
                                ringsAnimated = true
                                Task { await animateRings() }
                            }
                        }

                        Text("Era")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                        Button {
                            let completed = sessions.filter { ($0.value(forKey: "endedAt") as? Date) != nil }.count
                            if pm.isPro || access.canStartSession(completedSessions: completed, isPro: pm.isPro) {
                                showAnalytics = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .contentShape(Rectangle())
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show Analytics")
                        Button { showNotificationsSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .contentShape(Rectangle())
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Notification Settings")
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 180)

                    // Body Content
                    VStack {
                        if let last = lastSessionDate {
                            let t = timeSince(last, to: Date())

                            HStack(spacing: 8) {
                                HStack(spacing: 2) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 18, weight: .regular))
                                    Text("\(t.days) Day\(t.days == 1 ? "" : "s")")
                                        .font(.system(size: 18, weight: .bold))
                                }

                                Text("&")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)

                                if t.totalMinutes < 60 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 18, weight: .regular))
                                        Text("\(t.totalMinutes) min")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                } else {
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 18, weight: .regular))
                                        Text("\(t.hours) hr \(t.minutes) min")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                            }

                            Text("since you've paused to focus on your breathing.")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.top, 0.5)
                        } else {
                            Text("Let's take your first breathing session.")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
           
                    Spacer().frame(height: 30)
                    // Start button with tight masked glow
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
                                .mask(
                                    Capsule().stroke(lineWidth: 10)
                                )
                                .blur(radius: 8)
                                .opacity(0.6)
                            )
                            .allowsHitTesting(false)

                        Button(action: {
                            sessionJustCompleted = false
                            let completed = sessions.filter { ($0.value(forKey: "endedAt") as? Date) != nil }.count
                            if access.canStartSession(completedSessions: completed, isPro: pm.isPro) {
                                showBreathingView = true
                            } else {
                                showPaywall = true
                            }
                        }) {
                            Text("Start Breathing")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                                )
                        }
                    }
                    .frame(height: 64)
                    .padding(.horizontal, 50)
                    .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)
                    .onAppear {
                        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                            glowRotation = .degrees(360)
                        }
                    }

                    Spacer()
                }
                .padding(.top)
                .fullScreenCover(isPresented: $showBreathingView) {
                    BreathingView()
                        .environment(\.managedObjectContext, viewContext)
                        .ignoresSafeArea()
                }
                .sheet(isPresented: $showAnalytics) {
                    AnalyticsView(context: viewContext)
                }
                .sheet(isPresented: $showNotificationsSettings) {
                    NotificationSettingsView()
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                        .environmentObject(pm)
                        .environmentObject(access)
                        .presentationDetents([.fraction(0.6)])
                        .presentationDragIndicator(.visible)
                }
                .onReceive(pm.$isPro) { pro in
                    if pro {
                        showPaywall = false
                    }
                }
            }
        }
    }

    // Prefer endedAt; fall back to startedAt
    private var lastSessionDate: Date? {
        guard let s = sessions.first else { return nil }
        if let d = s.value(forKey: "endedAt") as? Date { return d }
        if let d = s.value(forKey: "startedAt") as? Date { return d }
        return nil
    }

    // Return (days, hours, minutes, totalMinutes)
    private func timeSince(_ from: Date, to: Date) -> (days: Int, hours: Int, minutes: Int, totalMinutes: Int) {
        let seconds = max(0, Int(to.timeIntervalSince(from)))
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let days = hours / 24
        return (days, hours, minutes, totalMinutes)
    }

    // First‑run ring animation (center → outer, then group pulse)
    private func animateRings() async {
        for i in 0..<ringScales.count {
            Task {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    ringScales[i] = 1.1
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}