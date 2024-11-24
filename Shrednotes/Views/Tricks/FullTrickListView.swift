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
                    HStack {
                        Text("Full Trick List")
                            .fontWidth(.expanded)
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
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
                            Button(action: {
                                selectedType = nil
                                expandedGroups = [:]
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
                            
                            ForEach(TrickType.allCases
                                .sorted(by: { $0.rawValue < $1.rawValue })
                                .filter { visibleTrickTypes.contains($0) }, id: \.self) { type in
                                Button(action: {
                                    selectedType = type
                                    expandedGroups = [type.rawValue: true]
                                }) {
                                    Text(type.rawValue == "Shuvit" ? type.displayName : type.rawValue)
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
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                }
            }
            .padding(.top, 24)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingAddTrickView.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .tint(.secondary)
                }
            }
            .onAppear {
                loadVisibleTrickTypes()
            }
            .navigationDestination(for: Trick.self) { trick in
                TrickDetailView(trick: trick)
            }
            .sheet(isPresented: $isShowingAddTrickView) {
                AddTrickView()
                    .modelContext(modelContext)
                    .presentationCornerRadius(24)
            }
            Spacer()
            HStack {
                GroupBox {
                    HStack {
                        Text("\(filteredTricks.count)")
                            .fontWeight(.bold)
                            .foregroundStyle(.indigo)
                        Text("tricks")
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
}
