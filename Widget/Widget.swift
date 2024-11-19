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

// MARK: – Stat Widget
struct InsightsWidget: Widget {
    let kind: String = "InsightsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            InsightsWidgetEntryView(entry: entry)
                .modelContainer(sharedModelContainer)
                .widgetAccentable()
        }
        .configurationDisplayName("Skating Insights")
        .description("Track your skating progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Control Widgets
struct JournalControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "AddSessionControlWidget"
        ) {
            ControlWidgetButton(action: OpenAddSessionIntent()) {
                Label("Add Session", systemImage: "widget.large.badge.plus")
            }
        }
        .displayName("Add Session")
        .description("Quickly add a new skate session")
    }
}

struct OpenAppWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "OpenWidget") {
            ControlWidgetButton(action: OpenAppWidgetIntent()) {
                Label("Open Shrednotes", systemImage: "skateboard")
            }
        }
        .displayName("Open Shrednotes")
        .description("Quickly open the app.")
    }
}

struct ViewJournalControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "ViewJournalControlWidget"
        ) {
            ControlWidgetButton(action: OpenViewJournalIntent()) {
                Label("View Journal", systemImage: "book.pages")
            }
        }
        .displayName("View Journal")
        .description("Quickly access your skate journal entries.")
    }
}

struct PracticeTricksControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "PracticeTricksControlWidget"
        ) {
            ControlWidgetButton(action: OpenPracticeTricksIntent()) {
                Label("Practice Tricks", systemImage: "figure.skateboarding")
            }
        }
        .displayName("Practice Tricks")
        .description("Quickly enter trick practice mode.")
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
            let deepLinkURL = URL(string: "shrednotes://sessionDetail/\(sessionString)")!
            
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
            let reference = SessionReference(latestSession)
            let sessionData = try? JSONEncoder().encode(reference)
            let sessionString = sessionData?.base64EncodedString() ?? ""
            let deepLinkURL = URL(string: "shrednotes://sessionDetail/\(sessionString)")!
            
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
                let deepLinkURL = URL(string: "shrednotes://trickDetail/\(trickString)")!
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
                let deepLinkURL = URL(string: "shrednotes://trickDetail/\(trickString)")!
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

struct InsightsWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallInsightsView()
        case .systemMedium:
            MediumInsightsView()
        case .systemLarge:
            LargeInsightsView()
        default:
            SmallInsightsView()
        }
    }
}

struct SmallInsightsView: View {
    @Query private var sessions: [SkateSession]
    @Query private var tricks: [Trick]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                StatRow(icon: "figure.skating",
                        value: "\(sessions.count)",
                        label: "Sessions")
                
                StatRow(icon: "checkmark.circle.fill",
                        value: "\(tricks.filter { $0.isLearned }.count)",
                        label: "Tricks Learned")
                
                StatRow(icon: "clock.fill",
                        value: formatTotalTime(),
                        label: "Time Skating")
                
                StatRow(icon: "timer",
                        value: formatAverageSessionTime(),
                        label: "Avg Session")
                
                StatRow(icon: "photo.fill",
                        value: "\(totalMediaCount())",
                        label: "Media")
                
                StatRow(icon: "flame.fill",
                        value: calculateStreak(),
                        label: "Streak")
                
                StatRow(icon: "chart.line.uptrend.xyaxis",
                        value: calculateTrickProgress(),
                        label: "Trick Progress")
            }
            Spacer()
        }
        .containerBackground(.background, for: .widget)
    }
    
    private func formatTotalTime() -> String {
        let totalMinutes = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        let hours = Int(totalMinutes / 60)
        
        if hours < 24 {
            return "\(hours)h"
        } else if hours < 168 { // Less than a week
            return "\(hours / 24)d"
        } else {
            return "\(hours / 168)w"
        }
    }
    
    private func formatAverageSessionTime() -> String {
        let totalSeconds = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        guard !sessions.isEmpty else { return "0m" }
        
        let avgSeconds = totalSeconds / Double(sessions.count)
        let minutes = Int(avgSeconds / 60)
        
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private func totalMediaCount() -> Int {
        sessions.reduce(0) { count, session in
            count + (session.media?.count ?? 0)
        }
    }
    
    private func calculateStreak() -> String {
        let sortedSessions = sessions.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        var streak = 0
        var currentDate = Date()
        
        for session in sortedSessions {
            guard let sessionDate = session.date else { continue }
            let calendar = Calendar.current
            let daysBetween = calendar.dateComponents([.day], from: sessionDate, to: currentDate).day ?? 0
            
            if daysBetween <= 1 {
                streak += 1
                currentDate = sessionDate
            } else {
                break
            }
        }
        
        return "\(streak)d"
    }
    
    private func calculateTrickProgress() -> String {
        guard !tricks.isEmpty else { return "0%" }
        let learnedCount = tricks.filter { $0.isLearned }.count
        let percentage = Double(learnedCount) / Double(tricks.count) * 100
        return "\(Int(percentage))%"
    }
}
struct MediumInsightsView: View {
    @Query private var sessions: [SkateSession]
    @Query private var tricks: [Trick]
    
