import SwiftUI
import SwiftData
import UserNotifications

struct TrickPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Trick> { $0.isLearning }) private var learningTricks: [Trick]
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]
    @State private var shuffledTricks: [Trick] = []
    @State private var currentTrickIndex: Int = 0
    @State private var landedAttempts: Int = 0
    @State private var failedAttempts: Int = 0
    @State private var showCheckmark: Bool = false
    @State private var oldConsistency: Int = 0
    @State private var newConsistency: Int = 0
    @State private var showConsistencyChange: Bool = false
    @State private var showCompletionSheet: Bool = false
    @State private var showInfoPanel: Bool = false
    
    let singleTrick: Trick?
    
    init(singleTrick: Trick? = nil) {
        self.singleTrick = singleTrick
    }
    
    var body: some View {
        VStack {
            if let trick = singleTrick ?? getCurrentTrick() {
                practiceView(for: trick)
            } else {
                Text("No tricks to practice")
            }
        }
        .navigationTitle(singleTrick != nil ? "Practice \(singleTrick!.name)" : "Practice Mode")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfoPanel.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .sheet(isPresented: $showCompletionSheet, content: {
            completionSheet
        })
        .sheet(isPresented: $showInfoPanel, content: {
            infoPanel
        })
    }
    
    private func getCurrentTrick() -> Trick? {
        guard !shuffledTricks.isEmpty, currentTrickIndex < shuffledTricks.count else {
            return nil
        }
        return shuffledTricks[currentTrickIndex]
    }
    
    private func practiceView(for trick: Trick) -> some View {
        VStack {
            Spacer()
            
            Text(trick.name)
                .font(.largeTitle)
                .fontWidth(.expanded)
                .fontWeight(.bold)
                .padding()
            
            ConsistencyRatingViewCondensed(consistency: trick.consistency)
                .padding(.horizontal)
            
            HStack {
                Gauge(value: Double(landedAttempts) / 10.0) {
                    Text("Lands")
                }
                .tint(.teal)
                
                Gauge(value: Double(failedAttempts) / 10.0) {
                    Text("Bails")
                }
                .tint(.red)
            }
            .font(.subheadline)
            .padding(.top, 24)
            .padding(.horizontal)
            .animation(.easeOut(duration: 0.3), value: landedAttempts)
            .animation(.easeOut(duration: 0.3), value: failedAttempts)
            
            Spacer()
            
            HStack {
                Button {
                    landedAttempts += 1
                    checkProgress()
                } label: {
                    Text("Landed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .opacity(showCheckmark ? 0.5 : 1)
                .disabled(showCheckmark)
                .sensoryFeedback(.success, trigger: landedAttempts)
                
                Button {
                    failedAttempts += 1
                    checkProgress()
                } label: {
                    Text("Bailed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .opacity(showCheckmark ? 0.5 : 1)
                .disabled(showCheckmark)
                .sensoryFeedback(.error, trigger: failedAttempts)
            }
            .padding()
            
            if learningTricks.count > 1 {
                Button {
                    moveToNextTrick()
                } label: {
                    Label("Next Trick", systemImage: "arrow.2.circlepath.circle")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay {
            if showCheckmark {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.teal)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            if showConsistencyChange {
                VStack {
                    if oldConsistency == newConsistency {
                        Text("No change")
                            .font(.title)
                            .fontWeight(.bold)
                    } else {
                        Text("Consistency Change")
                            .font(.headline)
                        HStack {
                            Text("\(oldConsistency)")
                                .strikethrough()
                            Image(systemName: "arrow.right")
                            Text("\(newConsistency)")
                                .fontWeight(.bold)
                        }
                        .font(.title)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showCheckmark)
        .animation(.smooth, value: showConsistencyChange)
    }
    
    private var infoPanel: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "info.circle")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
            Text("How it works")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .multilineTextAlignment(.center)
            
            Text("""
                 Regular reps help you to get tricks nailed and maintain or improve consistency. The minute you stop practicing a trick, you start to lose it gradually unless you've developed strong connections in your brain (muscle memory). 
                 
                 Think of this mode like sports drill practice. You get **10** attempts to land a trick before you have to move on to the next trick (if practicing multiple).
                 
                 Tap Landed or Bailed to capture each attempt and see the gauges fill up with your progress.
                 """)
            .font(.subheadline)
            
            Spacer()
            
            GradientButton<Any, Bool, Never>(
                label: "Got it!",
                action: {
                    showInfoPanel = false
                },
                hapticTrigger: showInfoPanel
            )
        }
        .padding()
        .presentationCornerRadius(24)
        .presentationDetents([.fraction(0.6)])
    }
    
    private var completionSheet: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "figure.skateboarding.circle")
                .font(.largeTitle)
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
            Text(singleTrick != nil ? "Practice Complete!" : "All Tricks Practiced!")
                .font(.title)
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(singleTrick != nil ? "You've completed practicing this trick." : "You've practiced all your learning tricks.")
                .font(.subheadline)
            
            Spacer()
            
            GradientButton<Any, Bool, Never>(
                label: "Finish",
                action: {
                    let calendar = Calendar.current
                    let _ = calendar.startOfDay(for: Date())
                    
                    let todaysEntries = sessions
                    
                    if todaysEntries.isEmpty {
                        scheduleJournalReminder()
                    }
                    showCompletionSheet = false
                    dismiss()
                },
                hapticTrigger: showCompletionSheet
            )
            .padding(.bottom)
        }
        .padding()
        .presentationCornerRadius(24)
        .presentationDetents([.fraction(0.3)])
    }
    
    private func setupInitialState() {
        if singleTrick == nil {
            shuffleTricks()
        } else {
            shuffledTricks = [singleTrick!]
        }
    }
    
    private func shuffleTricks() {
        shuffledTricks = learningTricks.shuffled()
    }
    
    private func checkProgress() {
        if landedAttempts + failedAttempts >= 10 {
            oldConsistency = shuffledTricks[currentTrickIndex].consistency
            updateTrickConsistency()
            newConsistency = shuffledTricks[currentTrickIndex].consistency
            showCheckmark = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCheckmark = false
                showConsistencyChange = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showConsistencyChange = false
                    moveToNextTrick()
                }
            }
        }
    }
    
    private func updateTrickConsistency() {
        let currentTrick = shuffledTricks[currentTrickIndex]
        let landedRatio = Double(landedAttempts) / Double(landedAttempts + failedAttempts)
        
        if landedRatio >= 0.8 && currentTrick.consistency < 5 {
            currentTrick.consistency += 1
        } else if landedRatio <= 0.2 && currentTrick.consistency > 0 {
            currentTrick.consistency -= 1
        }
        
        try? modelContext.save()
    }
    
    private func moveToNextTrick() {
        landedAttempts = 0
        failedAttempts = 0
        
        if singleTrick != nil {
            // For single trick practice, show completion sheet
            showCompletionSheet = true
        } else {
            if currentTrickIndex + 1 >= shuffledTricks.count {
                showCompletionSheet = true
            } else {
                currentTrickIndex += 1
            }
        }
    }
    
    private func scheduleJournalReminder() {
        // Check if most recent session is from today
        if let mostRecent = sessions.first,
           let sessionDate = mostRecent.date,
           Calendar.current.isDateInToday(sessionDate) {
            // Already have a session today, don't schedule notification
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Journal"
        content.body = "Record today's skateboarding progress in your journal"
        content.sound = .default
        
        // Schedule for 30 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1 * 60, repeats: false)
        
        let identifier = "journal-reminder-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
