import SwiftUI

struct SocialOnboardingSheet: View {
    @ObservedObject private var profileService = UserProfileService.shared
    @ObservedObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tosAccepted = false
    @State private var isLoading = false
    @State private var showSignIn = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Header
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text("Share With Your Class")
                            .font(AppTheme.Typography.title)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("Join your school's class feed to share simulation photos and connect with classmates.")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    // Guidelines
                    DPCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Label("Guidelines", systemImage: "shield.checkered")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            guidelineRow(icon: "checkmark.circle.fill", color: .green,
                                text: "Share simulation and typodont photos")
                            guidelineRow(icon: "checkmark.circle.fill", color: .green,
                                text: "Comment and react to classmates' work")
                            guidelineRow(icon: "xmark.circle.fill", color: .red,
                                text: "Real patient photos are strictly prohibited")
                            guidelineRow(icon: "eye.fill", color: .blue,
                                text: "Only classmates at your school can see your posts")
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    // ToS checkbox
                    Button {
                        tosAccepted.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                            Image(systemName: tosAccepted ? "checkmark.square.fill" : "square")
                                .foregroundColor(tosAccepted ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                .font(.title3)

                            Text("I agree to the Terms of Service and confirm I will only share simulation work")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    // Get Started button
                    DPButton(
                        "Get Started",
                        style: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: isLoading,
                        isDisabled: !tosAccepted
                    ) {
                        Task {
                            isLoading = true
                            try? await profileService.setSocialOptIn(true)
                            isLoading = false
                            dismiss()
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }

    private func guidelineRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}
