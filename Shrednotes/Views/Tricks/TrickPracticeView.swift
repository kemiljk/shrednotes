import SwiftUI
import SwiftData

struct TrickPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Trick> { $0.isLearning }) private var learningTricks: [Trick]
    @State private var shuffledTricks: [Trick] = []
    @State private var currentTrickIndex = 0
    @State private var landedAttempts = 0
    @State private var failedAttempts = 0
    @State private var showCheckmark = false
    @State private var oldConsistency = 0
    @State private var newConsistency = 0
    @State private var showConsistencyChange = false
    @State private var showCompletionSheet = false
    
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
        .onAppear {
            setupInitialState()
        }
        .sheet(isPresented: $showCompletionSheet, content: {
            completionSheet
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
                GroupBox {
                    Text("Landed")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .backgroundStyle(.clear)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.teal.opacity(0.3), lineWidth: 2)
                }
                .overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.teal.opacity(0.2))
                            .frame(width: geometry.size.width * CGFloat(landedAttempts) / 10)
                    }
                )
                .clipShape(.capsule)
                .foregroundStyle(.teal)
                
                GroupBox {
                    Text("Bailed")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .backgroundStyle(.clear)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.red.opacity(0.3), lineWidth: 2)
                }
                .overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: geometry.size.width * CGFloat(failedAttempts) / 10)
                    }
                )
                .clipShape(.capsule)
                .foregroundStyle(.red)
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
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showCheckmark)
        .animation(.smooth, value: showConsistencyChange)
    }
    
    private var completionSheet: some View {
        VStack(spacing: 20) {
            Text(singleTrick != nil ? "Practice Complete!" : "All Tricks Practiced!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .multilineTextAlignment(.center)
            
            Text(singleTrick != nil ? "You've completed practicing this trick." : "You've practiced all your learning tricks.")
                .font(.subheadline)
            
            Spacer()
            
            GradientButton<Any, Bool, Never>(
                label: "Finish",
                action: {
                    showCompletionSheet = false
                    dismiss()
                },
                hapticTrigger: showCompletionSheet
            )
        }
        .padding()
        .presentationCornerRadius(24)
        .presentationDetents([.medium])
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
}
