//
//  AppIntents.swift
//  Shrednotes
//
//  Created by Karl Koch on 18/11/2024.
//
import SwiftUI
import Observation
import AppIntents
import CoreLocation

struct AddJournalEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Session"
    static var description = IntentDescription("Add a new journal entry with a title and note.")

    @Parameter(title: "Title")
    var title: String
    
    @Parameter(title: "Note")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add a new session titled \(\.$title) with note \(\.$note)")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .addJournalEntry,
                object: nil,
                userInfo: [
                    "title": title,
                    "note": note
                ]
            )
        }
        return .result()
    }
}

struct OpenAppWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Shrednotes"
    static var description = IntentDescription("Quickly opens the app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result()
    }
}

struct OpenAddSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add New Session"
    static var description = IntentDescription("Opens the app and shows the Add Session screen.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showAddSession = true
        navigationModel.selectedView = .addSession
        return .result()
    }
    
    @Dependency
    private var navigationModel: NavigationModel
}

struct OpenViewJournalIntent: AppIntent {
    static var title: LocalizedStringResource = "View Journal"
    static var description = IntentDescription("Opens the app and shows the skate journal.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showViewJournal = true
        navigationModel.selectedView = .journal
        return .result()
    }
    
    @Dependency
    private var navigationModel: NavigationModel
}

struct OpenPracticeTricksIntent: AppIntent {
    static var title: LocalizedStringResource = "Practice Tricks"
    static var description = IntentDescription("Opens the app and shows the trick practice mode.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showPracticeTricks = true
        navigationModel.selectedView = .practice
        return .result()
    }
    
    @Dependency
    private var navigationModel: NavigationModel
}

struct OpenSKATEGameIntent: AppIntent {
    static var title: LocalizedStringResource = "Play S.K.A.T.E."
    static var description = IntentDescription("Opens the app and enters a new game of S.K.A.T.E.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showSKATEGame = true
        navigationModel.selectedView = .skateGame
        return .result()
    }
    
    @Dependency
    private var navigationModel: NavigationModel
}

@MainActor
@Observable class NavigationModel: @unchecked Sendable {
    static let shared = NavigationModel()
    
    var showAddSession: Bool = false
    var showViewJournal: Bool = false
    var showPracticeTricks: Bool = false
    var showSKATEGame: Bool = false
    var selectedView: ViewType = .home
}

enum ViewType {
    case home
    case addSession
    case journal
    case practice
    case skateGame
}

extension Notification.Name {
    static let addJournalEntry = Notification.Name("addJournalEntry")
    static let showPracticeTricks = Notification.Name("showPracticeTricks")
    static let showSKATEGame = Notification.Name("showSKATEGame")
}
