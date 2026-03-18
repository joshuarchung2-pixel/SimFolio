// PremiumFeatureGate.swift
// SimFolio - Premium Feature Gate Helpers
//
// Reusable helpers for gating premium features with paywall presentation.

import SwiftUI

// MARK: - Premium Gate Helper

/// Checks premium access and either executes the action or shows the paywall.
/// - Parameters:
///   - feature: The premium feature being accessed
///   - showPaywall: Binding to control paywall presentation
///   - action: The action to execute if the feature is available
func requirePremium(_ feature: PremiumFeature, showPaywall: Binding<Bool>, action: () -> Void) {
    if FeatureGateService.isAvailable(feature) {
        action()
    } else {
        AnalyticsService.logEvent(.paywallViewed, parameters: [
            "trigger_feature": feature.rawValue
        ])
        showPaywall.wrappedValue = true
    }
}

// MARK: - Premium Lock Badge

/// Small circular lock badge overlaid on premium-gated UI elements.
struct PremiumLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 8))
            .foregroundStyle(.white)
            .padding(2)
            .background(AppTheme.Colors.primary)
            .clipShape(Circle())
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a premium paywall full-screen cover to this view.
    /// - Parameters:
    ///   - feature: The premium feature to highlight in the paywall
    ///   - showPaywall: Binding controlling paywall presentation
    func premiumGate(for feature: PremiumFeature, showPaywall: Binding<Bool>) -> some View {
        self.fullScreenCover(isPresented: showPaywall) {
            PaywallView(mode: .optional, highlightedFeature: feature)
                .environmentObject(SubscriptionManager.shared)
        }
    }
}
