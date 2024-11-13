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
        let totalSeconds = sessions.reduce(0.0) { total, session in
            total + (session.workoutDuration ?? 0)
        }
        
        let months = Int(totalSeconds / (30 * 24 * 60 * 60))
        let remainingSeconds = totalSeconds.truncatingRemainder(dividingBy: 30 * 24 * 60 * 60)
        let days = Int(remainingSeconds / (24 * 60 * 60))
        
        return "\(months) months \(days) days"
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
