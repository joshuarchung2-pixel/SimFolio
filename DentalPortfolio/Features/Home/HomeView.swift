// HomeView.swift
// Dental Portfolio - Home Dashboard
//
// The main dashboard view - first screen users see after launch.
// Shows portfolio progress, quick capture buttons, and actionable items.
//
// Sections:
// 1. Quick Capture - Start capturing for each procedure
// 2. Active Portfolios - Horizontal scroll of portfolio cards with progress
// 3. Needs Attention - Missing photos or incomplete items
// 4. Recent Captures - Last photos taken

import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared
    @State private var greeting: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {

                    // 1. Quick Capture Section
                    QuickCaptureSection()

                    // 2. Active Portfolios Section (only if portfolios exist)
                    if !metadataManager.portfolios.isEmpty {
                        ActivePortfoliosSection()
                    }

                    // 3. Needs Attention Section (only if items exist)
                    NeedsAttentionSection()

                    // 4. Recent Captures Section (only if photos exist)
                    if !library.assets.isEmpty {
                        RecentCapturesSection()
                    }

                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        // Notification bell (future feature)
                        DPIconButton(icon: "bell", size: 36) {
                            // TODO: Show notifications
                        }

                        // Settings - navigate to profile
                        DPIconButton(icon: "gearshape", size: 36) {
                            router.selectedTab = .profile
                        }
                    }
                }
            }
            .onAppear {
                updateGreeting()
                library.fetchAssets()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            greeting = "Good morning"
        } else if hour < 17 {
            greeting = "Good afternoon"
        } else {
            greeting = "Good evening"
        }
    }
}

// MARK: - Quick Capture Section

/// Quick capture buttons for each procedure type
struct QuickCaptureSection: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Section header
            DPSectionHeader("Quick Capture", subtitle: "Tap a procedure to start")
                .padding(.horizontal, AppTheme.Spacing.md)

            // Horizontal scroll of procedure buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.procedures, id: \.self) { procedure in
                        QuickCaptureProcedureButton(
                            procedure: procedure,
                            color: AppTheme.procedureColor(for: procedure),
                            photoCount: metadataManager.photoCount(for: procedure)
                        ) {
                            router.navigateToCapture(procedure: procedure)
                        }
                    }

                    // Add new procedure button
                    AddProcedureButton {
                        // TODO: Show add procedure sheet
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Quick Capture Procedure Button

/// A button for quickly starting capture with a specific procedure
struct QuickCaptureProcedureButton: View {
    let procedure: String
    let color: Color
    let photoCount: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            VStack(spacing: AppTheme.Spacing.sm) {
                // Color circle with camera icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Procedure name
                Text(procedure)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                // Photo count
                Text("\(photoCount) photos")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 80)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEffect(isPressed: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Add Procedure Button

/// Button to add a new custom procedure
struct AddProcedureButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AppTheme.Colors.textTertiary,
                            style: StrokeStyle(lineWidth: 2, dash: [5])
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                Text("Add New")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                // Empty text for alignment
                Text(" ")
                    .font(AppTheme.Typography.caption2)
            }
            .frame(width: 80)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEffect(isPressed: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Active Portfolios Section

/// Horizontal scrolling list of active portfolios with progress
struct ActivePortfoliosSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Active Portfolios",
                actionTitle: "View All"
            ) {
                // Navigate to portfolios
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Placeholder content
            DPCard {
                Text("Active Portfolios Section")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Needs Attention Section

/// List of items that need attention (missing photos, incomplete metadata)
struct NeedsAttentionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader("Needs Attention")
                .padding(.horizontal, AppTheme.Spacing.md)

            // Placeholder content
            DPCard {
                Text("Needs Attention Section")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Recent Captures Section

/// Grid of recently captured photos
struct RecentCapturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Recent Captures",
                actionTitle: "See All"
            ) {
                // Navigate to library
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Placeholder content
            DPCard {
                Text("Recent Captures Section")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(NavigationRouter())
    }
}
#endif
