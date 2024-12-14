//
//  GradientButton.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import SwiftUI
import CoreHaptics

struct GradientButton<T, HapticTrigger, Destination>: View where Destination: View {
    let label: String
    let hasImage: Bool
    let image: String
    let binding: Binding<T>?
    let value: T?
    let action: (() -> Void)?
    let fullWidth: Bool
    let destination: Destination?
    let hapticTrigger: HapticTrigger?
    let hapticFeedbackType: HapticFeedbackType?
    let variant: ButtonVariant
    
    enum ButtonVariant {
        case primary
        case secondary
    }

    // First convenience initializer for non-navigation buttons
    init(
        label: String,
        hasImage: Bool = false,
        image: String = "",
        binding: Binding<T>? = nil,
        value: T? = nil,
        action: (() -> Void)? = nil,
        fullWidth: Bool = false,
        hapticTrigger: HapticTrigger? = nil,
        hapticFeedbackType: HapticFeedbackType? = nil,
        variant: ButtonVariant = .primary
    ) where Destination == EmptyView {
        self.label = label
        self.hasImage = hasImage
        self.image = image
        self.binding = binding
        self.value = value
        self.action = action
        self.fullWidth = fullWidth
        self.destination = nil
        self.hapticTrigger = hapticTrigger
        self.hapticFeedbackType = hapticFeedbackType
        self.variant = variant
    }

    // Main initializer for navigation buttons
    init(
        label: String,
        hasImage: Bool = false,
        image: String = "",
        binding: Binding<T>? = nil,
        value: T? = nil,
        action: (() -> Void)? = nil,
        fullWidth: Bool = false,
        destination: Destination? = nil,
        hapticTrigger: HapticTrigger? = nil,
        hapticFeedbackType: HapticFeedbackType? = nil,
        variant: ButtonVariant = .primary
    ) {
        self.label = label
        self.hasImage = hasImage
        self.image = image
        self.binding = binding
        self.value = value
        self.action = action
        self.fullWidth = fullWidth
        self.destination = destination
        self.hapticTrigger = hapticTrigger
        self.hapticFeedbackType = hapticFeedbackType
        self.variant = variant
    }
    
    var gradientColors: AnyGradient {
        switch variant {
        case .primary:
            return Color.indigo.gradient
        case .secondary:
            return Color(.systemGray5).gradient
        }
    }
    
    var textColor: Color {
        if variant == .primary {
            return .white
        } else {
            return .primary
        }
    }
    
    var body: some View {
        VStack {
            if let destination = destination {
                NavigationLink(destination: destination) {
                    buttonContent
                }
            } else {
                Button(action: {
                    if let binding = binding, let value = value {
                        binding.wrappedValue = value
                    } else {
                        action?()
                    }
                    triggerHapticFeedback()
                }) {
                    buttonContent
                }
            }
        }
        .frame(maxWidth: fullWidth ? .infinity : nil)
    }

    @ViewBuilder
    private var buttonContent: some View {
        if hasImage {
            Label(label, systemImage: image)
                .font(.headline)
                .padding()
                .background(gradientColors)
                .foregroundStyle(textColor)
                .clipShape(Capsule())
        } else {
            Text(label)
                .font(.headline)
                .padding()
                .background(gradientColors)
                .foregroundStyle(textColor)
                .clipShape(Capsule())
        }
    }

    private func triggerHapticFeedback() {
        if let feedbackType = hapticFeedbackType {
            switch feedbackType {
            case .impact:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            case .notification:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        }
    }
}


enum HapticFeedbackType {
    case impact
    case notification
    case selection
}
