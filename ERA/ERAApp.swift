//
//  ERAApp.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData

struct RootView: View {
    enum Step { case one, two, four, home }
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasAcceptedNotifications") private var hasAcceptedNotifications: Bool = false
    @AppStorage("hasConfiguredNotificationTimes") private var hasConfiguredNotificationTimes: Bool = false
    @AppStorage("forceOnboardingDebug") private var forceOnboardingDebug: Bool = false
    @State private var step: Step = .one

    var body: some View {
        Group {
            switch step {
            case .one:
                OnboardingOneView {
                    // After onboarding 1 finishes, go to onboarding 2
                    step = .two
                }
                .toolbar(.hidden, for: .navigationBar)

            case .two:
                OnboardingTwoView {
                    // After onboarding 2 finishes, show the main app
                    hasCompletedOnboarding = true
                    step = .home
                }
                .toolbar(.hidden, for: .navigationBar)

            case .four:
                OnboardingFourView()
                    .toolbar(.hidden, for: .navigationBar)

            case .home:
                ContentView()
            }
        }
        .onAppear {
            // If debugging is enabled, do not auto-route (so you can manually navigate)
            if forceOnboardingDebug { return }
            // If user accepted notifications earlier but didn't set times, send them to Onboarding 4
            if hasAcceptedNotifications && !hasConfiguredNotificationTimes {
                step = .four
                return
            }
            // If they fully completed onboarding previously, go straight home
            if hasCompletedOnboarding {
                step = .home
            }
        }
    }
}

@main
struct ERAApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
