import SwiftUI
import SwiftData
import TipKit

struct ComboBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var comboName: String = ""
    @State private var comboElements: [ComboElement] = []
    @State private var showingElementPicker = false
    @State private var isAddingElement = false
    @State private var swipeToLinkTip = SwipeToLinkTip()
    
    private let existingComboId: PersistentIdentifier?
    let isPresentedInNavigationStack: Bool
    
    init(existingCombo: ComboTrick? = nil, isPresentedInNavigationStack: Bool = false) {
        self.isPresentedInNavigationStack = isPresentedInNavigationStack
        if let combo = existingCombo {
            _comboName = State(initialValue: combo.name ?? "")
            // Sort elements by order when loading
            let sortedElements = (combo.comboElements ?? []).sorted { ($0.order ?? 0) < ($1.order ?? 0) }
            _comboElements = State(initialValue: sortedElements)
            self.existingComboId = combo.persistentModelID
        } else {
            self.existingComboId = nil
        }
    }
    
    var body: some View {
        List {
            Section {
                TextField("Custom Name", text: $comboName)
            } header: {
                Text("Combo Name")
            }
            .listRowSeparator(.hidden)
            
            Section {
                TipView(swipeToLinkTip)
                    .listRowSeparator(.hidden)
                
                ForEach(comboElements.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        if comboElements[index].isBreak == true {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            VStack(spacing: 0) {
                                ComboElementRow(element: $comboElements[index], onDelete: {
                                    removeElement(at: index)
                                })
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeElement(at: index)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                        if shouldShowIndentation(at: index) {
                            HStack {
                                Spacer()
                                Text(comboElements[index].indentation?.displayName ?? "None")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                                Spacer()
                            }
                            .padding(.top, 12)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .onDelete(perform: deleteElements)
                .onMove(perform: moveElements)
                
                if isAddingElement {
                    ComboElementRow(
                        element: .constant(ComboElement(
                            type: .baseTrick,
                            value: "New Element",
                            displayValue: "New Element"
                        )),
                        onDelete: {}
                    )
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                
                if comboElements.isEmpty || !isAddingElement {
                    Menu {
                        Button("Add Element") {
                            isAddingElement = true
                            showingElementPicker = true
                        }
                        Button("Add Break") {
                            addBreak()
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            } header: {
                Text("Combo Elements")
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(.background)
        .onChange(of: comboElements) { _, newValue in
            SwipeToLinkTip.elementCount = newValue.count
        }
        .navigationTitle("Combo Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingElementPicker, onDismiss: { isAddingElement = false }) {
            ComboElementPickerView(onElementSelected: { element in
                addElement(element)
            })
            .presentationDetents([.fraction(0.5), .medium, .large])
            
            .presentationBackgroundInteraction(.enabled)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isPresentedInNavigationStack {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            if #unavailable(iOS 26) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        saveAndDismiss()
                    }
                }
            }
        } else {
            if #unavailable(iOS 26) {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
            if #unavailable(iOS 26) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        saveAndDismiss()
                    }
                }
            }
        }
    }
    
    private func shouldShowIndentation(at index: Int) -> Bool {
        guard index < comboElements.count - 1,
              comboElements[index + 1].isBreak != true,
              let indentation = comboElements[index].indentation,
              indentation != 0 else {
            return false
        }
        return true
    }
    
    private func addElement(_ element: ComboElement) {
        comboElements.append(element)
    }
    
    private func addBreak() {
        let breakElement = ComboElement(
            type: .other,
            value: "",
            isBreak: true
        )
        comboElements.append(breakElement)
    }
    
    private func removeElement(at index: Int) {
        comboElements.remove(at: index)
    }
    
    private func saveAndDismiss() {
        saveCombo()
        if isPresentedInNavigationStack {
            presentationMode.wrappedValue.dismiss()
        } else {
            dismiss()
        }
    }
    
    private func saveCombo() {
        if let id = existingComboId,
           let existingCombo = try? modelContext.fetch(FetchDescriptor<ComboTrick>(predicate: #Predicate { $0.persistentModelID == id })).first {
            existingCombo.name = comboName
            // Create new ComboElement instances with order
            let newElements = comboElements.enumerated().map { index, element in
                let comboElement = ComboElement()
                comboElement.type = element.type
                comboElement.value = element.value
                comboElement.displayValue = element.displayValue
                comboElement.isBreak = element.isBreak
                comboElement.indentation = element.indentation
                comboElement.order = index  // Set the order
                comboElement.combo = existingCombo
                return comboElement
            }
            existingCombo.comboElements = newElements
            existingCombo.difficulty = comboElements.count
            try? modelContext.save()
        } else {
            let newCombo = ComboTrick(
                name: comboName,
                difficulty: comboElements.count
            )
            
            // Create new ComboElement instances with order
            let newElements = comboElements.enumerated().map { index, element in
                let comboElement = ComboElement()
                comboElement.type = element.type
                comboElement.value = element.value
                comboElement.displayValue = element.displayValue
                comboElement.isBreak = element.isBreak
                comboElement.indentation = element.indentation
                comboElement.order = index  // Set the order
                comboElement.combo = newCombo
                return comboElement
            }
            newCombo.comboElements = newElements
            modelContext.insert(newCombo)
        }
    }
    
    private func deleteElements(at offsets: IndexSet) {
        comboElements.remove(atOffsets: offsets)
    }
    
    private func moveElements(from source: IndexSet, to destination: Int) {
        comboElements.move(fromOffsets: source, toOffset: destination)
    }
}

// Add this extension for the shimmering effect
extension View {
    @ViewBuilder func shimmering() -> some View {
        self.modifier(Shimmer())
    }
}

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .modifier(ShimmerElement(phase: phase))
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    self.phase = 1
                }
            }
    }
}

struct ShimmerElement: AnimatableModifier {
    @Environment(\.colorScheme) var colorScheme
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Color.white.opacity(0.3)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.3),
                                        .init(color: .white, location: 0.7),
                                        .init(color: .clear, location: 1)
                                    ]), startPoint: .leading, endPoint: .trailing)
                                )
                                .rotationEffect(.degrees(30))
                                .offset(x: -geometry.size.width)
                                .offset(x: geometry.size.width * 2 * phase)
                        )
                        .blendMode(colorScheme == .dark ? .overlay : .normal)
                }
            )
    }
}

struct SwipeToLinkTip: Tip {
    @Parameter
    static var elementCount: Int = 0

    var title: Text {
        Text("Swipe to Link Tricks")
    }
    
    var message: Text? {
        Text("Swipe a trick from left to right to define how it links to the next trick (On, Over, To).")
    }
    
    var image: Image? {
        Image(systemName: "hand.draw")
    }

    var rules: [Rule] {
        #Rule(Self.$elementCount) { $0 >= 2 }
    }
}
