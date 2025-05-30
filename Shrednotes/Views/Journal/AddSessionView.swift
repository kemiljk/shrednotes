import SwiftUI
import PhotosUI
import SwiftData
import HealthKit
import AVKit
import MapKit
import WidgetKit

struct AddSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mediaState = MediaState()
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Query private var allTricks: [Trick]
    @Query private var skateSessions: [SkateSession]
    @State private var isHealthAccessGranted: Bool = UserDefaults.standard.bool(forKey: "isHealthAccessGranted")
    @State private var title = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var debouncedNote: String = ""
    @State private var debounceTimer: Timer?
    @State private var suggestedTricks: [Trick] = []
    @State private var feelings: [Feeling] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedTricks: Set<Trick> = []
    @State private var selectedCombos: Set<ComboTrick> = []
    @State private var mediaItems: [MediaItem] = []
    @State private var loadingMedia: Set<UUID> = []
    @State private var selectedMediaIds: Set<UUID> = []
    @State private var isEditMode: Bool = false
    @State private var isAddingTricks: Bool = false
    @State private var isSelectingCombo = false
    @State private var isSaved: Bool = false
    
    @State private var matchingWorkouts: [HKWorkout] = []
    @State private var totalDuration: TimeInterval = 0
    @State private var totalEnergyBurned: Double = 0
    
    @FocusState private var titleIsFocused: Bool
    @FocusState private var noteIsFocused: Bool
    @FocusState var locationSearchIsFocused: Bool
    
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @State private var selectedLocation: IdentifiableLocation?
    @State private var mapSelection: MKMapItem?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var hasDuration: Bool = false
    @State private var duration: Date = {
        let calendar = Calendar.current
        let reference = Date(timeIntervalSinceReferenceDate: 0)  // January 1, 2001, 00:00:00 UTC
        let components = DateComponents(hour: 0, minute: 0)
        return calendar.date(bySettingHour: components.hour ?? 0,
                            minute: components.minute ?? 0,
                            second: 0,
                            of: reference) ?? reference
    }()
    
    init(mediaItems: [MediaItem] = [], title: String = "", note: String = "") {
        self._mediaItems = State(initialValue: mediaItems)
        self._title = State(initialValue: title)
        self._note = State(initialValue: note)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Session Details")) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(titleIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: titleIsFocused ? 2 : 1)
                        )
                        .focused($titleIsFocused)
  
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .onChange(of: date) { _, newDate in
                            findMatchingWorkouts(for: newDate)
                        }
                    
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
                    }
                    
                    Section(header: Text("Feeling").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)) {
                        FeelingPickerView(feelings: $feelings)
                            .listRowInsets(EdgeInsets())
                    }
                    
                    TextField("Add some more details...", text: $note, axis: .vertical)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(noteIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: noteIsFocused ? 2 : 1)
                        )
                        .focused($noteIsFocused)
                        .onChange(of: note) { _, newValue in
                            findMatchingTricks(in: newValue)
                            debounceTimer?.invalidate()
                            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                debouncedNote = newValue
                            }
                        }
                }
                .listRowSeparator(.hidden)
                
                if !suggestedTricks.isEmpty {
                    TrickSuggestionPickerView(
                            suggestedTricks: $suggestedTricks,
                            selectedTricks: $selectedTricks,
                            note: note
                        )
                }
                
                mediaSection
                
                Section(header: Text("Tricks")) {
                    ForEach(Array(selectedTricks), id: \.id) { trick in
                        Text(trick.name)
                            .fontWidth(.expanded)
                    }
                    Button {
                        self.isAddingTricks = true
                    } label: {
                        Label("Select Tricks", systemImage: "figure.skateboarding")
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
                
                Section(header: Text("Combos")) {
                    ForEach(Array(selectedCombos), id: \.id) { combo in
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
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
                
                if !matchingWorkouts.isEmpty {
                    LiveWorkoutView(workouts: matchingWorkouts, activeEnergyBurned: totalEnergyBurned, totalDuration: totalDuration)
                        .environmentObject(healthKitManager)
                }
                
                Section(header: Text("Location")) {
                    LocationPickerView(
                            selectedLocation: $selectedLocation,
                            locationSearchIsFocused: $locationSearchIsFocused
                        )
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
            .onChange(of: debouncedNote) { _, newValue in
                findMatchingTricks(in: newValue)
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
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddingTricks, onDismiss: {
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving context: \(error)")
                }
            }) {
                TrickSelectionView(selectedTricks: $selectedTricks)
                    .presentationCornerRadius(24)
            }
            .sheet(isPresented: $isSelectingCombo, onDismiss: {
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving context: \(error)")
                }
            }) {
                ComboPicker(selectedCombos: $selectedCombos)
                    .presentationCornerRadius(24)
            }
            .onAppear {
                if isHealthAccessGranted {
                    healthKitManager.fetchLatestWorkout()
                    healthKitManager.fetchAllSkateboardingWorkouts()
                }
                if title.isEmpty {
                    title = "Session #\(skateSessions.count + 1)"
                }
                findMatchingWorkouts(for: date)
            }
            .onChange(of: date) {
                if isHealthAccessGranted {
                    healthKitManager.fetchAllSkateboardingWorkouts()
                }
                findMatchingWorkouts(for: date)
            }
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
        return TimeInterval(hour * 3600 + minute * 60)  // Converting to TimeInterval explicitly
    }
    
    @MainActor
    private func findMatchingTricks(in note: String) {
        // Split on whitespace and remove punctuation from each word
        let words = note.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { word in
                word.trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { !$0.isEmpty }
        
        var scoredTricks: [(trick: Trick, score: Int)] = []
        
        func standardizeWord(_ word: String) -> String {
            // Handle common plural forms and possessives
            var standardized = word.lowercased()
            if standardized.hasSuffix("'s") {
                standardized = String(standardized.dropLast(2))
            } else if standardized.hasSuffix("s") && !standardized.hasSuffix("bs") {  // Don't strip 's' from 'bs'
                standardized = String(standardized.dropLast())
            }
            return standardized
        }
        
        func standardizeTrickName(_ name: String) -> [String] {
            return name.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map(standardizeWord)
                .filter { !$0.isEmpty }
        }
        
        func isExactMatch(_ word: String, _ trickWord: String) -> Bool {
            let standardizedWord = standardizeWord(word)
            let standardizedTrickWord = standardizeWord(trickWord)
            
            // Handle FS/BS cases
            if (word == "fs" || word == "bs"), let wordIndex = words.firstIndex(of: word),
               wordIndex + 1 < words.count {
                // Look for "FS" or "BS" followed by the rest of the trick name
                let remainingWords = words[(wordIndex + 1)...].joined(separator: " ")
                let expectedMatch = word + " " + remainingWords
                return standardizeWord(trickWord) == standardizeWord(expectedMatch)
            }
            
            // For regular words, match standardized forms
            return standardizedWord == standardizedTrickWord
        }
        
        for trick in allTricks {
            let trickWords = standardizeTrickName(trick.name)
            var score = 0
            var lastMatchIndex = -1
            var matchedIndices = Set<Int>()
            
            // Handle full matches for FS/BS tricks
            if trick.name.lowercased().starts(with: "fs ") || trick.name.lowercased().starts(with: "bs ") {
                // Check if input contains the full trick name (after standardizing both)
                let inputPhrase = words.joined(separator: " ")
                let standardizedInput = standardizeWord(inputPhrase)
                let standardizedTrick = standardizeWord(trick.name.lowercased())
                
                if standardizedInput.contains(standardizedTrick) {
                    score += 5  // High score for complete FS/BS trick match
                }
            }
            
            // Then try matching individual words
            for word in words where word.count > 1 {
                for (index, trickWord) in trickWords.enumerated() where !matchedIndices.contains(index) {
                    if isExactMatch(word, trickWord) {
                        score += 2 // Higher score for exact matches
                        if index > lastMatchIndex {
                            score += 1  // Bonus for correct word order
                        }
                        lastMatchIndex = index
                        matchedIndices.insert(index)
                        break
                    }
                }
            }
            
            // Extra points for matching all words in the trick name
            if matchedIndices.count == trickWords.count {
                score += 3
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
        
        let maxSuggestions = 5
        suggestedTricks = scoredTricks.prefix(maxSuggestions).map { $0.trick }
    }
    
    // Update the findMatchingWorkouts function
    private func findMatchingWorkouts(for date: Date) {
        healthKitManager.fetchWorkoutsForDate(date) { workouts in
            DispatchQueue.main.async {
                self.matchingWorkouts = workouts
                if !workouts.isEmpty {
                    healthKitManager.sumWorkoutData(workouts: workouts) { duration, energyBurned in
                        DispatchQueue.main.async {
                            self.totalDuration = duration
                            self.totalEnergyBurned = energyBurned
                            
                            // Set the duration picker if we have HealthKit data
                            if duration > 0 {
                                let calendar = Calendar.current
                                let reference = Date(timeIntervalSinceReferenceDate: 0)
                                let hours = Int(duration) / 3600
                                let minutes = (Int(duration) % 3600) / 60
                                
                                self.duration = calendar.date(bySettingHour: hours,
                                                            minute: minutes,
                                                            second: 0,
                                                            of: reference) ?? reference
                                self.hasDuration = true
                            } else {
                                // Enable manual duration entry if no HealthKit duration
                                self.hasDuration = false
                                // Reset to 0 duration
                                let calendar = Calendar.current
                                let reference = Date(timeIntervalSinceReferenceDate: 0)
                                self.duration = calendar.date(bySettingHour: 0,
                                                            minute: 0,
                                                            second: 0,
                                                            of: reference) ?? reference
                            }
                        }
                    }
                } else {
                    self.totalDuration = 0
                    self.totalEnergyBurned = 0
                    // Enable manual duration entry if no HealthKit data
                    self.hasDuration = false
                    // Reset to 0 duration
                    let calendar = Calendar.current
                    let reference = Date(timeIntervalSinceReferenceDate: 0)
                    self.duration = calendar.date(bySettingHour: 0,
                                                minute: 0,
                                                second: 0,
                                                of: reference) ?? reference
                }
            }
        }
    }
    
    private func saveSession() {
        let sessionDuration: TimeInterval = totalDuration > 0 ? totalDuration : (getDurationInSeconds() ?? 0)
        
        // Calculate estimated energy burned if we don't have actual data
        let energyBurned: Double
        if totalEnergyBurned > 0 {
            energyBurned = totalEnergyBurned
        } else {
            let skateMET = 5.0 // Metabolic equivalent for skateboarding
            let averageWeightKg = 70.0 // Average adult weight in kg
            let durationHours = sessionDuration / 3600.0 // Convert seconds to hours
            
            // Formula: MET × Weight(kg) × Duration(hours)
            energyBurned = skateMET * averageWeightKg * durationHours
        }

        let newSession = SkateSession(
            title: title,
            date: date,
            note: note,
            feeling: feelings,
            media: mediaItems,
            tricks: Array(selectedTricks),
            combos: Array(selectedCombos),
            latitude: selectedLocation?.coordinate.latitude,
            longitude: selectedLocation?.coordinate.longitude,
            location: selectedLocation,
            workoutUUID: matchingWorkouts.first?.uuid,
            workoutDuration: sessionDuration,
            workoutEnergyBurned: energyBurned
        )
        
        modelContext.insert(newSession)
        WidgetCenter.shared.reloadAllTimelines()
        try? modelContext.save()
        isSaved = true
        dismiss()
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
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                    spacing: 16
                ) {
                    ForEach(mediaItems, id: \.id) { mediaItem in
                        mediaItemView(for: mediaItem)
                    }
                    
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
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
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
    
    @ViewBuilder
    private func mediaItemView(for mediaItem: MediaItem) -> some View {
        GeometryReader { geometry in
            MediaItemThumbnailView(
                mediaItem: mediaItem,
                mediaState: mediaState,
                size: geometry.size.width,
                isEditMode: isEditMode,
                isSelected: selectedMediaIds.contains(mediaItem.id ?? UUID()),
                onTap: { handleMediaItemTap(mediaItem) }
            )
        }
        .aspectRatio(1, contentMode: .fit) // This ensures the GeometryReader itself maintains a square aspect ratio
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
    
    @MainActor
    private func processSelectedItems() async {
        var newMediaItems: [MediaItem] = []
        
        for item in selectedItems {
            if let mediaItem = await item.toMediaItem() {
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
    
    private func deleteSelectedMedia() {
        mediaItems.removeAll { mediaItem in
            if let id = mediaItem.id, selectedMediaIds.contains(id) {
                mediaState.videoThumbnails.removeValue(forKey: id)
                return true
            }
            return false
        }
        selectedMediaIds.removeAll()
        isEditMode = false
    }
}

// Helper view for media thumbnails
struct MediaItemThumbnailView: View {
    let mediaItem: MediaItem
    @ObservedObject var mediaState: MediaState
    let size: CGFloat
    let isEditMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = loadedImage ?? mediaState.imageCache[mediaItem.id ?? UUID()] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(selectionOverlay)
                    .onTapGesture(perform: onTap)
            } else if let thumbnail = mediaState.videoThumbnails[mediaItem.id ?? UUID()] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(selectionOverlay)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    )
                    .onTapGesture(perform: onTap)
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 5)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadMediaIfNeeded()
        }
    }
    
    private var selectionOverlay: some View {
        ZStack {
            if isEditMode {
                Color.black.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title)
                }
            }
        }
    }
    
    private func loadMediaIfNeeded() {
        // Skip if already loaded
        if loadedImage != nil || 
           mediaState.imageCache[mediaItem.id ?? UUID()] != nil ||
           mediaState.videoThumbnails[mediaItem.id ?? UUID()] != nil {
            isLoading = false
            return
        }
        
        if mediaItem.isFromPhotosLibrary, let identifier = mediaItem.assetIdentifier {
            // Load from Photos library
            guard let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) else {
                isLoading = false
                return
            }
            
            if asset.mediaType == .image {
                PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: size * 2, height: size * 2)) { image in
                    DispatchQueue.main.async {
                        self.loadedImage = image
                        if let image = image, let id = mediaItem.id {
                            self.mediaState.imageCache[id] = image
                        }
                        self.isLoading = false
                    }
                }
            } else if asset.mediaType == .video {
                PhotosHelper.shared.getVideoURL(for: mediaItem) { url in
                    if let url = url {
                        generateThumbnail(for: url) { thumbnail in
                            DispatchQueue.main.async {
                                if let thumbnail = thumbnail, let id = mediaItem.id {
                                    self.mediaState.videoThumbnails[id] = thumbnail
                                }
                                self.isLoading = false
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    }
                }
            }
        } else if !mediaItem.data.isEmpty {
            // Legacy data-based loading
            if let uiImage = UIImage(data: mediaItem.data) {
                loadedImage = uiImage
                if let id = mediaItem.id {
                    mediaState.imageCache[id] = uiImage
                }
            } else if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                generateThumbnail(for: videoURL) { thumbnail in
                    DispatchQueue.main.async {
                        if let thumbnail = thumbnail, let id = mediaItem.id {
                            self.mediaState.videoThumbnails[id] = thumbnail
                        }
                        self.isLoading = false
                    }
                }
                return
            }
            isLoading = false
        } else {
            isLoading = false
        }
    }
}
