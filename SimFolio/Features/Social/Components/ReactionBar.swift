import SwiftUI

struct ReactionBar: View {
    let reactionCounts: [String: Int]
    let userReaction: String?
    let onToggle: (String) -> Void

    private let allReactions = ["🔥", "👏", "💯", "🦷", "⭐"]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(allReactions, id: \.self) { emoji in
                let count = reactionCounts[emoji] ?? 0
                let isSelected = userReaction == emoji

                Button {
                    onToggle(emoji)
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(emoji)
                            .font(AppTheme.Typography.body)
                        if count > 0 {
                            Text("\(count)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surfaceSecondary)
                    .cornerRadius(AppTheme.CornerRadius.full)
                }
            }
        }
    }
}
