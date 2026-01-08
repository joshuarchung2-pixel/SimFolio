// DentalPortfolioApp.swift
// Dental Portfolio - App Entry Point
//
// Main entry point for the Dental Portfolio iOS application.
// Handles app configuration, appearance setup, and delegate assignments.
//
// Features:
// - App delegate for lifecycle events
// - Notification delegate for push notifications
// - Global appearance configuration
// - App state initialization

import SwiftUI
import UserNotifications

// MARK: - App Entry Point

@main
struct DentalPortfolioApp: App {
    // MARK: - App Delegate

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    @StateObject private var appState = AppState.shared

    // MARK: - Initialization

    init() {
        configureAppearance()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Save state before termination
                    appState.saveState()
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
        // Configure notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Register for remote notifications if authorized
        Task {
            await registerForRemoteNotificationsIfNeeded()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert token to string for debugging/logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
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

    // MARK: - URL Handling

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle custom URL schemes
        // URLs are also handled in ContentView via onOpenURL
        return true
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
        case "portfolio_reminder":
            // Navigate to portfolio
            if let portfolioId = userInfo["portfolioId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToPortfolio,
                    object: nil,
                    userInfo: ["portfolioId": portfolioId]
                )
            }

        case "capture_reminder":
            // Navigate to capture
            if let procedure = userInfo["procedure"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToCapture,
                    object: nil,
                    userInfo: ["procedure": procedure]
                )
            }

        case "deadline_warning":
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
}

// MARK: - Preview Provider

#if DEBUG
struct DentalPortfolioApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
