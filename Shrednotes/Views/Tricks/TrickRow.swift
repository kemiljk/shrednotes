//
//  TrickRow.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import SwiftData

struct TrickRow: View {
    var trick: Trick
    var padless: Bool = false
    var onDark: Bool = false
    
    @State private var isPressed = false
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)]) private var sessions: [SkateSession]
    
    private var trickStreak: TrickStreak {
        trick.calculateStreak(from: sessions)
    }
    
    var stateColor: Color {
        if trick.isLearned {
            return .green
        } else if trick.isLearning {
            return .orange
        } else if trick.wantToLearn {
            return .blue
        } else if trick.isSkipped {
            return .gray
        } else {
            return .secondary.opacity(0.6)
        }
    }
    
    var stateIcon: String {
        if trick.isLearned {
            return "checkmark.circle.fill"
        } else if trick.isLearning {
            return "circle.dashed"
        } else if trick.wantToLearn {
            return "star.circle.fill"
        } else if trick.isSkipped {
            return "xmark.circle"
        } else {
            return "circle"
        }
    }

    var body: some View {
        VStack {
            HStack {
                // State Icon - only show if not onDark
                if !onDark {
                    Image(systemName: stateIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(stateColor)
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trick.name)
                            .fontWidth(.expanded)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(onDark ? .white : .primary)
                        
                        // Streak indicator (only if not onDark)
                        if !onDark && (trick.isLearned || trick.isLearning) && trickStreak.currentStreak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                Text("\(trickStreak.currentStreak)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack {
                        Text(trick.type.displayName)
                            .foregroundStyle(.secondary)
                            .textScale(.secondary)
                        
                        if trick.isLearnedDate != nil && trick.isLearned {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                            Text("Learned \(trick.isLearnedDate?.formatted(.relative(presentation: .named)) ?? "")")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                        } else if trick.isLearning {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                            Text("Learning now")
                                .foregroundStyle(onDark ? .secondary : stateColor.opacity(0.8))
                                .textScale(.secondary)
                        } else if trick.wantToLearn && !onDark {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                            Text("Up next")
                                .foregroundStyle(stateColor.opacity(0.8))
                                .textScale(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            ConsistencyRatingViewCondensed(consistency: trick.consistency, onDark: onDark)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, padless ? 0 : 16)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .contextMenu {
            // Quick actions
            Button {
                withAnimation {
                    trick.isLearned.toggle()
                    trick.isLearnedDate = trick.isLearned ? Date() : nil
                    trick.isLearning = false
                    trick.wantToLearn = false
                    if trick.isLearned {
                        HapticManager.shared.success()
                    }
                }
            } label: {
                Label(trick.isLearned ? "Mark as Not Learned" : "Mark as Learned", 
                      systemImage: trick.isLearned ? "xmark.circle" : "checkmark.circle.fill")
            }
            
            Button {
                withAnimation {
                    trick.isLearning.toggle()
                    trick.isLearned = false
                    trick.wantToLearn = false
                    HapticManager.shared.selection()
                }
            } label: {
                Label(trick.isLearning ? "Stop Learning" : "Start Learning", 
                      systemImage: trick.isLearning ? "pause.circle" : "play.circle")
            }
            
            Button {
                withAnimation {
                    trick.wantToLearn.toggle()
                    trick.wantToLearnDate = trick.wantToLearn ? Date() : nil
                    trick.isLearned = false
                    trick.isLearning = false
                    HapticManager.shared.selection()
                }
            } label: {
                Label(trick.wantToLearn ? "Remove from Up Next" : "Add to Up Next", 
                      systemImage: trick.wantToLearn ? "star.slash" : "star.circle.fill")
            }
            
            if trickStreak.totalSessions > 0 {
                Divider()
                Section {
                    if trickStreak.totalSessions > 0 {
                        Label("\(trickStreak.totalSessions) sessions", systemImage: "calendar")
                    }
                    if let lastPracticed = trickStreak.lastPracticed {
                        Label("Last: \(lastPracticed.formatted(.relative(presentation: .named)))", 
                              systemImage: "clock")
                    }
                }
            }
        } preview: {
            TrickPreviewCard(trick: trick, streak: trickStreak, sessions: sessions)
                .frame(width: 320)
                .preferredColorScheme(onDark ? .dark : nil)
        }
    }
    
    private func getDifficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
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

// MARK: - Trick Preview Card

struct TrickPreviewCard: View {
    let trick: Trick
    let streak: TrickStreak
    let sessions: [SkateSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: getStateIcon())
                    .font(.title2)
                    .foregroundStyle(getStateColor())
                
                VStack(alignment: .leading) {
                    Text(trick.name)
                        .font(.headline)
                    Text(trick.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Difficulty
                VStack {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < trick.difficulty ? 
                                      getDifficultyColor(trick.difficulty) : 
                                      Color.gray.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text(trick.difficulty.difficultyString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Notes/Description if available
            if let notes = trick.notes, !notes.isEmpty {
                let combinedNotes = notes.map { $0.text }.joined(separator: " ")
                if !combinedNotes.isEmpty {
                    Text(combinedNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.vertical, 4)
                }
            }
            
            // Progress Section
            if trick.isLearned || trick.isLearning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consistency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ConsistencyProgressRing(consistency: trick.consistency, size: 60)
                        .frame(maxWidth: .infinity)
                    
                    DynamicProgressBar(
                        progress: Double(trick.consistency) / 4.0,
                        difficulty: trick.difficulty,
                        height: 6
                    )
                }
            }
            
            // Practice Heat Map
            if streak.totalSessions > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Practice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    CompactHeatMapView(trick: trick, sessions: sessions)
                        .frame(height: 20)
                }
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                if let lastPracticed = streak.lastPracticed {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("Last: \(lastPracticed.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                HStack {
                    if streak.currentStreak > 0 {
                        StreakView(streak: streak.currentStreak, isActive: true)
                            .scaleEffect(0.8)
                    }
                    
                    Spacer()
                    
                    Text("\(streak.totalSessions) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func getStateIcon() -> String {
        if trick.isLearned {
            return "checkmark.circle.fill"
        } else if trick.isLearning {
            return "circle.dashed"
        } else if trick.wantToLearn {
            return "star.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private func getStateColor() -> Color {
        if trick.isLearned {
            return .green
        } else if trick.isLearning {
            return .orange
        } else if trick.wantToLearn {
            return .blue
        } else {
            return .secondary
        }
    }
    
    private func getDifficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
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
