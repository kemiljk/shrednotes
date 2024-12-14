//
//  Utils.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//
import SwiftUI
import SwiftData
import AVKit

extension Int {
    var difficultyString: String {
        switch self {
        case 1: return "Beginner"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Unknown"
        }
    }
}

extension MediaItem: Equatable {
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TrickType: String, CaseIterable, Codable {
    case basic = "Basic"
    case air = "Air"
    case flip = "Flip"
    case shuvit = "Shove It"
    case grind = "Grind"
    case slide = "Slide"
    case transition = "Transition"
    case footplant = "Footplant"
    case balance = "Balance"
    case misc = "Misc"
    
    var displayName: String {
        switch self {
        case .shuvit:
            return "Shove it"
        default:
            return rawValue.capitalized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value.lowercased() {
        case "shuvit": self = .shuvit
        default:
            if let type = TrickType(rawValue: value) {
                self = type
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid TrickType value: \(value)"
                ))
            }
        }
    }
}

enum ElementType: String, Codable {
    case baseTrick
    case direction
    case rotation
    case landing
    case obstacle
    case other
    
    var displayName: String {
        switch self {
        case .baseTrick:
            return "Base trick"
        default:
            return rawValue.capitalized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value.lowercased() {
        case "base trick": self = .baseTrick
        case "direction": self = .direction
        case "rotation": self = .rotation
        case "landing": self = .landing
        case "obstacle": self = .obstacle
        default:
            if let type = ElementType(rawValue: value) {
                self = type
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ElementType value: \(value)"  // Changed from TrickType
                ))
            }
        }
    }
}

enum ProgressState: String, CaseIterable {
    case notStarted = "Not Started"
    case learning = "Learning"
    case learned = "Learned"
}

enum Feeling: String, CaseIterable, Codable {
    case stoked, exhausted, pumped, thrilled
    case hyped, wrecked, amped, bummed
    case confident, sketchy, dialed, flowing
    case firedUp = "Fired Up"
    case gnarly, chill, rad, mellow
    case blissed, fizzled, slammed
}

func formatDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .short
    formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
    formatter.zeroFormattingBehavior = .dropAll
    return formatter.string(from: duration) ?? "0 min"
}

func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

func saveVideoToTemporaryDirectory(data: Data) -> URL? {
    let tempDirectory = FileManager.default.temporaryDirectory
    let videoURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
    
    do {
        try data.write(to: videoURL)
        return videoURL
    } catch {
        print("Error saving video to temporary directory: \(error)")
        return nil
    }
}

func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
    let asset = AVURLAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    let time = CMTime(seconds: 1, preferredTimescale: 60)
    imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
        if let error = error {
            print("Error generating thumbnail: \(error)")
            completion(nil)
            return
        }
        if let image = image {
            completion(UIImage(cgImage: image))
        } else {
            completion(nil)
        }
    }
}

func addMediaButton() -> some View {
    let size = UIScreen.main.bounds.width / 3 - 16
    return Image(systemName: "plus")
        .font(.largeTitle)
        .foregroundStyle(.indigo)
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}

struct ProgressiveBlur: ViewModifier {
    var blurRadius: CGFloat
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // Blurred background rectangle
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .frame(height: 64) // Adjust height as needed
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.1)]),
                                 startPoint: .top,
                                 endPoint: .bottom)
                )
        }
    }
}

