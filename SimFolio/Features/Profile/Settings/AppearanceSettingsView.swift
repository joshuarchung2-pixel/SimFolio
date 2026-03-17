// AppearanceSettingsView.swift
// SimFolio - Appearance Settings
//
// Allows users to select their preferred app appearance:
// - Dark mode (default)
// - Light mode
// - System (follows device settings)

import SwiftUI

// MARK: - AppearanceSettingsView

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        List {
            Section {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    AppearanceOptionRow(
                        appearance: appearance,
                        isSelected: themeManager.appearance == appearance,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.appearance = appearance
                            }
                        }
                    )
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how SimFolio looks. Dark mode is easier on the eyes in low-light environments.")
            }

            Section {
                // Preview of current appearance
                AppearancePreview()
            } header: {
                Text("Preview")
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(themeManager.appearance.colorScheme)
    }
}

// MARK: - AppearanceOptionRow

struct AppearanceOptionRow: View {
    let appearance: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconBackgroundColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: appearance.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(iconBackgroundColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(appearance.displayName)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(appearance.description)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconBackgroundColor: Color {
        switch appearance {
        case .dark:
            return .purple
        case .light:
            return .orange
        case .system:
            return AppTheme.Colors.primary
        }
    }
}

// MARK: - AppearancePreview

struct AppearancePreview: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Sample card
            HStack(spacing: AppTheme.Spacing.md) {
                // Sample avatar
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 18))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Card")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("This is how content will appear")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)

            // Sample buttons row
            HStack(spacing: AppTheme.Spacing.sm) {
                // Primary button sample
                Text("Primary")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.small)

                // Secondary button sample
                Text("Secondary")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)

                Spacer()
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surfaceSecondary)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Preview

#if DEBUG
struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppearanceSettingsView()
                .environmentObject(ThemeManager.shared)
        }
    }
}
#endif
