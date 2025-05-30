import SwiftUI
import SwiftData
import HealthKit
import AppIntents
import BackgroundTasks
import TipKit   
import WidgetKit

@main
struct SkateboardTrickApp: App {
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    @AppStorage("hasBeenOnboarded") private var hasBeenOnboarded: Bool = false
    
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var mediaState = MediaState()
    @State private var isLoading = false
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    private var sceneNavigationModel: NavigationModel
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)], animation: .bouncy) private var skateSessions: [SkateSession]
    
    static let shared = SkateboardTrickApp()
    
    init() {
        let navModel = NavigationModel.shared
        sceneNavigationModel = navModel
        
        AppDependencyManager.shared.add(dependency: navModel)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
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
                    
                    // Clean up old temporary video files
                    Task {
                        TempFileCleanup.shared.cleanupOldVideoFiles()
                        
                        // Log current temp directory size
                        let tempSize = TempFileCleanup.shared.getTempDirectorySize()
                        print("Temp directory size: \(TempFileCleanup.shared.formatBytes(tempSize))")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Clean up when app goes to background
                    TempFileCleanup.shared.cleanupOldVideoFiles()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
