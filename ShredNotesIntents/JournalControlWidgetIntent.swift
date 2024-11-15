import AppIntents

struct JournalControlWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Journal Entry"
    static var description = IntentDescription("Opens the Add Entry screen in the ShredNotes app.")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "shredNotes://addentry") else {
            throw IntentError.invalidURL
        }
        
        print("Navigating to URL: \(url)")
        
        return .result(opensIntent: OpenURLIntent(url))
    }
}

enum IntentError: Error {
    case invalidURL
} 