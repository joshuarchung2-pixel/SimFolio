import SwiftUI

struct CommentInputBar: View {
    let postId: String
    var onCommentAdded: ((Comment) -> Void)?

    @State private var text = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if let error = errorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.xs)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("Add a comment...", text: $text)
                    .font(AppTheme.Typography.body)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.surfaceSecondary)
                    .cornerRadius(AppTheme.CornerRadius.full)

                Button {
                    Task { await postComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
    }

    private func postComment() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isPosting = true
        defer { isPosting = false }

        do {
            let comment = try await SocialInteractionService.shared.addComment(postId: postId, text: trimmed)
            text = ""
            onCommentAdded?(comment)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
