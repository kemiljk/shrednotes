//
//  InsightDetailView.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//

import SwiftUI
import SwiftData

struct InsightDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Query private var sessions: [SkateSession]
    @Query private var tricks: [Trick]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontWidth(.expanded)
                        .padding(.horizontal)
                    
                    // Stats Grid
                    VStack(spacing: 16) {
                        // Total Sessions
                        InsightCard(
                            label: "Sessions this year",
                            value: "\(sessions.count)",
                            backgroundColor: Color(.systemBlue).opacity(0.1)
                        )
                        
                        // Tricks and Time
                        HStack(spacing: 16) {
                            InsightCard(
                                label: "Tricks learned",
                                value: "\(tricks.filter { $0.isLearned }.count)",
                                backgroundColor: Color(.systemBlue).opacity(0.1)
                            )
                            
                            InsightCard(
                                label: "Time skating",
                                value: formatTotalTime(),
                                backgroundColor: Color(.systemBlue).opacity(0.08)
                            )
                        }
                        
                        // Media Count
                        InsightCard(
                            label: "Total photos/videos captured",
                            value: "\(totalMediaCount())",
                            backgroundColor: Color(.systemBlue).opacity(0.1)
                        )
                        
                        // New: This Week, Month, Year stats
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                InsightCard(
                                    label: "Sessions this week",
                                    value: "\(sessionsThisWeek.count)",
                                    backgroundColor: Color(.systemTeal).opacity(0.1)
                                )
                                InsightCard(
                                    label: "Time this week",
                                    value: formatDuration(sessionsThisWeek.reduce(0) { $0 + ($1.workoutDuration ?? 0) }),
                                    backgroundColor: Color(.systemTeal).opacity(0.08)
                                )
                            }
                            HStack(spacing: 16) {
                                InsightCard(
                                    label: "Sessions this month",
                                    value: "\(sessionsThisMonth.count)",
                                    backgroundColor: Color(.systemGreen).opacity(0.1)
                                )
                                InsightCard(
                                    label: "Time this month",
                                    value: formatDuration(sessionsThisMonth.reduce(0) { $0 + ($1.workoutDuration ?? 0) }),
                                    backgroundColor: Color(.systemGreen).opacity(0.08)
                                )
                            }
                            HStack(spacing: 16) {
                                InsightCard(
                                    label: "Sessions this year",
                                    value: "\(sessionsThisYear.count)",
                                    backgroundColor: Color(.systemOrange).opacity(0.1)
                                )
                                InsightCard(
                                    label: "Time this year",
                                    value: formatDuration(sessionsThisYear.reduce(0) { $0 + ($1.workoutDuration ?? 0) }),
                                    backgroundColor: Color(.systemOrange).opacity(0.08)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Streaks
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Streaks")
                            .font(.title3)
                            .fontWeight(.bold)
                            .fontWidth(.expanded)
                        HStack(spacing: 16) {
                            StreakCard(
                                label: "Longest Daily Streak",
                                value: "5 Days",
                                backgroundColor: Color(.systemPink).opacity(0.1)
                            )
                            StreakCard(
                                label: "Longest Weekly Streak",
                                value: "8 Weeks",
                                backgroundColor: Color(.systemPurple).opacity(0.1)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Calendar Heat Map for Sessions (moved below streaks)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skating Frequency (Last 12 Weeks)")
                            .font(.headline)
                            .fontWidth(.expanded)
                            .padding(.bottom, 4)
                        SessionHeatMapView(sessions: sessions, weeks: 12)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
            }
        }
    }
    
    private func totalMediaCount() -> Int {
        sessions.reduce(0) { count, session in
            count + (session.media?.count ?? 0)
        }
    }

    private func formatTotalTime() -> String {
        let totalMinutes = sessions.reduce(0.0) { $0 + ($1.workoutDuration ?? 0) }
        
        let years = Int(totalMinutes / 525600) // 365 days * 24 hours * 60 minutes
        let months = Int((totalMinutes.truncatingRemainder(dividingBy: 525600)) / 43800) // 30.5 days * 24 hours * 60 minutes
        let days = Int((totalMinutes.truncatingRemainder(dividingBy: 43800)) / 1440) // 24 hours * 60 minutes
        let hours = Int((totalMinutes.truncatingRemainder(dividingBy: 1440)) / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        
        var components: [String] = []
        
        if years > 0 {
            components.append("\(years) years")
        }
        if months > 0 {
            components.append("\(months) months")
        }
        if days > 0 {
            components.append("\(days) days")
        }
        if hours > 0 {
            components.append("\(hours) hours")
        }
        if minutes > 0 || components.isEmpty {
            components.append("\(minutes) minutes")
        }
        
        // Return first two most significant units
        return components.prefix(2).joined(separator: " ")
    }

    // MARK: - Date Filtering Helpers
    private var sessionsThisWeek: [SkateSession] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return sessions.filter { session in
            if let date = session.date {
                return weekInterval.contains(date)
            }
            return false
        }
    }
    private var sessionsThisMonth: [SkateSession] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        return sessions.filter { session in
            if let date = session.date {
                return monthInterval.contains(date)
            }
            return false
        }
    }
    private var sessionsThisYear: [SkateSession] {
        let calendar = Calendar.current
        guard let yearInterval = calendar.dateInterval(of: .year, for: Date()) else { return [] }
        return sessions.filter { session in
            if let date = session.date {
                return yearInterval.contains(date)
            }
            return false
        }
    }
    // Format duration for week/month/year stats
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct InsightCard: View {
    let label: String
    let value: String
    let backgroundColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StreakCard: View {
    let label: String
    let value: String
    let backgroundColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SessionHeatMapView: View {
    let sessions: [SkateSession]
    let weeks: Int

    private var sessionData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        for session in sessions {
            if let date = session.date {
                let day = calendar.startOfDay(for: date)
                data[day, default: 0] += 1
            }
        }
        return data
    }

    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today) ?? today
        var dates: [Date] = []
        var currentDate = startDate
        while currentDate <= today {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return dates
    }

    private func colorForIntensity(_ count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.6)
        case 3: return Color.green.opacity(0.8)
        default: return Color.green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Use the parent width for grid sizing
            let columns = 7
            let _: CGFloat = 6 * 2
            
            // The grid
            HeatMapGrid(dateRange: dateRange, sessionData: sessionData, columns: columns, colorForIntensity: colorForIntensity)
            
            Spacer()

            // Legend
            HStack(spacing: 12) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(0..<5) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForIntensity(intensity))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct HeatMapGrid: View {
    let dateRange: [Date]
    let sessionData: [Date: Int]
    let columns: Int
    let colorForIntensity: (Int) -> Color

    var body: some View {
        // Use a fixed or default width for grid items
        let itemSize: CGFloat = 18 // Reasonable default for most screens
        let rows = dateRange.count / columns + 1
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(itemSize), spacing: 2), count: columns),
            spacing: 2
        ) {
            ForEach(Array(dateRange.enumerated()), id: \.offset) { _, date in
                let count = sessionData[date] ?? 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(colorForIntensity(count))
                    .frame(width: itemSize, height: itemSize)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(rows) * (itemSize + 2))
        .frame(minHeight: 100)
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    InsightDetailView()
        .modelContainer(for: [SkateSession.self, Trick.self], inMemory: true)
}
