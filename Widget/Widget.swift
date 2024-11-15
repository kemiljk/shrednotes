import WidgetKit
import SwiftUI
import SwiftData
import Charts
import AppIntents

// MARK: - Provider
struct Provider: TimelineProvider {
    typealias Entry = SimpleEntry
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entries = [SimpleEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - Helper Extensions
extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: self, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day) day\(day == 1 ? "" : "s") ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Latest Session Widget
struct LatestSessionWidget: Widget {
    static let schema = Schema([
        SkateSession.self,
        Trick.self,
        MediaItem.self,
        ComboTrick.self,
        Entry.self,
        Note.self
    ])
    
    let kind: String = "LatestSessionWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LatestSessionView()
                .modelContainer(sharedModelContainer)
        }
        .configurationDisplayName("Latest Session")
        .description("See your most recent skate session")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Session Stats Widget
struct SessionStatsWidget: Widget {
    let kind: String = "SessionStatsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SessionStatsView()
                .modelContainer(sharedModelContainer)
        }
        .configurationDisplayName("Session Stats")
        .description("View your skating statistics")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Quick Glance Widget
struct QuickGlanceWidget: Widget {
    let kind: String = "QuickGlanceWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QuickGlanceView()
                .modelContainer(sharedModelContainer)
        }
        .configurationDisplayName("Quick Glance")
        .description("See your skating status at a glance")
        .supportedFamilies([.accessoryRectangular, .systemSmall])
    }
}

// MARK: - Widget Views
struct QuickGlanceView: View {
    @Environment(\.widgetFamily) var family
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]
    
    var body: some View {
        if let latestSession = sessions.first {
            let sessionData = try? JSONEncoder().encode(latestSession)
            let sessionString = sessionData?.base64EncodedString() ?? ""
            let deepLinkURL = URL(string: "shredNotes://sessionDetail/\(sessionString)")!
            
            VStack(alignment: .leading, spacing: 4) {
                Text("LATEST SESSION")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(latestSession.title ?? "Untitled Session")
                    .font(.headline)
                    .fontWidth(family == .accessoryRectangular ? .standard : .expanded)
                    .lineLimit(1)
                
                if family != .accessoryRectangular {
                    let summarizer = TextSummarizer(tricks: latestSession.tricks ?? [])
                    let summary = summarizer.summarizeSession(
                        notes: latestSession.note ?? "",
                        landedTricks: latestSession.tricks ?? [],
                        date: latestSession.date ?? .now
                    )
                    
                    Text(summary)
                        .font(.caption)
                }
                
                Text(latestSession.date?.timeAgo() ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.background, for: .widget)
            .widgetURL(deepLinkURL)
        } else {
            ContentUnavailableView("No Sessions",
                                   systemImage: "skateboard",
                                   description: Text("Get skating!")
            )
        }
    }
}

