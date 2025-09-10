//
//  JournalView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import SwiftData
import PhotosUI
import TipKit
import WidgetKit
import FoundationModels

struct JournalView: View {
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mediaState = MediaState()
    @Namespace private var detailView
    @State private var showingAddSession = false
    @State private var showingInsightView = false
    @State private var selectedSession: SkateSession?
    @State private var sessionToEdit: SkateSession?
    @State private var groupedSessions: [(key: DateComponents, value: [SkateSession])] = []
    @State private var isLoading = true
    @State private var frequentTrickTip: FrequentTrickTip?
    @State private var frequentTrickNames: [String] = []
    @State private var searchText = ""
    @State private var isGenerating: Bool = false
    @State private var selectedMonths = Set<Int>()
    @State private var selectedYears = Set<Int>()
    
    @MainActor @AppStorage("lastTipDismissalDate") private var lastTipDismissalDate: Date = .distantPast
    @MainActor @AppStorage(
        "sessionSummary"
    ) private var summary: String = ""
    @MainActor @AppStorage("lastSessionCount") private var lastSessionCount: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if sessions.isEmpty && !isLoading {
                    ContentUnavailableView("No Journal Entries", systemImage: "book.circle", description: Text("Add a skate session to get started."))
                        .safeAreaInset(edge: .bottom) {
                            GradientButton<Bool, Bool, Never>(
                                label: "Add Session",
                                hasImage: true,
                                image: "plus.circle",
                                binding: $showingAddSession,
                                value: true,
                                fullWidth: false,
                                hapticTrigger: showingAddSession,
                                hapticFeedbackType: .impact
                            )
                            .padding(.bottom)
                    }
                } else {
                    List {
                        if let tip = frequentTrickTip {
                            TipView(tip)
                                .listRowSeparator(.hidden)
                        }
                        if #available(iOS 26, *) {
                            if sessions.count >= 2 {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "apple.intelligence")
                                            .foregroundStyle(.blue)
                                            .onTapGesture {
                                                Task {
                                                    await generateSummary()
                                                    lastSessionCount = sessions.count
                                                }
                                            }
                                            .symbolEffect(
                                                .pulse,
                                                isActive: isGenerating
                                            )
                                        Text("Summary")
                                            .foregroundStyle(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.orange, Color.red, Color.purple, Color.cyan]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        Spacer()
                                    }
                                    .fontWeight(.bold)
                                    .fontWidth(.expanded)
                                    .frame(maxWidth: .infinity)

                                    Text(summary)
                                }
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        ForEach(filteredGroupedSessions.isEmpty ? placeholderGroupedSessions : filteredGroupedSessions, id: \.key) { month, sessions in
                            Section(header: monthHeader(for: month)) {
                                ForEach(sessions.sorted(by: { $0.date ?? Date() > $1.date ?? Date() }), id: \.self) { session in
                                    SessionCard(session: session, mediaState: mediaState, onTap: {
                                        self.selectedSession = session
                                    }, onSelect: {
                                        self.selectedSession = session
                                    })
                                    .id(session.id)
                                    .contextMenu {
                                        Button {
                                            sessionToEdit = session
                                        } label: {
                                            Label("Edit", systemImage: "pencil.circle")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            deleteSession(session)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .listRowSeparator(.hidden)
                                    .redacted(reason: isLoading ? .placeholder : [])
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Filter sessions")
                    .listStyle(.plain)
                    .background(.background)
                }
            }
            .onAppear {
                loadSessions()
                checkForFrequentTricks()
                if #available(iOS 26, *) {
                    Task {
                        if summary.isEmpty {
                            await generateSummary()
                            lastSessionCount = sessions.count
                        }
                    }
                }
            }
            .onChange(of: sessions) {
                updateGroupedSessions()
                checkForFrequentTricks()
                updateLatestSession()
                if #available(iOS 26, *) {
                    Task {
                        if sessions.count != lastSessionCount {
                            await generateSummary()
                            lastSessionCount = sessions.count
                        }
                    }
                }
            }
            .navigationTitle("^[\(sessions.count) session](inflect: true)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if hasActiveFilters {
                            Button(role: .destructive) {
                                selectedMonths.removeAll()
                                selectedYears.removeAll()
                            } label: {
                                Label("Clear All Filters", systemImage: "xmark.circle.fill")
                            }
                            Divider()
                        }
                        
                        // Month filter section
                        Section(header: Text("Filter by Month")) {
                            ForEach(availableMonths, id: \.number) { month in
                                Button {
                                    if selectedMonths.contains(month.number) {
                                        selectedMonths.remove(month.number)
                                    } else {
                                        selectedMonths.insert(month.number)
                                    }
                                } label: {
                                    HStack {
                                        Text(month.name)
                                        Spacer()
                                        if selectedMonths.contains(month.number) {
                                            Image(systemName: "checkmark")
                                        } else {
                                            EmptyView()
                                        }
                                    }
                                }
                                .menuActionDismissBehavior(.disabled)
                            }
                        }
                        
                        // Year filter section
                        Section(header: Text("Filter by Year")) {
                            ForEach(availableYears, id: \.self) { year in
                                Button {
                                    if selectedYears.contains(year) {
                                        selectedYears.remove(year)
                                    } else {
                                        selectedYears.insert(year)
                                    }
                                } label: {
                                    HStack {
                                        Text(String(year))
                                        Spacer()
                                        if selectedYears.contains(year) {
                                            Image(systemName: "checkmark")
                                        } else {
                                            EmptyView()
                                        }
                                    }
                                }
                                .menuActionDismissBehavior(.disabled)
                            }
                        }
                    } label: {
                        Image(systemName: hasActiveFilters ? 
                            "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                            .foregroundStyle(hasActiveFilters ? .accent : .primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInsightView.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                        }
                    }
                    .sensoryFeedback(.increase, trigger: showingInsightView)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *) {
                        Button(role: .confirm) {
                            self.showingAddSession = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .sensoryFeedback(
                            .impact(weight: .medium),
                            trigger: showingAddSession
                        )
                    } else {
                        Button {
                            self.showingAddSession = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.accentColor)
                        .sensoryFeedback(
                            .impact(weight: .medium),
                            trigger: showingAddSession
                        )
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView(mediaState: mediaState)
                    
                    .modelContext(modelContext)
            }
            .sheet(item: $sessionToEdit) { session in
                EditSessionView(session: session, mediaState: mediaState)
                    
            }
            .fullScreenCover(item: $selectedSession) { session in
                NavigationStack {
                    SessionDetailView(session: session, mediaState: mediaState, fullScreenCover: true)
                }
                .navigationTransition(.zoom(sourceID: session.id, in: detailView))
            }
            .sheet(isPresented: $showingInsightView) {
                InsightDetailView()
                    
            }
        }
    }
    
    private var availableYears: [Int] {
        let years = sessions.compactMap { $0.date }.map {
            Calendar.current.component(.year, from: $0)
        }
        return Array(Set(years)).sorted(by: >)
    }
    
    private var availableMonths: [(number: Int, name: String)] {
        let monthNumbers = sessions.compactMap { $0.date }.map {
            Calendar.current.component(.month, from: $0)
        }
        
        let uniqueMonthNumbers = Set(monthNumbers)
        let dateFormatter = DateFormatter()
        
        let monthDetails = uniqueMonthNumbers.map { monthNumber in
            (number: monthNumber, name: dateFormatter.monthSymbols[monthNumber - 1])
        }
        
        return monthDetails.sorted { $0.number < $1.number }
    }
    
    private var selectedMonthName: String? {
        guard let monthNumber = selectedMonths.first else { return nil }
        let dateFormatter = DateFormatter()
        guard monthNumber > 0 && monthNumber <= dateFormatter.monthSymbols.count else { return nil }
        return dateFormatter.monthSymbols[monthNumber - 1]
    }
    
    private var hasActiveFilters: Bool {
        !selectedMonths.isEmpty || !selectedYears.isEmpty
    }
    
    private var filteredGroupedSessions: [(key: DateComponents, value: [SkateSession])] {
        var dateFilteredGroups = groupedSessions

        if !selectedYears.isEmpty {
            dateFilteredGroups = dateFilteredGroups.filter { group in
                guard let year = group.key.year else { return false }
                return selectedYears.contains(year)
            }
        }

        if !selectedMonths.isEmpty {
            dateFilteredGroups = dateFilteredGroups.filter { group in
                guard let month = group.key.month else { return false }
                return selectedMonths.contains(month)
            }
        }
        
        if searchText.isEmpty {
            return dateFilteredGroups
        }

        var filteredGroups: [(key: DateComponents, value: [SkateSession])] = []

        for (month, sessionsInMonth) in dateFilteredGroups {
            let filteredSessions = sessionsInMonth.filter { session in
                let searchTextLowercased = searchText.lowercased()
                
                let titleMatch = session.title?.lowercased().contains(searchTextLowercased) ?? false
                let noteMatch = session.note?.lowercased().contains(searchTextLowercased) ?? false
                
                let tricksMatch = session.tricks?.contains { trick in
                    trick.name.lowercased().contains(searchTextLowercased)
                } ?? false
                
                return titleMatch || noteMatch || tricksMatch
            }

            if !filteredSessions.isEmpty {
                filteredGroups.append((key: month, value: filteredSessions))
            }
        }

        return filteredGroups
    }
    
    private func loadSessions() {
        DispatchQueue.main.async {
            updateGroupedSessions()
            updateLatestSession()
            isLoading = false
        }
    }
    
    @available(iOS 26, *)
    private func generateSummary() async {
        isGenerating = true
        
        let _ = await AIModelAvailability.withAvailability {
            let instructions = Instructions {
                """
                You are an AI assistant that creates personalized skateboarding session summaries. Your task is to analyze the provided session data and generate an encouraging, accurate summary based ONLY on the actual information provided.

                **CRITICAL REQUIREMENTS:**
                - Use ONLY the data provided in the sessions array - never invent, assume, or add information not present in the data
                - If specific data points are missing or empty, simply exclude them from the summary
                - Never include example text, placeholder content, or generic statements
                - Base all observations on actual trick names, feelings, notes, and metrics from the data

                **DATA TO ANALYZE:**
                - Session titles, dates, and personal notes
                - Trick names and their learning status (isLearned, isLearning, consistency ratings)
                - Feelings: stoked, exhausted, pumped, thrilled, hyped, wrecked, amped, bummed, confident, sketchy, dialed, flowing, fired up, gnarly, chill, rad, mellow, blissed, fizzled, slammed
                - Workout metrics: duration, energy burned
                - Location information if available
                - Combo tricks and their elements

                **OUTPUT FORMAT:**
                - Single paragraph, 3-5 sentences maximum
                - Direct, personal tone using "you"
                - Focus on specific achievements, progress, and experiences from the actual data
                - Use human-readable date formatting
                - No AI acknowledgments, introductions, or conversational elements

                **PROHIBITED:**
                - Never output example text or placeholder content
                - Never mention being an AI or assistant
                - Never include generic statements not based on actual data
                - Never invent trick names, locations, or experiences not in the data
                """
            }
            
            let sessionData = sessions.map { session in
                var data: [String: Any] = [:]
                
                if let title = session.title, !title.isEmpty {
                    data["title"] = title
                }
                if let date = session.date {
                    data["date"] = date
                }
                if let note = session.note, !note.isEmpty {
                    data["note"] = note
                }
                if let feelings = session.feeling, !feelings.isEmpty {
                    data["feelings"] = feelings.map { $0.rawValue }
                }
                if let tricks = session.tricks, !tricks.isEmpty {
                    data["tricks"] = tricks.map { trick in
                        var trickData: [String: Any] = ["name": trick.name]
                        if trick.isLearned { trickData["isLearned"] = true }
                        if trick.isLearning { trickData["isLearning"] = true }
                        if trick.consistency > 0 { trickData["consistency"] = trick.consistency }
                        return trickData
                    }
                }
                if let combos = session.combos, !combos.isEmpty {
                    data["combos"] = combos.map { combo in
                        var comboData: [String: Any] = ["name": combo.name ?? "Combo"]
                        if let elements = combo.comboElements, !elements.isEmpty {
                            comboData["elements"] = elements
                                .map { $0.combo?.name }
                        }
                        return comboData
                    }
                }
                if let duration = session.workoutDuration {
                    data["duration"] = duration
                }
                if let energy = session.workoutEnergyBurned {
                    data["energyBurned"] = energy
                }
                if let location = session.location {
                    data["location"] = location.name
                }
                
                return data
            }
            
            let prompt = Prompt("Analyze this skateboarding session data and create a personalized summary: \(sessionData). Base the summary entirely on the provided data - do not add any information not present in the data.")
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                await MainActor.run {
                    self.summary = partial.content
                }
            }
            return true
            
        } onUnavailable: { error in
            print("AI feature unavailable: \(error.localizedDescription)")
            return
        }
        
        isGenerating = false
    }
    
    @MainActor
    private func updateLastTipDismissalDate() {
        lastTipDismissalDate = Date()
    }
    
    private func checkForFrequentTricks() {
        let allTricks = sessions.flatMap { $0.tricks ?? [] }
        let trickCounts = Dictionary(grouping: allTricks, by: { $0.name })
            .mapValues { $0.count }
        
        frequentTrickNames = trickCounts.filter { $0.value > FrequentTrickTip.frequentTrickCount }
            .keys
            .sorted()
        
        if !frequentTrickNames.isEmpty {
            // Check if there's a session more recent than the last tip dismissal
            Task { @MainActor in
                if let mostRecentSessionDate = sessions.first?.date, mostRecentSessionDate > lastTipDismissalDate {
                    frequentTrickTip = FrequentTrickTip(frequentTrickNames: frequentTrickNames)
                } else {
                    frequentTrickTip = nil
                }
            }
        } else {
            frequentTrickTip = nil
        }
    }
    
    @MainActor
    private func updateLatestSession() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteSession(_ session: SkateSession) {
        modelContext.delete(session)
        Task {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func monthHeader(for month: DateComponents) -> some View {
        Group {
            if #available(iOS 26, *) {
                Text(monthYearString(from: month))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.secondary)
                    .glassEffect(in: .capsule)
            } else {
                Text(monthYearString(from: month))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.secondary)
                    .backgroundStyle(.ultraThinMaterial)
                    .clipShape(.capsule)
            }
        }
    }
    
    private func monthYearString(from components: DateComponents) -> String {
        guard let date = Calendar.current.date(from: components) else {
            return "Unknown Date"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func compareDateComponents(_ lhs: DateComponents, _ rhs: DateComponents) -> Bool {
        guard let lhsYear = lhs.year, let lhsMonth = lhs.month,
              let rhsYear = rhs.year, let rhsMonth = rhs.month else {
            return false
        }
        
        if lhsYear != rhsYear {
            return lhsYear > rhsYear
        }
        return lhsMonth > rhsMonth
    }
    
    private func updateGroupedSessions() {
        let grouped = Dictionary(grouping: sessions) { session in
            guard let date = session.date else {
                return DateComponents()
            }
            return Calendar.current.dateComponents([.year, .month], from: date)
        }
        groupedSessions = grouped.sorted { compareDateComponents($0.key, $1.key) }
    }

    private var placeholderGroupedSessions: [(key: DateComponents, value: [SkateSession])] {
        let placeholderSessions = (0..<10).map { _ in SkateSession.placeholder }
        let grouped = Dictionary(grouping: placeholderSessions) { session in
            Calendar.current.dateComponents([.year, .month], from: Date())
        }
        return grouped.sorted { compareDateComponents($0.key, $1.key) }
    }
}

extension SkateSession {
    static var placeholder: SkateSession {
        let session = SkateSession()
        session.title = "A title for the session"
        session.feeling = [.amped, .stoked, .blissed]
        session.note = "A note for the session that is too long to fit in the preview"
        session.id = UUID()
        session.date = Date()
        return session
    }
}

struct FrequentTrickTip: Tip {
    static let frequentTrickCount = 10
    var frequentTrickNames: [String]
    
    var title: Text {
        Text("Time to Mix It Up!")
    }
    
    var message: Text? {
        if frequentTrickNames.count == 1 {
            return Text("You've logged **\(frequentTrickNames[0])** more than \(Self.frequentTrickCount) times. Consider trying something new in your next session!")
        } else {
            let tricksList = ListFormatter.localizedString(byJoining: frequentTrickNames)
            return Text("^[You've logged \(tricksList) more than \(Self.frequentTrickCount) times each. Consider trying something new in your next session!](inflect: true)")
        }
    }
    
    var image: Image? {
        Image(systemName: "sparkles")
    }
}
