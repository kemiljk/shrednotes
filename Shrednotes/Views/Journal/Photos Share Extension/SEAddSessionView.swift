//
//  SEAddSessionView.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/11/2024.
//

import SwiftUI
import SwiftData

struct SEAddSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var sessions: [SkateSession]
    @State private var mediaItems: [MediaItem]
    @ObservedObject var coordinator: ShareCoordinator
    @StateObject private var mediaState = MediaState()
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var feelings: [Feeling] = []
    @State private var note: String = ""
    
    @FocusState private var titleIsFocused: Bool
    @FocusState private var noteIsFocused: Bool
    
    init(coordinator: ShareCoordinator, mediaItems: [MediaItem]) {
        self.coordinator = coordinator
        self.mediaItems = mediaItems
    }
    
    var body: some View {
        List {
            Section(header: Text("Session Details")) {
                TextField("Title", text: $title)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(titleIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: titleIsFocused ? 2 : 1)
                    )
                    .focused($titleIsFocused)
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
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
            }
            .listRowSeparator(.hidden)
            
            Section(header: Text("Media")) {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 16) {
                    ForEach(mediaItems, id: \.id) { mediaItem in
                        mediaItemView(for: mediaItem)
                    }
                }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .navigationTitle("New Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            title = "Session #\(sessions.count + 1)"
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        coordinator.dismiss()
                    }
                    .foregroundStyle(.indigo)
            }
            ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
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
                } else if let thumbnail = mediaState.videoThumbnails[mediaItem.id ?? UUID()] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width) // Makes it square
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    
    private func saveSession() {
        print("Starting saveSession function")
        let newSession = SkateSession(title: title, date: date, note: note, feeling: feelings, media: mediaItems)
        
        print("Created new SkateSession: \(newSession)")
        
        // First, try to save to SwiftData
        modelContext.insert(newSession)
        
        do {
            try modelContext.save()
            print("Session saved successfully to SwiftData")
        } catch {
            print("Failed to save session to SwiftData: \(error)")
        }
        
        print("Calling coordinator.save()")
        coordinator.save()
        print("saveSession function completed")
    }
}
