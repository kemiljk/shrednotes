//
//  Utils.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//
import SwiftUI
import SwiftData
import AVKit
import CoreHaptics

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

struct TrickStreak {
    let currentStreak: Int
    let longestStreak: Int
    let lastPracticed: Date?
    let totalSessions: Int
}

extension Trick {
    func calculateStreak(from sessions: [SkateSession]) -> TrickStreak {
        // Filter sessions that include this trick, sorted by date (newest first)
        let sessionsWithTrick = sessions
            .filter { session in
                session.tricks?.contains(where: { $0.id == self.id }) ?? false
            }
            .sorted { $0.date ?? Date.distantPast > $1.date ?? Date.distantPast }
        
        let totalSessions = sessionsWithTrick.count
        let lastPracticed = sessionsWithTrick.first?.date
        
        // Calculate current streak
        var currentStreak = 0
        let calendar = Calendar.current
        var lastDate: Date?
        
        for session in sessionsWithTrick {
            guard let sessionDate = session.date else { continue }
            
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: sessionDate, to: last).day ?? 0
                
                // If more than 1 day between sessions, streak is broken
                if daysBetween > 1 {
                    break
                }
            }
            
            currentStreak += 1
            lastDate = sessionDate
        }
        
        // Calculate longest streak
        var longestStreak = 0
        var tempStreak = 0
        var previousDate: Date?
        
        for session in sessionsWithTrick.reversed() { // Process from oldest to newest
            guard let sessionDate = session.date else { continue }
            
            if let prev = previousDate {
                let daysBetween = calendar.dateComponents([.day], from: prev, to: sessionDate).day ?? 0
                
                if daysBetween <= 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            
            previousDate = sessionDate
        }
        
        longestStreak = max(longestStreak, tempStreak)
        
        return TrickStreak(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastPracticed: lastPracticed,
            totalSessions: totalSessions
        )
    }
}

struct StreakView: View {
    let streak: Int
    let isActive: Bool
    
    var streakColor: Color {
        if !isActive { return .gray }
        
        switch streak {
        case 0: return .gray
        case 1...3: return .orange
        case 4...7: return .yellow
        case 8...14: return .green
        case 15...30: return .blue
        default: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(streakColor)
            
            Text("\(streak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(streakColor)
            
            if streak > 0 {
                Text(streak == 1 ? "day" : "days")
                    .font(.caption2)
                    .foregroundColor(streakColor.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(streakColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(streakColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Animated State Transitions

struct StateTransition: ViewModifier {
    let isActive: Bool
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color)
                    .scaleEffect(isActive ? 2.5 : 0)
                    .opacity(isActive ? 0 : 0.3)
                    .animation(.easeOut(duration: 0.6), value: isActive)
                    .allowsHitTesting(false)
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActive)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : 0.3)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func stateTransition(isActive: Bool, color: Color) -> some View {
        modifier(StateTransition(isActive: isActive, color: color))
    }
    
    func shake(amount: CGFloat = 10, shakesPerUnit: Int = 3, animatableData: CGFloat) -> some View {
        modifier(ShakeEffect(amount: amount, shakesPerUnit: shakesPerUnit, animatableData: animatableData))
    }
    
    func pulseEffect(color: Color) -> some View {
        modifier(PulseEffect(color: color))
    }
}

// MARK: - Confetti Effect for Learned Tricks

struct ConfettiParticle: View {
    @State private var offsetY: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size * 2)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: Double.random(in: 1.5...2.5))) {
                    offsetY = CGFloat.random(in: 100...200)
                    offsetX = CGFloat.random(in: -50...50)
                    rotation = Double.random(in: -180...180)
                }
                
                withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
                    opacity = 0
                }
            }
    }
}

