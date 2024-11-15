//
//  WatchModelContainer.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/11/2024.
//
import SwiftUI
import SwiftData

@MainActor
let watchExtensionModelContainer: ModelContainer = {
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
