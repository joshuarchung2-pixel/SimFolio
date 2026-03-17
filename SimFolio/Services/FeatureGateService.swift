// FeatureGateService.swift
// SimFolio - Premium Feature Gating
//
// Defines premium features and checks whether they are available
// based on the user's subscription status.

import SwiftUI

// MARK: - PremiumFeature

/// All features that require a premium subscription
enum PremiumFeature: String, CaseIterable {
    case unlimitedPortfolios
    case photoEditing
    case photoAnnotations
    case portfolioExport
    case dueDateReminders
    case customProcedures
    case batchOperations

    var displayTitle: String {
        switch self {
        case .unlimitedPortfolios: return "Unlimited Portfolios"
        case .photoEditing: return "Photo Editing"
        case .photoAnnotations: return "Photo Annotations"
        case .portfolioExport: return "Advanced Export"
        case .dueDateReminders: return "Due Date Reminders"
        case .customProcedures: return "Custom Procedures"
        case .batchOperations: return "Batch Operations"
        }
    }

    var displayDescription: String {
        switch self {
        case .unlimitedPortfolios: return "Create as many portfolios as you need"
        case .photoEditing: return "Crop, adjust, and enhance your photos"
        case .photoAnnotations: return "Add markers, text, and other items"
        case .portfolioExport: return "Export as ZIP or individual files"
        case .dueDateReminders: return "Get notified before deadlines"
        case .customProcedures: return "Create your own procedure types"
        case .batchOperations: return "Select and manage multiple photos at once"
        }
    }

    var iconName: String {
        switch self {
        case .unlimitedPortfolios: return "infinity"
        case .photoEditing: return "slider.horizontal.3"
        case .photoAnnotations: return "pencil.tip.crop.circle"
        case .portfolioExport: return "square.and.arrow.up.fill"
        case .dueDateReminders: return "bell.badge.fill"
        case .customProcedures: return "plus.rectangle.on.folder"
        case .batchOperations: return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .unlimitedPortfolios: return .blue
        case .photoEditing: return .purple
        case .photoAnnotations: return .orange
        case .portfolioExport: return .green
        case .dueDateReminders: return .red
        case .customProcedures: return .cyan
        case .batchOperations: return .indigo
        }
    }
}

// MARK: - FeatureGateService

/// Centralized service for checking premium feature availability
enum FeatureGateService {

    /// Maximum number of portfolios on the free tier
    static let freePortfolioLimit = 2

    /// Check if a premium feature is available to the current user
    static func isAvailable(_ feature: PremiumFeature) -> Bool {
        SubscriptionManager.shared.isSubscribed
    }

    /// Check if the user can create a new portfolio (subscribed or under the free limit)
    static func canCreatePortfolio() -> Bool {
        SubscriptionManager.shared.isSubscribed ||
        MetadataManager.shared.portfolios.count < freePortfolioLimit
    }

    /// Whether to show the portfolio limit banner (free user at or over the limit)
    static func shouldShowPortfolioLimitBanner() -> Bool {
        !SubscriptionManager.shared.isSubscribed &&
        MetadataManager.shared.portfolios.count >= freePortfolioLimit
    }
}
