//
//  ERAApp.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData

struct RootView: View {
    enum Step { case one, two, home }
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
                    step = .home
                }
                .toolbar(.hidden, for: .navigationBar)

            case .home:
                ContentView()
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
