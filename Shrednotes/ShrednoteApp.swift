import SwiftUI
import SwiftData
import HealthKit
import AppIntents
import BackgroundTasks
import TipKit   
import WidgetKit

@main
struct SkateboardTrickApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    @AppStorage("hasBeenOnboarded") private var hasBeenOnboarded: Bool = false
    
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var mediaState = MediaState()
    @State private var navigateToAddEntry = false
    @State private var isLoading = false
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)], animation: .bouncy) private var skateSessions: [SkateSession]
    
    static let shared = SkateboardTrickApp()
    
    var body: some Scene {
        WindowGroup {
            MainView(navigateToAddEntry: $navigateToAddEntry)
                .environmentObject(healthKitManager)
                .environmentObject(mediaState)
                .environmentObject(sessionManager)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .onOpenURL { url in
                    if url.scheme == "shredNotes" && url.host == "addentry" {
                        navigateToAddEntry = true
                    }
                }
                .onAppear {
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(_ url: URL) {
        print("Received URL: \(url)")
        if url.scheme == "shredNotes" && url.host == "addentry" {
            print("Navigating to AddSessionView")
            navigateToAddEntry = true
        }
    }
}
