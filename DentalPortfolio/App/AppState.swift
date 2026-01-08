// AppState.swift
// Dental Portfolio - Global App State Management
//
// Centralized state management for app-wide concerns including:
// - Permission states (camera, photos, notifications)
// - User preferences
// - App lifecycle state
//
// Use AppState.shared for singleton access throughout the app.

import SwiftUI
import Combine
import AVFoundation
import Photos
import UserNotifications

// MARK: - AppState

/// Global app state manager
class AppState: ObservableObject {
    /// Shared singleton instance
    static let shared = AppState()

    // MARK: - Permission States

    /// Camera authorization status
    @Published var cameraPermission: AVAuthorizationStatus = .notDetermined

    /// Photo library authorization status
    @Published var photoLibraryPermission: PHAuthorizationStatus = .notDetermined

    /// Notification authorization status
    @Published var notificationPermission: UNAuthorizationStatus = .notDetermined

    // MARK: - App States

    /// Whether this is the first app launch
    @Published var isFirstLaunch: Bool = true

    /// Last time the app was active
    @Published var lastActiveDate: Date?

    /// Whether there are unsaved changes
    @Published var hasUnsavedChanges: Bool = false

    /// Whether the app is currently loading
    @Published var isLoading: Bool = false

    // MARK: - User Preferences

    /// Whether haptic feedback is enabled
    @Published var hapticFeedbackEnabled: Bool = true

    /// Whether to auto-save photos after capture
    @Published var autoSaveEnabled: Bool = true

    /// Default photo quality setting
    @Published var defaultPhotoQuality: PhotoQuality = .high

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadState()
        setupObservers()
    }

    // MARK: - State Management

    /// Load persisted state from UserDefaults
    func loadState() {
        let defaults = UserDefaults.standard

        // First launch check
        isFirstLaunch = !defaults.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            defaults.set(true, forKey: "hasLaunchedBefore")
        }

        // Load preferences
        lastActiveDate = defaults.object(forKey: "lastActiveDate") as? Date
        hapticFeedbackEnabled = defaults.object(forKey: "captureHaptics") as? Bool ?? true
        autoSaveEnabled = defaults.object(forKey: "autoSave") as? Bool ?? true

        if let qualityString = defaults.string(forKey: "photoQuality"),
           let quality = PhotoQuality(rawValue: qualityString) {
            defaultPhotoQuality = quality
        }
    }

    /// Save current state to UserDefaults
    func saveState() {
        let defaults = UserDefaults.standard

        defaults.set(Date(), forKey: "lastActiveDate")
        defaults.set(hapticFeedbackEnabled, forKey: "captureHaptics")
        defaults.set(autoSaveEnabled, forKey: "autoSave")
        defaults.set(defaultPhotoQuality.rawValue, forKey: "photoQuality")
    }

    // MARK: - Permission Checking

    /// Check all permission statuses
    @MainActor
    func checkAllPermissions() async {
        // Camera
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)

        // Photo Library
        photoLibraryPermission = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        // Notifications
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationPermission = settings.authorizationStatus
    }

    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermission = granted ? .authorized : .denied
        }
        return granted
    }

    /// Request photo library permission
    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photoLibraryPermission = status
        }
        return status == .authorized || status == .limited
    }

    /// Request notification permission
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                notificationPermission = granted ? .authorized : .denied
            }
            return granted
        } catch {
            await MainActor.run {
                notificationPermission = .denied
            }
            return false
        }
    }

    // MARK: - Permission Computed Properties

    /// Whether camera permission is granted
    var hasCameraPermission: Bool {
        cameraPermission == .authorized
    }

    /// Whether photo library permission is granted
    var hasPhotoLibraryPermission: Bool {
        photoLibraryPermission == .authorized || photoLibraryPermission == .limited
    }

    /// Whether notification permission is granted
    var hasNotificationPermission: Bool {
        notificationPermission == .authorized
    }

    /// Whether all required permissions are granted
    var hasAllRequiredPermissions: Bool {
        hasCameraPermission && hasPhotoLibraryPermission
    }

    // MARK: - Observers

    private func setupObservers() {
        // Listen for settings changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadPreferences()
            }
            .store(in: &cancellables)

        // Listen for app becoming active to refresh permissions
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAllPermissions()
                }
            }
            .store(in: &cancellables)
    }

    private func reloadPreferences() {
        let defaults = UserDefaults.standard
        hapticFeedbackEnabled = defaults.object(forKey: "captureHaptics") as? Bool ?? true
        autoSaveEnabled = defaults.object(forKey: "autoSave") as? Bool ?? true
    }
}

// MARK: - Photo Quality

/// Photo quality settings
enum PhotoQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"

    var displayName: String {
        switch self {
        case .low: return "Low (Fast)"
        case .medium: return "Medium"
        case .high: return "High"
        case .maximum: return "Maximum"
        }
    }

    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.85
        case .maximum: return 1.0
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AppState_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("App State Debug")
                .font(.headline)

            Group {
                StatusRow(label: "Camera", status: AppState.shared.hasCameraPermission)
                StatusRow(label: "Photos", status: AppState.shared.hasPhotoLibraryPermission)
                StatusRow(label: "Notifications", status: AppState.shared.hasNotificationPermission)
            }

            Divider()

            Group {
                Text("First Launch: \(AppState.shared.isFirstLaunch ? "Yes" : "No")")
                Text("Haptics: \(AppState.shared.hapticFeedbackEnabled ? "On" : "Off")")
                Text("Quality: \(AppState.shared.defaultPhotoQuality.displayName)")
            }
            .font(.caption)
        }
        .padding()
    }

    struct StatusRow: View {
        let label: String
        let status: Bool

        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(status ? .green : .red)
            }
        }
    }
}
#endif
