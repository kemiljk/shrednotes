//
//  FullTrickListViewForOnboarding.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//

import SwiftUI
import SwiftData

enum OnboardingMode {
    case learned
    case learning
}

struct FullTrickListViewForOnboarding: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var visibleTrickTypes: Set<TrickType>
    @Binding var learnedTricks: Set<Trick>
    @Binding var learningTricks: Set<Trick>
    var mode: OnboardingMode
    @State private var searchText: String = ""
    @State private var expandedGroups: [String: Bool] = [:]
    @State private var selectedType: TrickType?
    @FocusState private var searchIsFocused: Bool

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

    private func isSelected(_ trick: Trick) -> Bool {
        switch mode {
        case .learned: return learnedTricks.contains(trick)
        case .learning: return learningTricks.contains(trick)
        }
    }

    private func toggle(_ trick: Trick) {
        switch mode {
        case .learned:
            if learnedTricks.contains(trick) { learnedTricks.remove(trick) }
            else { learnedTricks.insert(trick) }
        case .learning:
            if learningTricks.contains(trick) { learningTricks.remove(trick) }
            else { learningTricks.insert(trick) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    searchField
                    typeFilterChips
                    trickList
                }
            }

            footerStats
                .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Button {
                        if searchIsFocused { searchIsFocused.toggle() }
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundStyle(.indigo)
                    }
                    Spacer()
                    Button {
                        if searchIsFocused { searchText = "" }
                    } label: {
                        Text("Clear")
                            .foregroundStyle(.indigo)
                    }
                }
            }
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass.circle")
                .font(.title3)
                .foregroundStyle(searchIsFocused ? .indigo : .secondary)
            TextField("Search tricks", text: $searchText)
        }
        .padding()
        .overlay(searchFieldBorder)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .focused($searchIsFocused)
    }

    private var searchFieldBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                searchIsFocused ? Color.indigo : Color.secondary.opacity(0.2),
                lineWidth: searchIsFocused ? 2 : 1
            )
    }

    // MARK: - Type filter chips

    private var typeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                filterChip(title: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                    expandedGroups = [:]
                }

                ForEach(TrickType.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                    if !groupedFilteredTricks(by: type).isEmpty {
                        filterChip(title: type.rawValue, isSelected: selectedType == type) {
                            selectedType = type
                            expandedGroups = [type.rawValue: true]
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
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

    // MARK: - Trick list

    private var trickList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(TrickType.allCases, id: \.self) { type in
                let typeTricks = groupedFilteredTricks(by: type)
                if !typeTricks.isEmpty {
                    disclosureGroup(for: type, tricks: typeTricks)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func disclosureGroup(for type: TrickType, tricks: [Trick]) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(for: type)) {
            disclosureContent(for: tricks)
        } label: {
            HStack {
                Text(type.rawValue)
                Text("\(tricks.filter { $0.isLearned }.count)/\(tricks.count)")
            }
            .textScale(.secondary)
            .textCase(.uppercase)
        }
    }

    private func expandedBinding(for type: TrickType) -> Binding<Bool> {
        Binding(
            get: {
                let stored = expandedGroups[type.rawValue] ?? false
                return stored || !searchText.isEmpty || selectedType == type
            },
            set: { expandedGroups[type.rawValue] = $0 }
        )
    }

    @ViewBuilder
    private func disclosureContent(for tricks: [Trick]) -> some View {
        let sections = sectionedTricks(for: tricks)
        ForEach(sections.keys.sorted(), id: \.self) { sectionKey in
            if let sectionTricks = sections[sectionKey], !sectionTricks.isEmpty {
                trickSection(title: sectionKey, tricks: sectionTricks)
            }
        }
    }

    @ViewBuilder
    private func trickSection(title: String, tricks: [Trick]) -> some View {
        Section(header: sectionHeader(title)) {
            ForEach(tricks) { trick in
                trickRow(trick)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        if !title.isEmpty {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                    .textScale(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 8)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func trickRow(_ trick: Trick) -> some View {
        let selected = isSelected(trick)
        TrickRow(trick: trick)
            .padding(.horizontal, 0)
            .background(selected ? Color.indigo.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .onTapGesture { toggle(trick) }
    }

    // MARK: - Footer stats

    private var footerStats: some View {
        HStack {
            statBox(value: filteredTricks.count, label: "available")
            statBox(value: tricks.filter { $0.isLearned }.count, label: "learned")
        }
    }

    private func statBox(value: Int, label: String) -> some View {
        GroupBox {
            HStack {
                Text("\(value)")
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
                Text(label)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary, lineWidth: 1)
                .opacity(0.2)
        )
    }
}
