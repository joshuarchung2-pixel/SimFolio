// AccessibilityModifiers.swift
// Dental Portfolio - Accessibility View Modifiers
//
// Custom view modifiers for adding accessibility support to views.
// Includes semantic, image, progress, and motion-aware modifiers.
//
// Contents:
// - SemanticAccessibilityModifier: Labels, hints, values, and traits
// - CardAccessibilityModifier: For interactive cards
// - ImageAccessibilityModifier: For images
// - ProgressAccessibilityModifier: For progress indicators
// - AdjustableAccessibilityModifier: For adjustable controls
// - ReducedMotionModifier: For respecting motion preferences
// - HighContrastModifier: For increased contrast support

import SwiftUI

// MARK: - Semantic Accessibility Modifier

/// ViewModifier for adding semantic accessibility information
struct SemanticAccessibilityModifier: ViewModifier {
    let label: String
    var hint: String? = nil
    var value: String? = nil
    var traits: AccessibilityTraits = []
    var isHeader: Bool = false

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityAddTraits(isHeader ? .isHeader : [])
    }
}

extension View {
    /// Add semantic accessibility information to a view
    /// - Parameters:
    ///   - label: The accessibility label (what the element is)
    ///   - hint: The accessibility hint (what happens when activated)
    ///   - value: The accessibility value (current state)
    ///   - traits: Additional accessibility traits
    ///   - isHeader: Whether this element is a header
    func semanticAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isHeader: Bool = false
    ) -> some View {
        modifier(SemanticAccessibilityModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits,
            isHeader: isHeader
        ))
    }
}

// MARK: - Card Accessibility Modifier

/// ViewModifier for making cards accessible as single elements
struct CardAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String
    var customActions: [(name: String, action: () -> Void)] = []

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                ForEach(customActions.indices, id: \.self) { index in
                    Button(customActions[index].name) {
                        customActions[index].action()
                    }
                }
            }
    }
}

extension View {
    /// Make a card accessible as a single interactive element
    /// - Parameters:
    ///   - label: Combined label for all card content
    ///   - hint: What happens when the card is activated
    ///   - customActions: Additional actions available in rotor
    func cardAccessibility(
        label: String,
        hint: String,
        customActions: [(name: String, action: () -> Void)] = []
    ) -> some View {
        modifier(CardAccessibilityModifier(
            label: label,
            hint: hint,
            customActions: customActions
        ))
    }
}

// MARK: - Image Accessibility Modifier

/// ViewModifier for adding accessibility to images
struct ImageAccessibilityModifier: ViewModifier {
    let description: String
    var isDecorative: Bool = false

    func body(content: Content) -> some View {
        if isDecorative {
            content
                .accessibilityHidden(true)
        } else {
            content
                .accessibilityLabel(description)
                .accessibilityAddTraits(.isImage)
        }
    }
}

extension View {
    /// Add accessibility information to an image
    /// - Parameters:
    ///   - description: Description of the image content
    ///   - isDecorative: If true, hides image from accessibility
    func imageAccessibility(_ description: String, isDecorative: Bool = false) -> some View {
        modifier(ImageAccessibilityModifier(description: description, isDecorative: isDecorative))
    }
}

// MARK: - Progress Accessibility Modifier

/// ViewModifier for making progress indicators accessible
struct ProgressAccessibilityModifier: ViewModifier {
    let label: String
    let currentValue: Double
    let maxValue: Double

    var percentageValue: String {
        let percentage = Int((currentValue / maxValue) * 100)
        return "\(percentage) percent"
    }

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(percentageValue)
    }
}

extension View {
    /// Add accessibility to a progress indicator
    /// - Parameters:
    ///   - label: What the progress represents
    ///   - current: Current progress value
    ///   - max: Maximum progress value
    func progressAccessibility(label: String, current: Double, max: Double = 1.0) -> some View {
        modifier(ProgressAccessibilityModifier(label: label, currentValue: current, maxValue: max))
    }
}

// MARK: - Adjustable Accessibility Modifier

/// ViewModifier for creating adjustable accessibility controls
struct AdjustableAccessibilityModifier: ViewModifier {
    let label: String
    let value: String
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onIncrement()
                case .decrement:
                    onDecrement()
                @unknown default:
                    break
                }
            }
    }
}

extension View {
    /// Make a control adjustable via VoiceOver swipe gestures
    /// - Parameters:
    ///   - label: What the control adjusts
    ///   - value: Current value description
    ///   - onIncrement: Called when user swipes up
    ///   - onDecrement: Called when user swipes down
    func adjustableAccessibility(
        label: String,
        value: String,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) -> some View {
        modifier(AdjustableAccessibilityModifier(
            label: label,
            value: value,
            onIncrement: onIncrement,
            onDecrement: onDecrement
        ))
    }
}

