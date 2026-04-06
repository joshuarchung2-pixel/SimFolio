import SwiftUI
import FirebaseAuth

struct PostDetailView: View {
    let post: SharedPost

    @ObservedObject private var interactionService = SocialInteractionService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var userReaction: String?
    @State private var currentReactionCounts: [String: Int]
    @State private var currentCommentCount: Int
    @State private var showReport = false
    @State private var showBlock = false
    @State private var showDeleteConfirmation = false

    private var isOwnPost: Bool {
        post.userId == Auth.auth().currentUser?.uid
    }

    init(post: SharedPost) {
        self.post = post
        _currentReactionCounts = State(initialValue: post.reactionCounts)
        _currentCommentCount = State(initialValue: post.commentCount)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    // Author header
                    HStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(AppTheme.Colors.primary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            HStack(spacing: 4) {
                                Text(post.authorSchool)
                                    .font(AppTheme.Typography.caption)
                                Text("·")
                                Text(post.displayDate)
                                    .font(AppTheme.Typography.caption)
                            }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        }

                        Spacer()

                        // Overflow menu
                        Menu {
                            if isOwnPost {
                                Button(role: .destructive) {
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Post", systemImage: "trash")
                                }
                            } else {
                                Button {
                                    showReport = true
                                } label: {
                                    Label("Report Post", systemImage: "flag")
                                }
                                Button(role: .destructive) {
                                    showBlock = true
                                } label: {
                                    Label("Block \(post.authorName)", systemImage: "person.crop.circle.badge.xmark")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    // Full image
                    AsyncImage(url: URL(string: post.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Rectangle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                                .frame(height: 300)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                )
                        default:
                            Rectangle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                                .frame(height: 300)
                                .overlay(ProgressView())
                        }
                    }

                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            DPTagPill(
                                post.procedure,
                                color: AppTheme.procedureColor(for: post.procedure)
                            )
                            if let stage = post.stage {
                                DPTagPill( stage, color: AppTheme.Colors.secondary)
                            }
                            if let angle = post.angle {
                                DPTagPill( angle, color: AppTheme.Colors.secondary)
                            }
                            if let tooth = post.toothNumber {
                                DPTagPill( "#\(tooth)", color: AppTheme.Colors.secondary)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    // Caption
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    // Reactions
                    ReactionPicker(userReaction: userReaction) { emoji in
                        Task { await toggleReaction(emoji) }
                    }

                    Divider()
                        .padding(.horizontal, AppTheme.Spacing.md)

                    // Comments
                    CommentListView(postId: post.id ?? "")
                        .padding(.horizontal, AppTheme.Spacing.md)

                    // Spacer for input bar
                    Spacer().frame(height: 80)
                }
            }

            // Comment input
            CommentInputBar(postId: post.id ?? "") { newComment in
                currentCommentCount += 1
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            userReaction = try? await interactionService.getUserReaction(postId: post.id ?? "")
            AnalyticsService.logPostViewed(postId: post.id ?? "", procedure: post.procedure)
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(targetType: .post, targetId: post.id ?? "", postId: nil) {
                dismiss()
            }
        }
        .sheet(isPresented: $showBlock) {
            BlockConfirmationView(userId: post.userId, userName: post.authorName) {
                dismiss()
            }
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await PhotoSharingService.shared.deletePost(post)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the post and all its comments.")
        }
    }

    private func toggleReaction(_ emoji: String) async {
        // Optimistic update
        let previousReaction = userReaction
        if userReaction == emoji {
            userReaction = nil
            currentReactionCounts[emoji, default: 0] -= 1
        } else {
            if let prev = previousReaction {
                currentReactionCounts[prev, default: 0] -= 1
            }
            userReaction = emoji
            currentReactionCounts[emoji, default: 0] += 1
        }

        do {
            try await interactionService.toggleReaction(postId: post.id ?? "", type: emoji)
        } catch {
            // Revert on failure
            userReaction = previousReaction
            currentReactionCounts = post.reactionCounts
        }
    }
}
