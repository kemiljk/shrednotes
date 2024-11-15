import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct ShareView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var mediaItems: [MediaItem] = []
    var extensionContext: NSExtensionContext?
    @ObservedObject var coordinator: ShareCoordinator
    @StateObject private var mediaState = MediaState()

    var body: some View {
        NavigationView {
            SEAddSessionView(coordinator: coordinator, mediaItems: mediaItems)
                .environment(\.modelContext, modelContext)
        }
        .onAppear {
            print("ShareView onAppear called")
            loadSharedMediaItems()
        }
    }

    private func loadSharedMediaItems() {
        print("Loading shared media items")
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("No input items found")
            return
        }
        for item in items {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        print("Found image attachment")
                        loadImageAttachment(attachment)
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        print("Found video attachment")
                        loadVideoAttachment(attachment)
                    }
                }
            }
        }
    }

    private func loadImageAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, error in
            if let url = data as? URL, let imageData = try? Data(contentsOf: url) {
                let mediaItem = MediaItem(data: imageData)
                DispatchQueue.main.async {
                    print("Loaded image: \(String(describing: mediaItem.id))")
                    self.mediaItems.append(mediaItem)
                    self.mediaState.imageCache[mediaItem.id ?? UUID()] = UIImage(data: imageData)
                }
            } else {
                print("Failed to load image: \(String(describing: error))")
            }
        }
    }

    private func loadVideoAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { data, error in
            if let url = data as? URL {
                let mediaItem = MediaItem(data: try! Data(contentsOf: url))
                DispatchQueue.main.async {
                    print("Loaded video: \(String(describing: mediaItem.id))")
                    self.mediaItems.append(mediaItem)
                    generateThumbnail(for: url) { thumbnail in
                        if let thumbnail = thumbnail {
                            self.mediaState.videoThumbnails[mediaItem.id ?? UUID()] = thumbnail
                        }
                    }
                }
            } else {
                print("Failed to load video: \(String(describing: error))")
            }
        }
    }
}
