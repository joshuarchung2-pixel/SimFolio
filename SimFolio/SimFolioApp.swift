// SimFolioApp.swift
// SimFolio - App Entry Point
//
// Main entry point for the SimFolio iOS application.
// Handles app configuration, appearance setup, and delegate assignments.
//
// Features:
// - App delegate for lifecycle events
// - Notification delegate for push notifications
// - Global appearance configuration
// - App state initialization

import SwiftUI
import UserNotifications
import RevenueCat
import AppTrackingTransparency
import AdSupport
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// MARK: - App Entry Point

@main
struct SimFolioApp: App {
    // MARK: - App Delegate

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // MARK: - Initialization

    init() {
        // Handle UI testing launch arguments
        #if DEBUG
        handleTestingLaunchArguments()
        #endif

        configureAppearance()

        // Initialize theme-aware UIKit appearance
        ThemeManager.shared.updateUIKitAppearance()
    }

    // MARK: - Testing Support

    #if DEBUG
    private func handleTestingLaunchArguments() {
        let arguments = CommandLine.arguments

        // Disable animations for faster UI tests
        if arguments.contains("--uitesting") {
            UIView.setAnimationsEnabled(false)
        }

        // Reset onboarding state for testing onboarding flow
        if arguments.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }

        // Skip onboarding for tests that don't need it
        if arguments.contains("--skip-onboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }

        // Reset all app data for clean test state
        if arguments.contains("--reset-all-data") {
            MetadataManager.shared.resetAllData()
        }

        // Add sample data for testing with data
        if arguments.contains("--with-sample-data") {
            addSampleDataForTesting()
        }
    }

    private func addSampleDataForTesting() {
        let manager = MetadataManager.shared

        // Add sample portfolios
        let requirement1 = PortfolioRequirement(
            procedure: "Class 1",
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"]
        )

        let requirement2 = PortfolioRequirement(
            procedure: "Crown",
            stages: ["Preparation"],
            angles: ["Buccal/Facial", "Lingual"]
        )

        let portfolio1 = Portfolio(
            name: "Fall 2024 Portfolio",
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
            requirements: [requirement1, requirement2]
        )

        let portfolio2 = Portfolio(
            name: "Clinical Skills Assessment",
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            requirements: [requirement1]
        )

        manager.addPortfolio(portfolio1)
        manager.addPortfolio(portfolio2)

        // Add sample metadata
        for i in 0..<10 {
            var metadata = PhotoMetadata()
            metadata.procedure = ["Class 1", "Class 2", "Crown", "Veneer"][i % 4]
            metadata.stage = ["Preparation", "Restoration"][i % 2]
            metadata.angle = ["Occlusal/Incisal", "Buccal/Facial", "Lingual"][i % 3]
            metadata.toothNumber = (i % 32) + 1
            metadata.rating = (i % 5) + 1

            manager.assetMetadata["test-asset-\(i)"] = metadata
        }
    }
    #endif

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(themeManager.appearance.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Save state before termination
                    appState.saveState()
                }
                .onChange(of: themeManager.appearance) { _ in
                    // Update UIKit appearance when theme changes
                    themeManager.updateUIKitAppearance()
                }
        }
    }

    // MARK: - Appearance Configuration

    private func configureAppearance() {
        // Configure Navigation Bar
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        navigationBarAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.primary)

        // Configure Tab Bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        tabBarAppearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor(AppTheme.Colors.primary)

        // Configure Table View
        UITableView.appearance().backgroundColor = UIColor(AppTheme.Colors.background)
        UITableView.appearance().separatorColor = UIColor(AppTheme.Colors.divider)

        // Configure Text Field
        UITextField.appearance().tintColor = UIColor(AppTheme.Colors.primary)

        // Configure Text View
        UITextView.appearance().tintColor = UIColor(AppTheme.Colors.primary)

        // Configure Page Control
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppTheme.Colors.primary)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppTheme.Colors.primary.opacity(0.3))

        // Configure Switch
        UISwitch.appearance().onTintColor = UIColor(AppTheme.Colors.primary)

        // Configure Segmented Control
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppTheme.Colors.primary)
        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor.white
        ], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor(AppTheme.Colors.textPrimary)
        ], for: .normal)

        // Configure Refresh Control
        UIRefreshControl.appearance().tintColor = UIColor(AppTheme.Colors.primary)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase (Analytics + Crashlytics + Auth + Firestore + Storage)
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        // Configure Firestore settings
        #if canImport(FirebaseFirestore)
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = firestoreSettings
        #endif

        // Configure notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Register for remote notifications if authorized
        Task {
            await registerForRemoteNotificationsIfNeeded()
        }

        // Reschedule all due date reminders on app launch
        Task { @MainActor in
            await NotificationManager.shared.rescheduleAllReminders()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        // Convert token to string for debugging/logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Remote Notification Registration

    private func registerForRemoteNotificationsIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        if settings.authorizationStatus == .authorized {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        return configuration
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Shared singleton instance
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    // MARK: - Foreground Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification Response

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap based on type
        handleNotificationAction(userInfo: userInfo, actionIdentifier: response.actionIdentifier)

        completionHandler()
    }

    // MARK: - Notification Handling

    private func handleNotificationAction(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        // Parse notification type
        guard let notificationType = userInfo["type"] as? String else { return }

        switch notificationType {
        case "due_date_reminder":
            // Navigate to portfolio
            if let portfolioId = userInfo["portfolioId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToPortfolio,
                    object: nil,
                    userInfo: ["portfolioId": portfolioId]
                )
            }

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Navigate to a specific portfolio
    static let navigateToPortfolio = Notification.Name("navigateToPortfolio")

    /// Navigate to capture with optional parameters
    static let navigateToCapture = Notification.Name("navigateToCapture")

    /// Navigate to library
    static let navigateToLibrary = Notification.Name("navigateToLibrary")

    /// Show a global toast
    static let showGlobalToast = Notification.Name("showGlobalToast")

    /// Photo edit was saved (for refreshing thumbnails)
    static let photoEditSaved = Notification.Name("photoEditSaved")

    /// Photo favorite status changed (for refreshing thumbnail heart icons)
    static let photoFavoriteChanged = Notification.Name("photoFavoriteChanged")
}

// MARK: - Preview Provider

#if DEBUG
struct SimFolioApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
