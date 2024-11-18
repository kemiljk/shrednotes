//
//  AppIntents.swift
//  Shrednotes
//
//  Created by Karl Koch on 18/11/2024.
//
import SwiftUI
import AppIntents

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

extension Notification.Name {
    static let addJournalEntry = Notification.Name("addJournalEntry")
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
    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(view: AddSessionView())
    }
}
