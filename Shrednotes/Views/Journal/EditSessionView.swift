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
import FoundationModels

struct EditSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allTricks: [Trick]
    @Query private var sessions: [SkateSession]
    @Bindable var session: SkateSession
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @ObservedObject var mediaState: MediaState
    @StateObject private var locationManager = LocationManager()
    @State private var selectedMediaIds: Set<UUID> = []
    @State private var isEditMode: Bool = false
    @State private var isAddingTricks = false
    @State private var isSelectingCombo = false
    @State private var isSaved = false
    @State private var suggestedTricks: [Trick] = []
    @State private var isSuggestingTricks = false
    
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
    
    @State private var hasDuration: Bool = false
    @State private var duration: Date = {
        let calendar = Calendar.current
        let reference = Date(timeIntervalSinceReferenceDate: 0)
        return reference
    }()
    @State private var manualDuration: TimeInterval?
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private func initializeDuration() {
        if let workoutDuration = session.workoutDuration, workoutDuration > 0 {
            let hours = Int(workoutDuration) / 3600
            let minutes = Int(workoutDuration) % 3600 / 60
            
            let calendar = Calendar.current
            let reference = Date(timeIntervalSinceReferenceDate: 0)
            if let newDate = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: reference) {
                duration = newDate
            }
        }
    }

    init(session: SkateSession, mediaState: MediaState) {
        self.session = session
        self.mediaState = mediaState
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
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(duration))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.2))
                            }
                    }
                    .onTapGesture {
                        withAnimation {
                            hasDuration.toggle()
                        }
                    }
                    
                    if hasDuration {
                        DatePicker("Duration", selection: $duration, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .animation(.spring, value: hasDuration)
                            .onChange(of: duration) { oldValue, newValue in
                                manualDuration = getDurationInSeconds() ?? 0
                            }
                    }
                    
                    Section(header: Text("Feeling").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)) {
                        FeelingPickerView(feelings: $session.feeling.withDefault([]))
                            .listRowInsets(EdgeInsets())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add some more details...", text: $debouncedNote, axis: .vertical)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(noteIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: noteIsFocused ? 2 : 1)
                            )
                            .focused($noteIsFocused)
                            .onChange(of: debouncedNote) { _, newValue in
                                debounceUpdateNote(newValue)
                            }
                        
                        if #available(iOS 26, *) {
                            Button {
                                Task {
                                    await generateTrickSuggestions()
                                }
                            } label: {
                                HStack {
                                    Label(isSuggestingTricks ? "Thinking..." : "Suggest Tricks", systemImage: "sparkles")
                                        .transition(.opacity)
                                }
                            }
                            .disabled(debouncedNote.isEmpty || isSuggestingTricks)
                            .foregroundStyle(colorScheme == .light ? .indigo : .white)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.mini)
                            .animation(.linear, value: isSuggestingTricks)
                            .listRowSeparator(.hidden)
                        }
                        
                        if !suggestedTricks.isEmpty {
                            TrickSuggestionPickerView(
                                suggestedTricks: $suggestedTricks,
                                selectedTricks: Binding(
                                    get: { Set(session.tricks ?? []) },
                                    set: { session.tricks = Array($0) }
                                ),
                                note: debouncedNote
                            )
                        }
                    }
                }
                .listRowSeparator(.hidden)
                
                
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(colorScheme == .light ? .indigo : .white)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Combos")) {
                    ForEach(Array(session.combos ?? []), id: \.id) { combo in
                        if let name = combo.name {
                            Text(name)
                                .fontWidth(.expanded)
                        }
                    }
                    Button {
                        self.isSelectingCombo = true
                    } label: {
                        Label("Select Combos", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(colorScheme == .light ? .indigo : .white)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Location")) {
                    LocationPickerView(selectedLocation: $selectedLocation, locationSearchIsFocused: $locationSearchIsFocused)
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
                ToolbarItemGroup(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            saveSession()
                        }
                    } else {
                        Button("Save") {
                            saveSession()
                        }
                        .fontWeight(.bold)
                        .sensoryFeedback(.success, trigger: isSaved)
                    }
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
            .sheet(isPresented: $isSelectingCombo) {
                ComboPicker(selectedCombos: Binding(
                    get: { Set(session.combos ?? []) },
                    set: { session.combos = Array($0) }
                ))
                
            }
        }
        .onAppear {
            loadExistingMedia()
            initializeDuration()
        }
    }
    
    private func dismissKeyboard() {
        titleIsFocused = false
        noteIsFocused = false
        locationSearchIsFocused = false
    }
    
    private func formatDuration(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        if hour == 0 {
            return "\(minute)min"
        } else if minute == 0 {
            return "\(hour)hr"
        } else {
            return "\(hour)hr \(minute)min"
        }
    }
    
    private func getDurationInSeconds() -> TimeInterval? {
        guard hasDuration else { return nil }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: duration)
        let minute = calendar.component(.minute, from: duration)
        
        print("Converting duration - Hours: \(hour), Minutes: \(minute)")
        let seconds = TimeInterval(hour * 3600 + minute * 60)
        print("Total seconds: \(seconds)")
        
        return seconds
    }
    
    @available(iOS 26, *)
    private func generateTrickSuggestions() async {
        isSuggestingTricks = true
        self.suggestedTricks = []
        
        do {
            let instructions = Instructions {
                """
                Extract skateboarding trick names from the session note.
                
                Rules:
                - Return ONLY a comma-separated list of trick names
                - Include common variations (e.g., "kickflip", "kickflips", "kick flip" all count as the same trick)
                - Common abbreviations: fs = frontside, bs = backside
                - NO explanations, just the trick names
                
                Examples:
                - "Landed some kickflips" → Kickflip
                - "pop shove it" → Pop Shove It
                - "bs flip" → BS Flip
                - "nose manual" → Nose Manual
                - "manual" → Manual (not Nose Manual)
                """
            }
            
            let prompt = Prompt("Extract trick names from: \(debouncedNote)")
            let session = LanguageModelSession(instructions: instructions)
            
            let response = try await session.respond(to: prompt)
            
            print("LLM Response: \(response.content)")
            
            // Extract trick names from response
            let extractedNames = response.content
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            print("Extracted names: \(extractedNames)")
            
            // Now match against our database with fuzzy matching
            var matchedTricks: [Trick] = []
            
            for extractedName in extractedNames {
                let normalizedExtracted = extractedName.lowercased()
                
                // First try exact match (case insensitive)
                if let exactMatch = allTricks.first(where: { $0.name.lowercased() == normalizedExtracted }) {
                    matchedTricks.append(exactMatch)
                    continue
                }
                
                // Check aliases
                let aliases: [String: String] = [
                    "bs flip": "BS 180 Kickflip",
                    "fs flip": "FS 180 Kickflip",
                    "tre flip": "Tre Flip",
                    "360 flip": "Tre Flip",
                    "noseslide": "BS Noseslide",
                    "nose slide": "BS Noseslide"
                ]
                
                if let aliasMatch = aliases[normalizedExtracted],
                   let trick = allTricks.first(where: { $0.name == aliasMatch }) {
                    matchedTricks.append(trick)
                    continue
                }
                
                // Try fuzzy matching for close matches
                let bestMatch = allTricks
                    .map { trick in
                        (trick: trick, score: similarityScore(normalizedExtracted, trick.name.lowercased()))
                    }
                    .filter { $0.score > 0.8 } // 80% similarity threshold
                    .max { $0.score < $1.score }
                
                if let match = bestMatch {
                    matchedTricks.append(match.trick)
                }
            }
            
            print("Matched tricks: \(matchedTricks.map { $0.name })")
            
            self.suggestedTricks = matchedTricks
            
        } catch {
            print("Error generating trick suggestions: \(error.localizedDescription)")
            
            // If LLM fails (including sensitive content), fall back to basic matching
            await performBasicTrickMatching()
        }
        
        self.isSuggestingTricks = false
    }
    
    @MainActor
    private func performBasicTrickMatching() async {
        // Simple word-based matching as fallback
        let words = debouncedNote.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        var matchedTricks: [Trick] = []
        
        for trick in allTricks {
            let trickWords = trick.name.lowercased().components(separatedBy: .whitespaces)
            
            // Check if all trick words appear in the note
            var allWordsFound = true
            for trickWord in trickWords {
                if !words.contains(where: { word in
                    word == trickWord || 
                    (word.hasPrefix(trickWord) && word.dropFirst(trickWord.count).allSatisfy { $0 == "s" })
                }) {
                    allWordsFound = false
                    break
                }
            }
            
            if allWordsFound {
                matchedTricks.append(trick)
            }
        }
        
        // Apply common aliases
        let aliasPatterns: [(pattern: String, trick: String)] = [
            ("bs flip", "BS 180 Kickflip"),
            ("fs flip", "FS 180 Kickflip"),
            ("noseslide", "BS Noseslide"),
            ("nose slide", "BS Noseslide")
        ]
        
        let noteText = debouncedNote.lowercased()
        for (pattern, trickName) in aliasPatterns {
            if noteText.contains(pattern),
               let trick = allTricks.first(where: { $0.name == trickName }),
               !matchedTricks.contains(where: { $0.id == trick.id }) {
                matchedTricks.append(trick)
            }
        }
        
        self.suggestedTricks = matchedTricks
    }
    
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        if str1 == str2 { return 1.0 }
        
        let len1 = str1.count
        let len2 = str2.count
        let maxLen = max(len1, len2)
        
        if maxLen == 0 { return 1.0 }
        
        let distance = levenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLen))
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let len1 = s1.count
        let len2 = s2.count
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[len1][len2]
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
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .foregroundStyle(colorScheme == .light ? .indigo : .white)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
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
                    Image(systemName: "checkmark.circle")
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
        var newMediaItems: [MediaItem] = []
        
        for item in selectedItems {
            if let mediaItem = await item.toMediaItem() {
                // Assign the session relationship
                mediaItem.session = session
                newMediaItems.append(mediaItem)
                
                // Pre-generate thumbnails for videos
                if mediaItem.isVideo {
                    PhotosHelper.shared.getVideoURL(for: mediaItem) { url in
                        if let url = url {
                            generateThumbnail(for: url) { thumbnail in
                                if let thumbnail = thumbnail, let id = mediaItem.id {
                                    DispatchQueue.main.async {
                                        self.mediaState.videoThumbnails[id] = thumbnail
                                    }
                                }
                            }
                        }
                    }
                } else if let identifier = mediaItem.assetIdentifier,
                          let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) {
                    // Pre-cache images
                    PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: 400, height: 400)) { image in
                        if let image = image, let id = mediaItem.id {
                            DispatchQueue.main.async {
                                self.mediaState.imageCache[id] = image
                            }
                        }
                    }
                }
            }
        }
        
        mediaItems.append(contentsOf: newMediaItems)
        selectedItems.removeAll()
    }
    
    private func loadExistingMedia() {
        for mediaItem in mediaItems {
            if mediaItem.isFromPhotosLibrary, let identifier = mediaItem.assetIdentifier {
                // Load from Photos library
                if let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) {
                    if asset.mediaType == .image {
                        PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: 400, height: 400)) { image in
                            if let image = image, let id = mediaItem.id {
                                DispatchQueue.main.async {
                                    self.mediaState.imageCache[id] = image
                                }
                            }
                        }
                    } else if asset.mediaType == .video {
                        PhotosHelper.shared.getVideoURL(for: mediaItem) { url in
                            if let url = url {
                                generateThumbnail(for: url) { thumbnail in
                                    if let thumbnail = thumbnail, let id = mediaItem.id {
                                        DispatchQueue.main.async {
                                            self.mediaState.videoThumbnails[id] = thumbnail
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if !mediaItem.data.isEmpty {
                // Legacy data-based media
                if let uiImage = UIImage(data: mediaItem.data) {
                    mediaState.imageCache[mediaItem.id ?? UUID()] = uiImage
                } else if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                    generateThumbnail(for: videoURL) { thumbnail in
                        if let thumbnail = thumbnail {
                            DispatchQueue.main.async {
                                self.mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveSession() {
        if manualDuration != nil {
            session.workoutDuration = manualDuration
        }
        
        // Calculate estimated energy burned if we don't have actual data
        let energyBurned: Double
        if let actualEnergy = session.workoutEnergyBurned, actualEnergy > 0 {
            energyBurned = actualEnergy
        } else {
            let skateMET = 5.0 // Metabolic equivalent for skateboarding
            let averageWeightKg = 70.0 // Average adult weight in kg
            let duration = session.workoutDuration ?? 0
            let durationHours = duration / 3600.0 // Convert seconds to hours
            
            // Formula: MET × Weight(kg) × Duration(hours)
            energyBurned = skateMET * averageWeightKg * durationHours
        }
        
        session.title = debouncedTitle
        session.note = debouncedNote
        session.media = mediaItems
        
        // Update location information
        if let selectedLocation = selectedLocation {
            session.latitude = selectedLocation.coordinate.latitude
            session.longitude = selectedLocation.coordinate.longitude
            session.location = selectedLocation
        } else {
            // Clear location if none selected
            session.latitude = nil
            session.longitude = nil
            session.location = nil
        }
        
        session.workoutEnergyBurned = energyBurned
        
        try? modelContext.save()
        print("Session saved with duration: \(session.workoutDuration ?? 0)")
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
