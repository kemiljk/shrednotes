//
//  LearnedTrickManager.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/12/2024.
//
import SwiftUI

@MainActor
class LearnedTrickManager: ObservableObject {
    static let shared = LearnedTrickManager()
    
    @Published var showingPrompt = false
    @Published var learnedTrick: Trick?
    
    private init() {}
    
    func trickLearned(_ trick: Trick) {
        self.learnedTrick = trick
        self.showingPrompt = true
    }
}

struct LearnedTrickPromptModifier: ViewModifier {
    @StateObject private var manager = LearnedTrickManager.shared
    
    func body(content: Content) -> some View {
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
