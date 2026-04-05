// AnalyticsService.swift
// SimFolio - Analytics and Crash Reporting
//
// Provides a centralized interface for Firebase Analytics and Crashlytics.
// Wraps Firebase APIs to allow easy tracking of user behavior and crash reporting.
//
// Usage:
// - Track events: AnalyticsService.logEvent(.portfolioCreated, parameters: ["name": portfolioName])
// - Set user properties: AnalyticsService.setUserProperty("student", forName: "user_type")
// - Log errors: AnalyticsService.logError(error, context: "photo_export")

import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// MARK: - Analytics Events

/// Predefined analytics events for SimFolio
enum AnalyticsEvent: String {
    // Onboarding
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"

    // Portfolio
    case portfolioCreated = "portfolio_created"
    case portfolioDeleted = "portfolio_deleted"
    case portfolioExported = "portfolio_exported"
    case portfolioViewed = "portfolio_viewed"

    // Photo
    case photoCaptured = "photo_captured"
    case photoTagged = "photo_tagged"
    case photoEdited = "photo_edited"
    case photoDeleted = "photo_deleted"
    case photoFavorited = "photo_favorited"

    // Requirement
    case requirementFulfilled = "requirement_fulfilled"
    case requirementAdded = "requirement_added"

    // Feature Usage
    case cameraOpened = "camera_opened"
    case libraryOpened = "library_opened"
    case filterApplied = "filter_applied"
    case searchPerformed = "search_performed"

    // Settings
    case settingsChanged = "settings_changed"
    case themeChanged = "theme_changed"
    case notificationsToggled = "notifications_toggled"

    // Subscription
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case subscriptionCancelled = "subscription_cancelled"

    // Premium
    case premiumFeatureGated = "premium_feature_gated"

    // App Tour
    case appTourCompleted = "app_tour_completed"
    case appTourSkipped = "app_tour_skipped"

    // Social Feed
    case feedViewed = "feed_viewed"
    case socialOptIn = "social_opt_in"

    // Errors
    case errorOccurred = "error_occurred"
}

// MARK: - User Properties

/// User properties for segmentation
enum AnalyticsUserProperty: String {
    case userType = "user_type"
    case schoolName = "school_name"
    case graduationYear = "graduation_year"
    case portfolioCount = "portfolio_count"
    case photoCount = "photo_count"
    case appTheme = "app_theme"
    case isPremium = "is_premium"
}

// MARK: - Analytics Service

/// Centralized analytics service for Firebase Analytics and Crashlytics
enum AnalyticsService {

    // MARK: - Configuration

    /// Whether analytics is enabled (can be controlled by user preference)
    private static var isEnabled: Bool {
        // Check if user has opted out of analytics
        !UserDefaults.standard.bool(forKey: "analyticsOptOut")
    }

    // MARK: - Event Logging

    /// Log an analytics event with optional parameters
    /// - Parameters:
    ///   - event: The predefined analytics event
    ///   - parameters: Optional dictionary of event parameters
    static func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: parameters)
        #endif

        #if DEBUG
        var debugMessage = "📊 Analytics: \(event.rawValue)"
        if let params = parameters {
            debugMessage += " - \(params)"
        }
        print(debugMessage)
        #endif
    }

    /// Log a custom event with a string name
    /// - Parameters:
    ///   - name: The event name (use snake_case)
    ///   - parameters: Optional dictionary of event parameters
    static func logCustomEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif

        #if DEBUG
        var debugMessage = "📊 Analytics (custom): \(name)"
        if let params = parameters {
            debugMessage += " - \(params)"
        }
        print(debugMessage)
        #endif
    }

    // MARK: - User Properties

    /// Set a user property for segmentation
    /// - Parameters:
    ///   - value: The property value (nil to clear)
    ///   - property: The predefined user property
    static func setUserProperty(_ value: String?, for property: AnalyticsUserProperty) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: property.rawValue)
        #endif

        #if DEBUG
        print("📊 User Property: \(property.rawValue) = \(value ?? "nil")")
        #endif
    }

    /// Set a custom user property
    /// - Parameters:
    ///   - value: The property value (nil to clear)
    ///   - name: The property name
    static func setCustomUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif

        #if DEBUG
        print("📊 User Property (custom): \(name) = \(value ?? "nil")")
        #endif
    }

    /// Set the user ID for analytics
    /// - Parameter userId: The user identifier (nil to clear)
    static func setUserId(_ userId: String?) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif

        #if DEBUG
        print("📊 User ID: \(userId ?? "nil")")
        #endif
    }

    // MARK: - Screen Tracking

    /// Log a screen view event
    /// - Parameters:
    ///   - screenName: The name of the screen
    ///   - screenClass: The class name of the screen (optional)
    static func logScreenView(_ screenName: String, screenClass: String? = nil) {
        guard isEnabled else { return }

        #if canImport(FirebaseAnalytics)
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]
        if let screenClass = screenClass {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
        #endif

        #if DEBUG
        print("📊 Screen View: \(screenName)")
        #endif
    }

    // MARK: - Error Logging (Crashlytics)

    /// Log an error to Crashlytics
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context about where the error occurred
    static func logError(_ error: Error, context: String? = nil) {
        #if canImport(FirebaseCrashlytics)
        if let context = context {
            Crashlytics.crashlytics().log("Context: \(context)")
        }
        Crashlytics.crashlytics().record(error: error)
        #endif

        #if DEBUG
        print("🔴 Error Logged: \(error.localizedDescription) - Context: \(context ?? "none")")
        #endif
    }

    /// Log a non-fatal issue with a custom message
    /// - Parameters:
    ///   - message: Description of the issue
    ///   - userInfo: Additional information dictionary
    static func logNonFatalIssue(_ message: String, userInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        let error = NSError(
            domain: "com.simfolio.nonfatal",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "additionalInfo": userInfo ?? [:]
            ]
        )
        Crashlytics.crashlytics().record(error: error)
        #endif

        #if DEBUG
        print("⚠️ Non-Fatal: \(message)")
        #endif
    }

    /// Add a breadcrumb log message to Crashlytics
    /// - Parameter message: The breadcrumb message
    static func addBreadcrumb(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif

        #if DEBUG
        print("🍞 Breadcrumb: \(message)")
        #endif
    }

    /// Set a custom key-value pair for crash reports
    /// - Parameters:
    ///   - key: The key name
    ///   - value: The value (String, Bool, Int, or Float)
    static func setCrashlyticsKey(_ key: String, value: Any) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }

    // MARK: - Opt-Out Management

    /// Enable or disable analytics collection
    /// - Parameter enabled: Whether analytics should be enabled
    static func setAnalyticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(!enabled, forKey: "analyticsOptOut")

        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        #endif
    }

    /// Check if analytics is currently enabled
    static var analyticsEnabled: Bool {
        isEnabled
    }
}

