//
//  EditSessionView.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//


import SwiftUI
import PhotosUI
import SwiftData
import AVKit
import MapKit

struct EditSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTricks: [Trick]
    @Query private var sessions: [SkateSession]
    @Bindable var session: SkateSession
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @StateObject private var mediaState = MediaState()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedMediaIds: Set<UUID> = []
    @State private var isEditMode: Bool = false
    @State private var isAddingTricks = false
    @State private var isSaved = false
    @State private var suggestedTricks: [Trick] = []
    
    @FocusState private var titleIsFocused: Bool
    @FocusState private var noteIsFocused: Bool
    @FocusState var locationSearchIsFocused: Bool
    
    // State properties for debouncing
    @State private var debouncedTitle: String = ""
    @State private var debouncedNote: String = ""
    
    private let debounceDelay: TimeInterval = 0.5
    
    @State private var region: MKCoordinateRegion
    @State private var selectedLocation: IdentifiableLocation?
    @State private var mapSelection: MKMapItem?

    init(session: SkateSession) {
        self.session = session
        _mediaItems = State(initialValue: session.media ?? [])
        _debouncedTitle = State(initialValue: session.title ?? "")
        _debouncedNote = State(initialValue: session.note ?? "")
        let initialCoordinate = CLLocationCoordinate2D(latitude: session.latitude ?? 37.7749, longitude: session.longitude ?? -122.4194)
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        _selectedLocation = State(initialValue: session.latitude != nil && session.longitude != nil ? IdentifiableLocation(coordinate: initialCoordinate, name: session.location?.name ?? "") : nil)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Session Details")) {
                    TextField("Title", text: $debouncedTitle)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(titleIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: titleIsFocused ? 2 : 1)
                        )
                        .focused($titleIsFocused)
                        .onChange(of: debouncedTitle) { _, newValue in
                            debounceUpdateTitle(newValue)
                        }
                    
                    DatePicker("Date", selection: $session.date.withDefault(Date()), displayedComponents: .date)
                    Section(header: Text("Feeling").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)) {
                        FeelingPickerView(feelings: $session.feeling.withDefault([]))
                            .listRowInsets(EdgeInsets())
                    }
                    TextField("Add some more details...", text: $debouncedNote, axis: .vertical)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(noteIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: noteIsFocused ? 2 : 1)
                        )
                        .focused($noteIsFocused)
                        .onChange(of: debouncedNote) { _, newValue in
                            debounceUpdateNote(newValue)
                            findMatchingTricks(in: newValue)
                        }
                }
                .listRowSeparator(.hidden)
                
