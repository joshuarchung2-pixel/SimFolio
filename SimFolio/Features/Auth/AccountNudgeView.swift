// AccountNudgeView.swift
// SimFolio - One-time nudge for existing users to create a free account
//
// Shown 3+ days after onboarding to encourage account creation for data backup.

import SwiftUI

struct AccountNudgeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showSignIn = false

    private let benefits: [String] = [
        "Keep your data safe",
        "Never lose your photos or tags",
        "Restore your portfolio on a new device",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Shield/cloud icon with teal glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Colors.primary.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, AppTheme.Spacing.lg)

            // Headline
            Text("Back Up Your Portfolio")
                .font(AppTheme.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, AppTheme.Spacing.xs)

            Text("Create a free account to keep your data safe and never lose your work.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xl)

            // Benefit list
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                            .frame(width: 28)

                        Text(benefit)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Spacer()
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

            // Primary CTA
            Button {
                showSignIn = true
            } label: {
                Text("Create Free Account")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.accentDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            // Maybe Later text link
            Button {
                AnalyticsService.logEvent(.accountNudgeDismissed)
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .onAppear {
            AnalyticsService.logEvent(.accountNudgeShown)
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(context: .generic, onSignIn: {
                AnalyticsService.logEvent(.accountCreated, parameters: ["source": "nudge"])
                Task { try? await UserProfileService.shared.linkOnboardingData() }
                dismiss()
            })
        }
    }
}

#if DEBUG
struct AccountNudgeView_Previews: PreviewProvider {
    static var previews: some View {
        AccountNudgeView()
    }
}
#endif
