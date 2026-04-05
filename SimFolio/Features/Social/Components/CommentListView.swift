import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CommentListView: View {
    let postId: String

    @ObservedObject private var interactionService = SocialInteractionService.shared
    @ObservedObject private var moderationService = ModerationService.shared
    @State private var comments: [Comment] = []
    @State private var lastDocument: DocumentSnapshot?
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var showReport: Comment?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if comments.isEmpty && !isLoading {
                Text("No comments yet")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .padding(.vertical, AppTheme.Spacing.md)
            }

            ForEach(comments) { comment in
                if !moderationService.isUserBlocked(comment.userId) {
                    commentRow(comment)
                }
            }

            if hasMore && !comments.isEmpty {
                Button("Load more comments") {
                    Task { await loadMore() }
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.vertical, AppTheme.Spacing.sm)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
        .task {
            await loadComments()
        }
        .sheet(item: $showReport) { comment in
            ReportSheet(
                targetType: .comment,
                targetId: comment.id ?? "",
                postId: postId
            )
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorName)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(comment.displayDate)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Spacer()

                Menu {
                    if comment.userId == Auth.auth().currentUser?.uid {
                        Button(role: .destructive) {
                            Task {
                                try? await interactionService.deleteComment(postId: postId, commentId: comment.id ?? "")
                                comments.removeAll { $0.id == comment.id }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showReport = comment
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .frame(width: 30, height: 30)
                }
            }

            Text(comment.text)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (newComments, lastDoc) = try await interactionService.getComments(postId: postId, limit: 20)
            comments = newComments
            lastDocument = lastDoc
            hasMore = newComments.count == 20
        } catch {}
    }

    private func loadMore() async {
        guard hasMore else { return }
        do {
            let (newComments, lastDoc) = try await interactionService.getComments(postId: postId, limit: 20, afterDocument: lastDocument)
            comments.append(contentsOf: newComments)
            lastDocument = lastDoc
            hasMore = newComments.count == 20
        } catch {}
    }
}

// Make Comment work with .sheet(item:)
extension Comment: @retroactive Identifiable {}
