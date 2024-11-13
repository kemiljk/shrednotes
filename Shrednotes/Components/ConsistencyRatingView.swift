//
//  ConsistencyRatingView.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//
import SwiftUI

struct ConsistencyRatingView: View {
    @Binding var consistency: Int
    let labels = ["Never", "Not often", "Sometimes", "Often", "Always"]

    var body: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<labels.count, id: \.self) { index in
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(consistency >= index ? LinearGradient(
                                gradient: Gradient(colors: [Color.indigo, Color.blue]),
                                startPoint: .top,
                                endPoint: .bottom
                            ) : LinearGradient(
                                gradient: Gradient(colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.1)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: CGFloat(40 + index * 20))
                        Text(labels[index])
                            .font(.caption)
                            .foregroundColor(consistency == index ? .primary : .secondary)
                    }
                    .onTapGesture {
                        consistency = index
                    }
                }
            }
        }
    }
}

struct ConsistencyRatingViewCondensed: View {
    var consistency: Int
    var onDark: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(consistency >= index ? (
                                onDark ? LinearGradient(
                                    gradient: Gradient(colors: [Color.white, Color.white]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) : LinearGradient(
                                    gradient: Gradient(colors: [Color.indigo, Color.blue]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            ) : LinearGradient(
                                gradient: Gradient(colors: [Color.secondary.opacity(0.1), Color.secondary.opacity(0.3)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: 4)
                    }
                }
            }
        }
    }
}
