//
//  TrickDetailView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import SwiftData
import PhotosUI
import AVKit

struct TrickDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var trick: Trick
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var expandedMediaIndex: Int?
    @State private var selectedMediaItem: MediaItem?
    @State private var dragOffset: CGSize = .zero
    @Namespace private var trickPicture
    @StateObject private var mediaState = MediaState()
    @State private var preloadedPlayers: [UUID: AVPlayer] = [:]
    @State private var loadingMedia: Set<UUID> = []
    @State private var newNoteText: String = ""
    @State private var consistency: Int = 0
    @State private var learnedDate: Date = Date()
    @State private var progress: ProgressState = .notStarted
    @State private var showDeleteConfirmation = false
    @State private var showEditTrickView = false
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @State private var selectedMediaIds: Set<UUID> = []
    @State private var processedItemIdentifiers = Set<String>()
    @State private var isEditMode: Bool = false
    @State private var showPracticeView = false
    
    @FocusState private var noteIsFocused: Bool
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)]) private var sessions: [SkateSession]

    var body: some View {
        ZStack {
            List {
                trickDetailsSection
                consistencySection
                practiceHistorySection
                notesSection
                mediaSection
                
                Section(header: Text("Trick Practice")) {
                    Button {
                        showPracticeView = true
                    } label: {
                        Text("Practice This Trick")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .controlSize(.large)
                }
                .listRowSeparator(.hidden)
                
            }
            .listStyle(.plain)
            .navigationTitle(trick.name)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditTrickView = true
                        } label: {
                            Label("Edit", systemImage: "pencil.circle")
                        }
                        Button {
                            trickIsLearning(trick: trick)
                        } label: {
                            Label("Learning", systemImage: "circle.dashed")
                        }
                        Button {
                            trickIsLearned(trick: trick, date: Date())
                        } label: {
                            Label("Learned", systemImage: "checkmark.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Trick", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            self.noteIsFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
            }
            .onAppear {
                setupInitialState()
            }
            .onChange(of: selectedItems) {
                handleSelectedItemsChange()
            }
            .onChange(of: trick.isLearning) {
                updateProgressState()
            }
            .onChange(of: trick.isLearned) {
                updateProgressState()
            }
            .confirmationDialog("Are you sure you want to delete this trick?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(trick)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .learnedTrickPrompt()
//        .sheet(isPresented: $showEditTrickView) {
//            EditTrickView(trick: trick)
//                .presentationCornerRadius(24)
//        }
        .sheet(isPresented: $showPracticeView) {
            TrickPracticeView(singleTrick: trick)
                .presentationCornerRadius(24)
        }
        .fullScreenCover(item: $selectedMediaItem, onDismiss: {
            currentZoom = 0.0
            totalZoom = 1.0
        }) { mediaItem in
            fullscreenMediaView(for: mediaItem)
                .navigationTransition(.zoom(sourceID: mediaItem.id ?? UUID(), in: trickPicture))
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
         }
     }
     
     private var trickDetailsSection: some View {
         Section(header: Text("Trick Details")) {
             HStack {
                 Text("Difficulty")
                     .foregroundStyle(.primary)
                 Spacer()
                 Text(trick.difficulty.difficultyString)
                     .foregroundStyle(.secondary)
             }
             HStack {
                 Text("Type")
                     .foregroundStyle(.primary)
                 Spacer()
                 Text(trick.type.rawValue == "Shuvit" ? trick.type.displayName : trick.type.rawValue)
                     .foregroundStyle(.secondary)
             }
             Picker("Progress", selection: $progress) {
                 ForEach(ProgressState.allCases, id: \.self) { state in
                     Text(state.rawValue).tag(state)
                 }
             }
             .onChange(of: progress) { _, newValue in
                 trick.isLearned = (newValue == .learned)
                 trick.isLearning = (newValue == .learning)
                 if newValue == .learned, trick.isLearnedDate == nil {
                     trick.isLearnedDate = Date()
                     LearnedTrickManager.shared.trickLearned(trick)
                 } else if newValue != .learned {
                     trick.isLearnedDate = nil
                 }
                 saveContext(modelContext: modelContext)
             }
             if progress == .learned {
                 DatePicker("Learned Date", selection: Binding(
                     get: { trick.isLearnedDate ?? Date() },
                     set: { trick.isLearnedDate = $0 }
                 ), displayedComponents: .date)
                 .onChange(of: trick.isLearnedDate) {
                     saveContext(modelContext: modelContext)
                 }
             }
         }
         .listRowSeparator(.hidden)
     }
     
     private var consistencySection: some View {
         Section(header: Text("Consistency")) {
             ConsistencyRatingView(consistency: $trick.consistency)
                 .onChange(of: trick.consistency) {
                     checkConsistency()
                     saveContext(modelContext: modelContext)
                     if trick.consistency == 5 {
                         trick.isLearned = true
                         if trick.isLearnedDate == nil {
                             trick.isLearnedDate = Date()
                         }
                     }
                 }
         }
         .listRowSeparator(.hidden)
     }
     
     private var practiceHistorySection: some View {
         Section(header: Text("Practice History")) {
             let trickStreak = trick.calculateStreak(from: sessions)
             
             VStack(alignment: .leading, spacing: 16) {
                 // Streak and session stats
                 HStack(spacing: 20) {
                     VStack(alignment: .leading) {
                         Text("Current Streak")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                         HStack(spacing: 4) {
                             Image(systemName: "flame.fill")
                                 .foregroundColor(.orange)
                             Text("\(trickStreak.currentStreak)")
                                 .font(.title3)
                                 .fontWeight(.semibold)
                             Text(trickStreak.currentStreak == 1 ? "day" : "days")
                                 .font(.caption)
                                 .foregroundStyle(.secondary)
                         }
                     }
                     
                     Spacer()
                     
                     VStack(alignment: .leading) {
                         Text("Total Sessions")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                         Text("\(trickStreak.totalSessions)")
                             .font(.title3)
                             .fontWeight(.semibold)
                     }
                     
                     Spacer()
                     
                     VStack(alignment: .leading) {
                         Text("Longest Streak")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                         Text("\(trickStreak.longestStreak)")
                             .font(.title3)
                             .fontWeight(.semibold)
                     }
                 }
                 .padding(.vertical, 8)
                 
                 // Heat map
                 VStack(alignment: .leading, spacing: 8) {
                     Text("Last 12 Weeks")
                         .font(.caption)
                         .foregroundStyle(.secondary)
                     
                     HeatMapView(trick: trick, sessions: sessions, weeks: 12)
                         .frame(maxWidth: .infinity)
                 }
                 
                 if let lastPracticed = trickStreak.lastPracticed {
                     HStack {
                         Image(systemName: "clock")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                         Text("Last practiced \(lastPracticed.formatted(.relative(presentation: .named)))")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                     }
                 }
             }
             .padding(.vertical, 4)
         }
         .listRowSeparator(.hidden)
     }
     
     private var notesSection: some View {
         Section(header: Text("Notes")) {
             ForEach(trick.notes ?? []) { note in
                 VStack(alignment: .leading, spacing: 8) {
                     Text(note.text)
                     Text(note.date, style: .relative)
                         .font(.caption)
                         .foregroundColor(.secondary)
                 }
                 .padding(.vertical, 4)
             }
             TextField("New Note", text: $newNoteText, axis: .vertical)
                 .padding()
                 .overlay(
                     RoundedRectangle(cornerRadius: 16, style: .continuous)
                         .stroke(noteIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: noteIsFocused ? 2 : 1)
                 )
                 .focused($noteIsFocused)
         }
         .listRowSeparator(.hidden)
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
             } else if let media = trick.media, !media.isEmpty {
                 Button("Select") {
                     isEditMode = true
                 }
                 .controlSize(.small)
                 .buttonBorderShape(.capsule)
                 .buttonStyle(.bordered)
             }
         }) {
             if let media = trick.media, !media.isEmpty {
                 LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                     ForEach(media, id: \.id) { mediaItem in
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
                 }
                 .buttonStyle(.bordered)
                 .buttonBorderShape(.roundedRectangle(radius: 16))
                 .controlSize(.large)
             }
         }
         .listRowSeparator(.hidden)
         .onChange(of: selectedItems) {
             Task {
                 let newMediaItems = await processNewMediaItems()
                 if !newMediaItems.isEmpty {
                     await MainActor.run {
                         if trick.media == nil {
                             trick.media = []
                         }
                         trick.media?.append(contentsOf: newMediaItems)
                         saveContext(modelContext: modelContext)
                     }
                 }
                 selectedItems.removeAll()
             }
         }
     }
     
     @MainActor
     private func processNewMediaItems() async -> [MediaItem] {
         var newMediaItems: [MediaItem] = []
         
         for item in selectedItems {
             guard let identifier = item.itemIdentifier else { continue }
             
             // Skip if we've already processed this item
             guard !processedItemIdentifiers.contains(identifier) else { continue }
             
             if let data = try? await item.loadTransferable(type: Data.self) {
                 let newMediaItem = MediaItem(id: UUID(), data: data)
                 
                 // Check if this item already exists in trick.media
                 if !(trick.media?.contains(where: { $0.id == newMediaItem.id }) ?? false) {
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
                     
                     newMediaItems.append(newMediaItem)
                     processedItemIdentifiers.insert(identifier)
                 }
             }
         }
         
         return newMediaItems
     }

     private func mediaItemView(for mediaItem: MediaItem) -> some View {
         let size = UIScreen.main.bounds.width / 3 - 16
         return Group {
             if let uiImage = UIImage(data: mediaItem.data) {
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
             } else if let _ = saveVideoToTemporaryDirectory(data: mediaItem.data),
                       let thumbnail = mediaState.videoThumbnails[mediaItem.id ?? UUID()] {
                 Image(uiImage: thumbnail)
                     .resizable()
                     .aspectRatio(contentMode: .fill)
                     .frame(width: size, height: size)
                     .clipped()
                     .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                     .overlay(selectionOverlay(for: mediaItem))
                     .overlay(
                         Image(systemName: "play.circle.fill")
                             .foregroundColor(.white)
                             .font(.title)
                     )
                     .onTapGesture {
                         handleMediaItemTap(mediaItem)
                     }
             } else {
                 ProgressView()
                     .frame(width: size, height: size)
                     .background(Color.secondary.opacity(0.1))
                     .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                     .shadow(radius: 5)
                     .onAppear {
                         loadMediaItem(mediaItem)
                     }
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

     private func handleMediaItemTap(_ mediaItem: MediaItem) {
         if isEditMode {
             if let id = mediaItem.id {
                 if selectedMediaIds.contains(id) {
                     selectedMediaIds.remove(id)
                 } else {
                     selectedMediaIds.insert(id)
                 }
             }
         } else {
             withAnimation(.easeInOut) {
                 selectedMediaItem = mediaItem
             }
         }
     }

     private func deleteSelectedMedia() {
         trick.media?.removeAll { mediaItem in
             if let id = mediaItem.id, selectedMediaIds.contains(id) {
                 mediaState.videoThumbnails.removeValue(forKey: id)
                 return true
             }
             return false
         }
         selectedMediaIds.removeAll()
         isEditMode = false
         saveContext(modelContext: modelContext)
     }

     private func loadMediaItem(_ mediaItem: MediaItem) {
         if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
             generateThumbnail(for: videoURL) { thumbnail in
                 if let thumbnail = thumbnail {
                     mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                     loadingMedia.remove(mediaItem.id ?? UUID())
                     saveContext(modelContext: modelContext)
                 }
             }
         } else {
             loadImage(for: mediaItem)
         }
     }

     private func setupInitialState() {
         if let media = trick.media {
             preGenerateVideoThumbnailsAndPreloadPlayers(for: media)
         }
         // Set the initial progress state based on the trick's properties
         if trick.isLearned {
             progress = .learned
         } else if trick.isLearning {
             progress = .learning
         } else {
             progress = .notStarted
         }
     }
     
     private func handleSelectedItemsChange() {
         Task {
             for item in selectedItems {
                 if let data = try? await item.loadTransferable(type: Data.self) {
                     let newMediaItem = MediaItem(id: UUID(), data: data)
                     
                     // Ensure trick.media is initialized
                     if trick.media == nil {
                         trick.media = []
                     }
                     
                     trick.media?.append(newMediaItem)
                     loadingMedia.insert(newMediaItem.id ?? UUID())
                     
                     // Start loading the image or video thumbnail
                     if let _ = UIImage(data: data) {
                         loadImage(for: newMediaItem)
                     } else {
                         if let videoURL = saveVideoToTemporaryDirectory(data: data) {
                             generateThumbnail(for: videoURL) { thumbnail in
                                 if let thumbnail = thumbnail {
                                     mediaState.videoThumbnails[newMediaItem.id ?? UUID()] = thumbnail
                                     loadingMedia.remove(newMediaItem.id ?? UUID())
                                 }
                             }
                         }
                     }
                     saveContext(modelContext: modelContext)
                 }
             }
             selectedItems.removeAll()
         }
     }
     
     private func loadImage(for mediaItem: MediaItem) {
         if let uiImage = UIImage(data: mediaItem.data) {
             mediaState.imageCache[mediaItem.id ?? UUID()] = uiImage
             loadingMedia.remove(mediaItem.id ?? UUID())
             saveContext(modelContext: modelContext)
         }
     }
     
     private func preGenerateVideoThumbnailsAndPreloadPlayers(for media: [MediaItem]) {
         for mediaItem in media {
             if let videoURL = saveVideoToTemporaryDirectory(data: mediaItem.data) {
                 generateThumbnail(for: videoURL) { thumbnail in
                     if let thumbnail = thumbnail {
                         mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                         loadingMedia.remove(mediaItem.id ?? UUID())
                         saveContext(modelContext: modelContext)
                     }
                 }
                 preloadVideoPlayer(for: mediaItem, url: videoURL)
             }
         }
     }
     
     private func preloadVideoPlayer(for mediaItem: MediaItem, url: URL) {
         let player = AVPlayer(url: url)
         player.currentItem?.preferredForwardBufferDuration = 5
         preloadedPlayers[mediaItem.id ?? UUID()] = player
     }
     
     private func trickIsLearned(trick: Trick, date: Date?) {
         trick.isLearnedDate = date
         saveContext(modelContext: modelContext)
         LearnedTrickManager.shared.trickLearned(trick)
     }
     
     private func trickIsLearning(trick: Trick) {
         trick.isLearning = true
         saveContext(modelContext: modelContext)
     }
     
     private func checkConsistency() {
         // Define the threshold for consistency to recommend marking as learned
         let consistencyThreshold = 8
         
         if trick.consistency >= consistencyThreshold && !trick.isLearned {
             // Recommend marking as learned
             trick.isLearned = true
             trick.isLearnedDate = Date()
             saveContext(modelContext: modelContext)
         }
     }
     
     private func addNote() {
         guard !newNoteText.isEmpty else { return }
         let newNote = Note(text: newNoteText)
         trick.notes?.append(newNote)
         newNoteText = ""
         saveContext(modelContext: modelContext)
     }
     
     private func updateProgressState() {
         if trick.isLearned {
             progress = .learned
         } else if trick.isLearning {
             progress = .learning
         } else {
             progress = .notStarted
         }
     }
    
    private func saveContext(modelContext: ModelContext) {
       do {
           try modelContext.save()
       } catch {
           print("Error saving context: \(error)")
       }
   }
 }
