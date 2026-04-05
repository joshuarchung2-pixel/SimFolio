import SwiftUI

struct SchoolMigrationSheet: View {
    let onComplete: () -> Void

    @State private var selectedSchool: DentalSchool?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Header
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.Colors.primary)

                Text("Select Your School")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("We've updated our school list to help you connect with classmates.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AppTheme.Spacing.xl)
            .padding(.horizontal, AppTheme.Spacing.lg)

            SchoolPickerView { school in
                selectedSchool = school

                // Save to UserDefaults
                UserDefaults.standard.set(school.name, forKey: "userSchool")
                UserDefaults.standard.set(school.id, forKey: "userSchoolId")
                UserDefaults.standard.set(true, forKey: "hasCompletedSchoolMigration")

                // Update analytics
                AnalyticsService.setUserProperty(school.name, for: .schoolName)

                onComplete()
            }
        }
        .interactiveDismissDisabled(true)
    }
}
