import SwiftUI
import SwiftData
import HealthKit
import AppIntents
import BackgroundTasks
import TipKit
import WidgetKit
import UIKit

enum TabIdentifier {
    case home, journal, skate, search
}

@main
struct SkateboardTrickApp: App {
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    @AppStorage("hasBeenOnboarded") private var hasBeenOnboarded: Bool = false
    
    @State private var selectedTab: TabIdentifier = .home
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var mediaState = MediaState()
    @State private var isLoading = false
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    @State private var searchText = ""
    private var sceneNavigationModel: NavigationModel
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)], animation: .bouncy) private var skateSessions: [SkateSession]
    
    static let shared = SkateboardTrickApp()
    
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        let navModel = NavigationModel.shared
        sceneNavigationModel = navModel
        AppDependencyManager.shared.add(dependency: navModel)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 26, *) {
                    TabView(selection: $selectedTab) {
                        Tab(
                            "Home",
                            systemImage: "square.grid.2x2",
                            value: TabIdentifier.home
                        ) {
                            MainView()
                        }
                        
                        Tab(
                            "Journal",
                            systemImage: "book",
                            value: TabIdentifier.journal
                        ) {
                            JournalView()
                        }
                        
                        Tab(
                            "S.K.A.T.E",
                            systemImage: "skateboard",
                            value: TabIdentifier.skate
                        ) {
                            SKATEGameView()
                        }
                        
                        Tab(
                            "Search",
                            systemImage: "magnifyingglass",
                            value: TabIdentifier.search,
                            role: .search
                        ) {
                            SearchView(searchText: $searchText)
                        }
                    }
                    .tabBarMinimizeBehavior(.onScrollDown)
                } else {
                    TabView(selection: $selectedTab) {
                        Tab(
                            "Home",
                            systemImage: "square.grid.2x2",
                            value: TabIdentifier.home
                        ) {
                            MainView()
                        }
                        
                        Tab(
                            "Journal",
                            systemImage: "book",
                            value: TabIdentifier.journal
                        ) {
                            JournalView()
                        }
                        
                        Tab(
                            "S.K.A.T.E",
                            systemImage: "skateboard",
                            value: TabIdentifier.skate
                        ) {
                            SKATEGameView()
                        }
                        
                        Tab(
                            "Search",
                            systemImage: "magnifyingglass",
                            value: TabIdentifier.search,
                            role: .search
                        ) {
                            SearchView(searchText: $searchText)
                        }
                    }
                }
            }
            .learnedTrickPrompt()
            .environmentObject(healthKitManager)
            .environmentObject(mediaState)
            .environmentObject(sessionManager)
            .environment(sceneNavigationModel)
            .task {
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            }
            .checkSkateInactivity()
            .onAppear {
                WidgetCenter.shared.reloadAllTimelines()
                Task {
                    TempFileCleanup.shared.cleanupOldVideoFiles()
                    let tempSize = TempFileCleanup.shared.getTempDirectorySize()
                    print("Temp directory size: \(TempFileCleanup.shared.formatBytes(tempSize))")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                TempFileCleanup.shared.cleanupOldVideoFiles()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
