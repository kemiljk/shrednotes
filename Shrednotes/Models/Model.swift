import SwiftData
import SwiftUI
import CoreLocation
import AVFoundation

@Model
final class SkateSession: Codable {
    var id: UUID?
    var title: String?
    var date: Date?
    var note: String?
    var feeling: [Feeling]?
    var media: [MediaItem]?
    var tricks: [Trick]?
    var combos: [ComboTrick]?
    var latitude: Double?
    var longitude: Double?
    var location: IdentifiableLocation?
    var workoutUUID: UUID?
    var workoutDuration: Double?
    var workoutEnergyBurned: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, date, note, feeling, media, tricks, combos, latitude, longitude, location, workoutUUID, workoutDuration, workoutEnergyBurned
    }

    init(title: String = "", date: Date = Date(), note: String = "", feeling: [Feeling] = [], media: [MediaItem] = [], tricks: [Trick]? = nil, combos: [ComboTrick]? = nil, latitude: Double? = nil, longitude: Double? = nil, location: IdentifiableLocation? = nil, workoutUUID: UUID? = nil, workoutDuration: Double? = nil, workoutEnergyBurned: Double? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.note = note
        self.feeling = feeling
        self.media = media
        self.tricks = tricks
        self.combos = combos
        self.latitude = latitude
        self.longitude = longitude
        self.location = location
        self.workoutUUID = workoutUUID
        self.workoutDuration = workoutDuration
        self.workoutEnergyBurned = workoutEnergyBurned
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decode(String.self, forKey: .note)
        feeling = try container.decode([Feeling].self, forKey: .feeling)
        media = try container.decode([MediaItem].self, forKey: .media)
        tricks = try container.decode([Trick].self, forKey: .tricks)
        combos = try container.decode([ComboTrick].self, forKey: .combos)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        location = try container.decodeIfPresent(IdentifiableLocation.self, forKey: .location)
        workoutUUID = try container.decodeIfPresent(UUID.self, forKey: .workoutUUID)
        workoutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .workoutDuration)
        workoutEnergyBurned = try container.decodeIfPresent(Double.self, forKey: .workoutEnergyBurned)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(note, forKey: .note)
        try container.encode(feeling, forKey: .feeling)
        try container.encode(media, forKey: .media)
        try container.encode(tricks, forKey: .tricks)
        try container.encode(combos, forKey: .combos)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(workoutUUID, forKey: .workoutUUID)
        try container.encodeIfPresent(workoutDuration, forKey: .workoutDuration)
        try container.encodeIfPresent(workoutEnergyBurned, forKey: .workoutEnergyBurned)
    }
}

struct SessionReference: Codable {
    let id: UUID
    
    init(_ session: SkateSession) {
        self.id = session.id ?? UUID()
    }
}

@Model
final class Trick: ObservableObject, Identifiable, Codable {
    var id: UUID?
    var timestamp: Date = Date()
    var name: String = "Ollie"
    var difficulty: Int = 1
    var type: TrickType = TrickType.air
    var isLearned: Bool = false
    var isLearnedDate: Date?
    var isLearning: Bool = false
    var isSkipped: Bool = false
    var notes: [Note]?
    var media: [MediaItem]?
    var consistency: Int = 0
    var wantToLearn: Bool = false
    var wantToLearnDate: Date?
    
    @Relationship(inverse: \DependentTricks.dependentTricks) var dependentTricks: [DependentTricks]?
    @Relationship(inverse: \Prerequisite.prerequisiteTricks) var prerequisites: [Prerequisite]?
    @Relationship(inverse: \Entry.trick) var entries: [Entry]?
    @Relationship(inverse: \SkateSession.tricks) var sessions: [SkateSession]?
    @Relationship(inverse: \ComboTrick.tricks) var combos: [ComboTrick]?


