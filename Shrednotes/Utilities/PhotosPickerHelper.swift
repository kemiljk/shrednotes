import SwiftUI
import PhotosUI
import Photos

extension PhotosPickerItem {
    // Convert PhotosPickerItem to MediaItem using PHAsset identifier
    func toMediaItem() async -> MediaItem? {
        // First try to get the item identifier (this is the PHAsset localIdentifier on iOS)
        if let itemIdentifier = self.itemIdentifier {
            // Try to fetch the PHAsset using this identifier
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
            if let asset = fetchResult.firstObject {
                // Successfully got PHAsset - create MediaItem with just the identifier
                return MediaItem(
                    id: UUID(),
                    data: Data(),
                    assetIdentifier: asset.localIdentifier,
                    isFromPhotosLibrary: true
                )
            }
        }
        
        // Fallback: If we can't get identifier, load the data (for compatibility)
        if let data = try? await self.loadTransferable(type: Data.self) {
            return MediaItem(
                id: UUID(),
                data: data,
                assetIdentifier: nil,
                isFromPhotosLibrary: false
            )
        }
        
        return nil
    }
}

// Extension to help with processing multiple items
extension View {
    func processPhotosPickerItems(_ items: [PhotosPickerItem]) async -> [MediaItem] {
        var mediaItems: [MediaItem] = []
        
        for item in items {
            if let mediaItem = await item.toMediaItem() {
                mediaItems.append(mediaItem)
            }
        }
        
        return mediaItems
    }
} 