import SwiftUI
import SwiftData
import PhotosUI

struct AddTrickView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Editing support
    var trickToEdit: Trick?
    
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
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = ""
    
    var difficultyLevels: Range<Int> = 1..<6  // Represents difficulties 1-5
    
    init(trickToEdit: Trick? = nil) {
        self.trickToEdit = trickToEdit
        // Pre-fill state if editing
        if let trick = trickToEdit {
            _trickName = State(initialValue: trick.name)
            _selectedDifficulty = State(initialValue: trick.difficulty)
            _selectedType = State(initialValue: trick.type)
            _consistency = State(initialValue: trick.consistency)
            _isLearning = State(initialValue: trick.isLearning)
            _isLearned = State(initialValue: trick.isLearned)
            _learnedDate = State(initialValue: trick.isLearnedDate ?? Date())
            _progress = State(initialValue: trick.isLearned ? .learned : (trick.isLearning ? .learning : .notStarted))
            if let notes = trick.notes, let first = notes.first {
                _newNoteText = State(initialValue: first.text)
            }
            // Media is not pre-filled for simplicity (could be added)
        }
    }
    
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
                        if progress == .paused || progress == .notStarted {
                            isLearned = false
                            isLearning = false
                        }
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
                            .frame(height: 32)
                            .foregroundStyle(colorScheme == .light ? .indigo : .white)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle(trickToEdit == nil ? "New Trick" : "Edit Trick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(trickToEdit == nil ? "Save" : "Update") {
                        saveTrick()
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
        .overlay(
            ToastView(show: $showToast, message: toastMessage, icon: toastIcon)
        )
    }
    
    private func saveTrick() {
        if let trick = trickToEdit {
            // Update existing trick
            trick.name = trickName
            trick.difficulty = selectedDifficulty
            trick.type = selectedType
            trick.consistency = consistency
            trick.isLearning = isLearning
            trick.isLearned = isLearned
            trick.isLearnedDate = isLearned ? learnedDate : nil
            // Only update the first note for simplicity
            if !newNoteText.isEmpty {
                if let notes = trick.notes, let first = notes.first {
                    first.text = newNoteText
                } else {
                    trick.notes = [Note(text: newNoteText)]
                }
            }
            // Media editing not implemented for simplicity
            try? modelContext.save()
            showCompletionToast()
        } else {
            // Create new trick
            let newTrick = Trick(
                name: trickName,
                difficulty: selectedDifficulty,
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
            if !selectedItems.isEmpty {
                Task {
                    let mediaItems = await processNewMediaItems()
                    await MainActor.run {
                        newTrick.media = mediaItems
                        modelContext.insert(newTrick)
                        try? modelContext.save()
                        showCompletionToast()
                    }
                }
            } else {
                modelContext.insert(newTrick)
                try? modelContext.save()
                showCompletionToast()
            }
        }
    }
    
    private func showCompletionToast() {
        toastMessage = trickToEdit == nil ? "Trick saved!" : "Trick updated!"
        toastIcon = "checkmark.circle"
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    @MainActor
    private func processNewMediaItems() async -> [MediaItem] {
        var newMediaItems: [MediaItem] = []
        for item in selectedItems {
            if let mediaItem = await item.toMediaItem() {
                newMediaItems.append(mediaItem)
                if mediaItem.isVideo {
                    loadingMedia.insert(mediaItem.id ?? UUID())
                    PhotosHelper.shared.getVideoURL(for: mediaItem) { url in
                        if let url = url {
                            generateThumbnail(for: url) { thumbnail in
                                if let thumbnail = thumbnail {
                                    DispatchQueue.main.async {
                                        self.mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                                        self.loadingMedia.remove(mediaItem.id ?? UUID())
                                    }
                                }
                            }
                        }
                    }
                } else if let identifier = mediaItem.assetIdentifier,
                          let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) {
                    loadingMedia.insert(mediaItem.id ?? UUID())
                    PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: 400, height: 400)) { image in
                        DispatchQueue.main.async {
                            if let image = image {
                                self.mediaState.imageCache[mediaItem.id ?? UUID()] = image
                            }
                            self.loadingMedia.remove(mediaItem.id ?? UUID())
                        }
                    }
                }
            }
        }
        return newMediaItems
    }
}

