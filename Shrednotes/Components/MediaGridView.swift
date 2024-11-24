//
//  MediaGridView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI

struct MediaGridView: View {
    var media: [MediaItem]
    @ObservedObject var mediaState: MediaState
    var onTap: (MediaItem) -> Void
    @State private var loadingThumbnails: Set<UUID> = []

    // Add spacing between grid items
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        let gridSpacing: CGFloat = 8
        
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(media, id: \.id) { item in
                if let uiImage = UIImage(data: item.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            onTap(item)
                        }
                        
                } else if let thumbnail = mediaState.videoThumbnails[item.id ?? UUID()] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            onTap(item)
                        }
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        )
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .cornerRadius(8)
                        
                        ProgressView()
                    }
                    .onAppear {
                        loadThumbnail(for: item)
                    }
                }
            }
        }
    }
    private func loadThumbnail(for item: MediaItem) {
        guard let id = item.id else { return }
        guard !loadingThumbnails.contains(id) else { return }
        
        loadingThumbnails.insert(id)
        
        if let videoURL = saveVideoToTemporaryDirectory(data: item.data) {
            generateThumbnail(for: videoURL) { thumbnail in
                DispatchQueue.main.async {
                    if let thumbnail = thumbnail {
                        mediaState.videoThumbnails[id] = thumbnail
                    }
                    loadingThumbnails.remove(id)
                }
            }
        } else {
            loadingThumbnails.remove(id)
        }
    }
}

