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
                    Section("Recent Sessions") {
                        ForEach(sessions.prefix(5)) { session in
                            NavigationLink(value: session) {
                                Text(session.title!)
                            }
                        }
                    }
                    Section("Recent Combos") {
                        ForEach(combos.prefix(5)) { combo in
                            NavigationLink(value: combo) {
                                Text(combo.name!)
                            }
                        }
                    }
                } else {
                    if !tricks.filter({ $0.name.localizedCaseInsensitiveContains(searchText) }).isEmpty {
                        Section("Tricks") {
                            ForEach(tricks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }) { trick in
                                NavigationLink(value: trick) {
                                    Text(trick.name)
                                }
                            }
                        }
                    }
                    
                    if !sessions.filter({ $0.title!.localizedCaseInsensitiveContains(searchText) }).isEmpty {
                        Section("Sessions") {
                            ForEach(sessions.filter { $0.title!.localizedCaseInsensitiveContains(searchText) }) { session in
                                NavigationLink(value: session) {
                                    Text(session.title!)
                                }
                            }
                        }
                    }
                    
                    if !combos.filter({ $0.name!.localizedCaseInsensitiveContains(searchText) }).isEmpty {
                        Section("Combos") {
                            ForEach(combos.filter { $0.name!.localizedCaseInsensitiveContains(searchText) }) { combo in
                                NavigationLink(value: combo) {
                                    Text(combo.name!)
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
