//
//  SessionCard.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//

import SwiftUI
import PhotosUI
import CoreLocation

struct SessionCard: View {
    let session: SkateSession
    @ObservedObject var mediaState: MediaState
    @State private var loadingThumbnails: Set<UUID> = []
    @State private var locationName: String?
    let onTap: (() -> Void)
    let onSelect: (() -> Void)
    
    @State private var mediaData: Data?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let media = session.media, !media.isEmpty {
                mediaItemView(for: media.first!, fullWidth: true)
            }
            if let title = session.title {
                Text(title)
                    .font(.headline)
                    .fontWidth(.expanded)
                    .multilineTextAlignment(.leading)
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
            if let note = session.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let summarizer = TextSummarizer(tricks: session.tricks ?? [])
                let summary = summarizer.summarizeSession(
                    notes: note,
                    landedTricks: session.tricks ?? [],
                    date: session.date ?? .now
                )
                
                Text(summary)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
            }
            if let media = session.media, !media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(media.dropFirst().prefix(3), id: \.id) { item in
                            mediaItemView(for: item)
                        }
                        if media.count > 4 {
                            Text("+\(media.count - 4)")
                                .font(.caption)
                                .frame(width: 60, height: 60)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            Divider()
            HStack {
                if let date = session.date {
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let locationName = session.location?.name {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let tricks = session.tricks {
                    Text("\(tricks.count) tricks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background {
            if let media = session.media?.first,
               let uiImage = UIImage(data: media.data) {
                GeometryReader { geometry in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.2)
                        .overlay {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                        }
                }
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onAppear {
            getLocationName()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private func mediaItemView(for item: MediaItem, fullWidth: Bool = false) -> some View {
        if let uiImage = UIImage(data: item.data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: fullWidth ? 320 : 60, maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
        } else if let thumbnail = mediaState.videoThumbnails[item.id ?? UUID()] {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: fullWidth ? 320 : 60, maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                )
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(minWidth: fullWidth ? 320 : 60, maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                ProgressView()
            }
            .onAppear {
                loadThumbnail(for: item)
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
    
    private func getLocationName() {
        guard let latitude = session.latitude, let longitude = session.longitude else { return }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                let name = [placemark.name, placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !name.isEmpty {
                    self.locationName = name
                } else if let locality = placemark.locality {
                    self.locationName = locality
                } else if let administrativeArea = placemark.administrativeArea {
                    self.locationName = administrativeArea
                }
            }
        }
    }
}
