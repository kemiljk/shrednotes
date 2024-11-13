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
    
    // Add spacing between grid items
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        let gridSpacing: CGFloat = 8
        
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(media, id: \.id) { mediaItem in
                if let uiImage = UIImage(data: mediaItem.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .onTapGesture {
                            onTap(mediaItem)
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "video.fill")
                                .foregroundColor(.white)
                                .font(.caption)
                        )
                        .onTapGesture {
                            onTap(mediaItem)
                        }
                }
            }
        }
    }
}
