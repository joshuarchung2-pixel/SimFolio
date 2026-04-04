// FreeUnlockAnnouncementView.swift
// SimFolio - One-time announcement that all features are now free
//
// Shown once to existing users on first launch after the update.

import SwiftUI

struct FreeUnlockAnnouncementView: View {
    @Environment(\.dismiss) var dismiss

    private let features: [(icon: String, title: String, color: Color)] = [
        ("infinity", "Unlimited Portfolios", .blue),
        ("slider.horizontal.3", "Advanced Photo Editing", .purple),
        ("pencil.tip.crop.circle", "Photo Annotations", .orange),
        ("square.and.arrow.up.fill", "Advanced Export", .green),
        ("bell.badge.fill", "Due Date Reminders", .red),
        ("plus.rectangle.on.folder", "Custom Procedures", .cyan),
        ("checkmark.circle.fill", "Batch Operations", .indigo),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Crown icon with celebration
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "crown.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, AppTheme.Spacing.lg)

            // Headline
            Text("Everything's Unlocked!")
                .font(AppTheme.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, AppTheme.Spacing.xs)

            Text("All premium features are now free for everyone.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xl)

            // Feature list
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(feature.color)
                            .frame(width: 28)

                        Text(feature.title)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.surfaceSecondary)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Text("Let's Go!")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }
}

#if DEBUG
struct FreeUnlockAnnouncementView_Previews: PreviewProvider {
    static var previews: some View {
        FreeUnlockAnnouncementView()
    }
}
#endif