    init(id: UUID = UUID(), timestamp: Date = Date(), name: String = "Ollie", difficulty: Int = 1, type: TrickType = .air, isLearned: Bool = false, isLearnedDate: Date? = nil, isLearning: Bool = false, isSkipped: Bool = false, prerequisites: [Prerequisite]? = nil, dependentTricks: [DependentTricks]? = nil, notes: [Note]? = [], media: [MediaItem]? = nil, consistency: Int = 0, sessions: [SkateSession]? = nil, entries: [Entry]? = nil, wantToLearn: Bool = false, wantToLearnDate: Date? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.difficulty = difficulty
        self.type = type
        self.isLearned = isLearned
        self.isLearnedDate = isLearnedDate
        self.isLearning = isLearning
        self.isSkipped = isSkipped
        self.prerequisites = prerequisites
        self.dependentTricks = dependentTricks
        self.notes = notes
        self.media = media
        self.consistency = consistency
        self.sessions = sessions
        self.entries = entries
        self.wantToLearn = wantToLearn
        self.wantToLearnDate = wantToLearnDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, name, difficulty, type, isLearned, isLearnedDate, isLearning, isSkipped, consistency, wantToLearn, wantToLearnDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(name, forKey: .name)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(type, forKey: .type)
        try container.encode(isLearned, forKey: .isLearned)
        try container.encode(isLearnedDate, forKey: .isLearnedDate)
        try container.encode(isLearning, forKey: .isLearning)
        try container.encode(isSkipped, forKey: .isSkipped)
        try container.encode(consistency, forKey: .consistency)
        try container.encode(wantToLearn, forKey: .wantToLearn)
        try container.encode(wantToLearnDate, forKey: .wantToLearnDate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        name = try container.decode(String.self, forKey: .name)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        type = try container.decode(TrickType.self, forKey: .type)
        isLearned = try container.decode(Bool.self, forKey: .isLearned)
        isLearnedDate = try container.decodeIfPresent(Date.self, forKey: .isLearnedDate)
        isLearning = try container.decode(Bool.self, forKey: .isLearning)
        isSkipped = try container.decode(Bool.self, forKey: .isSkipped)
        consistency = try container.decode(Int.self, forKey: .consistency)
        wantToLearn = try container.decode(Bool.self, forKey: .wantToLearn)
        wantToLearnDate = try container.decode(Date.self, forKey: .wantToLearnDate)
    
    }
}

@Model
final class Note: ObservableObject, Identifiable {
    var id: UUID = UUID()
    var text: String = ""
    var date: Date = Date()
    
    @Relationship(inverse: \Trick.notes) var trick: Trick?
    
    init(text: String, date: Date = Date(), trick: Trick? = nil) {
        self.text = text
        self.date = date
        self.trick = trick
    }
}


@Model
final class Prerequisite: ObservableObject, Identifiable {
    var id: UUID?
    var prerequisiteTricks: [Trick]?
    
    init(id: UUID = UUID(), prerequisiteTricks: [Trick]? = nil) {
        self.id = id
        self.prerequisiteTricks = prerequisiteTricks
    }
}

@Model
final class DependentTricks: ObservableObject, Identifiable {
    var id: UUID?
    var dependentTricks: [Trick]?
    
    init(id: UUID = UUID(), dependentTricks: [Trick]? = nil) {
        self.id = id
        self.dependentTricks = dependentTricks
    }
}

@Model
final class Entry: Identifiable {
    var id: UUID?
    var date: Date?
    var note: String?
    var feeling: [Feeling]?
    var media: [MediaItem]?
    var trick: Trick?
    
    init(id: UUID = UUID(), date: Date = Date(), note: String? = nil, feeling: [Feeling]? = nil) {
        self.id = id
        self.date = date
        self.note = note
        self.feeling = feeling
    }
}

@Model
final class MediaItem: Identifiable, Codable, Hashable {
    
    var id: UUID?
    var data: Data = Data()
    
    enum CodingKeys: String, CodingKey {
        case id, data
    }
    
    @Relationship(inverse: \Trick.media) var trick: Trick?
    @Relationship(inverse: \Entry.media) var entry: Entry?
    @Relationship(inverse: \SkateSession.media) var session: SkateSession?
    
    init(id: UUID = UUID(), data: Data = Data(), trick: Trick? = nil, entry: Entry? = nil, session: SkateSession? = nil) {
        self.id = id
        self.data = data
        self.trick = trick
        self.entry = entry
        self.session = session
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        data = try container.decode(Data.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(data, forKey: .data)
    }
}

class MediaState: ObservableObject {
    @Published var imageCache: [UUID: UIImage] = [:]
    @Published var videoThumbnails: [UUID: UIImage] = [:]
    @Published var failedThumbnails: Set<UUID> = []  // Track failed thumbnails
    