    var body: some View {
        HStack {
            // Left column
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(sessions.count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Right column - Stats
            VStack(alignment: .trailing, spacing: 8) {
                StatRow(icon: "checkmark.circle.fill",
                        value: "\(tricks.filter { $0.isLearned }.count)",
                        label: "Tricks Learned")
                StatRow(icon: "clock.fill",
                        value: formatTotalTime(),
                        label: "Time Skating")
                StatRow(icon: "photo.fill",
                        value: "\(totalMediaCount())",
                        label: "Media Items")
                StatRow(icon: "flame.fill",
                        value: calculateStreak(),
                        label: "Current Streak")
                StatRow(icon: "timer",
                        value: formatAverageSessionTime(),
                        label: "Avg Session")
                StatRow(icon: "chart.line.uptrend.xyaxis",
                        value: calculateTrickProgress(),
                        label: "Trick Progress")
            }
        }
        .containerBackground(.background, for: .widget)
    }
    
    private func formatTotalTime() -> String {
        let totalMinutes = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        let hours = Int(totalMinutes / 60)
        
        if hours < 24 {
            return "\(hours)h"
        } else if hours < 168 { // Less than a week
            return "\(hours / 24)d"
        } else {
            return "\(hours / 168)w"
        }
    }
    
    private func totalMediaCount() -> Int {
        sessions.reduce(0) { count, session in
            count + (session.media?.count ?? 0)
        }
    }
    
    private func calculateStreak() -> String {
        let sortedSessions = sessions.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        var streak = 0
        var currentDate = Date()
        
        for session in sortedSessions {
            guard let sessionDate = session.date else { continue }
            let calendar = Calendar.current
            let daysBetween = calendar.dateComponents([.day], from: sessionDate, to: currentDate).day ?? 0
            
            if daysBetween <= 1 {
                streak += 1
                currentDate = sessionDate
            } else {
                break
            }
        }
        
        return "\(streak)d"
    }
    
    private func formatAverageSessionTime() -> String {
        let totalSeconds = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        guard !sessions.isEmpty else { return "0m" }
        
        let avgSeconds = totalSeconds / Double(sessions.count)
        let minutes = Int(avgSeconds / 60)
        
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private func calculateTrickProgress() -> String {
        guard !tricks.isEmpty else { return "0%" }
        let learnedCount = tricks.filter { $0.isLearned }.count
        let percentage = Double(learnedCount) / Double(tricks.count) * 100
        return "\(Int(percentage))%"
    }
}

struct LargeInsightsView: View {
    @Query private var sessions: [SkateSession]
    @Query private var tricks: [Trick]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main stats
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sessions.count)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Detailed stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatCard(icon: "checkmark.circle.fill",
                        value: "\(tricks.filter { $0.isLearned }.count)",
                        label: "Tricks Learned")
                StatCard(icon: "clock.fill",
                        value: formatTotalTime(),
                        label: "Time Skating")
                StatCard(icon: "photo.fill",
                        value: "\(totalMediaCount())",
                        label: "Media Items")
                StatCard(icon: "flame.fill",
                        value: calculateStreak(),
                        label: "Current Streak")
                StatCard(icon: "timer",
                        value: formatAverageSessionTime(),
                        label: "Avg Session")
                StatCard(icon: "chart.line.uptrend.xyaxis",
                        value: calculateTrickProgress(),
                        label: "Trick Progress")
            }
        }
        .containerBackground(.background, for: .widget)
    }
    
    private func formatTotalTime() -> String {
        let totalMinutes = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        let hours = Int(totalMinutes / 60)
        
        if hours < 24 {
            return "\(hours)h"
        } else if hours < 168 { // Less than a week
            return "\(hours / 24)d"
        } else {
            return "\(hours / 168)w"
        }
    }
    
    private func totalMediaCount() -> Int {
        sessions.reduce(0) { count, session in
            count + (session.media?.count ?? 0)
        }
    }
    
    private func calculateStreak() -> String {
        let sortedSessions = sessions.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        var streak = 0
        var currentDate = Date()
        
        for session in sortedSessions {
            guard let sessionDate = session.date else { continue }
            let calendar = Calendar.current
            let daysBetween = calendar.dateComponents([.day], from: sessionDate, to: currentDate).day ?? 0
            
            if daysBetween <= 1 {
                streak += 1
                currentDate = sessionDate
            } else {
                break
            }
        }
        
        return "\(streak)d"
    }
    
    private func formatAverageSessionTime() -> String {
        let totalSeconds = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        guard !sessions.isEmpty else { return "0m" }
        
        let avgSeconds = totalSeconds / Double(sessions.count)
        let minutes = Int(avgSeconds / 60)
        
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private func calculateTrickProgress() -> String {
        guard !tricks.isEmpty else { return "0%" }
        let learnedCount = tricks.filter { $0.isLearned }.count
        let percentage = Double(learnedCount) / Double(tricks.count) * 100
        return "\(Int(percentage))%"
    }
}

struct StatRow: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
