// ProfileView.swift
// SimFolio - User Profile and Settings Hub
//
// Redesigned for Clarity direction:
// - Inline avatar + name header (no gradient, simple teal-tinted circle)
// - Horizontal stats row with dividers (3 stats: photos, portfolios, completion)
// - iOS-native grouped list-style settings sections
// - Removed procedure breakdown section and average rating stat
//
// Contents:
// - ProfileView: Main profile/settings screen
// - SettingsSection: Grouped settings container
// - SettingsRow: Individual settings row with icon and chevron
// - PortfolioListSheet: Sheet wrapper for PortfolioListView
// - Placeholder views for settings subviews (to be implemented)
//
// Related Files:
// - EditProfileSheet.swift: Profile editing

import SwiftUI
import FirebaseAuth

// MARK: - ProfileView

/// Main profile view serving as the settings hub
struct ProfileView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var authService = AuthenticationService.shared

    // MARK: - Navigation State

    @State private var showEditProfile: Bool = false
    @State private var showPortfolioList: Bool = false
    @State private var showProcedureManagement: Bool = false
    @State private var showCaptureSettings: Bool = false
    @State private var showNotificationSettings: Bool = false
    @State private var showDataManagement: Bool = false
    @State private var showAbout: Bool = false
    @State private var showHelp: Bool = false
    @State private var showAppearanceSettings: Bool = false
    @State private var showSubscriptionSettings: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showSocialSettings: Bool = false
    @State private var showSignIn: Bool = false
    @State private var showSignOutConfirmation: Bool = false

    // MARK: - Computed Properties

    var photoCount: Int {
        library.assets.count
    }

    var taggedPhotoCount: Int {
        metadataManager.assetMetadata.count
    }

    var portfolioCount: Int {
        metadataManager.portfolios.count
    }

    var isNewUser: Bool {
        photoCount == 0 && portfolioCount == 0
    }

    var activePortfolioCount: Int {
        metadataManager.portfolios.filter { portfolio in
            let stats = metadataManager.getPortfolioStats(portfolio)
            return stats.fulfilled < stats.total || stats.total == 0
        }.count
    }

    var overallCompletionRate: Double {
        let portfolios = metadataManager.portfolios
        guard !portfolios.isEmpty else { return 0 }

        var totalFulfilled = 0
        var totalRequired = 0

        for portfolio in portfolios {
            let stats = metadataManager.getPortfolioStats(portfolio)
            totalFulfilled += stats.fulfilled
            totalRequired += stats.total
        }

        guard totalRequired > 0 else { return 0 }
        return Double(totalFulfilled) / Double(totalRequired)
    }

    var completionPercentage: Int {
        Int(overallCompletionRate * 100)
    }

    // MARK: - User Info

    var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "SimFolio User"
    }

    var userSchool: String {
        UserDefaults.standard.string(forKey: "userSchool") ?? ""
    }

    var userClassYear: String {
        UserDefaults.standard.string(forKey: "userClassYear") ?? ""
    }

    var userInitials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "DS"
    }

    /// Combined school + class year line, e.g. "UCSF · Class of 2027"
    var schoolInfo: String {
        if !userSchool.isEmpty && !userClassYear.isEmpty {
            return "\(userSchool) · Class of \(userClassYear)"
        } else if !userSchool.isEmpty {
            return userSchool
        } else if !userClassYear.isEmpty {
            return "Class of \(userClassYear)"
        }
        return ""
    }

    var memberSince: String {
        if let date = UserDefaults.standard.object(forKey: "userCreatedDate") as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return "Member since \(formatter.string(from: date))"
        }
        return ""
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Header + optional get-started card
                    VStack(spacing: AppTheme.Spacing.sm) {
                        profileHeader

                        if isNewUser {
                            getStartedCard
                        }

                        statsRow
                    }

                    // Settings sections
                    accountSection
                    appearanceSection
                    subscriptionSection
                    socialSection
                    mainSettingsSection
                    aboutSignOutSection

                    // App version footer
                    appVersionFooter

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
            }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(isPresented: $showEditProfile)
        }
        .sheet(isPresented: $showPortfolioList) {
            PortfolioListSheet()
        }
        .sheet(isPresented: $showProcedureManagement) {
            ProcedureManagementView(isPresented: $showProcedureManagement)
        }
        .sheet(isPresented: $showCaptureSettings) {
            SettingsSheetWrapper(title: "Capture Settings", isPresented: $showCaptureSettings) {
                CaptureSettingsView()
            }
        }
        .sheet(isPresented: $showNotificationSettings) {
            SettingsSheetWrapper(title: "Notifications", isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
        }
        .sheet(isPresented: $showDataManagement) {
            SettingsSheetWrapper(title: "Data Management", isPresented: $showDataManagement) {
                DataManagementView()
            }
        }
        .sheet(isPresented: $showAbout) {
            SettingsSheetWrapper(title: "About", isPresented: $showAbout) {
                AboutView()
            }
        }
        .sheet(isPresented: $showAppearanceSettings) {
            SettingsSheetWrapper(title: "Appearance", isPresented: $showAppearanceSettings) {
                AppearanceSettingsView()
            }
        }
        .sheet(isPresented: $showSubscriptionSettings) {
            SettingsSheetWrapper(title: "Subscription", isPresented: $showSubscriptionSettings) {
                SubscriptionSettingsView()
            }
        }
        .sheet(isPresented: $showSocialSettings) {
            SettingsSheetWrapper(title: "Social Settings", isPresented: $showSocialSettings) {
                SocialSettingsView()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            let appURL = URL(string: "https://apps.apple.com/app/simfolio/id6746268638")!
            let shareText = "Check out SimFolio \u{2014} it makes managing your dental portfolio so much easier!"
            ActivityViewSheet(activityItems: [shareText, appURL])
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(context: .generic, onSignIn: {
                AnalyticsService.logEvent(.accountCreated, parameters: ["source": "profile"])
                Task { try? await UserProfileService.shared.linkOnboardingData() }
            })
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                try? AuthenticationService.shared.signOut()
                UserProfileService.shared.clearProfile()
                AnalyticsService.logEvent(.signOutCompleted)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            ensureUserCreatedDate()
        }
    }

    // MARK: - Profile Header

    var profileHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Avatar — simple teal-tinted circle with initials
                Text(userInitials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.Colors.accentLight)
                    .clipShape(Circle())

                // Name + school
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(userName)
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if !schoolInfo.isEmpty {
                        Text(schoolInfo)
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Edit profile button
                Button(action: { showEditProfile = true }) {
                    Text("Edit")
                        .font(AppTheme.Typography.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
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

    // MARK: - Stats Row

    var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(photoCount)", label: "Photos")
            Divider().frame(height: 32)
            statItem(value: "\(portfolioCount)", label: "Portfolios")
            Divider().frame(height: 32)
            statItem(
                value: "\(completionPercentage)%",
                label: "Complete",
                valueColor: AppTheme.Colors.primary
            )
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
    }

    private func statItem(value: String, label: String, valueColor: Color = AppTheme.Colors.textPrimary) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Get Started Card

    var getStartedCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.primary)

            Text("Welcome to SimFolio!")
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Start by capturing your first dental photo or creating a portfolio.")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    router.selectedTab = .capture
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Capture Photo")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.small)
                }

                Button {
                    showPortfolioList = true
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 14))
                        Text("Create Portfolio")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
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

    // MARK: - Settings Sections

    @ViewBuilder
    var accountSection: some View {
        if authService.authState == .signedOut {
            settingsGroup(title: "ACCOUNT") {
                settingsRow("Create Account") { showSignIn = true }
            }
        } else if authService.authState == .signedIn {
            settingsGroup(title: "ACCOUNT") {
                accountInfoRow
                Divider().padding(.leading, AppTheme.Spacing.md)
                signOutRow
            }
        }
    }

    var accountInfoRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(authService.currentUser?.email ?? "Signed in")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Signed in")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 13)
    }

    var signOutRow: some View {
        Button(action: { showSignOutConfirmation = true }) {
            HStack {
                Text("Sign Out")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(Color.red)
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    var appearanceSection: some View {
        settingsGroup(title: "APPEARANCE") {
            settingsRow("Appearance") { showAppearanceSettings = true }
        }
    }

    var subscriptionSection: some View {
        settingsGroup(title: "SUBSCRIPTION") {
            settingsRow(subscriptionManager.isSubscribed ? "Premium" : "Upgrade to Premium") {
                showSubscriptionSettings = true
            }
        }
    }

    @ViewBuilder
    var socialSection: some View {
        if AuthenticationService.shared.authState == .signedIn {
            settingsGroup(title: "SOCIAL") {
                settingsRow("Social Feed Settings") { showSocialSettings = true }
            }
        }
    }

    var mainSettingsSection: some View {
        settingsGroup(title: "SETTINGS") {
            settingsRow("Portfolios") { showPortfolioList = true }
            Divider().padding(.leading, AppTheme.Spacing.md)
            settingsRow("Capture Settings") { showCaptureSettings = true }
            Divider().padding(.leading, AppTheme.Spacing.md)
            settingsRow("Manage Procedures") { showProcedureManagement = true }
            Divider().padding(.leading, AppTheme.Spacing.md)
            settingsRow("Notifications") { showNotificationSettings = true }
            Divider().padding(.leading, AppTheme.Spacing.md)
            settingsRow("Data Management") { showDataManagement = true }
        }
    }

    var aboutSignOutSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("ABOUT")
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                settingsRow("About SimFolio") { showAbout = true }
                Divider().padding(.leading, AppTheme.Spacing.md)
                settingsRow("Help & Support") { showHelp = true }
                Divider().padding(.leading, AppTheme.Spacing.md)
                settingsRow("Contact Support") {
                    if let url = URL(string: "mailto:joshuarchung2@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                }
                Divider().padding(.leading, AppTheme.Spacing.md)
                settingsRow("Rate This App") { requestAppStoreReview() }
                Divider().padding(.leading, AppTheme.Spacing.md)
                settingsRow("Share SimFolio") { showShareSheet = true }
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }

    var appVersionFooter: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("SimFolio v\(appVersion)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textTertiary)

            Text("Made with love for professionals")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }

    // MARK: - Reusable Helpers

    /// Grouped settings section with header label and card container
    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }

    /// Standard settings row — title + chevron
    private func settingsRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    // MARK: - Helper Functions

    func ensureUserCreatedDate() {
        if UserDefaults.standard.object(forKey: "userCreatedDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "userCreatedDate")
        }
    }

    func requestAppStoreReview() {
        // Trigger App Store review request
        // Note: In production, use SKStoreReviewController.requestReview()
    }
}

// MARK: - SettingsSection

/// Container for grouped settings rows with header (legacy support for external callers)
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }
}

