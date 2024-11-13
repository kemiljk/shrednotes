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
                
//                if !suggestedTricks.isEmpty {
//                    TrickSuggestionPickerView(
//                            suggestedTricks: $suggestedTricks,
//                            selectedTricks: $selectedTricks,
//                            note: note
//                        )
//                }
                
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
//            .onChange(of: debouncedNote) { _, newValue in
//                findMatchingTricks(in: newValue)
//            }
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
//            .sheet(isPresented: $isSelectingCombo, onDismiss: {
//                do {
//                    try modelContext.save()
//                } catch {
//                    print("Error saving context: \(error)")
//                }
//            }) {
//                ComboPicker(selectedCombos: $selectedCombos)
//                    .presentationCornerRadius(24)
//            }
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
    
    private func findMatchingWorkouts(for date: Date) {
        healthKitManager.fetchWorkoutsForDate(date) { workouts in
            DispatchQueue.main.async {
                self.matchingWorkouts = workouts
                if !workouts.isEmpty {
                    healthKitManager.sumWorkoutData(workouts: workouts) { duration, energyBurned in
                        DispatchQueue.main.async {
                            self.totalDuration = duration
                            self.totalEnergyBurned = energyBurned
                        }
                    }
                } else {
                    self.totalDuration = 0
                    self.totalEnergyBurned = 0
                }
            }
        }
    }
    
    private func saveSession() {
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
            workoutUUID: matchingWorkouts.first?.uuid.uuidString,
            workoutDuration: totalDuration,
            workoutEnergyBurned: totalEnergyBurned
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
            Group {
                if let uiImage = mediaState.imageCache[mediaItem.id ?? UUID()] {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width) // Makes it square
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
                        .frame(width: geometry.size.width, height: geometry.size.width) // Makes it square
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(selectionOverlay(for: mediaItem))
                        .onTapGesture {
                            handleMediaItemTap(mediaItem)
                        }
                } else {
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.width) // Makes it square
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 5)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit) // This ensures the GeometryReader itself maintains a square aspect ratio
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
        let newMediaItems = selectedItems.map { PhotosPickerItem in
            MediaItem(id: UUID(), data: Data())
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
