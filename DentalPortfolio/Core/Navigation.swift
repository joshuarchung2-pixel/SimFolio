// Navigation.swift
// Dental Portfolio - Tab Management and Routing
//
// This file contains navigation infrastructure for the app.
// All navigation state is centralized in NavigationRouter for easy access.
//
// Contents:
// - MainTab: Tab enumeration with icons and titles
// - DPTabBar: Custom styled tab bar component
// - LibraryFilter: Filter state for library view
// - NavigationRouter: Central navigation state manager (ObservableObject)

import SwiftUI

// MARK: - MainTab

/// Enumeration of main app tabs
enum MainTab: Int, CaseIterable, Identifiable {
    case home = 0
    case capture = 1
    case library = 2
    case profile = 3

    var id: Int { rawValue }

    /// Display title for the tab
    var title: String {
        switch self {
        case .home: return "Home"
        case .capture: return "Capture"
        case .library: return "Library"
        case .profile: return "Profile"
        }
    }

    /// SF Symbol name for unselected state
    var icon: String {
        switch self {
        case .home: return "house"
        case .capture: return "camera"
        case .library: return "photo.on.rectangle"
        case .profile: return "person"
        }
    }

    /// SF Symbol name for selected state (filled variant)
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .capture: return "camera.fill"
        case .library: return "photo.on.rectangle.fill"
        case .profile: return "person.fill"
        }
    }

    /// Accessibility hint when not selected
    var accessibilityHint: String {
        "Double tap to switch to \(title)"
    }
}

/// Type alias for use with AccessibilityLabels
typealias Tab = MainTab

// MARK: - DPTabBar

/// Custom styled tab bar for main navigation
struct DPTabBar: View {
    @Binding var selectedTab: MainTab
    var badgeCounts: [MainTab: Int] = [:]

    @State private var pressedTab: MainTab?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabItem(for: tab)
            }
        }
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, bottomPadding)
        .background(
            AppTheme.Colors.surface
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
        )
    }

    @ViewBuilder
    private func tabItem(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        let isPressed = pressedTab == tab
        let badgeCount = badgeCounts[tab] ?? 0

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
            HapticsManager.shared.selectionChanged()
        } label: {
            VStack(spacing: AppTheme.Spacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 28, height: 28)

                    // Badge
                    if badgeCount > 0 {
                        badgeView(count: badgeCount)
                            .offset(x: 8, y: -4)
                            .accessibilityHidden(true)
                    }
                }

                Text(tab.title)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Minimum touch target
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(TabButtonStyle(isPressed: $pressedTab, tab: tab))
        // Accessibility
        .accessibilityLabel(tabAccessibilityLabel(tab: tab, badgeCount: badgeCount))
        .accessibilityHint(isSelected ? "Currently selected" : tab.accessibilityHint)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Generate accessibility label for tab
    private func tabAccessibilityLabel(tab: MainTab, badgeCount: Int) -> String {
        var label = tab.title
        if badgeCount > 0 {
            label += ", \(badgeCount) notification\(badgeCount == 1 ? "" : "s")"
        }
        return label
    }

    @ViewBuilder
    private func badgeView(count: Int) -> some View {
        let displayText = count > 99 ? "99+" : "\(count)"

        Text(displayText)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(AppTheme.Colors.error)
            .clipShape(Capsule())
            .minimumScaleFactor(0.8)
    }

    /// Calculate bottom padding including safe area
    private var bottomPadding: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        let safeAreaBottom = window?.safeAreaInsets.bottom ?? 0
        return max(safeAreaBottom, AppTheme.Spacing.sm)
    }
}

/// Button style for tab items to track press state
private struct TabButtonStyle: ButtonStyle {
    @Binding var isPressed: MainTab?
    let tab: MainTab

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue ? tab : nil
            }
    }
}

// MARK: - LibraryFilter

/// Filter configuration for the library view
struct LibraryFilter: Equatable {
    /// Selected procedure types (empty = all)
    var procedures: Set<String> = []

    /// Selected stages (empty = all)
    var stages: Set<String> = []

    /// Selected angles (empty = all)
    var angles: Set<String> = []

