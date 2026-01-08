// Haptics.swift
// Dental Portfolio - Haptic Feedback Manager
//
// This file contains the haptic feedback infrastructure for the app.
// Use HapticsManager.shared for all haptic feedback throughout the app.
//
// Contents:
// - HapticsManager: Singleton for haptic feedback
// - HapticStyle: Enum for different haptic types
// - View extensions for easy haptic integration

import SwiftUI
import UIKit

// MARK: - HapticsManager

/// Singleton manager for haptic feedback
/// Provides pre-configured haptic generators for various feedback types
class HapticsManager {
    /// Shared instance of the haptics manager
    static let shared = HapticsManager()

    // MARK: - Feedback Generators

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    private init() {
        // Private init for singleton
    }

    // MARK: - Preparation

    /// Prepare haptic generators to reduce latency
    /// Call this before a known haptic event (e.g., when a button appears)
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    /// Prepare a specific impact style
    /// - Parameter style: The impact style to prepare
    func prepareImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightImpact.prepare()
        case .medium:
            mediumImpact.prepare()
        case .heavy:
            heavyImpact.prepare()
        case .soft:
            softImpact.prepare()
        case .rigid:
            rigidImpact.prepare()
        @unknown default:
            mediumImpact.prepare()
        }
    }

    // MARK: - Impact Feedback

    /// Light tap feedback
    /// Use for: button taps, toggle switches, minor interactions
    func lightTap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap feedback
    /// Use for: confirmations, selections, moderate interactions
    func mediumTap() {
        mediumImpact.impactOccurred()
    }

    /// Heavy tap feedback
    /// Use for: photo capture, significant actions, emphasis
    func heavyTap() {
        heavyImpact.impactOccurred()
    }

    /// Soft tap feedback
    /// Use for: gentle interactions, background haptics
    func softTap() {
        softImpact.impactOccurred()
    }

    /// Rigid tap feedback
    /// Use for: firm, precise interactions
    func rigidTap() {
        rigidImpact.impactOccurred()
    }

    /// Impact with custom intensity
    /// - Parameters:
    ///   - style: The impact style
    ///   - intensity: Intensity from 0.0 to 1.0
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        switch style {
        case .light:
            lightImpact.impactOccurred(intensity: intensity)
        case .medium:
            mediumImpact.impactOccurred(intensity: intensity)
        case .heavy:
            heavyImpact.impactOccurred(intensity: intensity)
        case .soft:
            softImpact.impactOccurred(intensity: intensity)
        case .rigid:
            rigidImpact.impactOccurred(intensity: intensity)
        @unknown default:
            mediumImpact.impactOccurred(intensity: intensity)
        }
    }

    // MARK: - Selection Feedback

    /// Selection changed feedback
    /// Use for: picker scrolling, segment selection, tab changes
    func selectionChanged() {
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success notification feedback
    /// Use for: completed actions, saved successfully, photo captured
    func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning notification feedback
    /// Use for: alerts, attention needed, approaching limits
    func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error notification feedback
    /// Use for: failed actions, validation errors, problems
    func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Semantic Haptics

    /// Button tap haptic - light impact
    func buttonTap() {
        lightTap()
    }

    /// Photo capture haptic - heavy impact + success
    func photoCapture() {
        heavyTap()
        // Slight delay before success for two-part feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.success()
        }
    }

    /// Tag selection haptic - selection feedback
    func tagSelection() {
        selectionChanged()
    }

    /// Save completed haptic - success notification
    func saveCompleted() {
        success()
    }

    /// Delete action haptic - medium impact
    func deleteAction() {
        mediumTap()
    }

    /// Scroll snap haptic - soft impact
    func scrollSnap() {
        softTap()
    }

    /// Long press triggered haptic - rigid impact
    func longPressTriggered() {
        rigidTap()
    }
}

// MARK: - HapticStyle

/// Enum representing different haptic feedback styles
enum HapticStyle {
    /// Light impact - subtle feedback
    case light
    /// Medium impact - moderate feedback
    case medium
    /// Heavy impact - strong feedback
    case heavy
    /// Soft impact - gentle feedback
    case soft
    /// Rigid impact - firm feedback
    case rigid
    /// Selection change - for pickers and selections
    case selection
    /// Success notification
    case success
    /// Warning notification
    case warning
    /// Error notification
    case error
}

// MARK: - View Extension

