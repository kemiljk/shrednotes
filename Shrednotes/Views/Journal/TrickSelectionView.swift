//
//  TrickSelectionView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import SwiftData

struct TrickSelectionView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTricks: Set<Trick>
    @State private var visibleTrickTypes: Set<TrickType> = []
    @State private var searchText: String = ""
    @State private var selectedType: TrickType?
    @State private var showNewTrickSheet: Bool = false
    @FocusState private var searchIsFocused: Bool
    
    @Query(sort: [
        SortDescriptor(\Trick.difficulty, order: .forward),
        SortDescriptor(\Trick.name, order: .forward)
    ]) private var tricks: [Trick]
    
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)])
    private var allSessions: [SkateSession]
    
    private var recentSessions: [SkateSession] {
        Array(allSessions.prefix(2))
    }
    
    private func trickMatchesSearch(_ trick: Trick) -> Bool {
        if searchText.isEmpty {
            return true
        }
        let searchWords = searchText.lowercased().split(separator: " ")
        let trickName = trick.name.lowercased()
        return searchWords.allSatisfy { trickName.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("Add Tricks")
                        .fontWidth(.expanded)
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                // Search bar
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
                
                // TrickType filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: {
                            selectedType = nil
                        }) {
                            Text("All")
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedType == nil ? Color.indigo : Color.gray.opacity(0.2))
                                .foregroundColor(selectedType == nil ? Color.white : Color.primary)
                                .cornerRadius(20)
                        }
                        ForEach(Array(visibleTrickTypes).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                            Button(action: {
                                selectedType = (selectedType == type) ? nil : type
                            }) {
                                Text(type.rawValue == "Shuvit" ? type.displayName : type.rawValue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(selectedType == type ? Color.indigo : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedType == type ? Color.white : Color.primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                List {
                    let (recentTricks, learningTricks, groupedTricks) = filteredAndDeduplicatedTricks()
                    // Recents section
                    if !recentTricks.isEmpty {
                        Section(header: Text("Recents")) {
                            ForEach(recentTricks) { trick in
                                trickRow(for: trick)
                            }
                        }
                    }

                    // Learning tricks section
                    if !learningTricks.isEmpty {
                        Section(header: Text("Learning")) {
                            ForEach(learningTricks) { trick in
                                trickRow(for: trick)
                            }
                        }
                    }
                    
                    // Other tricks grouped by TrickType
                    ForEach(Array(groupedTricks.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                        if let tricks = groupedTricks[type], !tricks.isEmpty {
                            Section(header: Text(type.rawValue)) {
                                ForEach(sectionedTricks(for: tricks).keys.sorted(), id: \.self) { section in
                                    if let sectionTricks = sectionedTricks(for: tricks)[section], !sectionTricks.isEmpty {
                                        if !section.isEmpty {
                                            Text(section).foregroundStyle(.secondary).textScale(.secondary).textCase(.uppercase)
                                                .padding(.top, 8)
                                        }
                                        ForEach(sectionTricks) { trick in
                                            trickRow(for: trick)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button(action: {
                            showNewTrickSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .fontWeight(.bold)
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        HStack {
                            Button {
                                searchText = ""
                            } label: {
                                Text("Clear")
                                    .foregroundStyle(.indigo)
                                    .opacity(searchText != "" ? 1 : 0.5)
                            }
                            Spacer()
                            Button {
                                searchIsFocused.toggle()
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundStyle(.indigo)
                            }
                        }
                    }
                }
//                .sheet(isPresented: $showNewTrickSheet, onDismiss: {
//                    do {
//                        try modelContext.save()
//                    } catch {
//                        // Handle the error appropriately
//                        print("Failed to save context: \(error)")
//                    }
//                }) {
//                    NewTrickView { newTrick in
//                        modelContext.insert(newTrick)
//                        selectedTricks.insert(newTrick)
//                    }
//                    .presentationCornerRadius(24)
//                }
            }
            .padding(.top, 24)
            .onAppear(perform: loadVisibleTrickTypes)
        }
    }
    
    private var filteredTricks: [Trick] {
        tricks.filter { trick in
            trickMatchesSearch(trick) &&
            (selectedType == nil || trick.type == selectedType) &&
            visibleTrickTypes.contains(trick.type)
        }
    }
    
    @MainActor
    private func filteredAndDeduplicatedTricks() -> (recent: [Trick], learning: [Trick], grouped: [TrickType: [Trick]]) {
        var displayedTricks = Set<Trick>()
        
        // Filter recent tricks
        let recentTricks = recentSessions.flatMap { $0.tricks ?? [] }
            .filter { trickMatchesSearch($0) && (selectedType == nil || $0.type == selectedType) }
        let uniqueRecentTricks = Array(Set(recentTricks)).sorted { $0.name < $1.name }
        displayedTricks.formUnion(uniqueRecentTricks)
        
        // Filter learning tricks
        let learningTricks = filteredTricks.filter { $0.isLearning && !displayedTricks.contains($0) }
        displayedTricks.formUnion(learningTricks)
        
        // Group remaining tricks by type
        var groupedTricks: [TrickType: [Trick]] = [:]
        for type in visibleTrickTypes {
            let tricksOfType = filteredTricks.filter { $0.type == type && !displayedTricks.contains($0) }
            if !tricksOfType.isEmpty {
                groupedTricks[type] = tricksOfType
            }
            displayedTricks.formUnion(tricksOfType)
        }
        
        return (uniqueRecentTricks, learningTricks.sorted { $0.name < $1.name }, groupedTricks)
    }
    
    private func sectionedTricks(for tricks: [Trick]) -> [String: [Trick]] {
        var sections: [String: [Trick]] = ["": [], "Fakie": [], "Nollie": [], "Switch": []]
        
        for trick in tricks {
            if trick.name.contains("Fakie") {
                sections["Fakie", default: []].append(trick)
            } else if trick.name.contains("Nollie") {
                sections["Nollie", default: []].append(trick)
            } else if trick.name.contains("Switch") {
                sections["Switch", default: []].append(trick)
            } else {
                sections["", default: []].append(trick)
            }
        }
        
        return sections
    }
    
    private func trickRow(for trick: Trick) -> some View {
        HStack {
            Text(trick.name)
                .fontWidth(.expanded)
                .multilineTextAlignment(.leading)
            Spacer()
            if selectedTricks.contains(trick) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.indigo)
            }
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedTricks.contains(trick) {
                selectedTricks.remove(trick)
            } else {
                selectedTricks.insert(trick)
            }
        }
    }
    
    private func loadVisibleTrickTypes() {
        if let savedData = UserDefaults.standard.data(forKey: "visibleTrickTypes"),
           let decodedData = try? JSONDecoder().decode(Set<TrickType>.self, from: savedData) {
            visibleTrickTypes = decodedData
        } else {
            visibleTrickTypes = Set(TrickType.allCases)
        }
    }
}
