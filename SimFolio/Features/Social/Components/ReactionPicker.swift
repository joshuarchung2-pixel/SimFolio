import SwiftUI

struct ReactionPicker: View {
    let userReaction: String?
    let onSelect: (String) -> Void

    private let reactions: [(emoji: String, label: String)] = [
        ("🔥", "Great"),
        ("👏", "Impressive"),
        ("💯", "Perfect"),
        ("🦷", "Dental"),
        ("⭐", "Favorite"),
    ]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ForEach(reactions, id: \.emoji) { reaction in
                let isSelected = userReaction == reaction.emoji

                Button {
                    onSelect(reaction.emoji)
                } label: {
                    VStack(spacing: 4) {
                        Text(reaction.emoji)
                            .font(.title2)
                        Text(reaction.label)
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
}
