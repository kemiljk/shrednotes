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
        tricks.filter { trick in
            let searchWords = searchText.lowercased().split(separator: " ")
            let trickName = trick.name.lowercased()
            let containsAllSearchWords = searchWords.allSatisfy { trickName.contains($0) }
            
            return (searchText.isEmpty || containsAllSearchWords) &&
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
    
    var body: some View {
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
                .padding(.vertical, 8)
                .focused($searchIsFocused)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: {
                            selectedType = nil
                            expandedGroups = [:] // Close all groups when "All" is selected
                        }) {
                            Text("All")
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedType == nil ? Color.indigo : Color.gray.opacity(0.2))
                                .foregroundColor(selectedType == nil ? Color.white : Color.primary)
                                .cornerRadius(20)
                        }
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                .offset(y: phase.isIdentity ? 0 : 10)
                        }
                        ForEach(TrickType.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                            if !groupedFilteredTricks(by: type).isEmpty {
                                Button(action: {
                                    selectedType = type
                                    expandedGroups = [type.rawValue: true] // Open the selected group and hide others
                                }) {
                                    Text(type.rawValue)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(selectedType == type ? Color.indigo : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedType == type ? Color.white : Color.primary)
                                        .cornerRadius(20)
                                }
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                        .offset(y: phase.isIdentity ? 0 : 10)
                                }
                            }
                        }
                    }
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
                                                TrickRow(trick: trick)
                                                    .padding(.horizontal, 0)
                                                    .onTapGesture {
                                                        if mode == .learned {
                                                            if learnedTricks.contains(trick) {
                                                                learnedTricks.remove(trick)
                                                            } else {
                                                                learnedTricks.insert(trick)
                                                            }
                                                        } else if mode == .learning {
                                                            if learningTricks.contains(trick) {
                                                                learningTricks.remove(trick)
                                                            } else {
                                                                learningTricks.insert(trick)
                                                            }
                                                        }
                                                    }
                                                    .background(
                                                        (mode == .learned && learnedTricks.contains(trick)) || (mode == .learning && learningTricks.contains(trick)) ? Color.indigo.opacity(0.2) : Color.clear
                                                    )
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(type.rawValue)
                                    Text("\(tricks.filter { $0.isLearned }.count)/\(tricks.count)")
                                }
                                .textScale(.secondary)
                                .textCase(.uppercase)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                
            }
        }
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
        }
        Spacer()
        HStack {
            GroupBox {
                HStack {
                    Text("\(filteredTricks.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                    Text("available")
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 1)
                    .opacity(0.2)
            )
            GroupBox {
                HStack {
                    Text("\(tricks.filter { $0.isLearned }.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                    Text("learned")
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 1)
                    .opacity(0.2)
            )
        }
        .padding(.horizontal)
    }
}
