//
//  LatestSkateView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import HealthKit

// For real-time HealthKit data (used in AddSessionView/EditSessionView)
struct LiveWorkoutView: View {
    var workouts: [HKWorkout]
    var activeEnergyBurned: Double
    var totalDuration: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if !workouts.isEmpty {
                    Text("\(Int(activeEnergyBurned)) cal")
                        .font(.title)
                        .fontWeight(.bold)
                        .fontWidth(.expanded)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatDuration(totalDuration))
                        if let lastDate = workouts.last?.endDate {
                            Text(formatRelativeDate(lastDate))
                        }
                    }
                    .textScale(.secondary)
                    .foregroundStyle(.white).opacity(0.8)
                    Spacer()
                } else {
                    Text("No workout data for this date")
                        .textScale(.secondary)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .foregroundStyle(.white)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]),
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

// For stored SwiftData values (used in MainView and SessionDetailView)
struct StoredWorkoutView: View {
    @Environment(\.colorScheme) private var colorScheme
    var session: SkateSession
    var condensed: Bool = false
    
    var body: some View {
        if condensed {
            VStack(alignment: .leading) {
                HStack {
                    if let workoutEnergy = session.workoutEnergyBurned {
                        Text("\(Int(workoutEnergy)) cal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontWidth(.expanded)
                    }
                        
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        if let workoutDuration = session.workoutDuration {
                            Text(formatDuration(workoutDuration))
                        }
                        if let lastDate = session.date {
                            Text(formatRelativeDate(lastDate))
                        }
                    }
                    .textScale(.secondary)
                    .foregroundStyle(.white).opacity(0.8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]),
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        } else {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Section(header:
                                    HStack {
                            Text("Latest Skate")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Image(systemName: "figure.skateboarding")
                                .foregroundStyle(.secondary)
                        }
                            .frame(maxWidth: .infinity)
                        ) {
                            if let workoutEnergy = session.workoutEnergyBurned {
                                Text("\(Int(workoutEnergy)) cal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .fontWidth(.expanded)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 0) {
                                if let workoutDuration = session.workoutDuration {
                                    Text(formatDuration(workoutDuration))
                                }
                                if let lastDate = session.date {
                                    Text(formatRelativeDate(lastDate))
                                }
                            }
                            .textScale(.secondary)
                            .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(.background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(colorScheme == .light ? .black : .white, lineWidth: 2)
                        .blendMode(.overlay)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}
