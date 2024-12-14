//
//  LearnedTrickPromptView.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/12/2024.
//
import SwiftUI
import SwiftData

struct LearnedTrickPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthKitManager: HealthKitManager
    let trick: Trick
    @State private var showingAddSession = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
                
                Text("Congratulations!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Would you like to record a session for landing \(trick.name)?")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                HStack(spacing: 16) {
                    GradientButton<Bool, DismissAction, EmptyView>(
                        label: "Skip",
                        action: { dismiss() },
                        hapticTrigger: dismiss,
                        hapticFeedbackType: .impact,
                        variant: .secondary
                    )
                    
                    GradientButton<Bool, Bool, EmptyView>(
                        label: "Record Session",
                        action: { showingAddSession = true },
                        hapticTrigger: showingAddSession,
                        hapticFeedbackType: .impact,
                        variant: .primary
                    )
                }
                .padding(.top)
            }
            .padding()
            .presentationDetents([.fraction(0.4)])
            .presentationCornerRadius(24)
            .sheet(isPresented: $showingAddSession) {
                AddSessionView(
                    title: "Landed \(trick.name)",
                    note: "Learned \(trick.name)"
                )
                .environmentObject(healthKitManager) 
                .presentationCornerRadius(24)
                .onDisappear {
                    if !showingAddSession {
                        dismiss()
                    }
                }
            }
        }
    }
}
