import SwiftUI

struct SocialSettingsView: View {
    @ObservedObject private var profileService = UserProfileService.shared
    @ObservedObject private var moderationService = ModerationService.shared

    @State private var socialEnabled: Bool = false
    @State private var commentSetting: String = "everyone"
    @State private var showDisableConfirmation = false

    var body: some View {
        List {
            Section {
                Toggle("Social Feed", isOn: $socialEnabled)
                    .onChange(of: socialEnabled) { newValue in
                        if !newValue {
                            showDisableConfirmation = true
                        } else {
                            Task { try? await profileService.setSocialOptIn(true) }
                        }
                    }
            } header: {
                Text("SOCIAL FEATURES")
                    .font(AppTheme.Typography.sectionLabel)
                    .tracking(0.8)
            } footer: {
                Text("When enabled, you can share photos and see your classmates' posts.")
            }

            Section {
                HStack {
                    Text("Visibility")
                        .font(AppTheme.Typography.body)
                    Spacer()
                    Text("My School Only")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Picker("Who Can Comment", selection: $commentSetting) {
                    Text("Everyone").tag("everyone")
                    Text("No One").tag("none")
                }
                .onChange(of: commentSetting) { newValue in
                    Task { try? await profileService.setCommentSetting(newValue) }
                }
            } header: {
                Text("PRIVACY")
                    .font(AppTheme.Typography.sectionLabel)
                    .tracking(0.8)
            }

            if !moderationService.blockedUserIds.isEmpty {
                Section {
                    ForEach(moderationService.blockedUserIds, id: \.self) { userId in
                        HStack {
                            Text(userId)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button("Unblock") {
                                Task { try? await moderationService.unblockUser(userId: userId) }
                            }
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                } header: {
                    Text("BLOCKED USERS")
                        .font(AppTheme.Typography.sectionLabel)
                        .tracking(0.8)
                }
            }
        }
        .navigationTitle("Social Settings")
        .onAppear {
            socialEnabled = profileService.userProfile?.socialOptIn ?? false
            commentSetting = profileService.userProfile?.commentSetting ?? "everyone"
        }
        .alert("Disable Social Feed?", isPresented: $showDisableConfirmation) {
            Button("Disable", role: .destructive) {
                Task { try? await profileService.setSocialOptIn(false) }
            }
            Button("Cancel", role: .cancel) {
                socialEnabled = true
            }
        } message: {
            Text("Your shared posts will be hidden from the feed. You can re-enable anytime.")
        }
    }
}
