import SwiftUI

struct AddJournalEntryView: View {
    @State private var note: String = ""
    @State private var buttonText: String = "Save"

    var body: some View {
        VStack {
            TextField("Note", text: $note)
                .padding()
            Button(buttonText) {
                saveJournalEntry()
            }
            .padding()
        }
    }

    private func saveJournalEntry() {
        JournalManager.shared.addJournal(note: note)
        buttonText = "Saved"
        print("Saved note: \(note)")
        note = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            buttonText = "Save"
        }
    }
}
