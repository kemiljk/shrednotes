//
//  ComboPickerView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import SwiftData

struct ComboPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedCombos: Set<ComboTrick>
    @Query private var allCombos: [ComboTrick]
    @State private var showingAddCombo: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if #unavailable(iOS 26) {
                    HStack {
                        Text("Select Combos")
                            .fontWidth(.expanded)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                }
                
                List {
                    if allCombos.isEmpty {
                        ContentUnavailableView("No Combos", systemImage: "list.bullet", description: Text("Add a trick combo to get started."))
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(allCombos) { combo in
                            comboRow(for: combo)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .largeTitle) {
                        Text("Select Combos")
                            .fontWidth(.expanded)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .fontWeight(.bold)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .fontWeight(.bold)
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingAddCombo.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(.accentColor)
                    .sensoryFeedback(.impact, trigger: showingAddCombo)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if #unavailable(iOS 26) {
                    GradientButton<Bool, Bool, Never>(
                        label: "Add Combo",
                        hasImage: true,
                        image: "plus.circle",
                        binding: $showingAddCombo,
                        value: true,
                        fullWidth: false,
                        hapticTrigger: showingAddCombo,
                        hapticFeedbackType: .impact
                    )
                    .padding(.bottom)
                }
            }
            .sheet(isPresented: $showingAddCombo) {
                NavigationStack {
                    ComboBuilderView()
                        .presentationDragIndicator(.visible)
                        
                        .modelContext(modelContext)
                }
            }
        }
    }
    
    private func comboRow(for combo: ComboTrick) -> some View {
        Button(action: {
            if selectedCombos.contains(combo) {
                selectedCombos.remove(combo)
            } else {
                selectedCombos.insert(combo)
            }
        }) {
            HStack {
                ComboTrickRow(combo: combo)
                Spacer()
                if selectedCombos.contains(combo) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.indigo)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
    }
}
