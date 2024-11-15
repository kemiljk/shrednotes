//
//  Add_SessionApp.swift
//  Add Session Watch App
//
//  Created by Karl Koch on 14/11/2024.
//

import SwiftUI

@main
struct Add_Session_Watch_AppApp: App {
    @State private var navigateToAddEntry = false

       var body: some Scene {
           WindowGroup {
               NavigationStack {
                   AddJournalEntryView()
               }
               .environment(\.modelContext, watchExtensionModelContainer.mainContext)
               .modelContainer(watchExtensionModelContainer)
               .onOpenURL { url in
                   handleDeepLink(url)
               }
           }
       }

       private func handleDeepLink(_ url: URL) {
           if url.scheme == "journalapp" && url.host == "addentry" {
               navigateToAddEntry = true
           }
       }
}
