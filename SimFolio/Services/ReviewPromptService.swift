// ReviewPromptService.swift
// SimFolio - Smart Review Prompt
//
// Requests an App Store review at key milestones.
// Each milestone only triggers once. Apple rate-limits the prompt
// to 3 appearances per 365 days automatically.

import StoreKit

enum ReviewMilestone: String {
    case firstPhotoCaptured = "review_milestone_first_photo"
    case firstPortfolioCompleted = "review_milestone_first_portfolio_completed"
    case firstPortfolioExported = "review_milestone_first_portfolio_exported"
}

enum ReviewPromptService {

    /// Request a review if this milestone hasn't been triggered before.
    /// Call from the main thread after a positive user action.
    static func requestIfEligible(for milestone: ReviewMilestone) {
        let key = milestone.rawValue
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        // Mark as triggered so it only fires once per milestone
        UserDefaults.standard.set(true, forKey: key)

        // Small delay so the UI action completes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
