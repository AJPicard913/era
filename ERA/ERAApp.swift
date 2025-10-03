//
//  ERAApp.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData

struct RootView: View {
    enum Step { case one, two, four }
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var onboardingStep: Step = .one

    @EnvironmentObject var pm: PurchaseManager
    @EnvironmentObject var access: AccessGate

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
                    .onAppear { hasCompletedOnboarding = true }
            } else {
                switch onboardingStep {
                case .one:
                    OnboardingOneView {
                        onboardingStep = .two
                    }
                    .toolbar(.hidden, for: .navigationBar)

                case .two:
                    OnboardingTwoView {
                        hasCompletedOnboarding = true
                    }
                    .toolbar(.hidden, for: .navigationBar)

                case .four:
                    OnboardingFourView()
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
    }
}

@main
struct ERAApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var pm = PurchaseManager()
    @StateObject private var access = AccessGate()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(pm)
                .environmentObject(access)
        }
    }
}