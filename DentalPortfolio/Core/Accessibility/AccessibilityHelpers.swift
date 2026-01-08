// AccessibilityHelpers.swift
// Dental Portfolio - Accessibility Infrastructure
//
// Central manager for accessibility settings and announcements.
// Observes system accessibility preferences and provides helpers.
//
// Contents:
// - AccessibilityManager: Singleton for tracking accessibility state
// - VoiceOver announcements
// - Environment key for accessibility manager

import SwiftUI
import Combine

// MARK: - Accessibility Manager

/// Singleton manager for tracking accessibility settings and making announcements
class AccessibilityManager: ObservableObject {
    /// Shared instance
    static let shared = AccessibilityManager()

    // MARK: - Published Properties

    /// Whether VoiceOver is currently running
    @Published var isVoiceOverRunning: Bool = false

    /// Whether Reduce Motion is enabled
    @Published var isReduceMotionEnabled: Bool = false

    /// Whether Reduce Transparency is enabled
    @Published var isReduceTransparencyEnabled: Bool = false

    /// Whether Bold Text is enabled
    @Published var isBoldTextEnabled: Bool = false

    /// Whether Increase Contrast is enabled
    @Published var isIncreaseContrastEnabled: Bool = false

    /// Current preferred content size category
    @Published var preferredContentSizeCategory: UIContentSizeCategory = .medium

    /// Whether accessibility sizes are being used
    var isAccessibilitySize: Bool {
        switch preferredContentSizeCategory {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
        updateSettings()
    }

    // MARK: - Setup

    private func setupObservers() {
        // VoiceOver status changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)

        // Reduce Motion status changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Reduce Transparency status changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)

        // Bold Text status changes
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)

        // Increase Contrast status changes
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)

        // Content Size Category changes
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let category = notification.userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory {
                    self?.preferredContentSizeCategory = category
                }
            }
            .store(in: &cancellables)
    }

    private func updateSettings() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    }

    // MARK: - Announcements

    /// Announce a message to VoiceOver users
    /// - Parameters:
    ///   - message: The message to announce
    ///   - delay: Delay before announcement (helps ensure it's heard)
    func announce(_ message: String, delay: Double = 0.1) {
        guard isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Announce a screen change to VoiceOver
    /// - Parameter message: Optional message to accompany the screen change
    func announceScreenChange(_ message: String? = nil) {
        guard isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .screenChanged, argument: message)
        }
    }

    /// Announce a layout change to VoiceOver
    /// - Parameter element: Optional element to focus after the change
    func announceLayoutChange(_ element: Any? = nil) {
        guard isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }

    // MARK: - Semantic Announcements

    /// Announce photo capture success
    func announcePhotoCaptured() {
        announce("Photo captured successfully")
        HapticsManager.shared.success()
    }

    /// Announce photo saved with tags
    func announcePhotoSaved(tagCount: Int) {
        if tagCount > 0 {
            announce("Photo saved with \(tagCount) tag\(tagCount == 1 ? "" : "s")")
        } else {
            announce("Photo saved")
        }
    }

    /// Announce photo deleted
    func announcePhotoDeleted() {
        announce("Photo deleted")
    }

    /// Announce requirement completed
    func announceRequirementComplete(procedure: String) {
        announce("\(procedure) requirement complete")
    }

    /// Announce portfolio created
    func announcePortfolioCreated(name: String) {
        announce("Portfolio \(name) created")
    }

    /// Announce filter change results
    func announceFilterResults(count: Int) {
        announce("Showing \(count) photo\(count == 1 ? "" : "s")")
    }

    /// Announce error
    func announceError(_ message: String) {
        announce("Error: \(message)")
        HapticsManager.shared.error()
    }

    /// Announce loading state
    func announceLoading(_ message: String = "Loading") {
        announce(message)
    }

    /// Announce loading complete
    func announceLoadingComplete() {
        announce("Content loaded")
    }
}

// MARK: - Environment Key

/// Environment key for accessibility manager
struct AccessibilityManagerKey: EnvironmentKey {
    static let defaultValue = AccessibilityManager.shared
}

extension EnvironmentValues {
    /// Access the accessibility manager from environment
    var accessibilityManager: AccessibilityManager {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Inject accessibility manager into environment
    func withAccessibilityManager() -> some View {
        self.environmentObject(AccessibilityManager.shared)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AccessibilityHelpers_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Accessibility Status")
                .font(.headline)

            Group {
                StatusRow(label: "VoiceOver", isEnabled: AccessibilityManager.shared.isVoiceOverRunning)
                StatusRow(label: "Reduce Motion", isEnabled: AccessibilityManager.shared.isReduceMotionEnabled)
                StatusRow(label: "Bold Text", isEnabled: AccessibilityManager.shared.isBoldTextEnabled)
                StatusRow(label: "Increase Contrast", isEnabled: AccessibilityManager.shared.isIncreaseContrastEnabled)
            }

            Divider()

            Button("Test Announcement") {
                AccessibilityManager.shared.announce("This is a test announcement")
            }
        }
        .padding()
    }

    struct StatusRow: View {
        let label: String
        let isEnabled: Bool

        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(isEnabled ? "Enabled" : "Disabled")
                    .foregroundColor(isEnabled ? .green : .secondary)
            }
        }
    }
}
#endif
