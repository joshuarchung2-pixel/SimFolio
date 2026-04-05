import SwiftUI

struct BlockConfirmationView: View {
    let userId: String
    let userName: String
    var onComplete: (() -> Void)?

    @State private var isBlocking = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.error)

            Text("Block \(userName)?")
                .font(AppTheme.Typography.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("They won't be able to see your posts, and you won't see theirs. You can unblock them later in settings.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppTheme.Spacing.sm) {
                DPButton(
                    title: "Block",
                    style: .destructive,
                    size: .large,
                    isFullWidth: true,
                    isLoading: isBlocking
                ) {
                    Task {
                        isBlocking = true
                        try? await ModerationService.shared.blockUser(userId: userId)
                        isBlocking = false
                        onComplete?()
                        dismiss()
                    }
                }

                DPButton(
                    title: "Cancel",
                    style: .secondary,
                    size: .large,
                    isFullWidth: true
                ) {
                    dismiss()
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
    }
}
