//
//  ComboElementRow.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI

struct ComboElementRow: View {
    @Binding var element: ComboElement
    var onDelete: () -> Void
    
    var iconForType: String {
        switch element.type {
        case .baseTrick:
            return "skateboard"
        case .direction:
            return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotation:
            return "rotate.right"
        case .landing:
            return "arrow.down.to.line"
        case .obstacle:
            return "cube"
        case .other:
            return "questionmark.circle"
        case .none:
            return "circle"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconForType)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(element.displayValue ?? element.value ?? "")
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            Text(element.type?.displayName ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thickMaterial)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                element.indentation = 0
            } label: {
                Label("None", systemImage: "xmark")
            }
            .tint(.gray)
            Button(role: .destructive) {
                withAnimation {
                    onDelete()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                element.indentation = 1
            } label: {
                Text("On")
            }
            .tint(.primary.opacity(0.7))
            
            Button {
                element.indentation = 2
            } label: {
                Text("Over")
            }
            .tint(.secondary)
            
            Button {
                element.indentation = 3
            } label: {
                Text("To")
            }
            .tint(.secondary.opacity(0.5))
        }
    }
}

extension Int {
    var displayName: String {
        switch self {
        case 0: return "None"
        case 1: return "On"
        case 2: return "Over"
        case 3: return "To"
        default: return "None"
        }
    }
}
