//
//  SessionDetailView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import PhotosUI
import HealthKitUI
import AVKit
import MapKit

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager: HealthKitManager
    @Bindable var session: SkateSession
    @Bindable var mediaState: MediaState
    @State private var isHealthAccessGranted: Bool = UserDefaults.standard.bool(forKey: "isHealthAccessGranted")
    
    @State private var selectedMediaItem: MediaItem?
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @Namespace private var sessionPicture
    @State private var preloadedPlayers: [UUID: AVPlayer] = [:]
    @State private var isEditingSession = false
    @State private var showDeleteConfirmation: Bool = false
    
    @State private var matchingWorkout: HKWorkout?
    @State private var activeEnergyBurned: Double = 0.0
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var fullScreenCover: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                detailContent
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(.background)
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditingSession, onDismiss: handleEditDismiss) {
            EditSessionView(session: session, mediaState: mediaState)
        }
        .fullScreenCover(item: $selectedMediaItem, onDismiss: resetZoom) { mediaItem in
            if let media = session.media, !media.isEmpty {
                MediaGalleryView(
                    mediaItems: media,
                    initialItem: mediaItem,
                    mediaState: mediaState
                )
            }
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: session.media) { _, _ in refreshMediaState() }
        .onChange(of: healthKitManager.allSkateboardingWorkouts) { _, _ in findMatchingWorkout() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var heroSection: some View {
        if let firstMedia = session.media?.first {
            heroMediaView(mediaItem: firstMedia)
        } else if let latitude = session.latitude, let longitude = session.longitude {
            heroMapView(latitude: latitude, longitude: longitude)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 300)
                .overlay {
                    Image(systemName: "figure.skateboarding")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            sessionHeader
            if session.date != nil {
                StoredWorkoutView(session: session, condensed: true)
            }
            notesSection
            mediaGridSection
            tricksSection
            combosSection
            locationSectionIfNeeded
        }
        .padding()
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let duration = session.workoutDuration {
                    Label(formatDuration(duration), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let title = session.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontWidth(.expanded)
            }

            if let feelings = session.feeling {
                feelingChips(feelings)
            }
        }
    }

    private func feelingChips(_ feelings: [Feeling]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(feelings, id: \.self) { feeling in
                    Text(feeling.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.2))
                        .cornerRadius(10)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let note = session.note, !note.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                    .fontWidth(.expanded)
                Text(note)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var mediaGridSection: some View {
        if let media = session.media, media.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Media")
                    .font(.headline)
                    .fontWidth(.expanded)
                MediaGridView(media: Array(media.dropFirst()), mediaState: mediaState) { mediaItem in
                    selectedMediaItem = mediaItem
                }
            }
        }
    }

    @ViewBuilder
    private var tricksSection: some View {
        if let tricks = session.tricks, !tricks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tricks")
                        .font(.headline)
                        .fontWidth(.expanded)
                    Spacer()
                    Text("\(tricks.count)")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: trickGridColumns, spacing: 8) {
                    ForEach(tricks) { trick in
                        NavigationLink(destination: TrickDetailView(trick: trick)) {
                            TrickCard(trick: trick)
                        }
                    }
                }
            }
        }
    }

    private var trickGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    @ViewBuilder
    private var combosSection: some View {
        if let combos = session.combos, !combos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Combos")
                    .font(.headline)
                    .fontWidth(.expanded)
                ForEach(combos) { combo in
                    ComboCard(combo: combo)
                }
            }
        }
    }

    @ViewBuilder
    private var locationSectionIfNeeded: some View {
        if session.media != nil,
           let latitude = session.latitude,
           let longitude = session.longitude {
            locationSection(latitude: latitude, longitude: longitude)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if fullScreenCover == true {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel("Close")
            }
        }
        ToolbarItem {
            ShareLink(item: sessionSummary)
        }
        ToolbarItem {
            Button {
                isEditingSession = true
            } label: {
                Label("Edit", systemImage: "pencil.circle")
            }
        }
        ToolbarItem {
            Button {
                self.showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .confirmationDialog("Are you sure you want to delete this session?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Handlers

    private func handleOnAppear() {
        cleanupInvalidMedia()
        preGenerateVideoThumbnailsAndPreloadPlayers()
        refreshMediaState()
        healthKitManager.fetchLatestWorkout()
        healthKitManager.fetchAllSkateboardingWorkouts()
        findMatchingWorkout()
    }

    private func handleEditDismiss() {
        if let latitude = session.latitude, let longitude = session.longitude {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                ),
                distance: 5000,
                heading: 0,
                pitch: 0
            ))
        }
    }

    private func resetZoom() {
        currentZoom = 0.0
        totalZoom = 1.0
    }
    
    private var sessionSummary: String {
        var summary = ""
        
        if let title = session.title {
            summary += "Session: \(title)\n"
        }
        
        if let date = session.date {
            summary += "Date: \(date.formatted())\n"
        }
        
        if let note = session.note, !note.isEmpty {
            summary += "\nNotes:\n\(note)\n"
        }
        
        if let tricks = session.tricks, !tricks.isEmpty {
            summary += "\nTricks Landed:\n"
            for trick in tricks {
                summary += "- \(trick.name)\n"
            }
        }
        
        return summary
    }
    
    private func preGenerateVideoThumbnailsAndPreloadPlayers() {
        guard let media = session.media else { return }
        
        for mediaItem in media {
            if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                generateThumbnail(for: videoURL) { thumbnail in
                    if let thumbnail = thumbnail {
                        DispatchQueue.main.async {
                            mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                        }
                    }
                }
                preloadVideoPlayer(for: mediaItem, url: videoURL)
            }
        }
    }
    
    private func saveVideoToTemporaryDirectory(data: Data) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let videoURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        do {
            try data.write(to: videoURL)
            return videoURL
        } catch {
            print("Error saving video to temporary directory: \(error)")
            return nil
        }
    }
    
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
            if let error = error {
                print("Error generating thumbnail: \(error)")
                completion(nil)
                return
            }
            if let image = image {
                completion(UIImage(cgImage: image))
            } else {
                completion(nil)
            }
        }
    }
    
    private func preloadVideoPlayer(for mediaItem: MediaItem, url: URL) {
        let player = AVPlayer(url: url)
        player.currentItem?.preferredForwardBufferDuration = 5
        preloadedPlayers[mediaItem.id ?? UUID()] = player
    }
    
    private func refreshMediaState() {
        // Clear any thumbnails for media items that no longer exist
        let currentMediaIds = Set(session.media?.compactMap { $0.id } ?? [])
        mediaState.imageCache = mediaState.imageCache.filter { currentMediaIds.contains($0.key) }
        mediaState.videoThumbnails = mediaState.videoThumbnails.filter { currentMediaIds.contains($0.key) }
        
        for mediaItem in session.media ?? [] {
            let mediaId = mediaItem.id ?? UUID()
            
            // Skip if this media item has previously failed
            guard !mediaState.failedThumbnails.contains(mediaId) else { continue }
            
            // Check if the data is valid
            guard !mediaItem.data.isEmpty else {
                mediaState.markAsFailed(mediaId)
                continue
            }
            
            if let uiImage = UIImage(data: mediaItem.data) {
                mediaState.clearFailed(mediaId)
                mediaState.imageCache[mediaId] = uiImage
            } else {
                // Try to handle as video
                if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                    let thumbnailGenerationTimeout = DispatchWorkItem {
                        mediaState.markAsFailed(mediaId)
                    }
                    
                    // Set a timeout for thumbnail generation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: thumbnailGenerationTimeout)
                    
                    generateThumbnail(for: videoURL) { thumbnail in
                        thumbnailGenerationTimeout.cancel()
                        if let thumbnail = thumbnail {
                            DispatchQueue.main.async {
                                mediaState.clearFailed(mediaId)
                                mediaState.videoThumbnails[mediaId] = thumbnail
                            }
                        } else {
                            mediaState.markAsFailed(mediaId)
                        }
                    }
                } else {
                    mediaState.markAsFailed(mediaId)
                }
            }
        }
        
        // Clean up any media items with invalid data
        if let media = session.media {
            session.media = media.filter { mediaItem in
                let mediaId = mediaItem.id ?? UUID()
                return !mediaState.failedThumbnails.contains(mediaId)
            }
        }
    }
    
    // Add this function to SessionDetailView
    private func cleanupInvalidMedia() {
        if let media = session.media {
            let validMedia = media.filter { mediaItem in
                let mediaId = mediaItem.id ?? UUID()
                return !mediaState.failedThumbnails.contains(mediaId) && !mediaItem.data.isEmpty
            }
            
            if validMedia.count != media.count {
                session.media = validMedia
                try? modelContext.save()
            }
        }
    }
    
    private func findMatchingWorkout() {
        guard let date = session.date else { return }
        matchingWorkout = healthKitManager.allSkateboardingWorkouts.first { workout in
            let isMatch = Calendar.current.isDate(workout.startDate, inSameDayAs: date)
            return isMatch
        }
    }
    
    // Helper Views
    @ViewBuilder
    private func heroMediaView(mediaItem: MediaItem) -> some View {
        GeometryReader { geometry in
            Group {
                if let uiImage = mediaState.imageCache[mediaItem.id ?? UUID()] {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 300)
                        .clipped()
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                } else if let thumbnail = mediaState.videoThumbnails[mediaItem.id ?? UUID()] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 300)
                        .clipped()
                        .overlay(alignment: .center) {
                            Image(systemName: "play.circle")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .frame(height: 300)
        .ignoresSafeArea(.all, edges: .top)
        .onTapGesture {
            selectedMediaItem = mediaItem
        }
    }
    
    @ViewBuilder
    private func heroMapView(latitude: Double, longitude: Double) -> some View {
        Map(position: $cameraPosition) {
            Annotation(session.location?.name ?? "Session Location",
                       coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                Image(systemName: "mappin.circle")
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.indigo))
                    .clipShape(Circle())
            }
        }
        .onAppear {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                ),
                distance: 1000,
                heading: 0,
                pitch: 0
            ))
        }
        .frame(height: 300)
        .ignoresSafeArea(.all, edges: .top)
        .allowsHitTesting(false)
    }
    
    private func locationSection(latitude: Double, longitude: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let locationName = session.location?.name {
                Text(locationName)
                    .font(.headline)
                    .fontWidth(.expanded)
            }
            
            Map(position: $cameraPosition) {
                Annotation(session.location?.name ?? "Session Location",
                           coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.indigo))
                        .clipShape(Circle())
                }
            }
            .onAppear {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    ),
                    distance: 5000,
                    heading: 0,
                    pitch: 0
                ))
            }
            .frame(height: 200)
            .cornerRadius(16)
            .allowsHitTesting(false)
        }
    }
    
    // Add this helper function
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// New supporting views
struct TrickCard: View {
    let trick: Trick
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(trick.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .fontWidth(.expanded)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(.secondary.quinary, in: .rect(cornerRadius: 12, style: .continuous))
    }
}

struct ComboCard: View {
    let combo: ComboTrick
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = combo.name {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontWidth(.expanded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
