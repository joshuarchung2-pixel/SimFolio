// PaywallView.swift
// SimFolio - Subscription Paywall
//
// Full-screen paywall presented after onboarding.
// Shows premium features and subscription options.

import SwiftUI
import RevenueCat

// MARK: - Paywall Mode

enum PaywallMode {
    case mandatory  // No X button, cannot dismiss without subscribing
    case optional   // X button visible, can dismiss freely
}

// MARK: - Subscription Period Unit Extension

extension SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }

    var localizedDescriptionPlural: String {
        switch self {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        case .year: return "years"
        @unknown default: return ""
        }
    }
}

struct PaywallView: View {
    let mode: PaywallMode
    let highlightedFeature: PremiumFeature?

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDismissing = false

    init(mode: PaywallMode = .mandatory, highlightedFeature: PremiumFeature? = nil) {
        self.mode = mode
        self.highlightedFeature = highlightedFeature
    }

    // MARK: - Computed Properties

    /// Check if selected package has a free trial offer
    private var hasFreeTrial: Bool {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount else {
            return false
        }
        return intro.paymentMode == .freeTrial
    }

    /// Get trial duration text for selected package (e.g., "7-day", "1-week")
    private var trialDurationText: String? {
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else {
            return nil
        }
        let value = intro.subscriptionPeriod.value
        let unit = intro.subscriptionPeriod.unit
        let unitText = value == 1 ? unit.localizedDescription : unit.localizedDescriptionPlural
        return "\(value)-\(unitText)"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.primary.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    // Header
                    headerSection

                    // Free tier banner (optional mode only)
                    if mode == .optional {
                        freeTierBanner
                    }

                    // Features list
                    featuresSection

                    // Subscription options
                    subscriptionOptionsSection

                    // Purchase button
                    purchaseButtonSection

                    // Cancel anytime text
                    cancelAnytimeText

                    // Legal text
                    legalSection
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.md)
            }
            .scrollIndicators(.hidden)

            // Close button (only in optional mode)
            if mode == .optional {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            safeDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.Colors.surfaceSecondary)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close paywall")
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.top, AppTheme.Spacing.sm)
                    }
                    Spacer()
                }
            }

            // Loading overlay
            if isPurchasing || subscriptionManager.isLoading {
                loadingOverlay
            }
        }
        .interactiveDismissDisabled(mode == .mandatory)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Select annual package by default if available
            if selectedPackage == nil {
                selectedPackage = subscriptionManager.annualPackage ?? subscriptionManager.monthlyPackage
            }

            // Re-check subscription in case user is already entitled
            // (external purchase, family sharing, delayed propagation)
            // Only auto-dismiss on confirmed success — not on network failure
            Task {
                let result = await subscriptionManager.checkSubscriptionStatus()
                if case .success(let isSubscribed) = result, isSubscribed {
                    safeDismiss()
                }
            }
        }
        .onChange(of: subscriptionManager.isSubscribed) { isSubscribed in
            if isSubscribed {
                safeDismiss()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.warning, AppTheme.Colors.warning.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }

            Text(highlightedFeature != nil ? "Unlock \(highlightedFeature!.displayTitle)" : "Unlock SimFolio Premium")
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(highlightedFeature?.displayDescription ?? (mode == .optional ? "Start with the free plan or unlock everything with Premium." : "Upgrade to unlock premium features for your dental portfolio."))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Free Tier Banner

    private var freeTierBanner: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.success)

                Text("Free plan includes:")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                freeTierBullet("\(FeatureGateService.freePortfolioLimit) portfolios")
                freeTierBullet("Photo capture")
                freeTierBullet("Tagging & library")
                freeTierBullet("Basic photo editing (crop, rotate, brightness, contrast)")
            }
            .padding(.leading, AppTheme.Spacing.xs)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.success.opacity(0.08))
        .cornerRadius(AppTheme.CornerRadius.medium)
    }

    private func freeTierBullet(_ text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(AppTheme.Colors.success)
                .frame(width: 5, height: 5)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Premium adds:")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(PremiumFeature.allCases.filter(\.showInPaywall), id: \.self) { feature in
                FeatureRow(
                    icon: feature.iconName,
                    iconColor: feature.iconColor,
                    title: feature.displayTitle,
                    description: feature.displayDescription,
                    isHighlighted: highlightedFeature == feature
                )
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.large)
    }

    // MARK: - Subscription Options Section

    private var subscriptionOptionsSection: some View {
        Group {
            if let _ = subscriptionManager.currentOffering {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Annual option
                    if let annual = subscriptionManager.annualPackage {
                        CompactSubscriptionCard(
                            package: annual,
                            isSelected: selectedPackage?.identifier == annual.identifier,
                            savingsPercentage: subscriptionManager.annualSavingsPercentage,
                            isBestValue: true
                        ) {
                            selectedPackage = annual
                        }
                    }

                    // Monthly option
                    if let monthly = subscriptionManager.monthlyPackage {
                        CompactSubscriptionCard(
                            package: monthly,
                            isSelected: selectedPackage?.identifier == monthly.identifier,
                            savingsPercentage: nil,
                            isBestValue: false
                        ) {
                            selectedPackage = monthly
                        }
                    }
                }
            } else if let error = subscriptionManager.errorMessage {
                // Error state
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.Colors.warning)

                    Text(error)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task {
                            await subscriptionManager.fetchOfferings()
                        }
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.primary)
                }
                .frame(height: 120)
                .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                // Loading state
                VStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(height: 120)
            }
        }
    }

    // MARK: - Purchase Button Section

    private var purchaseButtonSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Subscribe button
            Button(action: purchase) {
                HStack {
                    Text(hasFreeTrial ? "Start Free Trial" : "Start Subscription")
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .disabled(selectedPackage == nil || isPurchasing)
            .opacity(selectedPackage == nil ? 0.6 : 1.0)

            // Restore purchases
            Button(action: restore) {
                Text("Restore Purchases")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.primary)
            }

            // Continue with Free Plan (optional mode only)
            if mode == .optional {
                Button(action: { safeDismiss() }) {
                    HStack(spacing: 4) {
                        Text("Continue with Free Plan")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Cancel Anytime Text

    private var cancelAnytimeText: some View {
        Text("Cancel anytime. No questions asked.")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your Account Settings on the App Store after purchase.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if hasFreeTrial {
                Text("Any unused portion of a free trial period will be forfeited when you purchase a subscription.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Button("Terms of Use") {
                    if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/terms.html") {
                        UIApplication.shared.open(url)
                    }
                }

                Text("|")
                    .foregroundStyle(AppTheme.Colors.textTertiary)

                Button("Privacy Policy") {
                    if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/privacy.html") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.primary)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text("Processing...")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(AppTheme.Spacing.xl)
            .background(.ultraThinMaterial)
            .cornerRadius(AppTheme.CornerRadius.large)
        }
    }

    // MARK: - Actions

    private func safeDismiss() {
        guard !isDismissing else { return }
        // In mandatory mode, only allow dismiss if subscribed
        if mode == .mandatory && !subscriptionManager.isSubscribed {
            return
        }
        isDismissing = true
        dismiss()
    }

    private func purchase() {
        guard let package = selectedPackage else { return }

        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionManager.purchase(package: package)
                isPurchasing = false

                if success {
                    safeDismiss()
                }
            } catch {
                isPurchasing = false
                errorMessage = subscriptionManager.errorMessage ?? "An error occurred during purchase."
                showError = true
            }
        }
    }

    private func restore() {
        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionManager.restorePurchases()
                isPurchasing = false

                if success {
                    safeDismiss()
                } else if let message = subscriptionManager.errorMessage {
                    errorMessage = message
                    showError = true
                }
            } catch {
                isPurchasing = false
                errorMessage = subscriptionManager.errorMessage ?? "Unable to restore purchases."
                showError = true
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.Colors.success)
        }
        .padding(isHighlighted ? AppTheme.Spacing.xs : 0)
        .background(isHighlighted ? AppTheme.Colors.primary.opacity(0.08) : Color.clear)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Compact Subscription Card

private struct CompactSubscriptionCard: View {
    let package: Package
    let isSelected: Bool
    let savingsPercentage: Int?
    let isBestValue: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xs) {
                // Best Value badge
                if isBestValue {
                    Text("BEST VALUE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.success)
                        .cornerRadius(AppTheme.CornerRadius.xs)
                } else {
                    // Spacer for consistent height
                    Text(" ")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .opacity(0)
                }

                // Plan title
                Text(package.storeProduct.localizedTitle)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Price
                Text(package.localizedPriceString)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Free trial badge
                if let intro = package.storeProduct.introductoryDiscount,
                   intro.paymentMode == .freeTrial {
                    let value = intro.subscriptionPeriod.value
                    let unit = intro.subscriptionPeriod.unit
                    let unitText = value == 1 ? unit.localizedDescription.uppercased() : unit.localizedDescriptionPlural.uppercased()
                    Text("\(value) \(unitText) FREE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.warning.opacity(0.15))
                        .cornerRadius(AppTheme.CornerRadius.xs)
                } else {
                    // Spacer for consistent height
                    Text(" ")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .opacity(0)
                }

                // Savings percentage
                if let savings = savingsPercentage, savings > 0 {
                    Text("Save \(savings)%")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.Colors.success)
                } else {
                    // Spacer for consistent height
                    Text(" ")
                        .font(AppTheme.Typography.caption)
                        .opacity(0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(
                isSelected
                    ? AppTheme.Colors.primary.opacity(0.1)
                    : AppTheme.Colors.surface
            )
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView(mode: .mandatory)
                .previewDisplayName("Mandatory")
            PaywallView(mode: .optional)
                .previewDisplayName("Optional")
        }
        .environmentObject(SubscriptionManager.shared)
    }
}
#endif