// MARK: - SettingsRow

/// Individual settings row with icon, title, subtitle, and chevron
struct SettingsRow: View {
    let icon: String
    var iconColor: Color = AppTheme.Colors.primary
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(iconColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

// MARK: - Settings Row Button Style

/// A button style for settings rows that shows a background highlight on press
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppTheme.Colors.surfaceSecondary : Color.clear)
    }
}

// MARK: - PortfolioListSheet

/// Sheet wrapper for presenting PortfolioListView
struct PortfolioListSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            PortfolioListView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - SettingsSheetWrapper

/// Wrapper for presenting settings views in a sheet with Done button
struct SettingsSheetWrapper<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationView {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            isPresented = false
                        }
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
        }
    }
}

// Note: The following views are now in separate files:
// - EditProfileSheet.swift: Profile editing with photo picker
// - ProcedureManagementView.swift: Procedure management
// - Settings/CaptureSettingsView.swift: Camera and capture settings
// - Settings/NotificationSettingsView.swift: Notification preferences
// - Settings/DataManagementView.swift: Data export and management
// - Settings/AboutView.swift: App information and credits

// MARK: - Preview Provider

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(NavigationRouter())
    }
}

struct SettingsSection_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            SettingsSection(title: "CAPTURE") {
                SettingsRow(
                    icon: "camera.fill",
                    iconColor: AppTheme.Colors.primary,
                    title: "Capture Settings",
                    subtitle: "Camera and save options",
                    action: { }
                )

                Divider()
                    .padding(.leading, 56)

                SettingsRow(
                    icon: "tag.fill",
                    iconColor: .purple,
                    title: "Manage Procedures",
                    subtitle: "Customize procedure list and colors",
                    action: { }
                )
            }
        }
        .padding(.vertical)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
