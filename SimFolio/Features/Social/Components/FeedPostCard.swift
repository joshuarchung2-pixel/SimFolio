import SwiftUI

struct FeedPostCard: View {
    let post: SharedPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            DPCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    // Author row
                    HStack {
                        // Author avatar circle with initial
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(AppTheme.Colors.primary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Text(post.displayDate)
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }

                        Spacer()

                        // Procedure tag
                        DPTagPill(
                            text: post.procedure,
                            color: AppTheme.procedureColor(for: post.procedure)
                        )
                    }

                    // Thumbnail
                    AsyncImage(url: URL(string: post.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 250)
                                .clipped()
                                .cornerRadius(AppTheme.CornerRadius.small)
                        case .failure:
                            Rectangle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                                .frame(height: 200)
                                .cornerRadius(AppTheme.CornerRadius.small)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                )
                        default:
                            Rectangle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                                .frame(height: 200)
                                .cornerRadius(AppTheme.CornerRadius.small)
                                .overlay(ProgressView())
                        }
                    }

                    // Caption
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                    }

                    // Bottom bar: reactions + comments
                    HStack {
                        // Reaction summary
                        if post.totalReactions > 0 {
                            HStack(spacing: 4) {
                                // Show top 3 reaction emojis
                                let topReactions = post.reactionCounts
                                    .filter { $0.value > 0 }
                                    .sorted { $0.value > $1.value }
                                    .prefix(3)
                                ForEach(Array(topReactions), id: \.key) { emoji, _ in
                                    Text(emoji)
                                        .font(.caption)
                                }
                                Text("\(post.totalReactions)")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        // Comment count
                        if post.commentCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.right")
                                    .font(.caption)
                                Text("\(post.commentCount)")
                                    .font(AppTheme.Typography.caption)
                            }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
