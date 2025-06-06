//
//  SharedModelContainer.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//
import SwiftUI
import SwiftData

@MainActor
var sharedModelContainer: ModelContainer = {
    @AppStorage("isFirstTimeLaunch") var isFirstTimeLaunch: Bool = true
    @AppStorage("hasBeenOnboarded") var hasBeenOnboarded: Bool = false
    
    let schema = Schema([Trick.self, SkateSession.self, ComboTrick.self])
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .identifier("group.com.shredNotes.journal")
    )

    do {
        let container = try ModelContainer(for: schema, configurations: modelConfiguration)
        
        // Initialize default tricks if needed
        if isFirstTimeLaunch && !hasBeenOnboarded {
            let context = container.mainContext
            let tricks = generateTricks() // Your trick generation function
            tricks.forEach { context.insert($0) }
            isFirstTimeLaunch = false
            
            // Clean up tricks if needed
            Task {
                _ = await cleanUpTricks()
            }
        }
        
        return container
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

@MainActor
let skateSessionExtensionModelContainer: ModelContainer = {
    let schema = Schema([SkateSession.self])
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .identifier("group.com.shredNotes.journal"),
        cloudKitDatabase: .automatic
    )

    do {
        let container = try ModelContainer(for: schema, configurations: modelConfiguration)
        return container
    } catch {
        fatalError("Could not create ModelContainer for Share Extension: \(error)")
    }
}()

@MainActor
func cleanUpTricks() async -> Int {
    let context = sharedModelContainer.mainContext
    var allTricks: [Trick] = []
    var deletedCount = 0
    
    do {
        allTricks = try context.fetch(FetchDescriptor<Trick>())
    } catch {
        print("Failed to fetch tricks: \(error)")
        return 0
    }
    
    let groupedTricks = Dictionary(grouping: allTricks, by: { $0.name })
    
    for (_, tricks) in groupedTricks where tricks.count > 1 {
        let tricksToKeep = tricks.filter { $0.isLearning || $0.isLearned }
        
        if let trickToKeep = tricksToKeep.first {
            // Keep one trick and delete the rest
            for trick in tricks where trick != trickToKeep {
                context.delete(trick)
                deletedCount += 1
            }
        } else {
            // If no tricks are marked as learning or learned, keep the first one
            for trick in tricks.dropFirst() {
                context.delete(trick)
                deletedCount += 1
            }
        }
    }
    
    do {
        if context.hasChanges {
            try context.save()
        }
    } catch {
        print("Failed to save context after cleanup: \(error)")
    }
    
    return deletedCount
}
