// PermissionDeniedView.swift
// Dental Portfolio - Permission Denied Views
//
// Views for displaying permission request states when access is denied.
// Provides clear messaging and easy access to Settings.
//
// Contents:
// - PermissionDeniedType: Enum for different permission types
// - PermissionDeniedView: Main permission denied display

import SwiftUI

// MARK: - Permission Denied Type

/// Types of permissions that can be denied
enum PermissionDeniedType {
    case camera
    case photos
    case notifications

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .photos: return "photo.fill.on.rectangle.fill"
        case .notifications: return "bell.slash.fill"
        }
    }

    var title: String {
        switch self {
        case .camera: return "Camera Access Required"
        case .photos: return "Photo Library Access Required"
        case .notifications: return "Notifications Disabled"
        }
    }

    var message: String {
        switch self {
        case .camera:
            return "Dental Portfolio needs camera access to capture your clinical photos. Please enable it in Settings."
        case .photos:
            return "Dental Portfolio needs access to your photo library to save and organize your photos. Please enable it in Settings."
        case .notifications:
            return "Enable notifications to receive due date reminders and progress updates."
        }
    }

    var iconColor: Color {
        switch self {
        case .camera: return .blue
        case .photos: return .purple
        case .notifications: return .red
        }
    }
}

// MARK: - PermissionDeniedView

/// View for displaying permission denied states with Settings link
struct PermissionDeniedView: View {
    let type: PermissionDeniedType
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Icon with slash overlay
            ZStack {
                Circle()
                    .fill(type.iconColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: type.icon)
                    .font(.system(size: 44))
                    .foregroundColor(type.iconColor)

                // Slash overlay
                Image(systemName: "slash.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppTheme.Colors.error)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.background)
                            .frame(width: 28, height: 28)
                    )
                    .offset(x: 30, y: 30)
            }

            // Text
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(type.title)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(type.message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            // Settings button
            DPButton(
                "Open Settings",
                icon: "gear",
                style: .primary,
                size: .large
            ) {
                HapticsManager.shared.lightTap()
                if let onOpenSettings = onOpenSettings {
                    onOpenSettings()
                } else {
                    openSettings()
                }
            }
            .padding(.top, AppTheme.Spacing.md)

            // Help text
            Text("You can change this anytime in your device settings.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }

    /// Open the app's settings page
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Compact Permission Banner

/// Compact banner for permission requests within content
struct PermissionBanner: View {
    let type: PermissionDeniedType
    var onRequestPermission: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(type.iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(type.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Tap to enable in Settings")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadowSmall()
        .onTapGesture {
            HapticsManager.shared.lightTap()
            if let onRequestPermission = onRequestPermission {
                onRequestPermission()
            } else {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PermissionDeniedView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Camera permission
            PermissionDeniedView(type: .camera)
                .previewDisplayName("Camera Permission")

            // Photos permission
            PermissionDeniedView(type: .photos)
                .previewDisplayName("Photos Permission")

            // Notifications permission
            PermissionDeniedView(type: .notifications)
                .previewDisplayName("Notifications Permission")

            // Permission banners
            VStack(spacing: AppTheme.Spacing.md) {
                PermissionBanner(type: .camera)
                PermissionBanner(type: .photos)
                PermissionBanner(type: .notifications)
            }
            .padding()
            .background(AppTheme.Colors.background)
            .previewDisplayName("Permission Banners")
        }
    }
}
#endif
