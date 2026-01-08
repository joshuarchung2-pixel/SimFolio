// ErrorView.swift
// Dental Portfolio - Error State Views
//
// Reusable error display views with retry actions.
// Includes predefined error types for common scenarios.
//
// Contents:
// - ErrorView: Main error display view
// - Predefined error view factory methods

import SwiftUI

// MARK: - ErrorView

/// View for displaying error states with optional retry action
struct ErrorView: View {
    let icon: String
    let title: String
    let message: String
    var retryAction: (() -> Void)? = nil
    var secondaryAction: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil

    // MARK: - Initialization

    init(
        icon: String = "exclamationmark.triangle.fill",
        title: String = "Something Went Wrong",
        message: String = "An unexpected error occurred. Please try again.",
        retryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.retryAction = retryAction
        self.secondaryAction = secondaryAction
        self.secondaryActionTitle = secondaryActionTitle
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.error.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.Colors.error)
            }

            // Text
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            // Actions
            VStack(spacing: AppTheme.Spacing.sm) {
                if let retryAction = retryAction {
                    DPButton(
                        "Try Again",
                        icon: "arrow.clockwise",
                        style: .primary,
                        size: .large
                    ) {
                        HapticsManager.shared.lightTap()
                        retryAction()
                    }
                }

                if let secondaryAction = secondaryAction,
                   let secondaryTitle = secondaryActionTitle {
                    Button(action: {
                        HapticsManager.shared.lightTap()
                        secondaryAction()
                    }) {
                        Text(secondaryTitle)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .padding(.top, AppTheme.Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Predefined Error Views

extension ErrorView {
    /// Generic error with optional retry
    static func generic(retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            icon: "exclamationmark.triangle.fill",
            title: "Something Went Wrong",
            message: "An unexpected error occurred. Please try again.",
            retryAction: retryAction
        )
    }

    /// Network/connectivity error
    static func network(retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            icon: "wifi.slash",
            title: "No Connection",
            message: "Please check your internet connection and try again.",
            retryAction: retryAction
        )
    }

    /// Content not found error
    static func notFound() -> ErrorView {
        ErrorView(
            icon: "questionmark.folder.fill",
            title: "Not Found",
            message: "The content you're looking for doesn't exist or has been removed."
        )
    }

    /// Request timeout error
    static func timeout(retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            icon: "clock.badge.exclamationmark.fill",
            title: "Request Timed Out",
            message: "The request took too long. Please try again.",
            retryAction: retryAction
        )
    }

    /// Storage/disk space error
    static func storage() -> ErrorView {
        ErrorView(
            icon: "externaldrive.badge.exclamationmark",
            title: "Storage Full",
            message: "Your device doesn't have enough storage space. Free up some space and try again."
        )
    }

    /// Photo save error
    static func photoSave(retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            icon: "photo.badge.exclamationmark.fill",
            title: "Couldn't Save Photo",
            message: "There was a problem saving your photo. Please try again.",
            retryAction: retryAction
        )
    }

    /// Export error
    static func export(retryAction: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            icon: "square.and.arrow.up.trianglebadge.exclamationmark",
            title: "Export Failed",
            message: "There was a problem exporting your portfolio. Please try again.",
            retryAction: retryAction
        )
    }
}

// MARK: - Inline Error Banner

/// Compact error banner for inline display
struct ErrorBanner: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.Colors.error)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            Spacer()

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }

            if let dismissAction = dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.error.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Generic error
            ErrorView.generic {
                print("Retry tapped")
            }
            .previewDisplayName("Generic Error")

            // Network error
            ErrorView.network {
                print("Retry tapped")
            }
            .previewDisplayName("Network Error")

            // Not found
            ErrorView.notFound()
                .previewDisplayName("Not Found")

            // Error banner
            VStack {
                ErrorBanner(
                    message: "Failed to load photos",
                    retryAction: { },
                    dismissAction: { }
                )
                .padding()

                Spacer()
            }
            .background(AppTheme.Colors.background)
            .previewDisplayName("Error Banner")
        }
    }
}
#endif
