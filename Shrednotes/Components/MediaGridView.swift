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
                MediaGridItemView(item: item, mediaState: mediaState, onTap: onTap)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct MediaGridItemView: View {
    let item: MediaItem
    @ObservedObject var mediaState: MediaState
    let onTap: (MediaItem) -> Void
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = loadedImage ?? mediaState.imageCache[item.id ?? UUID()] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            onTap(item)
                        }
                } else if let thumbnail = mediaState.videoThumbnails[item.id ?? UUID()] {
                    ZStack {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                            .cornerRadius(8)
                        
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .onTapGesture {
                        onTap(item)
                    }
                } else if isLoading {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
        }
        .onAppear {
            loadMedia()
        }
    }
    
    private func loadMedia() {
        if item.isFromPhotosLibrary, let identifier = item.assetIdentifier {
            // Load from Photos library
            guard let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) else {
                isLoading = false
                return
            }
            
            if asset.mediaType == .image {
                PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: 300, height: 300)) { image in
                    DispatchQueue.main.async {
                        self.loadedImage = image
                        if let image = image, let id = item.id {
                            self.mediaState.imageCache[id] = image
                        }
                        self.isLoading = false
                    }
                }
            } else if asset.mediaType == .video {
                PhotosHelper.shared.getVideoURL(for: item) { url in
                    if let url = url {
                        generateThumbnail(for: url) { thumbnail in
                            DispatchQueue.main.async {
                                if let thumbnail = thumbnail, let id = item.id {
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
        } else if !item.data.isEmpty {
            // Legacy data-based loading
            if let uiImage = UIImage(data: item.data) {
                loadedImage = uiImage
                if let id = item.id {
                    mediaState.imageCache[id] = uiImage
                }
            } else if let videoURL = saveVideoToTemporaryDirectory(data: item.data) {
                generateThumbnail(for: videoURL) { thumbnail in
                    DispatchQueue.main.async {
                        if let thumbnail = thumbnail, let id = item.id {
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

