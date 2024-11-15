//
//  TrickSuggestionPickerView.swift
//  Shrednotes
//
//  Created by Karl Koch on 15/11/2024.
//
import SwiftUI

struct TrickSuggestionPickerView: View {
    @Binding var suggestedTricks: [Trick]
    @Binding var selectedTricks: Set<Trick>
    let note: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedTricks) { trick in
                    Button(action: {
                        if selectedTricks.contains(trick) {
                            selectedTricks.remove(trick)
                        } else {
                            selectedTricks.insert(trick)
                        }
                        suggestedTricks.removeAll { $0.id == trick.id }
                    }) {
                        Text(trick.name.highlightMatching(words: note.components(separatedBy: .whitespacesAndNewlines)))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTricks.contains(trick) ? Color.indigo : Color.indigo.opacity(0.1))
                            .foregroundColor(selectedTricks.contains(trick) ? .white : .indigo)
                            .cornerRadius(4)
                    }
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.8)
                            .offset(y: phase.isIdentity ? 0 : 10)
                    }
                }
            }
            .padding(.bottom, 8)
            .scrollTargetBehavior(.viewAligned)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .transition(.opacity)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }
}

extension String {
    func highlightMatching(words: [String]) -> AttributedString {
        var attributedString = AttributedString(self)
        let lowercaseSelf = self.lowercased()
        
        for word in words where word.count > 1 {
            if let range = lowercaseSelf.range(of: word.lowercased()) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].inlinePresentationIntent = .stronglyEmphasized
                }
            }
        }
        
        return attributedString
    }
}