struct ConfettiView: View {
    let particleCount: Int = 20
    
    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { _ in
                ConfettiParticle(
                    color: [Color.blue, .green, .yellow, .orange, .pink, .purple].randomElement()!,
                    size: CGFloat.random(in: 4...8)
                )
                .position(
                    x: CGFloat.random(in: -50...50),
                    y: 0
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Haptic Feedback Manager

class HapticManager {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    
    init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }
    
    // Simple impact haptics
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Success haptic (for marking trick as learned)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    // Warning haptic (for errors or invalid actions)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    // Selection haptic (for UI selections)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // Custom pattern for trick learned celebration
    func trickLearnedCelebration() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }
        
        do {
            let pattern = try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.1),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0.2)
            ], parameters: [])
            
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    // Custom pattern for streak milestone
    func streakMilestone() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }
        
        do {
            let pattern = try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                ], relativeTime: 0, duration: 0.5),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0.5)
            ], parameters: [])
            
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    // Gentle tap for UI interactions
    func gentleTap() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            impact(.light)
            return
        }
        
        do {
            let pattern = try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0)
            ], parameters: [])
            
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            impact(.light)
        }
    }
}

// MARK: - View Extension for Haptic Feedback

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle, trigger: Bool) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.impact(style)
        }
    }
    
    func hapticSelection(trigger: Bool) -> some View {
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.selection()
        }
    }
}

// MARK: - Dynamic Color System

struct DynamicColors {
    // Progress-based gradient (0.0 to 1.0)
    static func progressGradient(for progress: Double) -> LinearGradient {
        let colors: [Color] = {
            switch progress {
            case 0..<0.25:
                return [.red, .orange]
            case 0.25..<0.5:
                return [.orange, .yellow]
            case 0.5..<0.75:
                return [.yellow, .green]
            case 0.75...1.0:
                return [.green, .teal]
            default:
                return [.gray, .gray]
            }
        }()
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Difficulty-based gradient
    static func difficultyGradient(for level: Int) -> LinearGradient {
        let colors: [Color] = {
            switch level {
            case 1:
                return [.green, .mint]
            case 2:
                return [.teal, .cyan]
            case 3:
                return [.blue, .indigo]
            case 4:
                return [.orange, .red]
            case 5:
                return [.red, .pink]
            case 6...:
                return [.purple, .pink]
            default:
                return [.gray, .gray]
            }
        }()
        
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Combined progress and difficulty gradient
    static func combinedGradient(progress: Double, difficulty: Int) -> LinearGradient {
        let progressColor = progressColor(for: progress)
        let difficultyColor = difficultyColor(for: difficulty)
        
        return LinearGradient(
            colors: [progressColor, difficultyColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Animated gradient colors based on state
    static func stateGradient(for state: TrickRowState) -> LinearGradient {
        switch state {
        case .learned:
            return LinearGradient(
                colors: [.green, .mint, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .learning:
            return LinearGradient(
                colors: [.orange, .yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .wantToLearn:
            return LinearGradient(
                colors: [.blue, .indigo, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .skipped:
            return LinearGradient(
                colors: [.gray, .gray.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .notStarted:
            return LinearGradient(
                colors: [.secondary.opacity(0.3), .secondary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private static func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.25: return .red
        case 0.25..<0.5: return .orange
        case 0.5..<0.75: return .yellow
        case 0.75...1.0: return .green
        default: return .gray
        }
    }
    
    private static func difficultyColor(for level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .teal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        case 6...: return .purple
        default: return .gray
        }
    }
}

enum TrickRowState {
    case notStarted, learning, learned, wantToLearn, skipped
}

// MARK: - Animated Gradient View

struct AnimatedGradient: View {
    let gradient: LinearGradient
    @State private var animateGradient = false
    
    var body: some View {
        gradient
            .hueRotation(.degrees(animateGradient ? 30 : 0))
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
    }
}

// MARK: - Progress Bar with Dynamic Colors

struct DynamicProgressBar: View {
    let progress: Double
    let difficulty: Int
    let height: CGFloat
    
    init(progress: Double, difficulty: Int, height: CGFloat = 4) {
        self.progress = min(max(progress, 0), 1)
        self.difficulty = difficulty
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))
                
                // Progress fill with gradient
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(DynamicColors.combinedGradient(progress: progress, difficulty: difficulty))
                    .frame(width: geometry.size.width * progress)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: height)
    }
}

