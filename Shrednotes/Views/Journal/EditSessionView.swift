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
    @Bindable var mediaState: MediaState
    @State private var locationManager = LocationManager()
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
    
    private var sessionTricksBinding: Binding<Set<Trick>> {
        Binding(
            get: { Set(session.tricks ?? []) },
            set: { session.tricks = Array($0) }
        )
    }

    private var sessionCombosBinding: Binding<Set<ComboTrick>> {
        Binding(
            get: { Set(session.combos ?? []) },
            set: { session.combos = Array($0) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                detailsSection
                mediaSection
                tricksSection
                combosSection
                locationSection
            }
            .listStyle(.plain)
            .onAppear {
                if !locationManager.locationAccessGranted {
                    locationManager.requestLocationAuthorization()
                }
            }
            .toolbar { toolbarContent }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddingTricks) {
                TrickSelectionView(selectedTricks: sessionTricksBinding)
            }
            .sheet(isPresented: $isSelectingCombo) {
                ComboPicker(selectedCombos: sessionCombosBinding)
            }
        }
        .onAppear {
            loadExistingMedia()
            initializeDuration()
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section(header: Text("Session Details")) {
            titleField
            DatePicker("Date", selection: $session.date.withDefault(Date()), displayedComponents: .date)
            durationRow
            if hasDuration {
                durationPicker
            }
            feelingSection
            noteBlock
        }
        .listRowSeparator(.hidden)
    }

    private var titleField: some View {
        TextField("Title", text: $debouncedTitle)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        titleIsFocused ? Color.indigo : Color.secondary.opacity(0.2),
                        lineWidth: titleIsFocused ? 2 : 1
                    )
            )
            .focused($titleIsFocused)
    }

    private var durationRow: some View {
        HStack {
            Text("Duration")
            Spacer()
            HStack(spacing: 4) {
                Text(formatDuration(duration))
                Image(systemName: hasDuration ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            }
        }
        .onTapGesture {
            withAnimation { hasDuration.toggle() }
        }
    }

    private var durationPicker: some View {
        DatePicker("Duration", selection: $duration, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .animation(.spring, value: hasDuration)
            .onChange(of: duration) { _, _ in
                manualDuration = getDurationInSeconds() ?? 0
            }
    }

    private var feelingSection: some View {
        Section(header: Text("Feeling").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)) {
            FeelingPickerView(feelings: $session.feeling.withDefault([]))
                .listRowInsets(EdgeInsets())
        }
    }

    private var noteBlock: some View {
        SessionNoteBlock(
            note: $debouncedNote,
            suggestedTricks: $suggestedTricks,
            selectedTricks: sessionTricksBinding,
            allTricks: allTricks
        )
        .listRowInsets(EdgeInsets())
    }



    private var tricksSection: some View {
        Section(header: Text("Tricks")) {
            ForEach(session.tricks ?? [], id: \.id) { trick in
                Text(trick.name)
                    .fontWidth(.expanded)
            }
            Button {
                self.isAddingTricks = true
            } label: {
                pickerButtonLabel(title: "Select Tricks", systemImage: "figure.skateboarding")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .listRowSeparator(.hidden)
    }

    private var combosSection: some View {
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
                pickerButtonLabel(title: "Select Combos", systemImage: "list.bullet")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func pickerButtonLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .foregroundStyle(colorScheme == .light ? Color.indigo : Color.white)
    }

    private var locationSection: some View {
        Section(header: Text("Location")) {
            LocationPickerView(
                selectedLocation: $selectedLocation,
                locationSearchIsFocused: $locationSearchIsFocused
            )
        }
        .listRowSeparator(.hidden)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            Button(role: .cancel) {
                dismiss()
            }
            .accessibilityLabel("Cancel")
        }
        ToolbarItemGroup(placement: .confirmationAction) {
            Button(role: .confirm) {
                saveSession()
            }
            .accessibilityLabel("Save session")
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
        return TimeInterval(hour * 3600 + minute * 60)
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
                GeometryReader { geometry in
                    let size = geometry.size.width / 3 - 16
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                        ForEach(mediaItems, id: \.id) { mediaItem in
                            mediaItemView(for: mediaItem, size: size)
                        }
                        
                        // Add media button
                        PhotosPicker(selection: $selectedItems, matching: .any(of: [.images, .videos])) {
                            addMediaButton(size: size)
                        }
                    }
                    .padding(.top, 16)
                }
                .frame(minHeight: 200)
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
    
    private func mediaItemView(for mediaItem: MediaItem, size: CGFloat) -> some View {
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

// MARK: - String Extension for Levenshtein Distance
extension String {
    func levenshteinDistance(to target: String) -> Int {
        let source = Array(self.unicodeScalars)
        let target = Array(target.unicodeScalars)
        
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }
        
        var distance = Array(repeating: Array(repeating: 0, count: target.count + 1),
                           count: source.count + 1)
        
        for i in 0...source.count {
            distance[i][0] = i
        }
        
        for j in 0...target.count {
            distance[0][j] = j
        }
        
        for i in 1...source.count {
            for j in 1...target.count {
                let cost = source[i-1] == target[j-1] ? 0 : 1
                distance[i][j] = Swift.min(
                    distance[i-1][j] + 1,      // deletion
                    distance[i][j-1] + 1,      // insertion
                    distance[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return distance[source.count][target.count]
    }
}