    /// Minimum star rating filter
    var minimumRating: Int?

    /// Date range filter
    var dateRange: DateRange?

    /// Filter to specific portfolio
    var portfolioId: String?

    /// Date range options
    enum DateRange: Equatable {
        case lastWeek
        case lastMonth
        case last3Months
        case lastYear
        case custom(start: Date, end: Date)

        var displayName: String {
            switch self {
            case .lastWeek: return "Last Week"
            case .lastMonth: return "Last Month"
            case .last3Months: return "Last 3 Months"
            case .lastYear: return "Last Year"
            case .custom: return "Custom Range"
            }
        }

        /// Get the date range as start and end dates
        var dates: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .lastWeek:
                let start = calendar.date(byAdding: .day, value: -7, to: now)!
                return (start, now)
            case .lastMonth:
                let start = calendar.date(byAdding: .month, value: -1, to: now)!
                return (start, now)
            case .last3Months:
                let start = calendar.date(byAdding: .month, value: -3, to: now)!
                return (start, now)
            case .lastYear:
                let start = calendar.date(byAdding: .year, value: -1, to: now)!
                return (start, now)
            case .custom(let start, let end):
                return (start, end)
            }
        }
    }

    /// Check if no filters are active
    var isEmpty: Bool {
        procedures.isEmpty &&
        stages.isEmpty &&
        angles.isEmpty &&
        minimumRating == nil &&
        dateRange == nil &&
        portfolioId == nil
    }

    /// Count of active filters
    var activeFilterCount: Int {
        var count = 0
        if !procedures.isEmpty { count += 1 }
        if !stages.isEmpty { count += 1 }
        if !angles.isEmpty { count += 1 }
        if minimumRating != nil { count += 1 }
        if dateRange != nil { count += 1 }
        if portfolioId != nil { count += 1 }
        return count
    }

    /// Reset all filters to default
    mutating func reset() {
        procedures = []
        stages = []
        angles = []
        minimumRating = nil
        dateRange = nil
        portfolioId = nil
    }
}

// MARK: - NavigationRouter

/// Central navigation state manager for the app
/// Use as @EnvironmentObject throughout the app for consistent navigation
class NavigationRouter: ObservableObject {
    // MARK: - Tab State

    /// Currently selected tab
    @Published var selectedTab: MainTab = .home

    // MARK: - Capture Flow State

    /// Whether capture flow is actively presenting
    @Published var captureFlowActive: Bool = false

    /// Pre-filled procedure for capture
    @Published var capturePrefilledProcedure: String?

    /// Pre-filled stage for capture
    @Published var capturePrefilledStage: String?

    /// Pre-filled angle for capture
    @Published var capturePrefilledAngle: String?

    /// Pre-filled tooth number for capture
    @Published var capturePrefilledToothNumber: Int?

    /// Portfolio ID to add captured photo to
    @Published var captureFromPortfolioId: String?

    // MARK: - Library State

    /// Current library filter configuration
    @Published var libraryFilter: LibraryFilter = LibraryFilter()

    // MARK: - Portfolio State

    /// Currently selected portfolio ID for detail view
    @Published var selectedPortfolioId: String?

    // MARK: - Sheet State

    /// Currently presented sheet type
    @Published var activeSheet: SheetType?

    /// Sheet types that can be presented
    enum SheetType: Identifiable, Equatable {
        case settings
        case filterPicker
        case photoDetail(id: String)
        case portfolioDetail(id: String)
        case tagEditor(photoId: String)
        case shareSheet(photoIds: [String])

        var id: String {
            switch self {
            case .settings: return "settings"
            case .filterPicker: return "filterPicker"
            case .photoDetail(let id): return "photoDetail-\(id)"
            case .portfolioDetail(let id): return "portfolioDetail-\(id)"
            case .tagEditor(let id): return "tagEditor-\(id)"
            case .shareSheet(let ids): return "shareSheet-\(ids.joined())"
            }
        }
    }

    // MARK: - Navigation Methods

    /// Navigate to the home tab
    func navigateToHome() {
        selectedTab = .home
    }

