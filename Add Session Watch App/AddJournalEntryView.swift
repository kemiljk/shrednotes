import SwiftUI
import SwiftData

enum Feeling: String, CaseIterable, Codable {
    case stoked, exhausted, pumped, thrilled
    case hyped, wrecked, amped, bummed
    case confident, sketchy, dialed, flowing
    case firedUp = "Fired Up"
    case gnarly, chill, rad, mellow
    case blissed, fizzled, slammed
}

enum TrickType: String, CaseIterable, Codable {
    case basic = "Basic"
    case air = "Air"
    case flip = "Flip"
    case shuvit = "Shove It"
    case grind = "Grind"
    case slide = "Slide"
    case transition = "Transition"
    case footplant = "Footplant"
    case balance = "Balance"
    case misc = "Misc"
    
    var displayName: String {
        switch self {
        case .shuvit:
            return "Shove it"
        default:
            return rawValue.capitalized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value.lowercased() {
        case "shuvit": self = .shuvit
        default:
            if let type = TrickType(rawValue: value) {
                self = type
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid TrickType value: \(value)"
                ))
            }
        }
    }
}

enum ElementType: String, Codable {
    case baseTrick
    case direction
    case rotation
    case landing
    case obstacle
    case other
    
    var displayName: String {
        switch self {
        case .baseTrick:
            return "Base trick"
        default:
            return rawValue.capitalized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value.lowercased() {
        case "base trick": self = .baseTrick
        case "direction": self = .direction
        case "rotation": self = .rotation
        case "landing": self = .landing
        case "obstacle": self = .obstacle
        default:
            if let type = ElementType(rawValue: value) {
                self = type
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ElementType value: \(value)"  // Changed from TrickType
                ))
            }
        }
    }
}

struct AddJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var sessionManager = SessionManager.shared
    @State private var note: String = ""
    @State private var isSaved: Bool = false
    @FocusState private var isNoteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextFieldLink(prompt: Text("Describe session")) {
                    Label("Record Session", systemImage: "mic.fill")
                } onSubmit: { inputText in
                    note = inputText
                }
                .focused($isNoteFieldFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isNoteFieldFocused = true
                    }
                }
                Spacer()
                Button {
                    saveJournalEntry()
                } label: {
                    HStack {
                        Image(systemName: isSaved ? "checkmark.circle" : "plus.circle")
                            .transition(.opacity)
                        Text(isSaved ? "Saved" : "Save")
                    }
                }
                .foregroundStyle(.indigo)
                .opacity(note.isEmpty ? 0.3 : 1)
                .animation(.default, value: isSaved)
            }
            .padding()
        }
    }

    private func saveJournalEntry() {
        let newSession = SkateSession(title: "Latest Session", date: Date(), note: note, feeling: [], media: [], tricks: nil, latitude: nil, longitude: nil, location: nil)
        modelContext.insert(newSession)
        isSaved = true
        print("Saved note: \(note)")
        note = ""
        do {
            try modelContext.save()
            sessionManager.sendSession(newSession)
        } catch {
            print("Error saving: \(error)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isSaved = false
        }
    }
}
