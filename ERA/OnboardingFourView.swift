//
//  OnboardingFourView.swift
//  ERA
//
//  Created by AJ Picard on 8/30/25.
//

import SwiftUI
import UserNotifications

struct OnboardingFourView: View {
    // Persist onboarding state
    @AppStorage("hasAcceptedNotifications") private var hasAcceptedNotifications: Bool = true
    @AppStorage("hasConfiguredNotificationTimes") private var hasConfiguredNotificationTimes: Bool = false

    // Time slots (hour & minute); start with one slot
    @State private var timeSlots: [Date] = [Date()]
    
    // Animated circles
    @State private var ringScales: [CGFloat] = [0.01, 0.01, 0.01, 0.01]
    private let ringSizes: [CGFloat] = [24, 36, 48, 60]
    private let ringOpacities: [Double] = [0.70, 0.5, 0.3, 0.15]
    @State private var ringsAnimated = false

    // Button glow
    @State private var glowRotation: Angle = .degrees(0)
    @State private var navigateHome: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                
                // Small animated circles in the top-left
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

                // Main content centered
                VStack(spacing: 20) {
                    // Header with gradient word "breath"
                    (
                        Text("What time do you want to get notified each day to a ")
                            .foregroundColor(.black)
                        +
                        Text("breath")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        +
                        Text("?")
                            .foregroundColor(.black)
                    )
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    // Primary time slot picker + any additional slots
                    VStack(spacing: 12) {
                        ForEach(timeSlots.indices, id: \.self) { idx in
                            HStack {
                                Text("Time")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black.opacity(0.7))
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { timeSlots[idx] },
                                        set: { timeSlots[idx] = $0 }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "en_US"))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }

                        // Add another slot
                        Button {
                            // Add a new slot +5 minutes from the last or now
                            let base = timeSlots.last ?? Date()
                            if let next = Calendar.current.date(byAdding: .minute, value: 5, to: base) {
                                timeSlots.append(next)
                            } else {
                                timeSlots.append(Date())
                            }
                        } label: {
                            HStack {
                                Text("Add Additional Time Slot")
                                    .font(.system(size: 16))
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)

                    // Save button with rotating glow + gradient
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
                            Task {
                                await scheduleDailyNotifications()
                                hasConfiguredNotificationTimes = true
                                navigateHome = true
                            }
                        } label: {
                            Text("Save")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
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
                
                // Bottom-docked Skip (optional shortcut to home)
                VStack {
                    Spacer()
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
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                
                // Navigation to ContentView after Save
                NavigationLink(destination: ContentView().navigationBarBackButtonHidden(true), isActive: $navigateHome) { EmptyView() }
            }
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    glowRotation = .degrees(360)
                }
            }
        }
    }

    // MARK: - Animations
    private func animateRings() async {
        for i in 0..<ringScales.count {
            Task {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                    ringScales[i] = 1.1
                }
            }
        }
    }

    // MARK: - Notifications
    private func scheduleDailyNotifications() async {
        let center = UNUserNotificationCenter.current()
        // Ensure we have permission (user accepted on previous screen)
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        // Clear previously scheduled "Era" reminders to avoid duplicates
        await center.removeAllPendingNotificationRequests()

        for date in timeSlots {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = "Era"
            content.body = "Hey! It's time to take a second to breath"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = "era.daily.\(comps.hour ?? 0)-\(comps.minute ?? 0)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}

#Preview {
    OnboardingFourView()
}