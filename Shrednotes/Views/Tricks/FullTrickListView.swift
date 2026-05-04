//
//  FullTrickListView.swift
//  ShredNotes
//
//  Created by Karl Koch on 31/07/2024.
//

import SwiftUI
import SwiftData

struct FullTrickListView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var visibleTrickTypes: Set<TrickType>
    @Binding var searchText: String
    @Binding var expandedGroups: [String: Bool]
    @Binding var selectedType: TrickType?
    @FocusState private var searchIsFocused: Bool
    @State private var isShowingAddTrickView: Bool = false
    var isTabItem: Bool = false
    
    var onTrickSelected: ((Trick) -> Void)? = nil
    
    @Query(sort: [
        SortDescriptor(\Trick.difficulty, order: .forward),
        SortDescriptor(\Trick.name, order: .forward)
    ]) private var tricks: [Trick]
    
    private var filteredTricks: [Trick] {
        let searchWords = searchText.lowercased().split(separator: " ")
        let isSearchEmpty = searchText.isEmpty
        return tricks.filter { trick in
            let trickName = trick.name.lowercased()
            let containsAllSearchWords = searchWords.allSatisfy { trickName.contains($0) }

            return (isSearchEmpty || containsAllSearchWords) &&
                   (selectedType == nil || trick.type == selectedType) &&
                   visibleTrickTypes.contains(trick.type)
        }
    }

    private var learnedCount: Int {
        tricks.lazy.filter { $0.isLearned }.count
    }

    @ViewBuilder
    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
            Text(label)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.indigo : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0)
                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                .offset(y: phase.isIdentity ? 0 : 10)
        }
    }
    
    private func groupedFilteredTricks(by type: TrickType) -> [Trick] {
        return filteredTricks.filter { $0.type == type }
    }
    
    private func sectionedTricks(for tricks: [Trick]) -> [String: [Trick]] {
        var sections: [String: [Trick]] = ["": [], "Fakie": [], "Nollie": [], "Switch": []]
        
        for trick in tricks {
            if trick.name.starts(with: "Fakie") {
                sections["Fakie", default: []].append(trick)
            } else if trick.name.starts(with: "Nollie") {
                sections["Nollie", default: []].append(trick)
            } else if trick.name.starts(with: "Switch") {
                sections["Switch", default: []].append(trick)
            } else {
                sections["", default: []].append(trick)
            }
        }
        
        return sections
    }
    
    func loadVisibleTrickTypes() {
        if let data = UserDefaults.standard.data(forKey: "visibleTrickTypes"),
           let decodedSet = try? JSONDecoder().decode(Set<TrickType>.self, from: data) {
            visibleTrickTypes = decodedSet
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Group {
                        HStack {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.title3)
                                .foregroundStyle(searchIsFocused ? .indigo : .secondary)
                            TextField("Search tricks", text: $searchText)
                        }
                        .padding()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(searchIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: searchIsFocused ? 2 : 1)
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .focused($searchIsFocused)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            filterChip(
                                title: "All",
                                isSelected: selectedType == nil
                            ) {
                                selectedType = nil
                                expandedGroups = [:]
                            }

                            ForEach(TrickType.allCases
                                .sorted(by: { $0.rawValue < $1.rawValue })
                                .filter { visibleTrickTypes.contains($0) }, id: \.self) { type in
                                filterChip(
                                    title: type.rawValue == "Shuvit" ? type.displayName : type.rawValue,
                                    isSelected: selectedType == type
                                ) {
                                    selectedType = type
                                    expandedGroups = [type.rawValue: true]
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(TrickType.allCases, id: \.self) { type in
                            let tricks = groupedFilteredTricks(by: type)
                            if !tricks.isEmpty {
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedGroups[type.rawValue] ?? false || !searchText.isEmpty || selectedType == type },
                                    set: { expandedGroups[type.rawValue] = $0 }
                                )) {
                                    let sections = sectionedTricks(for: tricks)
                                    ForEach(sections.keys.sorted(), id: \.self) { section in
                                        if let sectionTricks = sections[section], !sectionTricks.isEmpty {
                                            Section(header: HStack {
                                                if !section.isEmpty {
                                                    Text(section).foregroundStyle(.secondary).textScale(.secondary).textCase(.uppercase)
                                                        .padding(.top, 8)
                                                    Spacer()
                                                }
                                            }) {
                                                ForEach(sectionTricks) { trick in
                                                    if let onTrickSelected = onTrickSelected {
                                                        TrickRow(trick: trick, padless: true)
                                                            .padding(.horizontal, 0)
                                                            .onTapGesture { onTrickSelected(trick) }
                                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                                Button {
                                                                    trick.wantToLearn.toggle()
                                                                    trick.wantToLearnDate = trick.wantToLearn ? Date() : nil
                                                                    trick.isLearned = false
                                                                    trick.isLearning = false
                                                                } label: {
                                                                    Label(trick.wantToLearn ? "Remove from Up Next" : "Add to Up Next", systemImage: trick.wantToLearn ? "star.slash" : "star")
                                                                }
                                                                .tint(trick.wantToLearn ? .gray : .blue)
                                                            }
                                                    } else {
                                                        NavigationLink(value: trick) {
                                                            TrickRow(trick: trick, padless: true)
                                                                .padding(.horizontal, 0)
                                                        }
                                                        .contextMenu {
                                                            Button {
                                                                trick.isLearned.toggle()
                                                                trick.isLearnedDate = Date()
                                                                trick.isLearning = false
                                                                trick.wantToLearn = false
                                                                trick.wantToLearnDate = nil
                                                                LearnedTrickManager.shared.trickLearned(trick)
                                                            } label: {
                                                                Label("Learned", systemImage: trick.isLearned ? "xmark.circle" : "checkmark.circle")
                                                            }
                                                            Button {
                                                                trick.isLearning.toggle()
                                                                trick.isLearned = false
                                                                trick.wantToLearn = false
                                                                trick.wantToLearnDate = nil
                                                            } label: {
                                                                Label("Learning", systemImage: trick.isLearning ? "xmark.circle" : "circle.dashed")
                                                            }
                                                            Button {
                                                                trick.wantToLearn.toggle()
                                                                trick.isSkipped = false
                                                                trick.isLearned = false
                                                                trick.isLearning = false
                                                                trick.wantToLearnDate = Date()
                                                            } label: {
                                                                Label(trick.wantToLearn ? "Learning Next" : "Learn Next", systemImage: trick.wantToLearn ? "xmark.circle" : "text.insert")
                                                            }
                                                            Button {
                                                                trick.isSkipped.toggle()
                                                                trick.isLearning = false
                                                                trick.isLearned = false
                                                                trick.wantToLearn = false
                                                                trick.wantToLearnDate = nil
                                                            } label: {
                                                                Label(trick.isSkipped ? "Skipped" : "Skip", systemImage: trick.isSkipped ? "checkmark.circle" : "arrow.clockwise")
                                                            }
                                                        }
                                                        .tint(.primary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(type.rawValue)
                                        Text("\(learnedCount)/\(tricks.count)")
                                    }
                                    .textScale(.secondary)
                                    .textCase(.uppercase)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                }
            }
            .navigationTitle("Full Trick List")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Button {
                            if searchIsFocused {
                                searchIsFocused.toggle()
                            }
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.indigo)
                        }
                        Spacer()
                        Button {
                            if searchIsFocused {
                                searchText = ""
                            }
                        } label: {
                            Text("Clear")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if !isTabItem {
                        Button {
                            searchText = ""
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddTrickView.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .learnedTrickPrompt()
            .onAppear {
                loadVisibleTrickTypes()
            }
            .navigationDestination(for: Trick.self) { trick in
                TrickDetailView(trick: trick)
            }
            .sheet(isPresented: $isShowingAddTrickView) {
                AddTrickView()
                    .modelContext(modelContext)
                    
            }
            Spacer()
            HStack(spacing: 12) {
                statPill(value: "\(filteredTricks.count)", label: "tricks")
                statPill(value: "\(learnedCount)", label: "learned")
            }
            .padding(.horizontal)
            .padding(.bottom, isTabItem ? 8 : 0)
        }
    }
}
