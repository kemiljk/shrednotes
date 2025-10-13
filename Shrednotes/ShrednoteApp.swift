import SwiftUI
import SwiftData
import HealthKit
import AppIntents
import BackgroundTasks
import TipKit
import WidgetKit
import UIKit

enum TabIdentifier {
    case home, journal, skate, tricks, search
}

@main
struct SkateboardTrickApp: App {
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    @AppStorage("hasBeenOnboarded") private var hasBeenOnboarded: Bool = false
    @AppStorage("trickDatabaseVersion") private var trickDatabaseVersion: Int = 1
    
    @State private var selectedTab: TabIdentifier = .home
    @State private var showTrickUpdateAlert = false
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var mediaState = MediaState()
    @State private var isLoading = false
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    @State private var searchText = ""
    @State private var visibleTrickTypes: Set<TrickType> = Set(TrickType.allCases)
    @State private var expandedGroups: [String: Bool] = [:]
    @State private var selectedType: TrickType? = nil
    private var sceneNavigationModel: NavigationModel
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)], animation: .bouncy) private var skateSessions: [SkateSession]
    
    static let shared = SkateboardTrickApp()
    
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        let navModel = NavigationModel.shared
        sceneNavigationModel = navModel
        AppDependencyManager.shared.add(dependency: navModel)
    }
    
    func loadVisibleTrickTypes() {
        if let data = UserDefaults.standard.data(forKey: "visibleTrickTypes"),
           let decodedSet = try? JSONDecoder().decode(Set<TrickType>.self, from: data) {
            visibleTrickTypes = decodedSet
        }
    }
    
    func checkTrickDatabaseUpdate() {
        if trickDatabaseVersion < 2 && !isFirstTimeLaunch {
            showTrickUpdateAlert = true
        }
    }
    
    @MainActor
    func addNewTricks() async {
        let context = sharedModelContainer.mainContext
        let insertedCount = await insertNewTricksIfNeeded(context: context)
        print("Inserted \(insertedCount) new tricks")
        trickDatabaseVersion = 2
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
                            "Tricks",
                            systemImage: "figure.skating",
                            value: TabIdentifier.tricks
                        ) {
                            FullTrickListView(
                                visibleTrickTypes: $visibleTrickTypes,
                                searchText: $searchText,
                                expandedGroups: $expandedGroups,
                                selectedType: $selectedType,
                                isTabItem: true
                            )
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
                            "Tricks",
                            systemImage: "figure.skating",
                            value: TabIdentifier.tricks
                        ) {
                            FullTrickListView(
                                visibleTrickTypes: $visibleTrickTypes,
                                searchText: $searchText,
                                expandedGroups: $expandedGroups,
                                selectedType: $selectedType,
                                isTabItem: true
                            )
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
                loadVisibleTrickTypes()
                checkTrickDatabaseUpdate()
            }
            .alert("New Tricks Available", isPresented: $showTrickUpdateAlert) {
                Button("Add Tricks") {
                    Task {
                        await addNewTricks()
                    }
                }
                Button("Not Now", role: .cancel) {
                    trickDatabaseVersion = 2
                }
            } message: {
                Text("We've added 18 new tricks including Casper Flip, Pressure Flip, Double Kickflip, No Comply, Darkslide, Hurricane Grind, and more. Would you like to add them?")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                TempFileCleanup.shared.cleanupOldVideoFiles()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