    func markAsFailed(_ id: UUID) {
        DispatchQueue.main.async {
            self.failedThumbnails.insert(id)
            self.imageCache.removeValue(forKey: id)
            self.videoThumbnails.removeValue(forKey: id)
        }
    }
    
    func clearFailed(_ id: UUID) {
        DispatchQueue.main.async {
            self.failedThumbnails.remove(id)
        }
    }
}

@Model
final class ComboTrick: Identifiable, Codable {
    var id: UUID?
    var name: String?
    var difficulty: Int?
    var isLearned: Bool?
    var isLearning: Bool?
    var isSkipped: Bool?
    var indentation: Int?
    var tricks: [Trick]?
    
    @Relationship(inverse: \SkateSession.combos) var sessions: [SkateSession]?
    @Relationship(deleteRule: .cascade) var comboElements: [ComboElement]?
    
    init(id: UUID = UUID(),
         name: String,
         difficulty: Int,
         isLearned: Bool = false,
         isLearning: Bool = false,
         isSkipped: Bool = false,
         indentation: Int = 0,
         comboElements: [ComboElement] = [],
         tricks: [Trick] = [],
         sessions: [SkateSession] = []) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.isLearned = isLearned
        self.isLearning = isLearning
        self.isSkipped = isSkipped
        self.indentation = indentation
        self.comboElements = comboElements
        self.tricks = tricks
        self.sessions = sessions
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case difficulty
        case isLearned
        case isLearning
        case isSkipped
        case indentation
        case comboElements
        case tricks
        case sessions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(isLearned, forKey: .isLearned)
        try container.encodeIfPresent(isLearning, forKey: .isLearning)
        try container.encodeIfPresent(isSkipped, forKey: .isSkipped)
        try container.encodeIfPresent(indentation, forKey: .indentation)
        try container.encodeIfPresent(comboElements, forKey: .comboElements)
        try container.encodeIfPresent(tricks, forKey: .tricks)
        try container.encodeIfPresent(sessions, forKey: .sessions)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty)
        isLearned = try container.decodeIfPresent(Bool.self, forKey: .isLearned)
        isLearning = try container.decodeIfPresent(Bool.self, forKey: .isLearning)
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped)
        indentation = try container.decodeIfPresent(Int.self, forKey: .indentation) ?? 0
        comboElements = try container.decodeIfPresent([ComboElement].self, forKey: .comboElements) ?? []
        tricks = try container.decodeIfPresent([Trick].self, forKey: .tricks) ?? []
        sessions = try container.decodeIfPresent([SkateSession].self, forKey: .sessions) ?? []
    }
}

@Model
final class ComboElement: Identifiable, Codable {
    var id: UUID?
    var type: ElementType?
    var value: String?
    var displayValue: String?
    var isBreak: Bool?
    var indentation: Int?
    var order: Int?
    
    @Relationship(inverse: \ComboTrick.comboElements) var combo: ComboTrick?
    
    init() {
        self.id = UUID()
        self.isBreak = false
        self.order = 0
    }
    
    init(id: UUID = UUID(),
         type: ElementType = .baseTrick,
         value: String = "",
         displayValue: String = "",
         isBreak: Bool = false,
         indentation: Int? = nil,
         order: Int = 0,
         combo: ComboTrick? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.displayValue = displayValue
        self.isBreak = isBreak
        self.indentation = indentation
        self.order = order
        self.combo = combo
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case displayValue
        case isBreak = "break"
        case indentation
        case order
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        type = try container.decodeIfPresent(ElementType.self, forKey: .type)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        displayValue = try container.decodeIfPresent(String.self, forKey: .displayValue)
        isBreak = try container.decodeIfPresent(Bool.self, forKey: .isBreak) ?? false
        indentation = try container.decodeIfPresent(Int.self, forKey: .indentation)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(displayValue, forKey: .displayValue)
        try container.encodeIfPresent(isBreak, forKey: .isBreak)
        try container.encodeIfPresent(indentation, forKey: .indentation)
        try container.encodeIfPresent(order, forKey: .order)
    }
}

struct IdentifiableLocation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let name: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(name)
    }
    
    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, name: String) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.name = name
    }
}
