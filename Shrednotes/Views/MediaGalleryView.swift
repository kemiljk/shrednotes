import SwiftUI
import AVKit
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct MediaGalleryView: View {
    let mediaItems: [MediaItem]
    let initialItem: MediaItem
    @StateObject private var mediaState: MediaState
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex: Int
    
    init(mediaItems: [MediaItem], initialItem: MediaItem, mediaState: MediaState) {
        self.mediaItems = mediaItems
        self.initialItem = initialItem
        self._mediaState = StateObject(wrappedValue: mediaState)
        
        let initialIndex = mediaItems.firstIndex(where: { $0.id == initialItem.id }) ?? 0
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Simple TabView - horizontal for now, but reliable
            TabView(selection: $currentIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, item in
                    MediaItemView(
                        item: item,
                        mediaState: mediaState,
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .ignoresSafeArea()
            
            // Persistent dismiss button - always visible in top right
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
                    .padding(.trailing, 16)
                    .padding(.top, 48)
                }
                
                Spacer()
            }
            .ignoresSafeArea() // This ensures it goes into the safe area
        }
    }
}

// Separate view for each media item
struct MediaItemView: View {
    let item: MediaItem
    @ObservedObject var mediaState: MediaState
    
    @State private var loadedImage: UIImage?
    @State private var videoURL: URL?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = loadedImage {
                // Display image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let url = videoURL {
                // Display video
                VideoPlayer(player: AVPlayer(url: url)) {
                    // Video overlay content
                }
            } else if isLoading {
                // Loading state
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                // Error state
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Unable to load media")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadMedia()
        }
    }
    
    private func loadMedia() {
        // If we have data, use it directly
        if !item.data.isEmpty {
            if let image = UIImage(data: item.data) {
                loadedImage = image
                isLoading = false
            } else {
                // It's video data - save to temp file
                if let url = saveVideoToTemporaryFile() {
                    videoURL = url
                    isLoading = false
                }
            }
        } else if item.isFromPhotosLibrary, let identifier = item.assetIdentifier {
            // Load from Photos library
            guard let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) else {
                isLoading = false
                return
            }
            
            if asset.mediaType == .image {
                PhotosHelper.shared.loadImage(from: asset, targetSize: UIScreen.main.bounds.size) { image in
                    DispatchQueue.main.async {
                        self.loadedImage = image
                        self.isLoading = false
                    }
                }
            } else if asset.mediaType == .video {
                PhotosHelper.shared.getVideoURL(for: item) { url in
                    DispatchQueue.main.async {
                        self.videoURL = url
                        self.isLoading = false
                    }
                }
            }
        } else {
            isLoading = false
        }
    }
    
    private func saveVideoToTemporaryFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(item.id?.uuidString ?? UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Write data to temporary file
        do {
            try item.data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing video to temporary file: \(error)")
            return nil
        }
    }
} 
