// EmptyStateView.swift
// Dental Portfolio - Empty State Views
//
// Reusable empty state displays for when content is not available.
// Includes predefined empty states for common scenarios.
//
// Contents:
// - EmptyStateView: Main empty state display
// - Predefined empty state factory methods

import SwiftUI

// MARK: - EmptyStateView

/// View for displaying empty content states with optional action
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var iconColor: Color = AppTheme.Colors.textTertiary

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(iconColor.opacity(0.6))
            }

            // Text
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            // Action button
            if let actionTitle = actionTitle, let action = action {
                DPButton(
                    actionTitle,
                    style: .primary,
                    size: .medium
                ) {
                    HapticsManager.shared.lightTap()
                    action()
                }
                .padding(.top, AppTheme.Spacing.md)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    /// No photos empty state
    static func noPhotos(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "photo.on.rectangle.angled",
            title: "No Photos Yet",
            message: "Start capturing your clinical work to see photos here.",
            actionTitle: action != nil ? "Capture Photo" : nil,
            action: action,
            iconColor: AppTheme.Colors.primary
        )
    }

    /// No portfolios empty state
    static func noPortfolios(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "folder.badge.plus",
            title: "No Portfolios",
            message: "Create a portfolio to start tracking your requirements.",
            actionTitle: action != nil ? "Create Portfolio" : nil,
            action: action,
            iconColor: .orange
        )
    }

    /// No search results empty state
    static func noResults() -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No photos match your current filters. Try adjusting your search.",
            iconColor: AppTheme.Colors.textSecondary
        )
    }

    /// No tagged photos empty state
    static func noTags() -> EmptyStateView {
        EmptyStateView(
            icon: "tag.slash",
            title: "No Tagged Photos",
            message: "Photos you tag will appear here for easy organization.",
            iconColor: .purple
        )
    }

    /// No favorites empty state
    static func noFavorites() -> EmptyStateView {
        EmptyStateView(
            icon: "star.slash",
            title: "No Favorites",
            message: "Mark photos as favorites to quickly find your best work.",
            iconColor: .yellow
        )
    }

    /// No recent activity empty state
    static func noRecent() -> EmptyStateView {
        EmptyStateView(
            icon: "clock",
            title: "No Recent Activity",
            message: "Your recent photos and activity will appear here.",
            iconColor: AppTheme.Colors.textSecondary
        )
    }

    /// No procedures of type empty state
    static func noProcedures(procedureType: String, action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "tooth",
            title: "No \(procedureType) Photos",
            message: "You haven't captured any \(procedureType.lowercased()) photos yet.",
            actionTitle: action != nil ? "Capture Now" : nil,
            action: action,
            iconColor: AppTheme.procedureColor(for: procedureType)
        )
    }

    /// Portfolio requirements complete empty state
    static func requirementsComplete() -> EmptyStateView {
        EmptyStateView(
            icon: "checkmark.seal.fill",
            title: "All Done!",
            message: "You've completed all requirements for this portfolio.",
            iconColor: AppTheme.Colors.success
        )
    }

    /// No notifications empty state
    static func noNotifications() -> EmptyStateView {
        EmptyStateView(
            icon: "bell.slash",
            title: "No Notifications",
            message: "You're all caught up! Notifications will appear here.",
            iconColor: AppTheme.Colors.textSecondary
        )
    }
}

// MARK: - Compact Empty State

/// Smaller empty state for inline use within cards or sections
struct CompactEmptyState: View {
    let icon: String
    let message: String
    var iconColor: Color = AppTheme.Colors.textTertiary

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor.opacity(0.5))

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // No photos
            EmptyStateView.noPhotos {
                print("Capture tapped")
            }
            .previewDisplayName("No Photos")

            // No portfolios
            EmptyStateView.noPortfolios {
                print("Create tapped")
            }
            .previewDisplayName("No Portfolios")

            // No results
            EmptyStateView.noResults()
                .previewDisplayName("No Results")

            // No favorites
            EmptyStateView.noFavorites()
                .previewDisplayName("No Favorites")

            // Requirements complete
            EmptyStateView.requirementsComplete()
                .previewDisplayName("Requirements Complete")

            // Compact empty state
            DPCard {
                CompactEmptyState(
                    icon: "photo.on.rectangle",
                    message: "No photos in this category"
                )
            }
            .padding()
            .background(AppTheme.Colors.background)
            .previewDisplayName("Compact Empty State")
        }
    }
}
#endif
