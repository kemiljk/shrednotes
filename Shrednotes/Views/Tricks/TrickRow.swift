//
//  TrickRow.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI

struct TrickRow: View {
    var trick: Trick
    var padless: Bool = false
    var onDark: Bool = false

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(trick.name)
                        .fontWidth(.expanded)
                    HStack {
                        Text(trick.type.displayName)
                            .foregroundStyle(.secondary)
                            .textScale(.secondary)
                        if (trick.isLearnedDate != nil && trick.isLearned) {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                            Text("Learned \(trick.isLearnedDate?.formatted(.relative(presentation: .named)) ?? "")")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                        }
                        if (trick.isLearning) {
                            Text("•")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                            Text("Learning now")
                                .foregroundStyle(.secondary)
                                .textScale(.secondary)
                        }
                    }
                }
                Spacer()
                if (trick.isLearning) {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(trick.isLearned ? .accent : .primary)
                }
                if (trick.isLearned) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(trick.isLearned ? .accent : .primary)
                }
            }
            ConsistencyRatingViewCondensed(consistency: trick.consistency, onDark: onDark)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, padless ? 0 : 16) // Apply horizontal padding conditionally
    }
}
