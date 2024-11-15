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
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Bindable var session: SkateSession
    @ObservedObject var mediaState: MediaState
    @State private var isHealthAccessGranted: Bool = UserDefaults.standard.bool(forKey: "isHealthAccessGranted")
    
    @State private var selectedMediaItem: MediaItem?
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @Namespace private var sessionPicture
    @State private var preloadedPlayers: [UUID: AVPlayer] = [:]
    @State private var isEditingSession = false
    
    @State private var matchingWorkout: HKWorkout?
    @State private var activeEnergyBurned: Double = 0.0
    
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        if let title = session.title {
                            Text(title)
                                .font(.title)
                                .fontWeight(.bold)
                                .fontWidth(.expanded)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    
                    if let feelings = session.feeling {
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
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                        .offset(y: phase.isIdentity ? 0 : 10)
                                }
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                    }
                    
                    if let note = session.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .textSelection(.enabled)
                            .onLongPressGesture {
                                UIPasteboard.general.string = note
                            }
                    }
                    
                    if let media = session.media, !media.isEmpty {
                        MediaGridView(media: media, mediaState: mediaState, onTap: { mediaItem in
                            selectedMediaItem = mediaItem
                        })
                    }
                    
                    if let tricks = session.tricks, !tricks.isEmpty {
                        Text("Tricks Practiced")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .padding(.top, 16)
                        ForEach(tricks) { trick in
                            NavigationLink(destination: TrickDetailView(trick: trick)) {
                                TrickRow(trick: trick, padless: true)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    
                    if let combos = session.combos, !combos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Combos Practiced")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .fontWidth(.expanded)
                                .padding(.top, 16)
                            ForEach(combos) { combo in
                                VStack(alignment: .leading, spacing: 4) {
                                    ComboTrickRow(combo: combo)
                                }
                            }
                        }
                    }
                    
                    if session.date != nil {
                        StoredWorkoutView(session: session, condensed: true)
                    } else {
                        Text("No date available for this session")
                    }
                    
                    if let latitude = session.latitude, let longitude = session.longitude {
                        VStack(alignment: .leading, spacing: 8) {
                            if let locationName = session.location?.name {
                                Text(locationName)
                                    .font(.headline)
                                    .fontWidth(.expanded)
                            }
                            
                            Map(initialPosition: .camera(MapCamera(
                                centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                distance: 1000, // Distance in meters - increase this value to zoom out more
                                heading: 0,
                                pitch: 0
                            ))) {
                                UserAnnotation()
                                Annotation(session.location?.name ?? "Session Location",
                                          coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Circle().fill(Color.indigo))
                                        .clipShape(Circle())
                                }
                            }
                            .mapStyle(.standard)
                            .mapControls {
                                MapCompass()
                                MapScaleView()
                                
                            }
                            .frame(height: 200)
                            .cornerRadius(16)
                        }
                        .padding(.top, 16)
                    }

                }
                .padding()
            }
            .navigationTitle(session.date?.formatted(date: .abbreviated, time: .omitted) ?? "Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left.circle")
                            .symbolRenderingMode(.hierarchical)
                            .symbolVariant(.fill)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isEditingSession = true
                        } label: {
                            Label("Edit", systemImage: "pencil.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            print("Deleting session and dismissing view")
                            modelContext.delete(session)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .symbolVariant(.fill)
                    }
                }
            }
        }
        .onAppear {
            preGenerateVideoThumbnailsAndPreloadPlayers()
            refreshMediaState()
            healthKitManager.fetchLatestWorkout()
            healthKitManager.fetchAllSkateboardingWorkouts()
            findMatchingWorkout()
        }
        .onChange(of: session.media) {
            refreshMediaState()
        }
        .onChange(of: healthKitManager.allSkateboardingWorkouts) {
            findMatchingWorkout()
        }
        .sheet(isPresented: $isEditingSession) {
            EditSessionView(session: session)
                .presentationCornerRadius(24)
        }
        .fullScreenCover(item: $selectedMediaItem, onDismiss: {
            currentZoom = 0.0
            totalZoom = 1.0
        }) { mediaItem in
            fullscreenMediaView(for: mediaItem)
                .navigationTransition(.zoom(sourceID: mediaItem.id ?? UUID(), in: sessionPicture))
        }
    }
    
    private func fullscreenMediaView(for mediaItem: MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            if let uiImage = UIImage(data: mediaItem.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(currentZoom + totalZoom)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                currentZoom = value.magnification - 1
                            }
                            .onEnded { value in
                                totalZoom += currentZoom
                                currentZoom = 0
                            }
                    )
                    .accessibilityZoomAction { action in
                        if action.direction == .zoomIn {
                            totalZoom += 1
                        } else {
                            totalZoom -= 1
                        }
                    }
            } else if let player = preloadedPlayers[mediaItem.id ?? UUID()] {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        player.play()
                    }
            }
            
            Button(action: {
                selectedMediaItem = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
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
        for mediaItem in session.media ?? [] {
            if let uiImage = UIImage(data: mediaItem.data) {
                mediaState.imageCache[mediaItem.id ?? UUID()] = uiImage
            } else if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                generateThumbnail(for: videoURL) { thumbnail in
                    if let thumbnail = thumbnail {
                        DispatchQueue.main.async {
                            mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                        }
                    }
                }
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
}
