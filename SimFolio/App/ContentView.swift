// ContentView.swift
// SimFolio - Main App Container
//
// The root view of the app that manages tab-based navigation, global state,
// deep linking, and app lifecycle.
//
// Features:
// - Four-tab navigation with custom DPTabBar
// - App-wide state management with AppState
// - Deep link handling for portfolios and capture
// - Lifecycle management (foreground/background)
// - Global toast notification system
// - Onboarding flow integration

import SwiftUI
import Combine
import AVFoundation
import Photos

// Import edge case and error handling utilities

// MARK: - ContentView

struct ContentView: View {
    // MARK: - State Objects

    @StateObject private var router = NavigationRouter()
    @StateObject private var appState = AppState.shared
    @StateObject private var cameraService = CameraService()

    // MARK: - Observed Objects

    @ObservedObject private var photoLibrary = PhotoLibraryManager.shared
    @ObservedObject private var photoStorage = PhotoStorageService.shared
    @ObservedObject private var metadataManager = MetadataManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    // MARK: - Environment Objects

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    // MARK: - Local State

    @State private var showOnboarding: Bool = false
    @State private var isAppReady: Bool = false
    @State private var showGlobalToast: Bool = false
    @State private var globalToastMessage: String = ""
    @State private var globalToastType: DPToast.ToastType = .info
    @State private var showPostOnboardingPaywall: Bool = false
    @State private var previousTab: MainTab = .home
    @State private var showAppTour: Bool = false
    @State private var showFreeUnlockAnnouncement: Bool = false
    @State private var isMigrating: Bool = false
    @State private var migrationProgress: (Int, Int) = (0, 0)

    // MARK: - Persisted State

