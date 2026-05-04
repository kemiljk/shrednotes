//
//  LearnedTrickManager.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/12/2024.
//
import SwiftUI

@MainActor
@Observable
final class LearnedTrickManager {
    static let shared = LearnedTrickManager()

    var showingPrompt = false
    var learnedTrick: Trick?

    private init() {}

    func trickLearned(_ trick: Trick) {
        self.learnedTrick = trick
        self.showingPrompt = true
    }
}

struct LearnedTrickPromptModifier: ViewModifier {
    @State private var manager = LearnedTrickManager.shared

    func body(content: Content) -> some View {
        @Bindable var manager = manager
        content
            .overlay(
                ZStack {
                    if let trick = manager.learnedTrick {
                        ToastView(show: $manager.showingPrompt, message: "You've learned \(trick.name)!", icon: "sparkles")
                    }
                }
            )
    }
}

// Add a convenience extension to View
extension View {
    func learnedTrickPrompt() -> some View {
        modifier(LearnedTrickPromptModifier())
    }
}
