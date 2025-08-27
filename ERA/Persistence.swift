
//  Persistence.swift
//  ERA

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // ⚠️ This must match your .xcdatamodeld filename
        container = NSPersistentCloudKitContainer(name: "EraModel")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // iCloud: use default CK container; if you have a custom one, uncomment + set identifier:
        // description.cloudKitContainerOptions =
        //     NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.your.bundle.id")

        // Lightweight migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Useful for CloudKit sync
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Merge changes coming from background/CloudKit into the viewContext
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "viewContext"
        container.viewContext.transactionAuthor = "app"

        // Keep queries pinned to current generation (avoids seeing stale snapshots)
        do { try container.viewContext.setQueryGenerationFrom(.current) }
        catch { print("Failed to set query generation: \(error)") }
    }

    // MARK: - Preview helper
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        // Seed a sample session for previews
        let s = BreathingSession(context: ctx)
        s.setValue(UUID(), forKey: "id")
        s.setValue(Date().addingTimeInterval(-3600), forKey: "startedAt")
        s.setValue(Date().addingTimeInterval(-1800), forKey: "endedAt")
        try? ctx.save()

        return controller
    }()
}
