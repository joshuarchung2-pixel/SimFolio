// SubscriptionSettingsView.swift
// SimFolio - Subscription Settings
//
// Displays subscription status and management options.
// Allows users to view their current plan, upgrade, or manage subscription.

import SwiftUI

// MARK: - SubscriptionSettingsView

struct SubscriptionSettingsView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall: Bool = false
    @State private var isRestoring: Bool = false
    @State private var showRestoreAlert: Bool = false
    @State private var restoreAlertMessage: String = ""

    /// Whether the user has full access (subscribed or all features unlocked)
    private var hasFullAccess: Bool {
        FeatureGateService.allFeaturesUnlocked || subscriptionManager.isSubscribed
    }

    var body: some View {
        List {
            // Status Section
            statusSection

            // Premium Features (shown when not subscribed)
            premiumFeaturesSection

            // Actions Section
            actionsSection

            // Info Section
            infoSection
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(mode: .optional)
                .environmentObject(subscriptionManager)
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreAlertMessage)
        }
    }

    // MARK: - Status Section

    var statusSection: some View {
        Section {
            VStack(spacing: AppTheme.Spacing.md) {
                // Crown icon
                ZStack {
                    Circle()
                        .fill(hasFullAccess ?
                              LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ) :
                              LinearGradient(
                                colors: [AppTheme.Colors.surfaceSecondary, AppTheme.Colors.surfaceSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(hasFullAccess ? .white : AppTheme.Colors.textTertiary)
                }
                .padding(.top, AppTheme.Spacing.sm)

                // Status text
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text(hasFullAccess ? "All Features Active" : "Free Plan")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if subscriptionManager.isSubscribed {
                        // Plan details for subscribed users
                        if let planName = subscriptionManager.currentPlanName {
                            Text("\(planName) Plan")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        if subscriptionManager.hasBillingIssues {
                            Label("Billing issue detected", systemImage: "exclamationmark.triangle.fill")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.error)
                                .padding(.top, AppTheme.Spacing.xs)
                        } else if let expirationDate = subscriptionManager.formattedExpirationDate {
                            Text(subscriptionManager.willRenew ? "Renews \(expirationDate)" : "Expires \(expirationDate)")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    } else if !FeatureGateService.allFeaturesUnlocked {
                        Text("Upgrade to unlock all features")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, AppTheme.Spacing.sm)
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Status")
        }
    }

    // MARK: - Actions Section

    var actionsSection: some View {
        Section {
            if subscriptionManager.isSubscribed {
                // Manage subscription button for subscribed users
                Button {
                    subscriptionManager.openSubscriptionManagement()
                } label: {
                    HStack {
                        Label("Manage Subscription", systemImage: "gear")
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            } else if !FeatureGateService.allFeaturesUnlocked {
                // Upgrade button for non-subscribed users (hidden when all features unlocked)
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Upgrade to Premium", systemImage: "crown.fill")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Restore purchases button
            Button {
                restorePurchases()
            } label: {
                HStack {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .foregroundStyle(AppTheme.Colors.primary)
                    Spacer()
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isRestoring)
        } header: {
            Text("Actions")
        }
    }

    // MARK: - Premium Features Section

    @ViewBuilder
    var premiumFeaturesSection: some View {
        if !hasFullAccess {
            Section {
                ForEach(PremiumFeature.allCases.filter(\.showInPaywall), id: \.self) { feature in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: feature.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(feature.iconColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.displayTitle)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(feature.displayDescription)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xxs)
                }
            } header: {
                Text("Premium Features")
            }
        }
    }

    // MARK: - Info Section

    var infoSection: some View {
        Section {
            Button {
                if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/terms.html") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Label("Terms of Use", systemImage: "doc.text")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }

            Button {
                if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/privacy.html") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
        } header: {
            Text("Legal")
        } footer: {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your Account Settings on the App Store after purchase.")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
    }

    // MARK: - Helper Methods

    private func restorePurchases() {
        isRestoring = true
        Task {
            do {
                let restored = try await subscriptionManager.restorePurchases()
                isRestoring = false
                if restored {
                    restoreAlertMessage = "Your subscription has been restored successfully."
                } else {
                    restoreAlertMessage = "No active subscription found to restore."
                }
                showRestoreAlert = true
            } catch {
                isRestoring = false
                restoreAlertMessage = "Failed to restore purchases. Please try again."
                showRestoreAlert = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SubscriptionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubscriptionSettingsView()
        }
    }
}
#endif
