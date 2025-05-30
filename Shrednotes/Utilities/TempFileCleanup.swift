import Foundation

class TempFileCleanup {
    static let shared = TempFileCleanup()
    
    private let tempDirectory = FileManager.default.temporaryDirectory
    
    // Clean up video files older than 24 hours
    func cleanupOldVideoFiles() {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in tempFiles {
                // Only process .mov files (our video files)
                guard fileURL.pathExtension == "mov" else { continue }
                
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    print("Cleaned up old temp video: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning up temp files: \(error)")
        }
    }
    
    // Clean up all temporary video files
    func cleanupAllVideoFiles() {
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in tempFiles {
                // Only remove .mov files
                if fileURL.pathExtension == "mov" {
                    try fileManager.removeItem(at: fileURL)
                    print("Cleaned up temp video: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning up all temp files: \(error)")
        }
    }
    
    // Get current temporary directory size
    func getTempDirectorySize() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in tempFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        } catch {
            print("Error calculating temp directory size: \(error)")
        }
        
        return totalSize
    }
    
    // Format bytes to human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 