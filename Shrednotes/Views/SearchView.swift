import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var searchText: String
    
    @Query(sort: [SortDescriptor(\Trick.timestamp, order: .reverse)]) var tricks: [Trick]
    @Query(sort: [SortDescriptor(\SkateSession.date, order: .reverse)]) var sessions: [SkateSession]
    @Query(sort: [SortDescriptor(\ComboTrick.name, order: .reverse)]) var combos: [ComboTrick]
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section("Recent Tricks") {
                        ForEach(tricks.prefix(5)) { trick in
                            NavigationLink(value: trick) {
                                Text(trick.name)
                            }
                        }
                    }
                    if !sessions.isEmpty {
                        Section("Recent Sessions") {
                            ForEach(sessions.prefix(5)) { session in
                                NavigationLink(value: session) {
                                    Text(session.title ?? "Untitled session")
                                }
                            }
                        }
                    }
                    if !combos.isEmpty {
                        Section("Recent Combos") {
                            ForEach(combos.prefix(5)) { combo in
                                NavigationLink(value: combo) {
                                    Text(combo.name ?? "Untitled combo")
                                }
                            }
                        }
                    }
                } else {
                    let trickMatches = tricks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                    if !trickMatches.isEmpty {
                        Section("Tricks") {
                            ForEach(trickMatches) { trick in
                                NavigationLink(value: trick) {
                                    Text(trick.name)
                                }
                            }
                        }
                    }

                    let sessionMatches = sessions.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
                    if !sessionMatches.isEmpty {
                        Section("Sessions") {
                            ForEach(sessionMatches) { session in
                                NavigationLink(value: session) {
                                    Text(session.title ?? "Untitled session")
                                }
                            }
                        }
                    }

                    let comboMatches = combos.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
                    if !comboMatches.isEmpty {
                        Section("Combos") {
                            ForEach(comboMatches) { combo in
                                NavigationLink(value: combo) {
                                    Text(combo.name ?? "Untitled combo")
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationDestination(for: Trick.self) { trick in
                TrickDetailView(trick: trick)
            }
            .navigationDestination(for: SkateSession.self) { session in
                SessionDetailView(session: session, mediaState: MediaState())
            }
            .navigationDestination(for: ComboTrick.self) { combo in
                ComboBuilderView(existingCombo: combo, isPresentedInNavigationStack: true)
            }
        }
    }
} 
