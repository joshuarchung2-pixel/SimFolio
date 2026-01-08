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
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader("Quick Capture")
                .padding(.horizontal, AppTheme.Spacing.md)

            // Placeholder content
            DPCard {
                Text("Quick Capture Section")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
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
