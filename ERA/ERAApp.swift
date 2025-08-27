//
//  ERAApp.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData

@main
struct ERAApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}