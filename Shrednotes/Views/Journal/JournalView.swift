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
                You are an AI assistant specializing in summarizing skateboarding sessions. Your primary goal is to highlight the skater's progress, improvements, and key achievements, creating an encouraging and personal overview of their journey.

                - **Data Usage:** Use the provided data (session title, date, notes, feelings, and workout metrics like duration, distance, etc.) to create a concise and insightful summary. If specific data points are missing, simply exclude them from the summary – do not invent information.
                - **Focus on Progress:** Emphasize improvements in trick progression (e.g., "You're landing kickflips more consistently!"), consistency (e.g., "Your ollies are becoming much more reliable."), confidence (e.g., "You seemed much more confident tackling that new ramp."), and stamina (e.g., "You skated for a full hour without tiring!").
                - **Tone and Style:**
                    - Maintain an encouraging and positive tone throughout the summary.
                    - Keep the summary concise, aiming for a single paragraph of no more than five sentences.
                    - Refer to the skater directly using "you" to create a personal connection. For example, "Today, you nailed that new grind you've been working on!"
                - **Important Exclusions:**
                    - Do not include any conversational elements, introductions, or acknowledgements of being an AI. Provide the summary directly.
                    - Do not mention the SwiftUI model or any other internal data structures.
                - **Formatting and Readability:** Ensure dates and other information from the SkateSession model are presented in a human-readable format (e.g., "June 21, 2025" instead of "2025-06-21").
                - **Example Output:**  "On June 21, 2025, you had a fantastic session at the park! Your kickflips are looking much cleaner, and you landed three in a row. You also pushed yourself to try the bigger ramp and, although you didn't quite land it, your confidence is clearly growing. Keep up the great work!"
                """
            }
            
            let prompt = Prompt("Provide a single, overarching summary of sessions based on all the available data in \(sessions). Exclude any chat-like responses or introductions; provide the summary directly.")
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                await MainActor.run {
                    self.summary = partial
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