    /// Navigate to capture with optional pre-filled values
    /// - Parameters:
    ///   - procedure: Pre-fill procedure type
    ///   - stage: Pre-fill stage
    ///   - angle: Pre-fill angle
    ///   - toothNumber: Pre-fill tooth number
    ///   - forPortfolioId: Add to specific portfolio after capture
    func navigateToCapture(
        procedure: String? = nil,
        stage: String? = nil,
        angle: String? = nil,
        toothNumber: Int? = nil,
        forPortfolioId: String? = nil
    ) {
        // Set pre-filled values
        capturePrefilledProcedure = procedure
        capturePrefilledStage = stage
        capturePrefilledAngle = angle
        capturePrefilledToothNumber = toothNumber
        captureFromPortfolioId = forPortfolioId

        // Navigate to capture tab and activate flow
        selectedTab = .capture
        captureFlowActive = true
    }

    /// Navigate to library with optional filter
    /// - Parameter filter: Filter to apply (nil = keep current filter)
    func navigateToLibrary(filter: LibraryFilter? = nil) {
        if let filter = filter {
            libraryFilter = filter
        }
        selectedTab = .library
    }

    /// Navigate to portfolio detail
    /// - Parameter id: Portfolio ID to view
    func navigateToPortfolio(id: String) {
        selectedPortfolioId = id
        activeSheet = .portfolioDetail(id: id)
    }

    /// Navigate to photo detail
    /// - Parameter id: Photo ID to view
    func navigateToPhotoDetail(id: String) {
        activeSheet = .photoDetail(id: id)
    }

    /// Reset capture flow state
    func resetCaptureState() {
        captureFlowActive = false
        capturePrefilledProcedure = nil
        capturePrefilledStage = nil
        capturePrefilledAngle = nil
        capturePrefilledToothNumber = nil
        captureFromPortfolioId = nil
    }

    /// Present a sheet
    /// - Parameter sheet: Sheet type to present
    func presentSheet(_ sheet: SheetType) {
        activeSheet = sheet
    }

    /// Dismiss the current sheet
    func dismissSheet() {
        activeSheet = nil
    }

    /// Reset all navigation state
    func resetAll() {
        selectedTab = .home
        resetCaptureState()
        libraryFilter.reset()
        selectedPortfolioId = nil
        activeSheet = nil
    }
}

// MARK: - Environment Key

/// Environment key for NavigationRouter
private struct NavigationRouterKey: EnvironmentKey {
    static let defaultValue: NavigationRouter = NavigationRouter()
}

extension EnvironmentValues {
    /// Access the NavigationRouter from the environment
    var navigationRouter: NavigationRouter {
        get { self[NavigationRouterKey.self] }
        set { self[NavigationRouterKey.self] = newValue }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct Navigation_Previews: PreviewProvider {
    static var previews: some View {
        NavigationPreviewContainer()
    }
}

struct NavigationPreviewContainer: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        VStack {
            Spacer()

            // Content area
            VStack(spacing: AppTheme.Spacing.md) {
                Text("Selected Tab: \(selectedTab.title)")
                    .font(AppTheme.Typography.title2)

                Image(systemName: selectedTab.selectedIcon)
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar
            DPTabBar(
                selectedTab: $selectedTab,
                badgeCounts: [.library: 3, .profile: 12]
            )
        }
        .background(AppTheme.Colors.background)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct LibraryFilterPreview: View {
    @State private var filter = LibraryFilter()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("LibraryFilter Demo")
                .font(AppTheme.Typography.title3)

            Text("Active filters: \(filter.activeFilterCount)")
                .font(AppTheme.Typography.body)

            Text("Is empty: \(filter.isEmpty ? "Yes" : "No")")
                .font(AppTheme.Typography.body)

            HStack(spacing: AppTheme.Spacing.sm) {
                DPButton("Add Procedure", size: .small) {
                    filter.procedures.insert("Class I")
                }
                DPButton("Add Rating", size: .small) {
                    filter.minimumRating = 4
                }
                DPButton("Reset", style: .secondary, size: .small) {
                    filter.reset()
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
    }
}

struct LibraryFilterPreview_Previews: PreviewProvider {
    static var previews: some View {
        LibraryFilterPreview()
    }
}
#endif
