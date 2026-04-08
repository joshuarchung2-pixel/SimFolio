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
    @State private var showAccountNudge: Bool = false

    // MARK: - Persisted State

    @AppStorage("hasCompletedAppTour") private var hasCompletedAppTour = false
    @AppStorage("hasSeenFreeUnlockAnnouncement") private var hasSeenFreeUnlockAnnouncement = false
    @AppStorage("hasSeenAccountNudge") private var hasSeenAccountNudge = false

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Computed Properties

    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if isAppReady {
                mainAppContent
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
        .fullScreenCover(isPresented: $showAccountNudge, onDismiss: {
            hasSeenAccountNudge = true
        }) {
            AccountNudgeView()
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
        ZStack {
            TabView(selection: $router.selectedTab) {
                NavigationView {
                    HomeView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("Home", systemImage: router.selectedTab == .home ? "house.fill" : "house")
                }
                .tag(MainTab.home)

                CaptureFlowView(cameraService: cameraService)
                    .tabItem {
                        Label("Capture", systemImage: router.selectedTab == .capture ? "camera.fill" : "camera")
                    }
                    .tag(MainTab.capture)

                NavigationView {
                    LibraryView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("Library", systemImage: router.selectedTab == .library ? "photo.on.rectangle.fill" : "photo.on.rectangle")
                }
                .tag(MainTab.library)

                if FeatureGateService.socialFeedEnabled {
                    NavigationView {
                        SocialFeedView()
                    }
                    .navigationViewStyle(.stack)
                    .tabItem {
                        Label("Feed", systemImage: router.selectedTab == .feed ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.and.text.bubble.right")
                    }
                    .tag(MainTab.feed)
                }

                NavigationView {
                    ProfileView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("Profile", systemImage: router.selectedTab == .profile ? "person.fill" : "person")
                }
                .tag(MainTab.profile)
            }
            .tint(AppTheme.Colors.primary)
            .onChange(of: router.selectedTab) { newTab in
                if previousTab == .capture && newTab != .capture {
                    cameraService.stopSession()
                }
                if newTab == .capture && previousTab != .capture {
                    cameraService.startSession()
                }
                switch newTab {
                case .home:
                    AnalyticsService.logScreenView("Home", screenClass: "HomeView")
                case .capture:
                    AnalyticsService.logScreenView("Capture", screenClass: "CaptureFlowView")
                    AnalyticsService.logEvent(.cameraOpened)
                case .library:
                    AnalyticsService.logScreenView("Library", screenClass: "LibraryView")
                    AnalyticsService.logEvent(.libraryOpened)
                case .feed:
                    AnalyticsService.logScreenView("Social Feed", screenClass: "SocialFeedView")
                case .profile:
                    AnalyticsService.logScreenView("Profile", screenClass: "ProfileView")
                }
                previousTab = newTab
            }

            if showAppTour {
                AppTourView(
                    isPresented: $showAppTour,
                    selectedTab: $router.selectedTab
                )
                .transition(.opacity)
                .zIndex(999)
            }
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
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl))
                    .shadow(color: .black.opacity(AppTheme.Opacity.light), radius: 20, x: 0, y: 10)

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
                allAssets: photoLibrary.assets,
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

        case .signIn:
            SignInView()
        }
    }

    // MARK: - Initialization

    private func initializeApp() {
        Task {
            // Load app data
            await loadAppData()

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
                } else if !hasSeenAccountNudge
                    && AuthenticationService.shared.authState == .signedOut {
                    // Show account nudge 3+ days after onboarding
                    let createdDate = UserDefaults.standard.object(forKey: "userCreatedDate") as? Date ?? Date()
                    let daysSinceOnboarding = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
                    if daysSinceOnboarding >= 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showAccountNudge = true
                        }
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
