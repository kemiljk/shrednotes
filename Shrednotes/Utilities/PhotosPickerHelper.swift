import SwiftUI
import PhotosUI
import Photos

// Transfer type that is Sendable
struct MediaItemTransfer: Sendable {
    let id: UUID
    let data: Data
    let assetIdentifier: String?
    let isFromPhotosLibrary: Bool
}

extension PhotosPickerItem {
    // Convert PhotosPickerItem to MediaItemTransfer (which is Sendable)
    func toMediaItemTransfer() async -> MediaItemTransfer? {
        // First try to get the item identifier (this is the PHAsset localIdentifier on iOS)
        if let itemIdentifier = self.itemIdentifier {
            // Try to fetch the PHAsset using this identifier
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
            if let asset = fetchResult.firstObject {
                // Successfully got PHAsset - create transfer with just the identifier
                return MediaItemTransfer(
                    id: UUID(),
                    data: Data(),
                    assetIdentifier: asset.localIdentifier,
                    isFromPhotosLibrary: true
                )
            }
        }
        
        // Fallback: If we can't get identifier, load the data (for compatibility)
        if let data = try? await self.loadTransferable(type: Data.self) {
            return MediaItemTransfer(
                id: UUID(),
                data: data,
                assetIdentifier: nil,
                isFromPhotosLibrary: false
            )
        }
        
        return nil
    }
    
    // Convenience method that creates MediaItem on MainActor
    @MainActor
    func toMediaItem() async -> MediaItem? {
        guard let transfer = await toMediaItemTransfer() else { return nil }
        
        return MediaItem(
            id: transfer.id,
            data: transfer.data,
            assetIdentifier: transfer.assetIdentifier,
            isFromPhotosLibrary: transfer.isFromPhotosLibrary
        )
    }
} 