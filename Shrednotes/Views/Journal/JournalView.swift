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
                                        Button {
                                            Task {
                                                await generateSummary()
                                                lastSessionCount = sessions.count
                                            }
                                        } label: {
                                            Image(systemName: "apple.intelligence")
                                                .foregroundStyle(.blue)
                                                .symbolEffect(
                                                    .pulse,
                                                    isActive: isGenerating
                                                )
                                        }
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
    @MainActor
    private func generateSummary() async {
        isGenerating = true
        summary = ""
        defer { isGenerating = false }

        // Check model availability to provide helpful feedback on unsupported devices
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(.appleIntelligenceNotEnabled):
            summary = "Enable Apple Intelligence in Settings to see your personalized summary."
            return
        case .unavailable(.deviceNotEligible):
            summary = "This device doesn't support on‑device summaries."
            return
        case .unavailable(.modelNotReady):
            summary = "Preparing the on‑device model. Try again in a moment."
            return
        case .unavailable:
            summary = "Summary is currently unavailable."
            return
        }

        // Keep instructions short to save tokens
        let instructions = """
        Write a concise 3–5 sentence summary using only the session lines provided.
        Do not invent facts; ignore any missing fields.
        Use a direct, encouraging tone addressed to "you".
        Avoid introductions or meta commentary.
        """

        // Helper to sanitize and compress text
        func sanitize(_ text: String, max: Int) -> String {
            let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            return String(collapsed.prefix(max))
        }

        // Build ultra-compact, line-based payload under a character budget
        let charBudget = 2000 // leave room for instructions and prompt
        var totalChars = 0
        var lines: [String] = []
        let maxSessions = 8

        for session in sessions.prefix(50) { // iterate in recency order; budget will cap
            var parts: [String] = []
            if let title = session.title, !title.isEmpty {
                parts.append("Title: \(sanitize(title, max: 60))")
            }
            if let note = session.note, !note.isEmpty {
                parts.append("Note: \(sanitize(note, max: 100))")
            }
            if let tricks = session.tricks, !tricks.isEmpty {
                var seen = Set<String>()
                var uniqueNames: [String] = []
                for name in tricks.map({ $0.name }) {
                    if seen.insert(name).inserted { uniqueNames.append(name) }
                    if uniqueNames.count >= 5 { break }
                }
                if !uniqueNames.isEmpty {
                    parts.append("Tricks: \(uniqueNames.joined(separator: ", "))")
                }
            }

            if parts.isEmpty { continue }
            let line = "- " + parts.joined(separator: " | ")
            if totalChars + line.count > charBudget { break }
            lines.append(line)
            totalChars += line.count + 1
            if lines.count >= maxSessions { break }
        }

        // If there's nothing meaningful to summarize, provide guidance and return
        if lines.isEmpty {
            summary = "Add some session notes or tricks to see a personalized summary."
            return
        }

        let sessionsText = lines.joined(separator: "\n")
        let prompt = """
        Use only the following session lines to write the summary. Do not add any information not present here.
        \n\(sessionsText)
        """

        // Create a model session and generate a response
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: prompt, options: GenerationOptions(temperature: 0.2))
            self.summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LanguageModelSession.GenerationError {
            self.summary = "Summary couldn't be generated: \(error.localizedDescription)"
        } catch {
            self.summary = "Summary couldn't be generated."
        }
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