struct LatestSessionView: View {
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]
    
    var feelings: [Feeling] {
        sessions.first?.feeling ?? []
    }
    
    var body: some View {
        if let latestSession = sessions.first {
            let sessionData = try? JSONEncoder().encode(latestSession)
            let sessionString = sessionData?.base64EncodedString() ?? ""
            let deepLinkURL = URL(string: "shredNotes://sessionDetail/\(sessionString)")!
            
            VStack(alignment: .leading, spacing: 4) {
                Text(latestSession.title ?? "Latest Session")
                    .fontWidth(.expanded)
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack(spacing: 8) {
                    ForEach(feelings, id: \.self) { feeling in
                        Text(feeling.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 4)
                
                VStack {
                    let summarizer = TextSummarizer(tricks: latestSession.tricks ?? [])
                    let summary = summarizer.summarizeSession(
                        notes: latestSession.note ?? "",
                        landedTricks: latestSession.tricks ?? [],
                        date: latestSession.date ?? .now
                    )
                    
                    Text(summary)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                HStack {
                    Text(latestSession.date?.formatted(date: .numeric, time: .omitted) ?? "")
                    Text("•")
                    Text(latestSession.location?.name ?? "Unknown Location")
                    Spacer()
                    Text("\(latestSession.tricks?.count ?? 0) tricks")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .containerBackground(.background, for: .widget)
            .widgetURL(deepLinkURL)
        } else {
            ContentUnavailableView("No Sessions",
                                   systemImage: "skateboard",
                                   description: Text("Get skating!")
            )
        }
    }
}

struct SessionStatsView: View {
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]

    var filteredSessions: [SkateSession] {
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessions.filter { ($0.date ?? Date()) > lastWeek }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredSessions.isEmpty {
                ContentUnavailableView("No Sessions",
                                       systemImage: "skateboard",
                                       description: Text("Get skating!")
                )
            } else {
                HStack {
                    Text("Latest sessions")
                        .fontWidth(.expanded)
                        .font(.headline)
                    
                    Spacer()
                    
                    let totalCalories = filteredSessions.prefix(7).compactMap({ $0.workoutEnergyBurned }).reduce(0, +)
                    Text("Total Calories: \(Int(totalCalories))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                Chart(filteredSessions.prefix(7)) { session in
                    BarMark(
                        x: .value("Day", session.date ?? Date(), unit: .day),
                        y: .value("Duration", (session.workoutDuration ?? 0) / 3600)
                    )
                    .foregroundStyle(.indigo.gradient)
                    .cornerRadius(8, style: .continuous)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel("\(value.index) hrs")
                    }
                }
                .frame(height: 100)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}


// MARK: - Learn Next Widget
struct LearnNextWidget: Widget {
    let kind: String = "LearnNextWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LearnNextView()
                .modelContainer(sharedModelContainer)
        }
        .configurationDisplayName("Learn Next")
        .description("See which trick you should learn next")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}

struct LearnNextView: View {
    @Environment(\.widgetFamily) var family
    @AppStorage("nextTrickToLearn", store: UserDefaults(suiteName: "group.com.shredNotes.nextTrick"))
    private var nextTrickData: Data = Data()
    
    var nextTrick: Trick? {
        guard !nextTrickData.isEmpty else { return nil }
        return try? JSONDecoder().decode(Trick.self, from: nextTrickData)
    }
    
    var body: some View {
        if family == .systemSmall || family == .systemMedium {
            if let trick = nextTrick {
                let trickData = try? JSONEncoder().encode(trick)
                let trickString = trickData?.base64EncodedString() ?? ""
                let deepLinkURL = URL(string: "shredNotes://trickDetail/\(trickString)")!
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "skateboard")
                            .imageScale(.small)
                        Spacer()
                    }
                    
                    Text("LEARN NEXT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(trick.name)
                        .fontWeight(.semibold)
                        .fontWidth(.expanded)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(trick.type.displayName)
                            .font(.caption)
                        Spacer()
                        difficultyStars(count: trick.difficulty)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .containerBackground(.background, for: .widget)
                .widgetURL(deepLinkURL)
            } else {
                Text("No trick selected")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
            }
        }
        if family == .accessoryRectangular {
            if let trick = nextTrick {
                let trickData = try? JSONEncoder().encode(trick)
                let trickString = trickData?.base64EncodedString() ?? ""
                let deepLinkURL = URL(string: "shredNotes://trickDetail/\(trickString)")!
                VStack(alignment: .leading, spacing: 4) {
                    Text("LEARN NEXT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(trick.name)
                        .font(.headline)
                        .fontWidth(family == .accessoryRectangular ? .standard : .expanded)
                        .lineLimit(1)
                    
                    Text(trick.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .containerBackground(.clear, for: .widget)
                .widgetURL(deepLinkURL)
            }
        }
    }
    
    @ViewBuilder
    func difficultyStars(count: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .imageScale(.small)
            }
        }
    }
}

struct AddSessionButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "AddSessionControlWidget"
        ) {
            ControlWidgetButton(action: JournalControlWidgetIntent()) {
                Label("Add Session", systemImage: "widget.large.badge.plus")
            }
        }
        .displayName("Add Session")
        .description("Quickly add a new skate session")
    }
}

struct JournalControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "JournalWidget") {
            ControlWidgetButton(action: JournalControlWidgetIntent()) {
                Label("Journal Quick Add", systemImage: "widget.large.badge.plus")
            }
        }
        .displayName("Journal Quick Add")
        .description("Quickly add a new journal entry.")
    }
}
