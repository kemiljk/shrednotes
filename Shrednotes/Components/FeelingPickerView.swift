//
//  FeelingPickerView.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI

struct FeelingPickerView: View {
    @Binding var feelings: [Feeling]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Feeling.allCases, id: \.self) { feel in
                    Button(action: {
                        toggleFeeling(feel)
                    }) {
                        Text(feel.rawValue.capitalized)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(feelings.contains(feel) ? Color.accent : Color.secondary.opacity(0.2))
                            .foregroundColor(feelings.contains(feel) ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
                .scrollTransition { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.8)
                        .offset(y: phase.isIdentity ? 0 : 10)
                }
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .contentMargins(.horizontal, 20)
    }
    
    private func toggleFeeling(_ feel: Feeling) {
        if feelings.contains(feel) {
            feelings.removeAll { $0 == feel }
        } else {
            feelings.append(feel)
        }
    }
}
