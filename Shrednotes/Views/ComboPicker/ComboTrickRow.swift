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
            if let elements = combo.comboElements?.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) }) {
                HStack {
                    let totalTricks = elements.filter { element in
                        if let type = element.type {
                            return type == .baseTrick || type == .landing
                        }
                        return false
                    }.count
                    
                    let totalObstacles = elements.filter { element in
                        if let type = element.type {
                            return type == .obstacle
                        }
                        return false
                    }.count
                    
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
