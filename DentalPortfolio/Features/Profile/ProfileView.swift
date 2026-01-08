// ProfileView.swift
// Dental Portfolio - User Profile and Settings Hub
//
// This view serves as the main settings hub with user profile information,
// comprehensive statistics, and navigation to all settings screens.
//
// Features:
// - Profile header card with profile photo or gradient avatar
// - Stats grid showing photos, portfolios, completion, ratings
// - Procedure breakdown with progress bars
// - Settings sections for portfolios, capture, notifications, data, about
// - Navigation to all settings subviews
//
// Contents:
// - ProfileView: Main profile/settings screen
// - EnhancedStatCard: Stat card with icon, value, label, detail
// - ProcedureBreakdownRow: Row showing procedure count and progress
// - SettingsSection: Grouped settings container
// - SettingsRow: Individual settings row with icon and chevron
// - PortfolioListSheet: Sheet wrapper for PortfolioListView
// - Placeholder views for settings subviews (to be implemented)
//
// Related Files:
// - EditProfileSheet.swift: Profile editing with photo picker

import SwiftUI
import Photos

// MARK: - ProfileView

/// Main profile view serving as the settings hub
struct ProfileView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared

    // MARK: - Navigation State

    @State private var showEditProfile: Bool = false
    @State private var showPortfolioList: Bool = false
    @State private var showProcedureManagement: Bool = false
    @State private var showCaptureSettings: Bool = false
    @State private var showNotificationSettings: Bool = false
    @State private var showDataManagement: Bool = false
    @State private var showAbout: Bool = false
    @State private var showHelp: Bool = false

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

    var averageRating: Double {
        var totalRating = 0
        var ratedCount = 0

        for (_, metadata) in metadataManager.assetMetadata {
            if let rating = metadata.rating, rating > 0 {
                totalRating += rating
                ratedCount += 1
            }
        }

        return ratedCount > 0 ? Double(totalRating) / Double(ratedCount) : 0
    }

    var procedureBreakdown: [(procedure: String, count: Int)] {
        var counts: [String: Int] = [:]

        for (_, metadata) in metadataManager.assetMetadata {
            if let procedure = metadata.procedure {
                counts[procedure, default: 0] += 1
            }
        }

        return counts
            .map { (procedure: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - User Info

    var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Dental Student"
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
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Profile header card
                    profileHeaderCard

                    // Stats grid
                    statsGrid

                    // Procedure breakdown (if photos exist)
                    if !procedureBreakdown.isEmpty {
                        procedureBreakdownSection
                    }

                    // Settings sections
                    portfolioSection
                    captureSection
                    notificationSection
                    dataSection
                    aboutSection

                    // App version footer
                    appVersionFooter

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            ensureUserCreatedDate()
        }
    }

    // MARK: - Profile Header Card

    var profileHeaderCard: some View {
        DPCard {
            VStack(spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Avatar with profile photo or gradient initials
                    ZStack {
                        if let imageData = UserDefaults.standard.data(forKey: "userProfileImage"),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Text(userInitials)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)

                    // User info
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(userName)
                            .font(AppTheme.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        if !userSchool.isEmpty {
                            Text(userSchool)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }

                        HStack(spacing: AppTheme.Spacing.sm) {
                            if !userClassYear.isEmpty {
                                Label("Class of \(userClassYear)", systemImage: "graduationcap")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }

                        if !memberSince.isEmpty {
                            Text(memberSince)
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }

                    Spacer()
                }

                // Edit profile button
                Button(action: { showEditProfile = true }) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("Edit Profile")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Stats Grid

    var statsGrid: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                EnhancedStatCard(
                    icon: "photo.fill",
                    iconColor: AppTheme.Colors.primary,
                    value: "\(photoCount)",
                    label: "Total Photos",
                    detail: "\(taggedPhotoCount) tagged"
                )

                EnhancedStatCard(
                    icon: "folder.fill",
                    iconColor: .orange,
                    value: "\(portfolioCount)",
                    label: "Portfolios",
                    detail: "\(activePortfolioCount) active"
                )
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                EnhancedStatCard(
                    icon: "chart.pie.fill",
                    iconColor: AppTheme.Colors.success,
                    value: "\(Int(overallCompletionRate * 100))%",
                    label: "Completion",
                    detail: "Overall progress"
                )

                EnhancedStatCard(
                    icon: "star.fill",
                    iconColor: .yellow,
                    value: averageRating > 0 ? String(format: "%.1f", averageRating) : "—",
                    label: "Avg Rating",
                    detail: averageRating > 0 ? "Out of 5 stars" : "No ratings yet"
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Procedure Breakdown Section

    var procedureBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("PHOTO BREAKDOWN")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            DPCard(padding: AppTheme.Spacing.md) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(procedureBreakdown.prefix(5), id: \.procedure) { item in
                        ProcedureBreakdownRow(
                            procedure: item.procedure,
                            count: item.count,
                            total: taggedPhotoCount
                        )
                    }

                    if procedureBreakdown.count > 5 {
                        Text("+ \(procedureBreakdown.count - 5) more procedures")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, AppTheme.Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Settings Sections

    var portfolioSection: some View {
        SettingsSection(title: "PORTFOLIOS") {
            SettingsRow(
                icon: "folder.fill",
                iconColor: .orange,
                title: "Manage Portfolios",
                subtitle: portfolioCount > 0 ? "\(portfolioCount) portfolio\(portfolioCount == 1 ? "" : "s")" : "Create and track portfolios",
                action: { showPortfolioList = true }
            )
        }
    }

    var captureSection: some View {
        SettingsSection(title: "CAPTURE") {
            SettingsRow(
                icon: "camera.fill",
                iconColor: AppTheme.Colors.primary,
                title: "Capture Settings",
                subtitle: "Camera and save options",
                action: { showCaptureSettings = true }
            )

            Divider()
                .padding(.leading, 56)

            SettingsRow(
                icon: "tag.fill",
                iconColor: .purple,
                title: "Manage Procedures",
                subtitle: "Customize procedure list and colors",
                action: { showProcedureManagement = true }
            )
        }
    }

    var notificationSection: some View {
        SettingsSection(title: "NOTIFICATIONS") {
            SettingsRow(
                icon: "bell.fill",
                iconColor: .red,
                title: "Notifications",
                subtitle: "Due date and reminder settings",
                action: { showNotificationSettings = true }
            )
        }
    }

    var dataSection: some View {
        SettingsSection(title: "DATA & STORAGE") {
            SettingsRow(
                icon: "externaldrive.fill",
                iconColor: .gray,
                title: "Data Management",
                subtitle: "Export, backup, and storage",
                action: { showDataManagement = true }
            )
        }
    }

    var aboutSection: some View {
        SettingsSection(title: "ABOUT") {
            SettingsRow(
                icon: "info.circle.fill",
                iconColor: AppTheme.Colors.primary,
                title: "About Dental Portfolio",
                subtitle: "Version \(appVersion)",
                action: { showAbout = true }
            )

            Divider()
                .padding(.leading, 56)

            SettingsRow(
                icon: "questionmark.circle.fill",
                iconColor: AppTheme.Colors.success,
                title: "Help & Support",
                subtitle: "Get help and send feedback",
                action: { showHelp = true }
            )

            Divider()
                .padding(.leading, 56)

            SettingsRow(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Rate This App",
                subtitle: "Love Dental Portfolio? Leave a review!",
                action: { requestAppStoreReview() }
            )
        }
    }

    var appVersionFooter: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Dental Portfolio v\(appVersion)")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)

            Text("Made with ❤️ for dental students")
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }

    // MARK: - Helper Functions

    func ensureUserCreatedDate() {
        if UserDefaults.standard.object(forKey: "userCreatedDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "userCreatedDate")
        }
    }

    func requestAppStoreReview() {
        // Trigger App Store review request
        HapticsManager.shared.success()
        // Note: In production, use SKStoreReviewController.requestReview()
    }
}

// MARK: - EnhancedStatCard

/// Enhanced stat card with icon, value, label, and detail text
struct EnhancedStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                if let detail = detail {
                    Text(detail)
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - ProcedureBreakdownRow

/// Row showing procedure name, count, and progress bar
struct ProcedureBreakdownRow: View {
    let procedure: String
    let count: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var procedureColor: Color {
        MetadataManager.shared.procedureColor(for: procedure)
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Procedure color indicator
            Circle()
                .fill(procedureColor)
                .frame(width: 10, height: 10)

            // Procedure name
            Text(procedure)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            // Count
            Text("\(count)")
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.Colors.surfaceSecondary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(procedureColor)
                        .frame(width: geometry.size.width * percentage, height: 4)
                }
            }
            .frame(width: 60, height: 4)
        }
    }
}

// MARK: - SettingsSection

/// Container for grouped settings rows with header
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)
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

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(isPressed ? AppTheme.Colors.surfaceSecondary : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
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
                        .foregroundColor(AppTheme.Colors.primary)
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

struct EnhancedStatCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            EnhancedStatCard(
                icon: "photo.fill",
                iconColor: AppTheme.Colors.primary,
                value: "156",
                label: "Total Photos",
                detail: "42 tagged"
            )

            EnhancedStatCard(
                icon: "folder.fill",
                iconColor: .orange,
                value: "5",
                label: "Portfolios",
                detail: "2 active"
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
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
