// ContentView.swift
// Main container with tab navigation
//
// The root view of the app that manages tab-based navigation.
// Uses custom DPTabBar at bottom with four main tabs:
// - Home: Dashboard with quick actions and stats
// - Capture: Camera for photo capture
// - Library: Photo gallery and organization
// - Profile: Settings and user preferences

import SwiftUI
import AVFoundation

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var router = NavigationRouter()
    @StateObject private var sharedCameraService = CameraService()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch router.selectedTab {
                case .home:
                    HomeView()
                        .transition(.opacity)

                case .capture:
                    // Full capture flow (Phase 3)
                    CaptureFlowView(cameraService: sharedCameraService)
                        .transition(.opacity)

                case .library:
                    LibraryView()
                        .transition(.opacity)

                case .profile:
                    // Temporary placeholder until Phase 6
                    ProfileTabPlaceholder()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: router.selectedTab)

            // Custom tab bar (hide during capture)
            if router.selectedTab != .capture {
                DPTabBar(selectedTab: $router.selectedTab)
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.light)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Initialize photo library
            PhotoLibraryManager.shared.fetchAssets()
        }
    }
}

// MARK: - Capture Tab Placeholder

/// Temporary placeholder for the Capture tab (will be replaced in Phase 3)
private struct CaptureTabPlaceholder: View {
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                // Camera icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                }

                // Title
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Capture")
                        .font(AppTheme.Typography.title2)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Camera capture flow coming in Phase 3")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Show pre-filled values if any
                if let procedure = router.capturePrefilledProcedure {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("Pre-filled values:")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            DPTagPill(procedure, color: AppTheme.procedureColor(for: procedure))

                            if let stage = router.capturePrefilledStage {
                                DPTagPill(stage, color: AppTheme.Colors.secondary)
                            }

                            if let angle = router.capturePrefilledAngle {
                                DPTagPill(angle, color: AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.md)
                }

                Spacer()

                // Back to home button
                DPButton("Back to Home", style: .secondary) {
                    router.resetCaptureState()
                    router.selectedTab = .home
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, 100)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Library Tab Placeholder

/// Temporary placeholder for the Library tab (will be replaced in Phase 4)
private struct LibraryTabPlaceholder: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var library = PhotoLibraryManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                if library.assets.isEmpty {
                    // Empty state
                    Spacer()

                    DPEmptyState(
                        icon: "photo.on.rectangle",
                        title: "No Photos Yet",
                        message: "Start capturing dental photos to see them here"
                    ) {
                        DPButton("Start Capturing", icon: "camera.fill") {
                            router.selectedTab = .capture
                        }
                    }

                    Spacer()
                } else {
                    // Photo count info
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("\(library.assets.count)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text("photos in your library")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    Spacer()

                    // Placeholder message
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.Colors.textTertiary)

                        Text("Full library view coming in Phase 4")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 80)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Profile Tab Placeholder

/// Temporary placeholder for the Profile tab (will be replaced in Phase 6)
private struct ProfileTabPlaceholder: View {
    var body: some View {
        NavigationView {
            List {
                // App info section
                Section {
                    HStack(spacing: AppTheme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 60, height: 60)

                            Image(systemName: "tooth")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text("Dental Portfolio")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            Text("Version 2.0 (Redesign)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                }

                // Settings placeholder
                Section(header: Text("Settings")) {
                    SettingsRow(icon: "bell", title: "Notifications", subtitle: "Coming soon")
                    SettingsRow(icon: "camera", title: "Camera Settings", subtitle: "Coming soon")
                    SettingsRow(icon: "photo.on.rectangle", title: "Library Settings", subtitle: "Coming soon")
                }

                // Data section
                Section(header: Text("Data")) {
                    SettingsRow(icon: "square.and.arrow.up", title: "Export Data", subtitle: "Coming soon")
                    SettingsRow(icon: "trash", title: "Clear Data", subtitle: "Coming soon", isDestructive: true)
                }

                // About section
                Section(header: Text("About")) {
                    SettingsRow(icon: "info.circle", title: "About", subtitle: "Full profile view coming in Phase 6")
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Coming soon")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Settings Row Helper

/// A row for the settings list
private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
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
