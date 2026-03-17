// AppVersion.swift
// SimFolio - App Version and Environment Information
//
// Provides centralized access to app version, build, and environment information.
// Useful for about screens, support info, and conditional behavior.

import Foundation
import UIKit

// MARK: - AppVersion

struct AppVersion {

    // MARK: - Version Info

    /// App version string (e.g., "1.0.0")
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Build number string (e.g., "1")
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Full version string (e.g., "1.0.0 (1)")
    static var fullVersion: String {
        "\(version) (\(build))"
    }

    /// Bundle identifier (e.g., "com.company.simfolio")
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.simfolio"
    }

    /// App display name
    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "SimFolio"
    }

    // MARK: - Environment Detection

    /// Whether the app is running in debug mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Whether the app is running from TestFlight
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }

    /// Whether the app is running from the App Store
    static var isAppStore: Bool {
        !isDebug && !isTestFlight
    }

    /// Current environment name
    static var environment: String {
        if isDebug { return "Development" }
        if isTestFlight { return "TestFlight" }
        return "App Store"
    }

    /// Environment color for UI display
    static var environmentColor: String {
        if isDebug { return "orange" }
        if isTestFlight { return "purple" }
        return "green"
    }

    // MARK: - Device Info

    /// Device model identifier (e.g., "iPhone14,2")
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// Friendly device name (e.g., "iPhone 14 Pro")
    static var deviceName: String {
        UIDevice.current.name
    }

    /// Device type (e.g., "iPhone")
    static var deviceType: String {
        UIDevice.current.model
    }

    /// OS version string (e.g., "iOS 17.0")
    static var osVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    /// Screen scale factor
    static var screenScale: CGFloat {
        UIScreen.main.scale
    }

    /// Screen size in points
    static var screenSize: CGSize {
        UIScreen.main.bounds.size
    }

    // MARK: - Support Info

    /// Formatted support information for bug reports
    static var supportInfo: String {
        """
        App: \(appName) \(fullVersion)
        Environment: \(environment)
        Device: \(deviceModel)
        OS: \(osVersion)
        Screen: \(Int(screenSize.width))x\(Int(screenSize.height)) @\(Int(screenScale))x
        """
    }

    /// Copyable support info for user support requests
    static var copyableSupportInfo: String {
        """
        --- Support Info ---
        App: \(appName)
        Version: \(fullVersion)
        Environment: \(environment)
        Device: \(deviceModel)
        OS: \(osVersion)
        Bundle ID: \(bundleIdentifier)
        --------------------
        """
    }

    // MARK: - Version Comparison

    /// Compare version strings (e.g., "1.0.0" < "1.1.0")
    static func isVersion(_ version: String, lessThan otherVersion: String) -> Bool {
        version.compare(otherVersion, options: .numeric) == .orderedAscending
    }

    /// Compare version strings (e.g., "1.0.0" > "0.9.0")
    static func isVersion(_ version: String, greaterThan otherVersion: String) -> Bool {
        version.compare(otherVersion, options: .numeric) == .orderedDescending
    }

    /// Check if current version is at least the specified version
    static func isCurrentVersionAtLeast(_ minimumVersion: String) -> Bool {
        !isVersion(version, lessThan: minimumVersion)
    }

    // MARK: - Feature Flags

    /// Whether to show debug UI elements
    static var showDebugUI: Bool {
        isDebug
    }

    /// Whether analytics should be enabled
    static var analyticsEnabled: Bool {
        !isDebug // Disable analytics in debug builds
    }

    /// Whether crash reporting should be enabled
    static var crashReportingEnabled: Bool {
        !isDebug // Disable crash reporting in debug builds
    }
}

// MARK: - Version History

extension AppVersion {

    /// Key for storing last run version in UserDefaults
    private static let lastRunVersionKey = "lastRunAppVersion"

    /// The version from the last time the app was run
    static var lastRunVersion: String? {
        UserDefaults.standard.string(forKey: lastRunVersionKey)
    }

    /// Whether this is a fresh install (no previous version)
    static var isFreshInstall: Bool {
        lastRunVersion == nil
    }

    /// Whether the app was updated since last run
    static var wasUpdated: Bool {
        guard let last = lastRunVersion else { return false }
        return isVersion(last, lessThan: version)
    }

    /// Save the current version as the last run version
    static func saveCurrentVersion() {
        UserDefaults.standard.set(version, forKey: lastRunVersionKey)
    }

    /// Get the update type if the app was updated
    static var updateType: UpdateType? {
        guard wasUpdated, let last = lastRunVersion else { return nil }

        let lastComponents = last.split(separator: ".").compactMap { Int($0) }
        let currentComponents = version.split(separator: ".").compactMap { Int($0) }

        // Safely access version components with bounds checking
        guard let lastMajor = lastComponents.first,
              let currentMajor = currentComponents.first else {
            return nil
        }

        // Get minor versions, defaulting to 0 if not present
        let lastMinor = lastComponents.count > 1 ? lastComponents[1] : 0
        let currentMinor = currentComponents.count > 1 ? currentComponents[1] : 0

        if currentMajor > lastMajor {
            return .major
        } else if currentMinor > lastMinor {
            return .minor
        } else {
            return .patch
        }
    }

    enum UpdateType {
        case major  // 1.0.0 -> 2.0.0
        case minor  // 1.0.0 -> 1.1.0
        case patch  // 1.0.0 -> 1.0.1

        var description: String {
            switch self {
            case .major: return "Major Update"
            case .minor: return "New Features"
            case .patch: return "Bug Fixes"
            }
        }
    }
}

// MARK: - App Store

extension AppVersion {

    /// App Store ID (set this to your actual App Store ID)
    static let appStoreId = "6758177870"

    /// App Store URL for reviews
    static var appStoreReviewURL: URL? {
        URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)?action=write-review")
    }

    /// App Store URL for the app page
    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)")
    }

    /// Open the App Store review page
    static func openAppStoreForReview() {
        guard let url = appStoreReviewURL else { return }
        UIApplication.shared.open(url)
    }

    /// Open the App Store page
    static func openAppStore() {
        guard let url = appStoreURL else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Logging

extension AppVersion {

    /// Log version info at app launch (for debugging)
    static func logVersionInfo() {
        #if DEBUG
        print("""

        ========================================
        \(appName) Launch Info
        ========================================
        Version: \(fullVersion)
        Environment: \(environment)
        Bundle ID: \(bundleIdentifier)
        Device: \(deviceModel)
        OS: \(osVersion)
        Fresh Install: \(isFreshInstall)
        Was Updated: \(wasUpdated)
        ========================================

        """)
        #endif
    }
}
