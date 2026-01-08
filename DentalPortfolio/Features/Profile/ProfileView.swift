// ProfileView.swift
// Dental Portfolio - User Profile and Settings
//
// This view displays user profile information, app stats, and settings.
// Key features:
// - Profile header with user avatar and info
// - Stats cards showing photos, portfolios, completion rate
// - Navigation to portfolio management
// - Settings sections for capture, notifications, data
//
// Contents:
// - ProfileView: Main profile screen
// - StatCard: Stat display card component
// - SettingsSection: Grouped settings container
// - SettingsRow: Individual settings row
// - EditProfileSheet: Form for editing profile
// - FormField: Reusable form input field

import SwiftUI

// MARK: - ProfileView

/// Main profile view with user info, stats, and settings
struct ProfileView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared

    @State private var showPortfolioList: Bool = false
    @State private var showEditProfile: Bool = false

    // MARK: - Computed Properties

    var photoCount: Int {
        library.assets.count
    }

    var portfolioCount: Int {
        metadataManager.portfolios.count
    }

    var completionRate: Int {
        let portfolios = metadataManager.portfolios
        guard !portfolios.isEmpty else { return 0 }

        var totalProgress: Double = 0
        for portfolio in portfolios {
            let stats = metadataManager.getPortfolioStats(portfolio)
            if stats.total > 0 {
                totalProgress += Double(stats.fulfilled) / Double(stats.total)
            }
        }

        return Int((totalProgress / Double(portfolios.count)) * 100)
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

    // MARK: - User Info (from UserDefaults)

    var userName: String {
        UserDefaults.standard.string(forKey: "userName") ?? "Dental Student"
    }

    var userSchool: String {
        UserDefaults.standard.string(forKey: "userSchool") ?? ""
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

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Profile header
                    profileHeader

                    // Stats section
                    statsSection

                    // Settings sections
                    settingsSections

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditProfile = true }) {
                        Text("Edit")
                            .font(AppTheme.Typography.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(isPresented: $showEditProfile)
            }
            .sheet(isPresented: $showPortfolioList) {
                NavigationView {
                    PortfolioListView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showPortfolioList = false
                                }
                            }
                        }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Profile Header

    var profileHeader: some View {
        DPCard {
            HStack(spacing: AppTheme.Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Text(userInitials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(userName)
                        .font(AppTheme.Typography.title3)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if !userSchool.isEmpty {
                        Text(userSchool)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    if let classYear = UserDefaults.standard.string(forKey: "userClassYear"), !classYear.isEmpty {
                        Text("Class of \(classYear)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Stats Section

    var statsSection: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileStatCard(
                icon: "photo.fill",
                iconColor: AppTheme.Colors.primary,
                value: "\(photoCount)",
                label: "Photos"
            )

            ProfileStatCard(
                icon: "folder.fill",
                iconColor: .orange,
                value: "\(portfolioCount)",
                label: "Portfolios"
            )

            ProfileStatCard(
                icon: "checkmark.circle.fill",
                iconColor: AppTheme.Colors.success,
                value: "\(completionRate)%",
                label: "Complete"
            )

            ProfileStatCard(
                icon: "star.fill",
                iconColor: .yellow,
                value: averageRating > 0 ? String(format: "%.1f", averageRating) : "-",
                label: "Avg Rating"
            )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Settings Sections

    var settingsSections: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Portfolios section
            ProfileSettingsSection(title: "PORTFOLIOS") {
                ProfileSettingsRow(
                    icon: "folder.fill",
                    iconColor: .orange,
                    title: "Manage Portfolios",
                    subtitle: "\(portfolioCount) portfolio\(portfolioCount == 1 ? "" : "s")",
                    action: { showPortfolioList = true }
                )
            }

            // Capture section
            ProfileSettingsSection(title: "CAPTURE") {
                ProfileSettingsRow(
                    icon: "camera.fill",
                    iconColor: AppTheme.Colors.primary,
                    title: "Capture Settings",
                    subtitle: "Camera preferences",
                    action: { /* Navigate to capture settings */ }
                )

                ProfileSettingsRow(
                    icon: "tag.fill",
                    iconColor: .purple,
                    title: "Procedures",
                    subtitle: "Manage procedure list",
                    action: { /* Navigate to procedures */ }
                )
            }

            // Notifications section
            ProfileSettingsSection(title: "NOTIFICATIONS") {
                ProfileSettingsRow(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Notification Settings",
                    subtitle: "Due date reminders",
                    action: { /* Navigate to notification settings */ }
                )
            }

            // Data section
            ProfileSettingsSection(title: "DATA") {
                ProfileSettingsRow(
                    icon: "externaldrive.fill",
                    iconColor: .gray,
                    title: "Data Management",
                    subtitle: "Export, backup, clear data",
                    action: { /* Navigate to data management */ }
                )
            }

            // About section
            ProfileSettingsSection(title: "ABOUT") {
                ProfileSettingsRow(
                    icon: "info.circle.fill",
                    iconColor: AppTheme.Colors.textSecondary,
                    title: "About",
                    subtitle: "Version 2.0.0",
                    action: { /* Navigate to about */ }
                )

                ProfileSettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: AppTheme.Colors.primary,
                    title: "Help & Support",
                    action: { /* Navigate to help */ }
                )
            }
        }
    }
}

// MARK: - ProfileStatCard

/// Compact stat card showing icon, value, and label
struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)

            Text(value)
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - ProfileSettingsSection

/// Container for grouped settings rows
struct ProfileSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.caption)
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

// MARK: - ProfileSettingsRow

/// Individual settings row with icon, title, subtitle, and action
struct ProfileSettingsRow: View {
    let icon: String
    var iconColor: Color = AppTheme.Colors.primary
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - EditProfileSheet

/// Sheet for editing user profile information
struct EditProfileSheet: View {
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var school: String = ""
    @State private var classYear: String = ""

    var userInitials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "DS"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Avatar preview
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Text(userInitials)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.top, AppTheme.Spacing.lg)

                    // Form fields
                    VStack(spacing: AppTheme.Spacing.md) {
                        ProfileFormField(label: "Name", text: $name, placeholder: "Your Name")
                        ProfileFormField(label: "School", text: $school, placeholder: "Dental School")
                        ProfileFormField(label: "Class Year", text: $classYear, placeholder: "2025", keyboardType: .numberPad)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    Spacer()
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    func loadProfile() {
        name = UserDefaults.standard.string(forKey: "userName") ?? ""
        school = UserDefaults.standard.string(forKey: "userSchool") ?? ""
        classYear = UserDefaults.standard.string(forKey: "userClassYear") ?? ""
    }

    func saveProfile() {
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(school, forKey: "userSchool")
        UserDefaults.standard.set(classYear, forKey: "userClassYear")
        HapticsManager.shared.success()
        isPresented = false
    }
}

// MARK: - ProfileFormField

/// Reusable form field with label and text input
struct ProfileFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)

            TextField(placeholder, text: $text)
                .font(AppTheme.Typography.body)
                .keyboardType(keyboardType)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(NavigationRouter())
    }
}

struct EditProfileSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileSheet(isPresented: .constant(true))
    }
}
#endif
