import SwiftUI
import SwiftData
import WidgetKit
import HealthKit
import AppIntents

struct MainView: View {
    @Namespace private var buttonNamespace: Namespace.ID
    @Namespace private var detailView: Namespace.ID
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mediaState: MediaState
    
    @State private var isHealthAccessGranted: Bool = UserDefaults.standard.bool(forKey: "isHealthAccessGranted")
    @State private var expandedGroups: [String: Bool] = [:]
    @State private var searchText: String = ""
    @State private var selectedType: TrickType? = nil
    @State private var visibleTrickTypes: Set<TrickType> = Set(TrickType.allCases)
    @State private var showDeleteConfirmation = false
    @State private var isOnboardingComplete: Bool = false
    @State private var activeSheet: ActiveSheet?
    @State private var showingAddSession = false
    @State private var trick: Trick?
    @State private var session: SkateSession?
    @State private var showTrickDetail: Bool = false
    @State private var showSessionDetail: Bool = false
    @State private var isShowingJournal: Bool = false
    @State private var nextCombinationTricks: [Trick] = []
    @State private var filteredTricks: [Trick] = []
    @State private var inProgressTricks: [Trick] = []
    @State private var refreshView: Bool = false
    @State private var inProgressTricksCount: Int = 0
    @State private var lastProcessedSessionDate: Date?
    @State private var showingComboBuilder = false
    @State private var isInProgressExpanded = false
    @State private var isComboExpanded = false
    @State private var latestWorkoutRefreshTrigger = UUID()
    
    @Environment(NavigationModel.self) private var navigationModel

    @MainActor @AppStorage("nextTrickToLearn", store: UserDefaults(suiteName: "group.com.shredNotes.nextTrick")) private var nextTrickData: Data = Data()
    @AppStorage("HideRecommendations") private var hideRecommendations: Bool = false
    @AppStorage("HideJournal") private var hideJournal: Bool = false
    
    enum ActiveSheet: Identifiable {
        case settings, fullTrickList, onboarding
        
        var id: Int { hashValue }
    }
    
