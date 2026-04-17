// UntaggedPhotosCard.swift
// SimFolio - Home-screen nudge card for untagged imported photos.
//
// Shown when MetadataManager.shared.incompleteAssetCount > 0 AND the dismissal
// counter (UserDefaults: "untaggedCardDismissedRemainingSessions") is 0.
// Tapping "Tag now" deep-links to the Library with showUntaggedOnly = true.
// Tapping dismiss sets the counter to 2 — the card stays hidden for the next
// two app launches, then returns.

import SwiftUI

enum UntaggedCardDismissal {
    static let userDefaultsKey = "untaggedCardDismissedRemainingSessions"
    static let dismissalSessionCount = 2

    /// Called when the user taps the dismiss button.
    static func dismiss() {
        UserDefaults.standard.set(dismissalSessionCount, forKey: userDefaultsKey)
    }

    /// Called once per `SimFolioApp` launch — decrements the remaining sessions.
    static func tickDownOnLaunch() {
        let remaining = UserDefaults.standard.integer(forKey: userDefaultsKey)
        if remaining > 0 {
            UserDefaults.standard.set(remaining - 1, forKey: userDefaultsKey)
        }
    }

    /// Whether the card is currently suppressed by the dismissal counter.
    static var isSuppressed: Bool {
        UserDefaults.standard.integer(forKey: userDefaultsKey) > 0
    }
}

struct UntaggedPhotosCard: View {
    let count: Int
    let onTagNow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "tag.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.primary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("\(count) photo\(count == 1 ? "" : "s") need tagging")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Tag them so they count toward your portfolios")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button(action: onTagNow) {
                    Text("Tag now")
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.top, AppTheme.Spacing.xs)
                }
                .accessibilityIdentifier("untagged-card-tag-now")
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .padding(AppTheme.Spacing.xs)
            }
            .accessibilityLabel("Dismiss for a couple of sessions")
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

#if DEBUG
struct UntaggedPhotosCard_Previews: PreviewProvider {
    static var previews: some View {
        UntaggedPhotosCard(count: 12, onTagNow: {}, onDismiss: {})
            .padding()
            .background(AppTheme.Colors.background)
    }
}
#endif
