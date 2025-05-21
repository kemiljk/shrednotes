//
//  OnboardingView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var locationManager = LocationManager()
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var healthAccessGranted: Bool = UserDefaults.standard.bool(forKey: "HealthAccessGranted")
    @State private var notificationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "NotificationAccessGranted")
    @State private var isNotificationAccessGranted: Bool = false
    @State private var locationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "LocationAccessGranted")
    @State private var visibleTrickTypes: Set<TrickType> = Set(TrickType.allCases)
    @State private var learnedTricks: Set<Trick> = []
    @State private var learningTricks: Set<Trick> = []
    
    @State private var healthPulse = false
    @State private var notificationPulse = false
    @State private var locationPulse = false
    @State private var trickTypePulse = false
    @State private var learnedTricksPulse = false
    @State private var learningTricksPulse = false
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Welcome to Shrednotes!")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
                .fontWidth(.expanded)
                .fontWeight(.bold)
                .padding()
            
            Spacer()
            
            switch currentStep {
            case 0:
                healthAccessView
            case 1:
                notificationAccessView
            case 2:
                locationAccessView
            case 3:
                trickTypeSelectionView
            case 4:
                learnedTricksSelectionView
            case 5:
                learningTricksSelectionView
            default:
                EmptyView()
            }
        }
        .onAppear {
            healthPulse = true
        }
        .onChange(of: currentStep) { _, newValue in
            switch newValue {
            case 1:
                notificationPulse = true
            case 2:
                locationPulse = true
            case 3:
                trickTypePulse = true
            case 4:
                learnedTricksPulse = true
            case 5:
                learningTricksPulse = true
            default:
                break
            }
        }
        .onChange(of: healthAccessGranted) { _, granted in
            if granted {
                currentStep += 1
            }
        }
        .onChange(of: notificationAccessGranted) { _, granted in
            if granted {
                notificationAccessGranted = true
                currentStep += 1
            }
        }
        .onReceive(locationManager.$locationAccessGranted) { granted in
            if granted {
                locationAccessGranted = true
                currentStep += 1
            }
        }
    }
    
    private var healthAccessView: some View {
        ScrollView {
            Image(systemName: "heart.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.pink)
                .font(.largeTitle)
                .symbolEffect(.breathe, options: .repeating, value: healthPulse)
            Text("We need access to your Health data to track your Skating workouts.")
                .padding()
                .multilineTextAlignment(.center)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if healthAccessGranted {
                    GradientButton<Any, Bool, Never>(
                        label: "Next",
                        hasImage: true,
                        image: "arrow.right.circle.fill",
                        action: {
                            currentStep += 1
                        },
                        hapticTrigger: healthAccessGranted
                    )
                    .padding(.horizontal)
                } else {
                    GradientButton<Any, Bool, Never>(
                        label: "Grant Health Access",
                        hasImage: true,
                        image: "heart.fill",
                        action: {
                            healthKitManager.requestAuthorization { success in
                                DispatchQueue.main.async {
                                    healthAccessGranted = success
                                }
                            }
                        },
                        hapticTrigger: healthAccessGranted
                    )
                    .padding(.horizontal)
                }
                if currentStep < 5 {
                    Button("Skip") {
                        currentStep += 1
                    }
                    .padding()
                }
            }
        }
    }
    
    private var notificationAccessView: some View {
        ScrollView {
            Image(systemName: "app.badge")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.primary, .red)
                .font(.largeTitle)
                .symbolEffect(.wiggle, value: notificationPulse)
            Text("Enable notifications to stay updated on your skating progress.")
                .padding()
                .multilineTextAlignment(.center)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if isNotificationAccessGranted {
                    GradientButton<Any, Bool, Never>(
                        label: "Next",
                        hasImage: true,
                        image: "arrow.right.circle.fill",
                        action: {
                            currentStep += 1
                        },
                        hapticTrigger: notificationAccessGranted
                    )
                    .padding(.horizontal)
                } else {
                    GradientButton<Any, Bool, Never>(
                        label: "Grant Notification Access",
                        hasImage: true,
                        image: "app.badge.fill",
                        action: {
                            requestNotificationAuthorization()
                        },
                        hapticTrigger: notificationAccessGranted
                    )
                    .padding(.horizontal)
                }
                if currentStep < 5 {
                    Button("Skip") {
                        currentStep += 1
                    }
                    .padding()
                }
            }
        }
    }
    
    private var locationAccessView: some View {
        ScrollView {
            Image(systemName: "location.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.teal)
                .font(.largeTitle)
                .symbolEffect(.pulse, options: .repeating, value: locationPulse)
            Text("We need access to your location to track your skating sessions.")
                .padding()
                .multilineTextAlignment(.center)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                    GradientButton<Any, Bool, Never>(
                        label: "Next",
                        hasImage: true,
                        image: "arrow.right.circle.fill",
                        action: {
                            currentStep += 1
                        },
                        hapticTrigger: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                    )
                    .padding(.horizontal)
                } else {
                    GradientButton<Any, Bool, Never>(
                        label: "Grant Location Access",
                        hasImage: true,
                        image: "location.fill",
                        action: {
                            locationManager.requestLocationAuthorization()
                        },
                        hapticTrigger: false
                    )
                    .padding(.horizontal)
                }
                if currentStep < 5 {
                    Button("Skip") {
                        currentStep += 1
                    }
                    .padding()
                }
            }
        }
    }
    
    private var trickTypeSelectionView: some View {
        ScrollView {
            Image(systemName: "skateboard")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)
                .font(.largeTitle)
                .symbolEffect(.wiggle, value: trickTypePulse)
            Text("Select the trick types you want to see")
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(TrickType.allCases, id: \.self) { type in
                        Button(action: {
                            toggleTrickType(type)
                        }) {
                            Text(type.displayName)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(visibleTrickTypes.contains(type) ? Color.indigo : Color.secondary.opacity(0.2))
                                .foregroundColor(visibleTrickTypes.contains(type) ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                .offset(y: phase.isIdentity ? 0 : 4)
                        }
                    }
                }
                .scrollTargetBehavior(.viewAligned)
            }
            .contentMargins(.horizontal, 20)
            
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                GradientButton<Any, Int, Never>(
                    label: "Next",
                    hasImage: true,
                    image: "arrow.right.circle.fill",
                    action: {
                        currentStep += 1
                    },
                    hapticTrigger: currentStep
                )
                .padding(.horizontal)
                if currentStep < 5 {
                    Button("Skip") {
                        currentStep += 1
                    }
                    .padding()
                }
            }
        }
    }
    
    private var learnedTricksSelectionView: some View {
        ScrollView {
            Image(systemName: "figure.skateboarding.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)
                .font(.largeTitle)
                .symbolEffect(.pulse, options: .repeating, value: learnedTricksPulse)
                Text("Select the tricks you've already learned")
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                FullTrickListViewForOnboarding(
                    visibleTrickTypes: $visibleTrickTypes,
                    learnedTricks: $learnedTricks,
                    learningTricks: $learningTricks,
                    mode: .learned
                )
            }
            .contentMargins(.horizontal, 20)
            .safeAreaInset(edge: .bottom) {
                VStack {
                    GradientButton<Any, Int, Never>(
                        label: "Next",
                        hasImage: true,
                        image: "arrow.right.circle.fill",
                        action: {
                            currentStep += 1
                        },
                        hapticTrigger: currentStep
                    )
                    .padding(.horizontal)
                    if currentStep < 5 {
                        Button("Skip") {
                            currentStep += 1
                        }
                        .padding()
                    }
                }
            }
    }
    
    private var learningTricksSelectionView: some View {
        ScrollView {
            Image(systemName: "figure.skateboarding.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)
                .font(.largeTitle)
                .symbolEffect(.pulse, options: .repeating, value: learningTricksPulse)
            Text("Select the tricks you're currently learning")
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            
            FullTrickListViewForOnboarding(
                visibleTrickTypes: $visibleTrickTypes,
                learnedTricks: $learnedTricks,
                learningTricks: $learningTricks,
                mode: .learning
            )
        }
        .contentMargins(.horizontal, 20)
        .safeAreaInset(edge: .bottom) {
            VStack {
                GradientButton<Any, Bool, Never>(
                    label: "Let's go!",
                    hasImage: true,
                    image: "figure.skateboarding",
                    action: {
                        completeOnboarding()
                    },
                    hapticTrigger: isOnboardingComplete
                )
                .padding(.horizontal)
                if currentStep < 5 {
                    Button("Skip") {
                        currentStep += 1
                    }
                    .padding()
                }
            }
        }
    }
    
    private func toggleTrickType(_ type: TrickType) {
        if visibleTrickTypes.contains(type) {
            visibleTrickTypes.remove(type)
        } else {
            visibleTrickTypes.insert(type)
        }
    }
    
    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
        UserDefaults.standard.set(healthAccessGranted, forKey: "HealthAccessGranted")
        UserDefaults.standard.set(notificationAccessGranted, forKey: "NotificationAccessGranted")
        UserDefaults.standard.set(locationAccessGranted, forKey: "LocationAccessGranted")
        saveVisibleTrickTypes()
        dismiss()
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                notificationAccessGranted = granted
            }
        }
        isNotificationAccessGranted = true
    }
    
    private func saveVisibleTrickTypes() {
        let encodedData = try? JSONEncoder().encode(visibleTrickTypes)
        UserDefaults.standard.set(encodedData, forKey: "visibleTrickTypes")
    }
    
}
