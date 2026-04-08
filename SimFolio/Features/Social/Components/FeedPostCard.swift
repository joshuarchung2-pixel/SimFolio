import SwiftUI

struct FeedPostCard: View {
    let post: SharedPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                // Author row
                HStack {
                    // Author avatar circle with initial
                    Circle()
                        .fill(AppTheme.procedureBackgroundColor(for: post.procedure))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.procedureColor(for: post.procedure))
                        )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(post.authorName)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(post.displayDate)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }

                    Spacer()

                    // Procedure badge top-right
                    Text(post.procedure)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.procedureColor(for: post.procedure))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.procedureBackgroundColor(for: post.procedure))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(AppTheme.procedureBorderColor(for: post.procedure), lineWidth: 1)
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
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
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
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Bottom bar: heart + comment count only
                HStack(spacing: 12) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        Text("\(post.totalReactions)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        Text("\(post.commentCount)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
