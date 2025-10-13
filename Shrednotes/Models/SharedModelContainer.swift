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
    @AppStorage("trickDatabaseVersion") var trickDatabaseVersion: Int = 1
    
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
            let tricks = generateTricks()
            tricks.forEach { context.insert($0) }
            
            do {
                try context.save()
                isFirstTimeLaunch = false
                trickDatabaseVersion = 2
                
                Task {
                    let deduplicatedCount = await cleanUpTricks()
                    if deduplicatedCount > 0 {
                        print("Removed \(deduplicatedCount) duplicate tricks on first launch")
                    }
                }
            } catch {
                print("Failed to save tricks on first launch: \(error)")
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
    var deletedCount = 0
    
    do {
        let allTricks = try context.fetch(FetchDescriptor<Trick>())
        
        let groupedTricks = Dictionary(grouping: allTricks, by: { $0.name })
        
        for (_, tricks) in groupedTricks where tricks.count > 1 {
            let tricksToKeep = tricks.filter { $0.isLearning || $0.isLearned }
            let trickToKeepID: UUID?
            
            if let trickToKeep = tricksToKeep.first {
                trickToKeepID = trickToKeep.id
            } else {
                trickToKeepID = tricks.first?.id
            }
            
            guard let keepID = trickToKeepID else { continue }
            
            for trick in tricks where trick.id != keepID {
                context.delete(trick)
                deletedCount += 1
            }
        }
        
        if context.hasChanges {
            try context.save()
        }
    } catch {
        print("Failed to cleanup tricks: \(error)")
    }
    
    return deletedCount
}

@MainActor
func insertNewTricksIfNeeded(context: ModelContext) async -> Int {
    var insertedCount = 0
    
    do {
        let descriptor = FetchDescriptor<Trick>()
        let existingTricks = try context.fetch(descriptor)
        let existingNames = Set(existingTricks.map { $0.name.lowercased() })
        
        let newTricks = generateNewTricksV2()
        
        for trick in newTricks {
            if !existingNames.contains(trick.name.lowercased()) {
                context.insert(trick)
                insertedCount += 1
            }
        }
        
        if context.hasChanges {
            try context.save()
        }
        
        let deduplicatedCount = await cleanUpTricks()
        if deduplicatedCount > 0 {
            print("Automatically removed \(deduplicatedCount) duplicate tricks")
        }
    } catch {
        print("Failed to insert new tricks: \(error)")
    }
    
    return insertedCount
}
