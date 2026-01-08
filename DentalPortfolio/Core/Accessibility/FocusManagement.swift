// FocusManagement.swift
// Dental Portfolio - Accessibility Focus Management
//
// Helpers for managing VoiceOver focus and navigation.
// Ensures focus moves appropriately during navigation and state changes.
//
// Contents:
// - Focus on appear modifier
// - Rotor actions modifier
// - Accessibility focus helpers
// - Navigation focus management

import SwiftUI

// MARK: - Focus On Appear Modifier

/// ViewModifier that sets VoiceOver focus when view appears
struct FocusOnAppearModifier: ViewModifier {
    @AccessibilityFocusState var isFocused: Bool
    let shouldFocus: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onAppear {
                if shouldFocus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        isFocused = true
                    }
                }
            }
    }
}

extension View {
    /// Focus this element with VoiceOver when it appears
    /// - Parameters:
    ///   - condition: Whether to focus (default true)
    ///   - delay: Delay before focusing (default 0.5s)
    func focusOnAppear(when condition: Bool = true, delay: Double = 0.5) -> some View {
        modifier(FocusOnAppearModifier(shouldFocus: condition, delay: delay))
    }
}

// MARK: - Rotor Actions Modifier

/// ViewModifier for adding custom rotor actions
struct RotorActionsModifier: ViewModifier {
    let actions: [(name: String, action: () -> Void)]

    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                ForEach(actions.indices, id: \.self) { index in
                    Button(actions[index].name) {
                        actions[index].action()
                    }
                }
            }
    }
}

extension View {
    /// Add custom actions to VoiceOver rotor
    /// - Parameter actions: Array of (name, action) tuples
    func rotorActions(_ actions: [(name: String, action: () -> Void)]) -> some View {
        modifier(RotorActionsModifier(actions: actions))
    }
}

// MARK: - Accessibility Focus Wrapper

/// Wrapper for managing accessibility focus state
struct AccessibleFocusWrapper<FocusValue: Hashable, Content: View>: View {
    @AccessibilityFocusState var focusedField: FocusValue?
    @Binding var externalFocus: FocusValue?
    let content: (Binding<FocusValue?>) -> Content

    init(
        focus: Binding<FocusValue?>,
        @ViewBuilder content: @escaping (Binding<FocusValue?>) -> Content
    ) {
        self._externalFocus = focus
        self.content = content
    }

    var body: some View {
        content($focusedField)
            .onChange(of: externalFocus) { newValue in
                focusedField = newValue
            }
            .onChange(of: focusedField) { newValue in
                externalFocus = newValue
            }
    }
}

// MARK: - Screen Change Announcer

/// ViewModifier that announces screen changes
struct ScreenChangeAnnouncerModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                AccessibilityManager.shared.announceScreenChange("Now viewing \(screenName)")
            }
    }
}

extension View {
    /// Announce this screen when it appears
    /// - Parameter screenName: Name of the screen to announce
    func announceScreenChange(_ screenName: String) -> some View {
        modifier(ScreenChangeAnnouncerModifier(screenName: screenName))
    }
}

// MARK: - Focus After Action Modifier

/// ViewModifier that focuses an element after an action
struct FocusAfterActionModifier: ViewModifier {
    @AccessibilityFocusState var isFocused: Bool
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: trigger) { newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFocused = true
                        trigger = false
                    }
                }
            }
    }
}

extension View {
    /// Focus this element when trigger becomes true
    /// - Parameter trigger: Binding that triggers focus when true
    func focusAfterAction(trigger: Binding<Bool>) -> some View {
        modifier(FocusAfterActionModifier(trigger: trigger))
    }
}

// MARK: - Accessibility Navigation Container

/// Container that manages VoiceOver navigation for a group of elements
struct AccessibilityNavigationContainer<Content: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder let content: () -> Content

    init(
        label: String,
        hint: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.hint = hint
        self.content = content
    }

    var body: some View {
        content()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Skip Navigation Link

/// Accessibility element that allows skipping to main content
struct SkipNavigationLink: View {
    @AccessibilityFocusState var isSkipFocused: Bool
    @AccessibilityFocusState var isMainFocused: Bool

    let mainContentLabel: String

    var body: some View {
        // This is a hidden element for VoiceOver users
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityLabel("Skip to \(mainContentLabel)")
            .accessibilityHint("Double tap to skip navigation")
            .accessibilityFocused($isSkipFocused)
            .accessibilityAction {
                isMainFocused = true
            }
    }
}

// MARK: - Accessibility Group

/// Group elements for logical VoiceOver navigation
struct AccessibilityGroup<Content: View>: View {
    let label: String
    let combineChildren: Bool
    @ViewBuilder let content: () -> Content

    init(
        label: String,
        combineChildren: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.combineChildren = combineChildren
        self.content = content
    }

    var body: some View {
        content()
            .accessibilityElement(children: combineChildren ? .combine : .contain)
            .accessibilityLabel(label)
    }
}

// MARK: - Accessibility Escape Handler

/// ViewModifier that handles VoiceOver escape gesture
struct AccessibilityEscapeModifier: ViewModifier {
    let action: () -> Bool

    func body(content: Content) -> some View {
        content
            .accessibilityAction(.escape) {
                _ = action()
            }
    }
}

extension View {
    /// Handle VoiceOver escape gesture (two-finger Z)
    /// - Parameter action: Action to perform, return true if handled
    func accessibilityEscape(_ action: @escaping () -> Bool) -> some View {
        modifier(AccessibilityEscapeModifier(action: action))
    }
}

// MARK: - Announcement Helper View

/// View that makes announcements when state changes
struct AnnouncementView: View {
    let message: String
    let announce: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: announce) { shouldAnnounce in
                if shouldAnnounce {
                    AccessibilityManager.shared.announce(message)
                }
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct FocusManagement_Previews: PreviewProvider {
    static var previews: some View {
        FocusManagementPreviewContent()
    }

    struct FocusManagementPreviewContent: View {
        @State private var selectedItem: Int? = nil
        @State private var shouldFocus = false

        var body: some View {
            VStack(spacing: 20) {
                Text("Focus Management Demo")
                    .font(.headline)
                    .focusOnAppear()

                // Rotor actions example
                Text("Item with custom actions")
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .rotorActions([
                        ("Edit", { print("Edit") }),
                        ("Delete", { print("Delete") }),
                        ("Share", { print("Share") })
                    ])

                // Accessibility group example
                AccessibilityGroup(label: "Statistics section") {
                    HStack {
                        StatBox(value: "42", label: "Photos")
                        StatBox(value: "3", label: "Portfolios")
                        StatBox(value: "75%", label: "Complete")
                    }
                }

                // Screen change announcer
                Button("Navigate") {
                    // Navigation would happen here
                }
                .announceScreenChange("Settings")

                Divider()

                Button("Trigger Focus") {
                    shouldFocus = true
                }

                Text("Focus Target")
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                    .focusAfterAction(trigger: $shouldFocus)
            }
            .padding()
        }

        struct StatBox: View {
            let value: String
            let label: String

            var body: some View {
                VStack {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
#endif