    @Query(sort: [
        SortDescriptor(\Trick.difficulty, order: .forward),
        SortDescriptor(\Trick.name, order: .forward)
    ], animation: .bouncy) private var tricks: [Trick]
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)], animation: .bouncy) private var skateSessions: [SkateSession]
    
    @Query(sort: [SortDescriptor(\ComboTrick.id, order: .reverse)], animation: .bouncy) private var combos: [ComboTrick]
    
    var nextEasiestTrick: Trick? {
        let eligibleTricks = tricks.filter { !$0.isLearned && !$0.isLearning && !$0.isSkipped && visibleTrickTypes.contains($0.type) }
        
        // First, get all wantToLearn tricks sorted by date
        let wantToLearnTricks = eligibleTricks
            .filter { $0.wantToLearn }
            .sorted { ($0.wantToLearnDate ?? .distantFuture) > ($1.wantToLearnDate ?? .distantFuture) }
        
        // If we have any want to learn tricks, return the oldest one
        if let nextWantToLearnTrick = wantToLearnTricks.first {
            return nextWantToLearnTrick
        }
        
        // If no wantToLearn tricks found, fall back to difficulty sorting
        return eligibleTricks
            .sorted { $0.difficulty < $1.difficulty }
            .first
    }
    
    private func similarityScore(trick: Trick, learnedTricks: [Trick]) -> Int {
        let trickWords = Set(trick.name.lowercased().split(separator: " "))
        let learnedWords = Set(learnedTricks.flatMap { $0.name.lowercased().split(separator: " ") })
        
        return trickWords.intersection(learnedWords).count
    }
    
    private func groupedTricks(by type: TrickType) -> [Trick] {
        return tricks.filter { $0.type == type }
    }
    
    private func loadOnboardingStatus() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    }
    
    func loadVisibleTrickTypes() {
        if let data = UserDefaults.standard.data(forKey: "visibleTrickTypes"),
           let decodedSet = try? JSONDecoder().decode(Set<TrickType>.self, from: data) {
            visibleTrickTypes = decodedSet
        }
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible())
    ]
    
    let iPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        @Bindable var navigationModel = navigationModel

        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack(spacing: 16) {
                            if !hideRecommendations {
                                recommendationSection
                            }

                            if let latestSessionDate = skateSessions.first?.date {
                                latestSkateView(latestSessionDate: latestSessionDate)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        .padding(.bottom, !hideRecommendations ? 16 : 0)
                        
                        if iPad {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                                if !inProgressTricks.isEmpty {
                                    inProgressSection
                                }
                                
                                if !combos.isEmpty {
                                    comboTricksSection
                                        .frame(maxHeight: .infinity, alignment: .top)
                                }
                                
                                if !hideRecommendations {
                                    basedOnTricksYouKnowSection
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                if !inProgressTricks.isEmpty {
                                    inProgressSection
                                }
                                
                                if !combos.isEmpty {
                                    comboTricksSection
                                }
                                
                                if !hideRecommendations {
                                    basedOnTricksYouKnowSection
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .refreshable {
                    inProgressTricks = computeInProgressTricks()
                    nextCombinationTricks = computeNextCombinationTricks()
                    filteredTricks = computeFilteredTricks()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .safeAreaInset(edge: .bottom) {
                    ZStack {
                        VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop)
                            .frame(height: 120)
                            .ignoresSafeArea(edges: .bottom)
                            .padding(.bottom, -44)
                        VStack(alignment: .trailing) {
                            HStack {
                                Spacer()
                                if !hideJournal {
                                    GradientButton<Bool, Bool, Never>(
                                        label: "Session",
                                        hasImage: true,
                                        image: "plus.circle.fill",
                                        binding: $showingAddSession,
                                        value: true,
                                        hapticTrigger: showingAddSession
                                    )
                                    .frame(maxHeight: 44)
                                }
                                GradientButton<Bool, Bool, Never>(
                                    label: "Combo",
                                    hasImage: true,
                                    image: "plus.circle.fill",
                                    binding: $showingComboBuilder,
                                    value: true,
                                    hapticTrigger: showingComboBuilder,
                                    variant: .secondary
                                )
                                .frame(maxHeight: 44)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            activeSheet = .settings
                        }) {
                            Image(systemName: "gearshape.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                        .sensoryFeedback(.increase, trigger: activeSheet)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            activeSheet = .fullTrickList
                        }) {
                            Image(systemName: "list.bullet")
                                .symbolVariant(.circle.fill)
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                        .sensoryFeedback(.increase, trigger: activeSheet)
                    }
                    if !hideJournal {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                self.isShowingJournal = true
                            } label: {
                                HStack {
                                    Image(systemName: "book.pages")
                                        .symbolVariant(.fill)
                                    Text("Journal")
                                }
                            }
                            .controlSize(.mini)
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .sensoryFeedback(.increase, trigger: isShowingJournal)
                        }
                    }
                }
                .fullScreenCover(isPresented: $isShowingJournal) {
                    JournalView()
                        .environmentObject(SessionManager.shared)
                }
                .fullScreenCover(isPresented: $showingComboBuilder, content: {
                    NavigationStack {
                        ComboBuilderView()
                            .modelContext(modelContext)
                    }
                    .sensoryFeedback(.increase, trigger: showingComboBuilder)
                })
                .sheet(item: $activeSheet, onDismiss: {
                    do {
                        try modelContext.save()
                    } catch {
                        print("Error saving context: \(error)")
                    }
                }) { item in
                    switch item {
                    case .settings:
                        SettingsView(visibleTrickTypes: $visibleTrickTypes)
                            .presentationCornerRadius(24)
                            .environmentObject(healthKitManager)
                            .onDisappear {
                                loadVisibleTrickTypes()
                            }
                    case .fullTrickList:
                        FullTrickListView(
                            visibleTrickTypes: $visibleTrickTypes,
                            searchText: $searchText,
                            expandedGroups: $expandedGroups,
                            selectedType: $selectedType
                        )
                        .presentationCornerRadius(24)
                        .onDisappear {
                            updateNextTrickInAppStorage()
                            inProgressTricks = computeInProgressTricks()
                            nextCombinationTricks = computeNextCombinationTricks()
                            filteredTricks = computeFilteredTricks()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    case .onboarding:
                        OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                            .presentationCornerRadius(24)
                            .presentationDetents([.medium, .large])
                            .environmentObject(healthKitManager)
                            .interactiveDismissDisabled(!isOnboardingComplete)
                    }
                }
                .sheet(isPresented: $showingAddSession) {
                    AddSessionView()
                        .presentationCornerRadius(24)
                        .modelContext(modelContext)
                }
                .onChange(of: isOnboardingComplete) { _, newValue in
                    if newValue {
                        activeSheet = nil
                        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                        inProgressTricks = computeInProgressTricks()
                        nextCombinationTricks = computeNextCombinationTricks()
                    }
                }
            }
            .onOpenURL { url in
               if let trick = decodeTrick(from: url) {
                    self.trick = trick
                    showTrickDetail = true
                } else if let sessionId = decodeSessionReference(from: url) {
                    if let session = skateSessions.first(where: { $0.id == sessionId }) {
                        self.session = session
                        showSessionDetail = true
                    }
                }
            }
            .navigationDestination(isPresented: $showTrickDetail) {
                if let trick = trick {
                    TrickDetailView(trick: trick)
                        .onDisappear {
                            showTrickDetail = false
                        }
                }
            }
            .sheet(isPresented: $showSessionDetail) {
                if let session = session {
                    SessionDetailView(session: session, mediaState: mediaState)
                        .presentationCornerRadius(24)
                }
            }
            .sheet(isPresented: $navigationModel.showAddSession) {
                AddSessionView()
                    .presentationCornerRadius(24)
                    .modelContext(modelContext)
            }
            .sheet(isPresented: $navigationModel.showViewJournal) {
                JournalView()
                    .presentationCornerRadius(24)
            }
            .sheet(isPresented: $navigationModel.showPracticeTricks) {
                TrickPracticeView()
                    .presentationCornerRadius(24)
            }
            .navigationDestination(for: Trick.self) { trick in
                TrickDetailView(trick: trick)
                    .onDisappear {
                        updateNextTrickInAppStorage()
                        inProgressTricks = computeInProgressTricks()
                        nextCombinationTricks = computeNextCombinationTricks()
                        filteredTricks = computeFilteredTricks()
                        WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .id(inProgressTricksCount)
        .onAppear {
            loadVisibleTrickTypes()
            loadOnboardingStatus()
            if !isOnboardingComplete {
                activeSheet = .onboarding
            }
            updateNextTrickInAppStorage()
            nextCombinationTricks = computeNextCombinationTricks()
            filteredTricks = computeFilteredTricks()
            inProgressTricks = computeInProgressTricks()
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.addObserver(
                forName: .addJournalEntry,
                object: nil,
                queue: .main
            ) { notification in
                if let note = notification.userInfo?["note"] as? String,
                    let title = notification.userInfo?["title"] as? String {
                    let session = SkateSession()
                    session.note = note
                    session.title = title
                    session.date = Date()
                    
                    modelContext.insert(session)
                    try? modelContext.save()
                }
            }
        }
        .onChange(of: nextCombinationTricks) { refreshView.toggle() }
        .onChange(of: filteredTricks) { refreshView.toggle() }
        .onChange(of: inProgressTricks) { refreshView.toggle() }
        .onChange(of: inProgressTricks.count) { _, newValue in
            DispatchQueue.main.async {
                inProgressTricksCount = newValue
            }
        }
        .onChange(of: hasTricksToLearnOrLearned) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private var hasTricksToLearnOrLearned: Bool {
        tricks.contains(where: { $0.isLearning && !$0.isSkipped || $0.isLearned && !$0.isSkipped })
    }
    
    private func updateNextTrickInAppStorage() {
        if let encodedData = try? JSONEncoder().encode(nextEasiestTrick) {
            nextTrickData = encodedData
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func decodeTrick(from url: URL) -> Trick? {
        guard url.scheme == "shrednotes" else {
            return nil
        }
        let trickString = url.path.replacingOccurrences(of: "/trickDetail/", with: "")
        let cleanedTrickString = trickString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let trickData = Data(base64Encoded: cleanedTrickString) else {
            return nil
        }
        do {
            let trick = try JSONDecoder().decode(Trick.self, from: trickData)
            return trick
        } catch {
            return nil
        }
    }
    
    private func decodeSessionReference(from url: URL) -> UUID? {
        guard url.scheme == "shrednotes" else {
            return nil
        }
        let journalString = url.path.replacingOccurrences(of: "/sessionDetail/", with: "")
        let cleanedJournalString = journalString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let journalData = Data(base64Encoded: cleanedJournalString) else {
            return nil
        }
        do {
            let reference = try JSONDecoder().decode(SessionReference.self, from: journalData)
            return reference.id
        } catch {
            print("Failed to decode session reference: \(error)")
            return nil
        }
    }
    
    private func computeNextCombinationTricks() -> [Trick] {
        let learnedTricks = tricks.filter { $0.isLearned }
        let currentlyLearningTricks = tricks.filter { $0.isLearning }
        
        return tricks.filter { trick in
            !trick.isLearned &&
            !trick.isLearning &&
            !trick.wantToLearn &&
            !trick.isSkipped &&
            visibleTrickTypes.contains(trick.type) &&
            !currentlyLearningTricks.contains(where: { learningTrick in
                trick.name.lowercased().contains(learningTrick.name.lowercased())
            })
        }
        .sorted {
            let score1 = similarityScore(trick: $0, learnedTricks: learnedTricks)
            let score2 = similarityScore(trick: $1, learnedTricks: learnedTricks)
            
            if score1 == score2 {
                return $0.difficulty < $1.difficulty
            } else {
                return score1 > score2
            }
        }
        .prefix(3)
        .map { $0 }
    }

    private func computeFilteredTricks() -> [Trick] {
        if searchText.isEmpty {
            return tricks.filter { visibleTrickTypes.contains($0.type) }
        } else {
            return tricks.filter { $0.name.localizedCaseInsensitiveContains(searchText) && visibleTrickTypes.contains($0.type) }
        }
    }

    private func computeInProgressTricks() -> [Trick] {
        return tricks.filter { $0.isLearning && !$0.isLearned }
    }
    
    @ViewBuilder
    private var recommendationSection: some View {
        VStack(alignment: .leading) {
            Section(header: HStack {
                Text("Learn next").textScale(.secondary).textCase(.uppercase).padding(.leading)
                Spacer()
            }) {
                if let easiestTrick = nextEasiestTrick {
                    NavigationLink(value: easiestTrick) {
                        TrickRow(trick: easiestTrick, onDark: true)
                            .foregroundStyle(.white)
                    }
                    .contextMenu {
                        Button {
                            easiestTrick.isLearned.toggle()
                            easiestTrick.isLearning = false
                            easiestTrick.wantToLearn = false
                            easiestTrick.wantToLearnDate = nil
                            easiestTrick.isLearnedDate = Date()
                            DispatchQueue.main.async {
                                inProgressTricks = computeInProgressTricks()
                                nextCombinationTricks = computeNextCombinationTricks()
                                updateNextTrickInAppStorage()
                            }
                            LearnedTrickManager.shared.trickLearned(easiestTrick)
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Label("Learned", systemImage: easiestTrick.isLearned ? "xmark.circle" : "checkmark.circle")
                        }
                        Button {
                            easiestTrick.isLearning.toggle()
                            easiestTrick.isLearned = false
                            easiestTrick.wantToLearn = false
                            easiestTrick.wantToLearnDate = nil
                            DispatchQueue.main.async {
                                inProgressTricks = computeInProgressTricks()
                                nextCombinationTricks = computeNextCombinationTricks()
                                updateNextTrickInAppStorage()
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Label("Learning", systemImage: easiestTrick.isLearning ? "xmark.circle" : "circle.dashed")
                        }
                        Button {
                            easiestTrick.wantToLearn.toggle()
                            easiestTrick.isSkipped = false
                            easiestTrick.isLearned = false
                            easiestTrick.isLearning = false
                            easiestTrick.wantToLearnDate = Date()
                            DispatchQueue.main.async {
                                inProgressTricks = computeInProgressTricks()
                                nextCombinationTricks = computeNextCombinationTricks()
                                updateNextTrickInAppStorage()
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Label(easiestTrick.wantToLearn ? "Learning Next" : "Learn Next", systemImage: easiestTrick.wantToLearn ? "xmark.circle" : "text.insert")
                        }
                        Button {
                            easiestTrick.isSkipped.toggle()
                            easiestTrick.isLearned = false
                            easiestTrick.isLearning = false
                            easiestTrick.wantToLearn = false
                            easiestTrick.wantToLearnDate = nil
                            DispatchQueue.main.async {
                                inProgressTricks = computeInProgressTricks()
                                nextCombinationTricks = computeNextCombinationTricks()
                                updateNextTrickInAppStorage()
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Label(easiestTrick.isSkipped ? "Skipped" : "Skip", systemImage: easiestTrick.isSkipped ? "checkmark.circle" : "arrow.clockwise")
                        }
                    }
                } else if tricks.allSatisfy({ $0.isLearned }) {
                    Text("All tricks learned!")
                        .padding(.leading)
                } else {
                    VStack(alignment: .leading) {
                        Text("Start by choosing which tricks you're learning")
                            .font(.callout)
                        Button {
                            activeSheet = .fullTrickList
                        } label: {
                            Text("Choose tricks")
                                .font(.headline)
                                .foregroundStyle(.black)
                        }
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(.white)
                        .clipShape(.capsule)
                    }
                    .padding(.top, 4)
                    .padding(.leading)
                }
            }
            .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    @ViewBuilder
    private func latestSkateView(latestSessionDate: Date) -> some View {
        if let latestSession = skateSessions.first {
                StoredWorkoutView(session: latestSession)
                .onTapGesture {
                    self.showSessionDetail = true
                }
                .fullScreenCover(isPresented: $showSessionDetail) {
                    SessionDetailView(session: latestSession, mediaState: mediaState)
                        .navigationTransition(.zoom(sourceID: latestSession.id, in: detailView))
                }
        }
    }
    
    @ViewBuilder
    private var inProgressSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Tricks in Progress")
                    .foregroundStyle(.secondary)
                    .textScale(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if inProgressTricks.count > 6 {
                    Button(action: {
                        withAnimation(.spring(.bouncy)) {
                            isInProgressExpanded.toggle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .foregroundStyle(.thinMaterial)
                                .frame(width: 32, height: 32)
                            Image(systemName: isInProgressExpanded ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            ForEach(isInProgressExpanded ? inProgressTricks : Array(inProgressTricks.prefix(6))) { trick in
                NavigationLink(value: trick) {
                    TrickRow(trick: trick, padless: true)
                }
                .foregroundStyle(.primary)
                .contextMenu {
                    Button {
                        trick.isLearned.toggle()
                        trick.isLearnedDate = Date()
                        trick.isLearning = false
                        trick.wantToLearn = false
                        trick.wantToLearnDate = nil
                        DispatchQueue.main.async {
                            inProgressTricks = computeInProgressTricks()
                            nextCombinationTricks = computeNextCombinationTricks()
                            updateNextTrickInAppStorage()
                        }
                        LearnedTrickManager.shared.trickLearned(trick)
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Label("Learned", systemImage: trick.isLearned ? "xmark.circle" : "checkmark.circle")
                    }
                    Button {
                        trick.isLearning.toggle()
                        trick.isLearned = false
                        trick.wantToLearn = false
                        trick.wantToLearnDate = nil
                        DispatchQueue.main.async {
                            inProgressTricks = computeInProgressTricks()
                            nextCombinationTricks = computeNextCombinationTricks()
                            updateNextTrickInAppStorage()
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Label("Learning", systemImage: trick.isLearning ? "xmark.circle" : "circle.dashed")
                    }
                    Button {
                        trick.wantToLearn.toggle()
                        trick.isSkipped = false
                        trick.isLearned = false
                        trick.isLearning = false
                        trick.wantToLearnDate = Date()
                        DispatchQueue.main.async {
                            inProgressTricks = computeInProgressTricks()
                            nextCombinationTricks = computeNextCombinationTricks()
                            updateNextTrickInAppStorage()
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Label(trick.wantToLearn ? "Learning Next" : "Learn Next", systemImage: trick.wantToLearn ? "xmark.circle" : "text.insert")
                    }
                    Button {
                        trick.isSkipped.toggle()
                        trick.isLearning = false
                        trick.isLearned = false
                        trick.wantToLearn = false
                        trick.wantToLearnDate = nil
                        DispatchQueue.main.async {
                            inProgressTricks = computeInProgressTricks()
                            nextCombinationTricks = computeNextCombinationTricks()
                            updateNextTrickInAppStorage()
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Label(trick.isSkipped ? "Skipped" : "Skip", systemImage: trick.isSkipped ? "checkmark.circle" : "arrow.clockwise")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            if inProgressTricks.count > 6 && !isInProgressExpanded {
                VStack(alignment: .center) {
                    Text("+ \(inProgressTricks.count - 6) more")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom)
            }
            
            NavigationLink(destination: TrickPracticeView()) {
                Text("Practice Tricks")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .padding(.bottom, 24)
        .padding(.top, hideRecommendations ? 24 : 0)
    }
    
    @ViewBuilder
    private var comboTricksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Combo Tricks")
                    .foregroundStyle(.secondary)
                    .textScale(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if combos.count > 6 {
                    Button(action: {
                        withAnimation(.spring(.bouncy)) {
                            isComboExpanded.toggle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .foregroundStyle(.thinMaterial)
                                .frame(width: 32, height: 32)
                            Image(systemName: isComboExpanded ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            ForEach(isComboExpanded ? combos : Array(combos.prefix(6))) { combo in
                NavigationLink(destination: ComboBuilderView(existingCombo: combo, isPresentedInNavigationStack: true)) {
                    ComboTrickRow(combo: combo)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(combo)
                            } label: {
                                Label("Delete Combo", systemImage: "trash")
                            }
                        }
                }
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            if combos.count > 6 && !isComboExpanded {
                VStack(alignment: .center) {
                    Text("+ \(combos.count - 6) more")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom)
            }
        }
        .padding(.vertical)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var basedOnTricksYouKnowSection: some View {
        VStack {
            if nextCombinationTricks.isEmpty {
                VStack(alignment: .leading) {
                    Section(header: Text("Based On Tricks You Know").foregroundStyle(.secondary).textScale(.secondary).textCase(.uppercase)) {
                        Text("No combination tricks available based on your current selection.")
                            .font(.callout)
                            .padding (.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(colorScheme == .dark ? 0.125 : 0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(colorScheme == .light ? .black : .white, lineWidth: 2)
                        .blendMode(.overlay)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom, 24)
            } else {
                VStack(alignment: .leading) {
                    Section(header: Text("Based On Tricks You Know").foregroundStyle(.secondary).textScale(.secondary).textCase(.uppercase)) {
                        ForEach(nextCombinationTricks) { trick in
                            NavigationLink(value: trick) {
                                TrickRow(trick: trick, padless: true)
                            }
                            .foregroundStyle(.primary)
                            .contextMenu {
                                Button {
                                    trick.isLearned.toggle()
                                    trick.isLearnedDate = Date()
                                    trick.isLearning = false
                                    trick.wantToLearn = false
                                    trick.wantToLearnDate = nil
                                    DispatchQueue.main.async {
                                        inProgressTricks = computeInProgressTricks()
                                        nextCombinationTricks = computeNextCombinationTricks()
                                        updateNextTrickInAppStorage()
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    Label("Learned", systemImage: trick.isLearned ? "xmark.circle" : "checkmark.circle")
                                }
                                Button {
                                    trick.isLearning.toggle()
                                    trick.isLearned = false
                                    trick.wantToLearn = false
                                    trick.wantToLearnDate = nil
                                    DispatchQueue.main.async {
                                        inProgressTricks = computeInProgressTricks()
                                        nextCombinationTricks = computeNextCombinationTricks()
                                        updateNextTrickInAppStorage()
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    Label("Learning", systemImage: trick.isLearning ? "xmark.circle" : "circle.dashed")
                                }
                                Button {
                                    trick.wantToLearn.toggle()
                                    trick.isSkipped = false
                                    trick.isLearned = false
                                    trick.isLearning = false
                                    trick.wantToLearnDate = Date()
                                    DispatchQueue.main.async {
                                        inProgressTricks = computeInProgressTricks()
                                        nextCombinationTricks = computeNextCombinationTricks()
                                        updateNextTrickInAppStorage()
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    Label(trick.wantToLearn ? "Learning Next" : "Learn Next", systemImage: trick.wantToLearn ? "xmark.circle" : "text.insert")
                                }
                                Button {
                                    trick.isSkipped.toggle()
                                    trick.isLearning = false
                                    trick.isLearned = false
                                    trick.wantToLearn = false
                                    trick.wantToLearnDate = nil
                                    DispatchQueue.main.async {
                                        inProgressTricks = computeInProgressTricks()
                                        nextCombinationTricks = computeNextCombinationTricks()
                                        updateNextTrickInAppStorage()
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    Label(trick.isSkipped ? "Skipped" : "Skip", systemImage: trick.isSkipped ? "checkmark.circle" : "arrow.clockwise")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(colorScheme == .dark ? 0.125 : 0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(colorScheme == .light ? .black : .white, lineWidth: 2)
                        .blendMode(.overlay)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.bottom, 24)
            }
        }
    }
}

extension Notification.Name {
    static let showAddSession = Notification.Name("showAddSession")
}
