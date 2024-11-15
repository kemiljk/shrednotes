import SwiftUI
import SwiftData
import PhotosUI

struct AddTrickView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var trickName: String = ""
    @State private var selectedDifficulty: Int = 1  // Default to Beginner
    @State private var selectedType: TrickType = .flip
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var newNoteText: String = ""
    @State private var consistency: Int = 0
    @State private var isLearning: Bool = false
    @State private var isLearned: Bool = false
    @State private var learnedDate: Date = Date()
    @State private var progress: ProgressState = .notStarted
    
    // Media handling state
    @StateObject private var mediaState = MediaState()
    @State private var loadingMedia: Set<UUID> = []
    
    @FocusState private var noteIsFocused: Bool
    
    var difficultyLevels: Range<Int> = 1..<6  // Represents difficulties 1-5
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Trick Details")) {
                    TextField("Trick Name", text: $trickName)
                    
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(difficultyLevels, id: \.self) { difficulty in
                            Text(difficulty.difficultyString)
                                .tag(difficulty)
                        }
                    }
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(TrickType.allCases, id: \.self) { type in
                            Text(type.rawValue == "Shuvit" ? type.displayName : type.rawValue)
                                .tag(type)
                        }
                    }
                    
                    Picker("Progress", selection: $progress) {
                        ForEach(ProgressState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .onChange(of: progress) {
                        isLearned = (progress == .learned)
                        isLearning = (progress == .learning)
                    }
                    
                    if progress == .learned {
                        DatePicker("Learned Date", selection: $learnedDate, displayedComponents: .date)
                    }
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Consistency")) {
                    ConsistencyRatingView(consistency: $consistency)
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Notes")) {
                    TextField("Add a note", text: $newNoteText, axis: .vertical)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(noteIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: noteIsFocused ? 2 : 1)
                        )
                        .focused($noteIsFocused)
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Media")) {
                    PhotosPicker(selection: $selectedItems, matching: .any(of: [.images, .videos])) {
                        Label("Add Photos or Videos", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("New Trick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewTrick()
                    }
                    .disabled(trickName.isEmpty)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            noteIsFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
            }
        }
    }
    
    private func saveNewTrick() {
        let newTrick = Trick(
            name: trickName,
            difficulty: selectedDifficulty,  // Now passing the Int directly
            type: selectedType
        )
        
        newTrick.isLearning = isLearning
        newTrick.isLearned = isLearned
        newTrick.isLearnedDate = isLearned ? learnedDate : nil
        newTrick.consistency = consistency
        
        if !newNoteText.isEmpty {
            let note = Note(text: newNoteText)
            newTrick.notes = [note]
        }
        
        // Process any media items that were selected
        if !selectedItems.isEmpty {
            Task {
                let mediaItems = await processNewMediaItems()
                await MainActor.run {
                    newTrick.media = mediaItems
                    modelContext.insert(newTrick)
                    try? modelContext.save()
                    dismiss()
                }
            }
        } else {
            modelContext.insert(newTrick)
            try? modelContext.save()
            dismiss()
        }
    }
    
    @MainActor
    private func processNewMediaItems() async -> [MediaItem] {
        var newMediaItems: [MediaItem] = []
        
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let newMediaItem = MediaItem(id: UUID(), data: data)
                newMediaItems.append(newMediaItem)
                
                loadingMedia.insert(newMediaItem.id ?? UUID())
                
                if let uiImage = UIImage(data: data) {
                    mediaState.imageCache[newMediaItem.id ?? UUID()] = uiImage
                    loadingMedia.remove(newMediaItem.id ?? UUID())
                } else if let videoURL = saveVideoToTemporaryDirectory(data: data) {
                    generateThumbnail(for: videoURL) { thumbnail in
                        if let thumbnail = thumbnail {
                            mediaState.videoThumbnails[newMediaItem.id ?? UUID()] = thumbnail
                            loadingMedia.remove(newMediaItem.id ?? UUID())
                        }
                    }
                }
            }
        }
        
        return newMediaItems
    }
}
