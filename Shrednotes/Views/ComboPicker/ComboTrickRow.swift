//
//  ComboTrickRow.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI

struct ComboTrickRow: View {
    var combo: ComboTrick

    var body: some View {
        VStack(alignment: .leading) {
            if let name = combo.name {
                Text(name)
                    .fontWidth(.expanded)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if let elements = combo.comboElements {
                HStack {
                    let totalTricks = elements.filter { $0.type == .baseTrick || $0.type == .landing }.count
                    let totalObstacles = elements.filter { $0.type == .obstacle }.count
                    if totalTricks != 0 {
                        Text("^[\(totalTricks) trick](inflect: true)")
                    }
                    if totalObstacles != 0 {
                        Text("•")
                        Text("^[\(totalObstacles) obstacle](inflect: true)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
} 
