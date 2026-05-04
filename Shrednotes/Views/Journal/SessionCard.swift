//
//  SessionCard.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//

import SwiftUI
import PhotosUI
import CoreLocation
import MapKit
import CoreImage

struct SessionCard: View {
    let session: SkateSession
    @Bindable var mediaState: MediaState
    @State private var loadingThumbnails: Set<UUID> = []
    @State private var locationName: String?
    let onTap: (() -> Void)
    let onSelect: (() -> Void)
    
    @State private var mediaData: Data?
    @State private var dominantColor: Color?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroMediaIfAny
            titleIfAny
            feelingsScroll
            noteIfAny
            mediaThumbnailRow
            Divider()
            metaRow
        }
        .padding(20)
        .background {
            if let dominantColor = dominantColor {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                dominantColor.opacity(0.3),
                                dominantColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
            } else if let id = session.media?.first?.id,
                      let cached = mediaState.imageCache[id] {
                GeometryReader { geometry in
                    Image(uiImage: cached)
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
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 28))
        .onAppear {
            getLocationName()
            extractDominantColor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Body slices

    @ViewBuilder
    private var heroMediaIfAny: some View {
        if let media = session.media, !media.isEmpty, let first = media.first {
            mediaItemView(for: first, fullWidth: true)
        }
    }

    @ViewBuilder
    private var titleIfAny: some View {
        if let title = session.title {
            Text(title)
                .font(.headline)
                .fontWidth(.expanded)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var feelingsScroll: some View {
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
    }

    @ViewBuilder
    private var noteIfAny: some View {
        if let note = session.note,
           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = note.components(separatedBy: .newlines)
            let truncated = lines.prefix(3).joined(separator: "\n")
            let display = lines.count > 3 ? truncated + "..." : truncated
            Text(display)
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var mediaThumbnailRow: some View {
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
    }

    private var metaRow: some View {
        HStack {
            if let date = session.date {
                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let duration = session.workoutDuration, duration > 0 {
                Text("•")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(formatDuration(duration), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleOnly)
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

    @ViewBuilder
    private func mediaItemView(for item: MediaItem, fullWidth: Bool = false) -> some View {
        let cachedImage = mediaState.imageCache[item.id ?? UUID()]
        let cachedThumb = mediaState.videoThumbnails[item.id ?? UUID()]

        if let uiImage = cachedImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let thumbnail = cachedThumb {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Image(systemName: "play.circle")
                        .foregroundColor(.white)
                        .font(.title3)
                )
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: fullWidth ? .infinity : 60, minHeight: fullWidth ? 200 : 60, maxHeight: fullWidth ? 200 : 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                ProgressView()
            }
            .task(id: item.id) {
                await loadMedia(for: item)
            }
        }
    }

    @MainActor
    private func loadMedia(for item: MediaItem) async {
        guard let id = item.id else { return }
        guard !loadingThumbnails.contains(id) else { return }
        loadingThumbnails.insert(id)
        defer { loadingThumbnails.remove(id) }

        // Decode image off main thread.
        let data = item.data
        let decoded: UIImage? = await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value

        if let img = decoded {
            mediaState.imageCache[id] = img
            return
        }

        // Fall back to video thumbnail.
        if let videoURL = saveVideoToTemporaryDirectory(data: data) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                generateThumbnail(for: videoURL) { thumbnail in
                    Task { @MainActor in
                        if let thumb = thumbnail {
                            mediaState.videoThumbnails[id] = thumb
                        }
                        cont.resume()
                    }
                }
            }
        }
    }
    
    private func getLocationName() {
        guard let latitude = session.latitude, let longitude = session.longitude else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        guard let request = MKReverseGeocodingRequest(location: location) else { return }
        
        Task {
            do {
                let mapItems = try await request.mapItems
                guard let mapItem = mapItems.first else { return }
                
                await MainActor.run {
                    if let name = mapItem.name, !name.isEmpty {
                        self.locationName = name
                    } else if let address = mapItem.address {
                        self.locationName = address.fullAddress
                    }
                }
            } catch {
                print("Reverse geocoding error: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func extractDominantColor() {
        guard let media = session.media?.first else { return }
        
        Task {
            let color: Color?
            
            if let uiImage = UIImage(data: media.data) {
                color = await extractColorFromImage(uiImage)
            } else if let identifier = media.assetIdentifier,
                      let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) {
                color = await extractColorFromAsset(asset)
            } else {
                color = nil
            }
            
            await MainActor.run {
                self.dominantColor = color
            }
        }
    }
    
    private func extractColorFromImage(_ image: UIImage) async -> Color? {
        return await Task.detached(priority: .utility) {
            guard let inputImage = CIImage(image: image) else { return nil }
            
            let extentVector = CIVector(x: inputImage.extent.origin.x,
                                       y: inputImage.extent.origin.y,
                                       z: inputImage.extent.size.width,
                                       w: inputImage.extent.size.height)
            
            guard let filter = CIFilter(name: "CIAreaAverage",
                                       parameters: [kCIInputImageKey: inputImage,
                                                  kCIInputExtentKey: extentVector]) else { return nil }
            guard let outputImage = filter.outputImage else { return nil }
            
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
            context.render(outputImage,
                         toBitmap: &bitmap,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: nil)
            
            return Color(red: Double(bitmap[0]) / 255,
                        green: Double(bitmap[1]) / 255,
                        blue: Double(bitmap[2]) / 255)
        }.value
    }
    
    private func extractColorFromAsset(_ asset: PHAsset) async -> Color? {
        return await withCheckedContinuation { continuation in
            PhotosHelper.shared.loadImage(from: asset, targetSize: CGSize(width: 100, height: 100)) { image in
                if let image = image {
                    Task {
                        let color = await self.extractColorFromImage(image)
                        continuation.resume(returning: color)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

