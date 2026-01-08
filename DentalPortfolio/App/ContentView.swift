// ContentView.swift
// Dental Portfolio - Main App Container
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

    // MARK: - Local State

    @State private var showOnboarding: Bool = false
    @State private var isAppReady: Bool = false
    @State private var showGlobalToast: Bool = false
    @State private var globalToastMessage: String = ""
    @State private var globalToastType: DPToast.ToastType = .info

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
        .preferredColorScheme(.light)
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
    }

    // MARK: - Launch Screen

    private var launchScreen: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 20, x: 0, y: 10)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }

                Text("Dental Portfolio")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    .padding(.top, AppTheme.Spacing.md)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dental Portfolio loading")
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: NavigationRouter.SheetType) -> some View {
        switch sheet {
        case .settings:
            NavigationView {
                ProfileView()
            }

        case .filterPicker:
            // Filter picker would go here
            Text("Filter Picker")

        case .photoDetail(let id):
            // Photo detail with ID lookup
            if let asset = photoLibrary.assets.first(where: { $0.localIdentifier == id }) {
                PhotoDetailSheet(asset: asset)
            }

        case .portfolioDetail(let id):
            // Portfolio detail with ID lookup
            if let portfolio = metadataManager.portfolios.first(where: { $0.id == id }) {
                PortfolioDetailView(portfolio: portfolio)
            }

        case .tagEditor(let photoId):
            // Tag editor for specific photo
            Text("Tag Editor for \(photoId)")

        case .shareSheet(let photoIds):
            // Share sheet for photos
            Text("Share \(photoIds.count) photos")
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

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isAppReady = true
                }

                // Show onboarding if needed
                if !hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showOnboarding = true
                    }
                }
            }
        }
    }

    private func loadAppData() async {
        // Load metadata
        metadataManager.loadMetadata()
        metadataManager.loadPortfolios()
        metadataManager.loadProcedures()

        // Fetch photo library assets
        photoLibrary.fetchAssets()
    }

    // MARK: - Onboarding Complete

    private func onOnboardingComplete() {
        // Refresh data after permissions granted
        Task {
            await loadAppData()
        }

        // Show welcome toast
        showToast(type: .success, message: "Welcome to Dental Portfolio!")

        // Announce for accessibility
        AccessibilityManager.shared.announce("Onboarding complete. Welcome to Dental Portfolio.")
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
    }

    private func onAppBecameInactive() {
        // Pause camera
        cameraService.stopSession()
    }

    private func onAppEnteredBackground() {
        // Save any pending data
        metadataManager.saveMetadata()
        metadataManager.savePortfolios()
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

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                // Photo would be displayed here
                Text("Photo Detail")
                    .font(AppTheme.Typography.title2)
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