extension View {
    /// Add haptic feedback when view is tapped
    /// - Parameter style: The haptic style to use
    /// - Returns: Modified view with haptic feedback
    func hapticOnTap(_ style: HapticStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                triggerHaptic(style)
            }
        )
    }

    /// Add haptic feedback when a value changes
    /// - Parameters:
    ///   - value: The value to observe
    ///   - style: The haptic style to use
    /// - Returns: Modified view with haptic feedback on change
    func hapticOnChange<T: Equatable>(of value: T, style: HapticStyle = .selection) -> some View {
        self.onChange(of: value) { _ in
            triggerHaptic(style)
        }
    }

    /// Internal function to trigger haptic based on style
    private func triggerHaptic(_ style: HapticStyle) {
        let manager = HapticsManager.shared
        switch style {
        case .light:
            manager.lightTap()
        case .medium:
            manager.mediumTap()
        case .heavy:
            manager.heavyTap()
        case .soft:
            manager.softTap()
        case .rigid:
            manager.rigidTap()
        case .selection:
            manager.selectionChanged()
        case .success:
            manager.success()
        case .warning:
            manager.warning()
        case .error:
            manager.error()
        }
    }
}

// MARK: - Haptic Feedback View Modifier

/// ViewModifier that triggers haptic feedback on state change
struct HapticFeedbackModifier<T: Equatable>: ViewModifier {
    let trigger: T
    let style: HapticStyle

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _ in
                let manager = HapticsManager.shared
                switch style {
                case .light:
                    manager.lightTap()
                case .medium:
                    manager.mediumTap()
                case .heavy:
                    manager.heavyTap()
                case .soft:
                    manager.softTap()
                case .rigid:
                    manager.rigidTap()
                case .selection:
                    manager.selectionChanged()
                case .success:
                    manager.success()
                case .warning:
                    manager.warning()
                case .error:
                    manager.error()
                }
            }
    }
}

extension View {
    /// Add haptic feedback when a trigger value changes
    /// - Parameters:
    ///   - style: The haptic style to use
    ///   - trigger: The value that triggers the haptic when changed
    /// - Returns: Modified view with haptic feedback
    func hapticFeedback<T: Equatable>(_ style: HapticStyle, trigger: T) -> some View {
        modifier(HapticFeedbackModifier(trigger: trigger, style: style))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct Haptics_Previews: PreviewProvider {
    static var previews: some View {
        HapticsPreviewContainer()
    }
}

struct HapticsPreviewContainer: View {
    @State private var counter = 0

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Haptics Demo")
                    .font(AppTheme.Typography.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap the buttons to feel different haptic feedback styles")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Impact Feedback
                Text("Impact Feedback")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: AppTheme.Spacing.sm) {
                    hapticButton("Light", style: .light)
                    hapticButton("Medium", style: .medium)
                    hapticButton("Heavy", style: .heavy)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    hapticButton("Soft", style: .soft)
                    hapticButton("Rigid", style: .rigid)
                }

                Divider()

                // Selection Feedback
                Text("Selection Feedback")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DPButton("Selection Changed", style: .secondary) {
                    HapticsManager.shared.selectionChanged()
                }

                Divider()

                // Notification Feedback
                Text("Notification Feedback")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: AppTheme.Spacing.sm) {
                    DPButton("Success", style: .primary, size: .small) {
                        HapticsManager.shared.success()
                    }
                    DPButton("Warning", style: .secondary, size: .small) {
                        HapticsManager.shared.warning()
                    }
                    DPButton("Error", style: .destructive, size: .small) {
                        HapticsManager.shared.error()
                    }
                }

                Divider()

                // Semantic Haptics
                Text("Semantic Haptics")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: AppTheme.Spacing.sm) {
                    DPButton("Photo Capture", icon: "camera.fill") {
                        HapticsManager.shared.photoCapture()
                    }

                    DPButton("Save Completed", icon: "checkmark.circle.fill", style: .secondary) {
                        HapticsManager.shared.saveCompleted()
                    }
                }

                Divider()

                // View Modifier Demo
                Text("View Modifier Demo")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Counter: \(counter)")
                    .font(AppTheme.Typography.title3)
                    .hapticFeedback(.selection, trigger: counter)

                DPButton("Increment Counter", style: .secondary) {
                    counter += 1
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }

    @ViewBuilder
    private func hapticButton(_ title: String, style: HapticStyle) -> some View {
        Button(action: {
            let manager = HapticsManager.shared
            switch style {
            case .light: manager.lightTap()
            case .medium: manager.mediumTap()
            case .heavy: manager.heavyTap()
            case .soft: manager.softTap()
            case .rigid: manager.rigidTap()
            default: break
            }
        }) {
            Text(title)
                .font(AppTheme.Typography.footnote)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surfaceSecondary)
                .cornerRadius(AppTheme.CornerRadius.small)
        }
    }
}
#endif
