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
    
    @MainActor @AppStorage("lastTipDismissalDate") private var lastTipDismissalDate: Date = .distantPast
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if sessions.isEmpty && !isLoading {
                    ContentUnavailableView("No Journal Entries", systemImage: "book.circle", description: Text("Add a skate session to get started."))
                        .safeAreaInset(edge: .bottom) {
                            GradientButton<Bool, Bool, Never>(
                                label: "Add Session",
                                hasImage: true,
                                image: "plus.circle.fill",
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
                        ForEach(groupedSessions.isEmpty ? placeholderGroupedSessions : groupedSessions, id: \.key) { month, sessions in
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
                    .listStyle(.plain)
                    .safeAreaInset(edge: .bottom) {
                        GradientButton<Bool, Bool, Never>(
                            label: "Add Session",
                            hasImage: true,
                            image: "plus.circle.fill",
                            binding: $showingAddSession,
                            value: true,
                            fullWidth: false,
                            hapticTrigger: showingAddSession,
                            hapticFeedbackType: .impact
                        )
                        .padding(.bottom)
                        .frame(maxHeight: 44)
                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .symbolRenderingMode(.hierarchical)
                            .symbolVariant(.fill)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("^[\(sessions.count) session](inflect: true)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInsightView.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb")
                                .symbolRenderingMode(.hierarchical)
                                .symbolVariant(.fill)
                            Text("Insight")
                        }
                    }
                    .controlSize(.mini)
                    .buttonBorderShape(.capsule)
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView()
                    .presentationCornerRadius(24)
                    .modelContext(modelContext)
            }
            .sheet(item: $sessionToEdit) { session in
                EditSessionView(session: session)
                    .presentationCornerRadius(24)
            }
            .fullScreenCover(item: $selectedSession) { session in
                SessionDetailView(session: session, mediaState: mediaState)
                    .navigationTransition(.zoom(sourceID: session.id, in: detailView))
                    
            }
            .sheet(isPresented: $showingInsightView) {
                InsightDetailView()
                    .presentationCornerRadius(24)
            }
        }
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