//                if !suggestedTricks.isEmpty {
//                    TrickSuggestionPickerView(
//                        suggestedTricks: $suggestedTricks,
//                        selectedTricks: Binding(
//                            get: { Set(session.tricks ?? []) },
//                            set: { session.tricks = Array($0) }
//                        ),
//                        note: debouncedNote
//                    )
//                }
                
                mediaSection
                
                Section(header: Text("Tricks")) {
                    ForEach(session.tricks ?? [], id: \.id) { trick in
                        Text(trick.name)
                            .fontWidth(.expanded)
                    }
                    Button {
                        self.isAddingTricks = true
                    } label: {
                        Label("Select Tricks", systemImage: "figure.skateboarding")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.indigo)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.thinMaterial)
                            )
                    }
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Location")) {
                    LocationPickerView(selectedLocation: $selectedLocation, locationSearchIsFocused: $locationSearchIsFocused)
                        .frame(height: 300)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .onAppear {
                if !locationManager.locationAccessGranted {
                    locationManager.requestLocationAuthorization()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .fontWeight(.bold)
                    .sensoryFeedback(.success, trigger: isSaved)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddingTricks) {
                TrickSelectionView(selectedTricks: Binding(
                    get: { Set(session.tricks ?? []) },
                    set: { session.tricks = Array($0) }
                ))
            }
        }
        .onAppear {
            loadExistingMedia()
        }
    }
    
    private func dismissKeyboard() {
        titleIsFocused = false
        noteIsFocused = false
        locationSearchIsFocused = false
    }
    
    @MainActor
    private func findMatchingTricks(in note: String) {
        let words = note.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var scoredTricks: [(trick: Trick, score: Int)] = []
        
        func standardizeTrickName(_ name: String) -> [String] {
            return name.lowercased()
                .replacingOccurrences(of: "'s", with: "s")
                .replacingOccurrences(of: "-", with: " ")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
        }
        
        for trick in allTricks {
            let trickWords = standardizeTrickName(trick.name)
            var score = 0
            var lastMatchIndex = -1
            
            for word in words where word.count > 1 {
                if let matchIndex = trickWords.firstIndex(where: { $0.contains(word) || word.contains($0) }) {
                    score += 1
                    if matchIndex > lastMatchIndex {
                        score += 1  // Bonus for correct word order
                    }
                    lastMatchIndex = matchIndex
                }
            }
            
            if score > 0 {
                scoredTricks.append((trick: trick, score: score))
            }
        }
        
        // Sort by score (descending) and then by name length (ascending)
        scoredTricks.sort {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.trick.name.count < $1.trick.name.count
        }
        
        // Take top 5 matches
        let maxSuggestions = 5
        suggestedTricks = scoredTricks.prefix(maxSuggestions).map { $0.trick }
    }
    
    private var mediaSection: some View {
        Section(header:
                    HStack {
            Text("Media")
            Spacer()
            if isEditMode {
                Button(role: .destructive) {
                    deleteSelectedMedia()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
                .disabled(selectedMediaIds.isEmpty)
                Button("Cancel") {
                    isEditMode = false
                    selectedMediaIds.removeAll()
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
            } else if !mediaItems.isEmpty {
                Button("Select") {
                    isEditMode = true
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
            }
        }) {
            if !mediaItems.isEmpty {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                    ForEach(mediaItems, id: \.id) { mediaItem in
                        mediaItemView(for: mediaItem)
                    }
                    
                    // Add media button
                    PhotosPicker(selection: $selectedItems, matching: .any(of: [.images, .videos])) {
                        addMediaButton()
                    }
                }
                .padding(.top, 16)
            } else {
                // Ensure the PhotosPicker is shown if there's no media at all
                PhotosPicker(selection: $selectedItems, matching: .any(of: [.images, .videos])) {
                    Label("Add Photos or Videos", systemImage: "photo.on.rectangle.angled")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.indigo)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                        )
                }
            }
        }
        .listRowSeparator(.hidden)
        .onChange(of: selectedItems) {
            Task {
                await processSelectedItems()
            }
        }
    }
    
    private func mediaItemView(for mediaItem: MediaItem) -> some View {
        let size = UIScreen.main.bounds.width / 3 - 16
        return Group {
            if let uiImage = mediaState.imageCache[mediaItem.id ?? UUID()] {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(selectionOverlay(for: mediaItem))
                    .onTapGesture {
                        handleMediaItemTap(mediaItem)
                    }
            } else if let thumbnail = mediaState.videoThumbnails[mediaItem.id ?? UUID()] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(selectionOverlay(for: mediaItem))
                    .onTapGesture {
                        handleMediaItemTap(mediaItem)
                    }
            } else {
                ProgressView()
                    .frame(width: size, height: size)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 5)
            }
        }
    }
    
    private func selectionOverlay(for mediaItem: MediaItem) -> some View {
        ZStack {
            if isEditMode {
                Color.black.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                if selectedMediaIds.contains(mediaItem.id ?? UUID()) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title)
                }
            }
        }
    }
    
    private func addMediaButton() -> some View {
        let size = UIScreen.main.bounds.width / 3 - 16
        return Image(systemName: "plus")
            .font(.largeTitle)
            .foregroundStyle(.indigo)
            .frame(width: size, height: size)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func handleMediaItemTap(_ mediaItem: MediaItem) {
        if isEditMode {
            if let id = mediaItem.id {
                if selectedMediaIds.contains(id) {
                    selectedMediaIds.remove(id)
                } else {
                    selectedMediaIds.insert(id)
                }
            }
        }
    }
    
    private func deleteSelectedMedia() {
        mediaItems.removeAll { mediaItem in
            if let id = mediaItem.id, selectedMediaIds.contains(id) {
                mediaState.videoThumbnails.removeValue(forKey: id)
                mediaState.imageCache.removeValue(forKey: id)
                return true
            }
            return false
        }
        selectedMediaIds.removeAll()
        isEditMode = false
    }
    
    @MainActor
    private func processSelectedItems() async {
        let newMediaItems = selectedItems.map { PhotosPickerItem in
            MediaItem(id: UUID(), data: Data(), session: session)
        }
        mediaItems.append(contentsOf: newMediaItems)
        
        for (index, item) in selectedItems.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let newMediaItem = newMediaItems[index]
                newMediaItem.data = data
                
                if let uiImage = UIImage(data: data) {
                    mediaState.imageCache[newMediaItem.id ?? UUID()] = uiImage
                } else if let videoURL = saveVideoToTemporaryDirectory(data: data) {
                    generateThumbnail(for: videoURL) { thumbnail in
                        if let thumbnail = thumbnail {
                            mediaState.videoThumbnails[newMediaItem.id ?? UUID()] = thumbnail
                        }
                    }
                }
            }
        }
        selectedItems.removeAll()
    }
    
    private func loadExistingMedia() {
        for mediaItem in mediaItems {
            if let uiImage = UIImage(data: mediaItem.data) {
                mediaState.imageCache[mediaItem.id ?? UUID()] = uiImage
            } else if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                generateThumbnail(for: videoURL) { thumbnail in
                    if let thumbnail = thumbnail {
                        mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                    }
                }
            }
        }
    }
    
    private func saveSession() {
        session.title = debouncedTitle
        session.note = debouncedNote
        session.media = mediaItems
        if let selectedLocation = selectedLocation {
            session.latitude = selectedLocation.coordinate.latitude
            session.longitude = selectedLocation.coordinate.longitude
        }
        session.location = selectedLocation
        try? modelContext.save()
        isSaved = true
        dismiss()
    }
    
    private func debounceUpdateTitle(_ newValue: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay) {
            if newValue == debouncedTitle {
                session.title = newValue
            }
        }
    }
    
    private func debounceUpdateNote(_ newValue: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay) {
            if newValue == debouncedNote {
                session.note = newValue
            }
        }
    }
}

// Helper extension to provide default values for optional bindings
extension Binding {
    func withDefault<T>(_ defaultValue: T) -> Binding<T> where Value == Optional<T> {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
