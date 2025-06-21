import SwiftUI
import SwiftData

struct ComboElementPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Trick.name) private var tricks: [Trick]
    
    @State private var selectedType: ElementType = .direction
    @State private var searchText: String = ""
    @State private var elementSelected: Bool = true
    @FocusState private var searchIsFocused: Bool
    
    let onElementSelected: (ComboElement) -> Void
    
    private let elementTypes: [ElementType] = [
        .direction,
        .rotation,
        .baseTrick,
        .landing,
        .obstacle,
        .other
    ]
    
    private var filteredValues: [String] {
        let values: [String] = switch selectedType {
        case .direction:
            ["Nollie", "Fakie", "Switch"]
        case .rotation:
            ["FS", "BS"]
        case .baseTrick:
            tricks.filter { trick in
                trick.type == .basic ||
                trick.type == .air ||
                trick.type == .flip ||
                trick.type == .shuvit ||
                trick.type == .misc
            }.map(\.name)
        case .landing:
            tricks.filter { trick in
                trick.type == .grind ||
                trick.type == .slide ||
                trick.type == .balance ||
                trick.type == .transition
            }.map(\.name)
        case .obstacle:
            [
                "Manual Pad",
                "Bank",
                "Pyramid",
                "Round Rail",
                "Square Rail",
                "Ledge",
                "Hubba",
                "Stairs",
                "Transition",
                "Hip",
                "Wedge"
            ]
            case .other:
                []
        }
        
        if searchText.isEmpty {
            return values
        }
        return values.filter { $0.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Element Type Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(elementTypes, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                            }) {
                                Text(type.rawValue.capitalized)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedType == type ?
                                        Color.indigo : Color.indigo.opacity(0.1)
                                    )
                                    .foregroundColor(
                                        selectedType == type ?
                                            .white : .indigo
                                    )
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Search Field
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
                .focused($searchIsFocused)
                .onChange(of: selectedType) {
                    searchText = ""
                }
                .onChange(of: elementSelected) {
                    searchText = ""
                    $searchIsFocused.wrappedValue = false
                }
                
                // Element Values
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 148), spacing: 8)
                    ], spacing: 8) {
                        ForEach(filteredValues, id: \.self) { value in
                            Button(action: {
                                let element = ComboElement(
                                    type: selectedType,
                                    value: value,
                                    displayValue: value
                                )
                                onElementSelected(element)
                                elementSelected.toggle()
                            }) {
                                Text(value)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.indigo.opacity(0.1))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Add Break Button
                Button(action: {
                    let breakElement = ComboElement(
                        type: .other,
                        value: "Break",
                        displayValue: "Break",
                        isBreak: true
                    )
                    onElementSelected(breakElement)
                    elementSelected.toggle()
                }) {
                    Label("Break", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .navigationTitle("Add Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if #available(iOS 26, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