// MARK: - Convenience Extensions

extension AnalyticsService {

    /// Log portfolio creation with details
    static func logPortfolioCreated(name: String, requirementCount: Int, hasDueDate: Bool) {
        logEvent(.portfolioCreated, parameters: [
            "name": name,
            "requirement_count": requirementCount,
            "has_due_date": hasDueDate
        ])
    }

    /// Log photo capture with metadata
    static func logPhotoCaptured(procedure: String?, stage: String?, toothNumber: Int?) {
        var params: [String: Any] = [:]
        if let procedure = procedure {
            params["procedure"] = procedure
        }
        if let stage = stage {
            params["stage"] = stage
        }
        if let tooth = toothNumber {
            params["tooth_number"] = tooth
        }
        logEvent(.photoCaptured, parameters: params.isEmpty ? nil : params)
    }

    /// Log photo tagging
    static func logPhotoTagged(procedure: String, stage: String, angle: String, toothNumber: Int?) {
        var params: [String: Any] = [
            "procedure": procedure,
            "stage": stage,
            "angle": angle
        ]
        if let tooth = toothNumber {
            params["tooth_number"] = tooth
        }
        logEvent(.photoTagged, parameters: params)
    }

    /// Log photo editing completion
    static func logPhotoEdited(adjustmentsMade: [String]) {
        logEvent(.photoEdited, parameters: [
            "adjustments_made": adjustmentsMade.joined(separator: ","),
            "adjustment_count": adjustmentsMade.count
        ])
    }

    /// Log portfolio export
    static func logPortfolioExported(format: String, photoCount: Int) {
        logEvent(.portfolioExported, parameters: [
            "format": format,
            "photo_count": photoCount
        ])
    }

    /// Log requirement fulfilled
    static func logRequirementFulfilled(portfolioId: String, procedure: String, stage: String, angle: String) {
        logEvent(.requirementFulfilled, parameters: [
            "portfolio_id": portfolioId,
            "procedure": procedure,
            "stage": stage,
            "angle": angle
        ])
    }

    /// Log onboarding completion
    static func logOnboardingCompleted(durationSeconds: Int, schoolSelected: Bool) {
        logEvent(.onboardingCompleted, parameters: [
            "duration_seconds": durationSeconds,
            "school_selected": schoolSelected
        ])
    }

    /// Update user statistics properties
    static func updateUserStats(portfolioCount: Int, photoCount: Int, isPremium: Bool) {
        setUserProperty(String(portfolioCount), for: .portfolioCount)
        setUserProperty(String(photoCount), for: .photoCount)
        setUserProperty(isPremium ? "true" : "false", for: .isPremium)
    }
}

// MARK: - SwiftUI View Modifier for Screen Tracking

import SwiftUI

/// View modifier for automatic screen tracking
struct AnalyticsScreenViewModifier: ViewModifier {
    let screenName: String
    let screenClass: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsService.logScreenView(screenName, screenClass: screenClass)
            }
    }
}

extension View {
    /// Track screen view when this view appears
    /// - Parameters:
    ///   - screenName: The name to log for this screen
    ///   - screenClass: Optional class name
    /// - Returns: Modified view with screen tracking
    func trackScreen(_ screenName: String, screenClass: String? = nil) -> some View {
        modifier(AnalyticsScreenViewModifier(screenName: screenName, screenClass: screenClass))
    }
}