    @AppStorage("hasCompletedAppTour") private var hasCompletedAppTour = false
    @AppStorage("hasSeenFreeUnlockAnnouncement") private var hasSeenFreeUnlockAnnouncement = false

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Computed Properties

    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    private var isTabBarVisible: Bool {
        router.selectedTab != .capture && router.isTabBarVisible
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if isAppReady {
                mainAppContent
            } else if isMigrating {
                migrationProgressView
            } else {
                launchScreen
            }
        }
        .onAppear {
            initializeApp()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding) {
                onOnboardingComplete()
            }
        }
        .fullScreenCover(isPresented: $showFreeUnlockAnnouncement, onDismiss: {
            hasSeenFreeUnlockAnnouncement = true
        }) {
            FreeUnlockAnnouncementView()
        }
        .fullScreenCover(isPresented: $showPostOnboardingPaywall, onDismiss: {
            // After paywall dismisses, show tour if not completed
            if !hasCompletedAppTour {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAppTour = true
                }
            }
        }) {
            PaywallView(mode: .optional, highlightedFeature: nil)
        }
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(router.alertTitle, isPresented: $router.showAlert) {
            Button("OK") {
                router.alertPrimaryAction?()
            }
            if router.alertSecondaryAction != nil {
                Button("Cancel", role: .cancel) {
                    router.alertSecondaryAction?()
                }
            }
        } message: {
            Text(router.alertMessage)
        }
        .overlay(alignment: .top) {
            if showGlobalToast {
                DPToast(globalToastMessage, type: globalToastType)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation {
                            showGlobalToast = false
                        }
                    }
                    .zIndex(1000)
            }
        }
        .environmentObject(router)
        .environmentObject(appState)
        .environment(\.accessibilityManager, accessibilityManager)
        // Color scheme is now controlled at the App level by ThemeManager
        .withErrorHandling() // Add centralized error handling
        .onReceive(NotificationCenter.default.publisher(for: .showGlobalToast)) { notification in
            if let userInfo = notification.userInfo,
               let message = userInfo["message"] as? String {
                let typeString = userInfo["type"] as? String ?? "info"
                let type: DPToast.ToastType
                switch typeString {
                case "success": type = .success
                case "warning": type = .warning
                case "error": type = .error
                default: type = .info
                }
                showToast(type: type, message: message)
            }
        }
    }

    // MARK: - Main App Content

    @ViewBuilder
    private var mainAppContent: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar with animated visibility
            if isTabBarVisible {
                DPTabBar(selectedTab: $router.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // App tour overlay (above everything, including tab bar)
            if showAppTour {
                AppTourView(
                    isPresented: $showAppTour,
                    selectedTab: $router.selectedTab
                )
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTabBarVisible)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch router.selectedTab {
            case .home:
                NavigationView {
                    HomeView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .transition(.opacity)

            case .capture:
                CaptureFlowView(cameraService: cameraService)
                    .transition(.opacity)

            case .library:
                NavigationView {
                    LibraryView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .transition(.opacity)

            case .profile:
                NavigationView {
                    ProfileView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.selectedTab)
        .onChange(of: router.selectedTab) { newTab in
            // Manage camera lifecycle on tab switch
            if previousTab == .capture && newTab != .capture {
                cameraService.stopSession()
            }
            if newTab == .capture && previousTab != .capture {
                cameraService.startSession()
            }

            // Track screen views for analytics
            switch newTab {
            case .home:
                AnalyticsService.logScreenView("Home", screenClass: "HomeView")
            case .capture:
                AnalyticsService.logScreenView("Capture", screenClass: "CaptureFlowView")
                AnalyticsService.logEvent(.cameraOpened)
            case .library:
                AnalyticsService.logScreenView("Library", screenClass: "LibraryView")
                AnalyticsService.logEvent(.libraryOpened)
            case .profile:
                AnalyticsService.logScreenView("Profile", screenClass: "ProfileView")
            }

            previousTab = newTab
        }
    }

    // MARK: - Launch Screen

    private var launchScreen: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                // App icon
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)

                Text("SimFolio")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    .padding(.top, AppTheme.Spacing.md)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SimFolio loading")
    }

    // MARK: - Migration Progress View

    private var migrationProgressView: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("Updating Photo Storage")
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Moving your photos to secure app storage...")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                if migrationProgress.1 > 0 {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView(value: Double(migrationProgress.0), total: Double(migrationProgress.1))
                            .tint(AppTheme.Colors.primary)

                        Text("\(migrationProgress.0) of \(migrationProgress.1) photos")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                } else {
                    ProgressView()
                        .tint(AppTheme.Colors.primary)
                }
            }
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: NavigationRouter.SheetType) -> some View {
        switch sheet {
        case .settings:
            NavigationView {
                ProfileView()
            }

        case .photoDetail(let id):
            // Photo detail with ID lookup
            PhotoDetailSheet(
                photoId: id,
                allRecords: PhotoStorageService.shared.records,
                onDismiss: { router.dismissSheet() },
                onPhotoTagged: { _ in
                    router.dismissSheet()
                }
            )

        case .portfolioDetail(let id):
            // Portfolio detail with ID lookup
            if let portfolio = metadataManager.portfolios.first(where: { $0.id == id }) {
                PortfolioDetailView(portfolio: portfolio)
            }

        case .shareSheet(let photoIds):
            PhotoShareSheet(photoIds: photoIds)

        case .portfolioList:
            // Portfolio list/management view
            NavigationView {
                PortfolioListView()
            }

        case .notificationSettings:
            // Notification settings view
            NavigationView {
                NotificationSettingsView()
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Initialization

    private func initializeApp() {
        Task {
            // Load app data
            await loadAppData()

            // Check if photo migration is needed
            if PhotoMigrationService.needsMigration() {
                await MainActor.run {
                    isMigrating = true
                }

                let mapping = await PhotoMigrationService.migrate { completed, total in
                    Task { @MainActor in
                        migrationProgress = (completed, total)
                    }
                }

                // Remap metadata keys
                await MainActor.run {
                    MetadataManager.shared.remapMetadataKeys(mapping)
                    PhotoMigrationService.remapEditStates(using: mapping)
                    isMigrating = false
                }
            }

            // Check permissions
            await appState.checkAllPermissions()

            // Small delay for smooth transition
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Refresh subscription status silently
            await subscriptionManager.checkSubscriptionStatus()

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isAppReady = true
                }

                // Show onboarding if needed
                if !hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showOnboarding = true
                    }
                } else if FeatureGateService.allFeaturesUnlocked && !hasSeenFreeUnlockAnnouncement {
                    // One-time announcement for existing users that all features are now free
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFreeUnlockAnnouncement = true
                    }
                }
            }
        }
    }

    private func loadAppData() async {
        // Load procedure configs (data loads automatically on MetadataManager init)
        await safeExecuteAsync(context: "Loading procedures", fallback: ()) {
            metadataManager.loadProcedures()
        }

        // Fetch photo library assets
        await safeExecuteAsync(context: "Fetching photo library", fallback: ()) {
            photoLibrary.fetchAssets()
        }
    }

    // MARK: - Onboarding Complete

    private func onOnboardingComplete() {
        Task {
            await loadAppData()
            await subscriptionManager.checkSubscriptionStatus()
            showToast(type: .success, message: "Welcome to SimFolio!")
            AccessibilityManager.shared.announce("Onboarding complete. Welcome to SimFolio.")

            // Show post-onboarding paywall for non-subscribers (skip when all features unlocked)
            if !FeatureGateService.allFeaturesUnlocked && !subscriptionManager.isSubscribed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showPostOnboardingPaywall = true
                }
            } else if !hasCompletedAppTour {
                // Subscribed, or all features unlocked — go straight to tour
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showAppTour = true
                }
            }
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            onAppBecameActive()
        case .inactive:
            onAppBecameInactive()
        case .background:
            onAppEnteredBackground()
        @unknown default:
            break
        }
    }

    private func onAppBecameActive() {
        // Refresh photo library
        photoLibrary.fetchAssets()

        // Resume camera if on capture tab
        if router.selectedTab == .capture {
            cameraService.startSession()
        }

        // Check for permission changes
        Task {
            await appState.checkAllPermissions()
        }

        // Refresh subscription status silently (picks up external purchases, family sharing, delayed transactions)
        // Debounce: skip if we checked successfully within the last 10 seconds
        if let lastCheck = subscriptionManager.lastSuccessfulCheckDate,
           Date().timeIntervalSince(lastCheck) < 10 {
            return
        }

        Task {
            await subscriptionManager.checkSubscriptionStatus()
        }
    }

    private func onAppBecameInactive() {
        // Pause camera
        cameraService.stopSession()
    }

    private func onAppEnteredBackground() {
        // Save any pending data (procedures are auto-saved in MetadataManager)
        metadataManager.saveProcedures()
        appState.saveState()
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        let pathComponents = components.path.split(separator: "/").map(String.init)

        switch pathComponents.first {
        case "portfolio":
            if pathComponents.count > 1 {
                let portfolioId = pathComponents[1]
                router.navigateToPortfolio(id: portfolioId)
            }

        case "capture":
            // Parse query parameters for pre-fill
            if let queryItems = components.queryItems {
                var procedure: String?
                var stage: String?
                var angle: String?

                for item in queryItems {
                    switch item.name {
                    case "procedure": procedure = item.value
                    case "stage": stage = item.value
                    case "angle": angle = item.value
                    default: break
                    }
                }

                router.navigateToCapture(
                    procedure: procedure,
                    stage: stage,
                    angle: angle
                )
            } else {
                router.selectedTab = .capture
            }

        case "library":
            router.selectedTab = .library

        case "profile":
            router.selectedTab = .profile

        default:
            break
        }

        // Announce navigation for accessibility
        AccessibilityManager.shared.announceScreenChange()
    }

    // MARK: - Toast Helper

    func showToast(type: DPToast.ToastType, message: String, duration: Double = 3.0) {
        globalToastType = type
        globalToastMessage = message

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showGlobalToast = true
        }

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.2)) {
                showGlobalToast = false
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
