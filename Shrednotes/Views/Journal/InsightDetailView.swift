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
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .tint(.secondary)
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

#Preview {
    InsightDetailView()
        .modelContainer(for: [SkateSession.self, Trick.self], inMemory: true)
}
