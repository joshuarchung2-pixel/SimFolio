// ThemeManager.swift
// SimFolio - Theme Management
//
// Manages app-wide theme state and preferences.
// Supports dark mode (default), light mode, and system appearance.

import SwiftUI
import Combine

// MARK: - App Appearance

/// Available appearance modes for the app
enum AppAppearance: String, CaseIterable {
    case dark = "dark"
    case light = "light"
    case system = "system"

    /// Display name for UI
    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }

    /// SF Symbol icon for the appearance mode
    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// Description text for the appearance mode
    var description: String {
        switch self {
        case .dark: return "Always use dark appearance"
        case .light: return "Always use light appearance"
        case .system: return "Match device settings"
        }
    }

    /// The SwiftUI color scheme for this appearance
    /// Returns nil for .system to let the system decide
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

// MARK: - Theme Manager

/// Observable theme manager for app-wide theme control
class ThemeManager: ObservableObject {
    /// Shared singleton instance
    static let shared = ThemeManager()

    /// Current appearance preference, persisted via UserDefaults
    /// Defaults to .dark (dark mode is the default)
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
            updateUIKitAppearance()
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved appearance preference, default to dark
        if let savedAppearance = UserDefaults.standard.string(forKey: "appAppearance"),
           let appearance = AppAppearance(rawValue: savedAppearance) {
            self.appearance = appearance
        } else {
            self.appearance = .dark
        }
    }

    // MARK: - UIKit Appearance

    /// Updates UIKit appearance settings when theme changes
    func updateUIKitAppearance() {
        DispatchQueue.main.async {
            // Determine if we're in dark mode
            let isDark: Bool
            switch self.appearance {
            case .dark:
                isDark = true
            case .light:
                isDark = false
            case .system:
                isDark = UITraitCollection.current.userInterfaceStyle == .dark
            }

            // Configure Navigation Bar
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithOpaqueBackground()
            navigationBarAppearance.backgroundColor = isDark ? UIColor(Color("Surface")) : UIColor(Color("Surface"))
            navigationBarAppearance.titleTextAttributes = [
                .foregroundColor: UIColor(Color("TextPrimary")),
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navigationBarAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor(Color("TextPrimary")),
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
            tabBarAppearance.backgroundColor = UIColor(Color("Surface"))
            tabBarAppearance.shadowColor = .clear

            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            UITabBar.appearance().tintColor = UIColor(AppTheme.Colors.primary)

            // Configure Table View
            UITableView.appearance().backgroundColor = UIColor(Color("Background"))
            UITableView.appearance().separatorColor = UIColor(Color("Divider"))

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
                .foregroundColor: UIColor(Color("TextPrimary"))
            ], for: .normal)

            // Configure Refresh Control
            UIRefreshControl.appearance().tintColor = UIColor(AppTheme.Colors.primary)
        }
    }
}
