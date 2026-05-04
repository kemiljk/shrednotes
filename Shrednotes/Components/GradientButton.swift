//
//  GradientButton.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//
//  Note: name is preserved for source compatibility with existing call sites.
//  The visual style is now flat / native — primary uses `.glassProminent`,
//  secondary uses `.glass`. This is the single source of truth for primary
//  button styling across the app.
//

import SwiftUI
import CoreHaptics

enum PrimaryButtonVariant {
    case primary
    case secondary
}

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
    let variant: PrimaryButtonVariant

    typealias ButtonVariant = PrimaryButtonVariant

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

    var body: some View {
        Group {
            if let destination = destination {
                NavigationLink(destination: destination) {
                    buttonLabel
                }
            } else {
                Button {
                    if let binding = binding, let value = value {
                        binding.wrappedValue = value
                    } else {
                        action?()
                    }
                    triggerHapticFeedback()
                } label: {
                    buttonLabel
                }
            }
        }
        .modifier(PrimaryButtonStyleModifier(variant: variant, fullWidth: fullWidth))
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if hasImage {
            Label(label, systemImage: image)
        } else {
            Text(label)
        }
    }

    private func triggerHapticFeedback() {
        guard let feedbackType = hapticFeedbackType else { return }
        switch feedbackType {
        case .impact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .notification:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

/// Single source of truth for the app's primary / secondary button visual style.
/// Apply with `.modifier(PrimaryButtonStyleModifier(variant: .primary))` or
/// equivalently via the `.primaryButtonStyle()` view extension.
struct PrimaryButtonStyleModifier: ViewModifier {
    let variant: PrimaryButtonVariant
    var fullWidth: Bool = false

    func body(content: Content) -> some View {
        if variant == .primary {
            content
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.indigo)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        } else {
            content
                .buttonStyle(.glass)
                .controlSize(.large)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
    }
}

extension View {
    /// Apply the app-standard primary button style (glassProminent + indigo tint, large size).
    func primaryButtonStyle(fullWidth: Bool = false) -> some View {
        modifier(PrimaryButtonStyleModifier(variant: .primary, fullWidth: fullWidth))
    }

    /// Apply the app-standard secondary button style (glass, large size).
    func secondaryButtonStyle(fullWidth: Bool = false) -> some View {
        modifier(PrimaryButtonStyleModifier(variant: .secondary, fullWidth: fullWidth))
    }
}

enum HapticFeedbackType {
    case impact
    case notification
    case selection
}
