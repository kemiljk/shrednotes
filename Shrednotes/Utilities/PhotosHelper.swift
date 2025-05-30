import Photos
import UIKit
import SwiftUI

class PhotosHelper {
    static let shared = PhotosHelper()
    
    // Request photo library permission
    func requestPhotoLibraryAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
        default:
            return false
        }
    }
    
    // Fetch asset from identifier
    func fetchAsset(identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    // Load image from PHAsset
    func loadImage(from asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            completion(image)
        }
    }
    
    // Load video from PHAsset
    func loadVideo(from asset: PHAsset, completion: @escaping (AVAsset?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, _ in
            completion(avAsset)
        }
    }
    
    // Load data for MediaItem
    func loadMediaData(for item: MediaItem, completion: @escaping (Data?) -> Void) {
        guard let identifier = item.assetIdentifier,
              let asset = fetchAsset(identifier: identifier) else {
            completion(nil)
            return
        }
        
        if asset.mediaType == .image {
            loadImage(from: asset) { image in
                completion(image?.jpegData(compressionQuality: 0.8))
            }
        } else if asset.mediaType == .video {
            // For videos, we should stream instead of loading data
            // Return nil and handle video streaming separately
            completion(nil)
        }
    }
    
    // Get video URL for streaming
    func getVideoURL(for item: MediaItem, completion: @escaping (URL?) -> Void) {
        guard let identifier = item.assetIdentifier,
              let asset = fetchAsset(identifier: identifier),
              asset.mediaType == .video else {
            completion(nil)
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                completion(urlAsset.url)
            } else {
                completion(nil)
            }
        }
    }
}

// Extension to create MediaItem from PHAsset
extension MediaItem {
    static func fromPHAsset(_ asset: PHAsset) -> MediaItem {
        return MediaItem(
            id: UUID(),
            data: Data(), // Empty data - will load on demand
            assetIdentifier: asset.localIdentifier,
            isFromPhotosLibrary: true
        )
    }
    
    // Helper to check if this is a video
    var isVideo: Bool {
        if !data.isEmpty {
            return UIImage(data: data) == nil
        }
        
        if let identifier = assetIdentifier,
           let asset = PhotosHelper.shared.fetchAsset(identifier: identifier) {
            return asset.mediaType == .video
        }
        
        return false
    }
} 