// MARK: - Reduced Motion Modifier

/// ViewModifier that respects Reduce Motion preference
struct ReducedMotionModifier<V: Equatable>: ViewModifier {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared

    let value: V
    let animation: Animation?
    let reducedAnimation: Animation?

    func body(content: Content) -> some View {
        content
            .animation(
                accessibilityManager.isReduceMotionEnabled ? reducedAnimation : animation,
                value: value
            )
    }
}

extension View {
    /// Apply animation that respects Reduce Motion preference
    /// - Parameters:
    ///   - value: Value to animate changes of
    ///   - animation: Animation to use normally
    ///   - reducedAnimation: Animation to use when Reduce Motion is on (nil for no animation)
    func respectReducedMotion<V: Equatable>(
        value: V,
        animation: Animation? = .easeInOut(duration: 0.3),
        reducedAnimation: Animation? = nil
    ) -> some View {
        modifier(ReducedMotionModifier(
            value: value,
            animation: animation,
            reducedAnimation: reducedAnimation
        ))
    }
}

// MARK: - High Contrast Modifier

/// ViewModifier that provides high contrast alternatives
struct HighContrastModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast

    let normalColor: Color
    let highContrastColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(contrast == .increased ? highContrastColor : normalColor)
    }
}

extension View {
    /// Apply different foreground colors based on contrast preference
    /// - Parameters:
    ///   - normal: Color for normal contrast
    ///   - highContrast: Color for increased contrast
    func highContrastForeground(normal: Color, highContrast: Color) -> some View {
        modifier(HighContrastModifier(normalColor: normal, highContrastColor: highContrast))
    }
}

// MARK: - High Contrast Background Modifier

/// ViewModifier for high contrast backgrounds
struct HighContrastBackgroundModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast

    let normalColor: Color
    let highContrastColor: Color

    func body(content: Content) -> some View {
        content
            .background(contrast == .increased ? highContrastColor : normalColor)
    }
}

extension View {
    /// Apply different background colors based on contrast preference
    func highContrastBackground(normal: Color, highContrast: Color) -> some View {
        modifier(HighContrastBackgroundModifier(normalColor: normal, highContrastColor: highContrast))
    }
}

// MARK: - Accessibility Button Modifier

/// ViewModifier for making elements button-accessible
struct AccessibilityButtonModifier: ViewModifier {
    let label: String
    let hint: String
    let action: () -> Void

    func body(content: Content) -> some View {
        Button(action: action) {
            content
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}

extension View {
    /// Make a view accessible as a button
    /// - Parameters:
    ///   - label: What the button is
    ///   - hint: What happens when activated
    ///   - action: Action to perform
    func accessibilityButton(
        label: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(AccessibilityButtonModifier(label: label, hint: hint, action: action))
    }
}

// MARK: - Accessibility Sort Priority Modifier

/// ViewModifier for controlling VoiceOver navigation order
struct AccessibilitySortPriorityModifier: ViewModifier {
    let priority: Double

    func body(content: Content) -> some View {
        content
            .accessibilitySortPriority(priority)
    }
}

extension View {
    /// Set VoiceOver navigation priority (higher = earlier)
    func accessibilityNavigationPriority(_ priority: Double) -> some View {
        modifier(AccessibilitySortPriorityModifier(priority: priority))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AccessibilityModifiers_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Semantic accessibility
            Text("Header")
                .font(.title)
                .semanticAccessibility(
                    label: "Section Header",
                    hint: nil,
                    value: nil,
                    traits: [],
                    isHeader: true
                )

            // Card accessibility
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .frame(height: 100)
                .cardAccessibility(
                    label: "Sample card with content",
                    hint: "Double tap to view details"
                )

            // Image accessibility
            Image(systemName: "photo")
                .font(.largeTitle)
                .imageAccessibility("Sample photo of dental procedure")

            // Progress accessibility
            ProgressView(value: 0.7)
                .progressAccessibility(label: "Portfolio completion", current: 0.7)

            // Adjustable control
            HStack {
                Text("Rating: 3")
                Spacer()
            }
            .adjustableAccessibility(
                label: "Rating",
                value: "3 of 5 stars",
                onIncrement: { print("Increment") },
                onDecrement: { print("Decrement") }
            )
        }
        .padding()
    }
}
#endif
