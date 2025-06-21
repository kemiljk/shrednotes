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
    @State private var selectedMonth: Int?
    @State private var selectedYear: Int?
    
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
            }
            .onChange(of: sessions) {
                updateGroupedSessions()
                checkForFrequentTricks()
                updateLatestSession()
            }
            .navigationTitle("^[\(sessions.count) session](inflect: true)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if selectedMonth != nil || selectedYear != nil {
                            Button(role: .destructive) {
                                selectedMonth = nil
                                selectedYear = nil
                            } label: {
                                Label("Clear Filters", systemImage: "xmark.circle.fill")
                            }
                            Divider()
                        }
                        
                        Menu {
                            ForEach(availableMonths, id: \.number) { month in
                                Button(month.name) {
                                    selectedMonth = month.number
                                    selectedYear = nil
                                }
                            }
                        } label: {
                            Label(selectedMonthName ?? "Filter by Month", systemImage: "calendar")
                        }

                        Menu {
                            ForEach(availableYears, id: \.self) { year in
                                Button(String(year)) {
                                    selectedYear = year
                                    selectedMonth = nil
                                }
                            }
                        } label: {
                            Label(selectedYear.map { String($0) } ?? "Filter by Year", systemImage: "calendar.badge.clock")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
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
        guard let monthNumber = selectedMonth else { return nil }
        let dateFormatter = DateFormatter()
        guard monthNumber > 0 && monthNumber <= dateFormatter.monthSymbols.count else { return nil }
        return dateFormatter.monthSymbols[monthNumber - 1]
    }
    
    private var filteredGroupedSessions: [(key: DateComponents, value: [SkateSession])] {
        var dateFilteredGroups = groupedSessions

        if let year = selectedYear {
            dateFilteredGroups = dateFilteredGroups.filter { $0.key.year == year }
        }

        if let month = selectedMonth {
            dateFilteredGroups = dateFilteredGroups.filter { $0.key.month == month }
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
        Text(monthYearString(from: month))
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.secondary)
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

struct BlurUpTextRenderer: TextRenderer, Animatable {
    var elapsedTime: TimeInterval
    var elementDuration: TimeInterval
    var totalDuration: TimeInterval

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for (index, line) in layout.enumerated() {
            let delay = elementDuration * Double(index)
            let time = max(0, min(elapsedTime - delay, elementDuration))
            let progress = time / elementDuration

            var copy = ctx
            let blur = (1 - progress) * 10
            let offsetY = (1 - progress) * 20
            copy.addFilter(.blur(radius: blur))
            copy.opacity = progress
            copy.translateBy(x: 0, y: -offsetY)
            copy.draw(line, options: .disablesSubpixelQuantization)
        }
    }
}

struct BlurUpTextTransition: Transition {
    let duration: TimeInterval = 0.7
    let elementDuration: TimeInterval = 0.2

    func body(content: Content, phase: TransitionPhase) -> some View {
        let elapsedTime = phase.isIdentity ? duration : 0
        let renderer = BlurUpTextRenderer(
            elapsedTime: elapsedTime,
            elementDuration: elementDuration,
            totalDuration: duration
        )
        content.transaction { transaction in
            if !transaction.disablesAnimations {
                transaction.animation = .linear(duration: duration)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}
