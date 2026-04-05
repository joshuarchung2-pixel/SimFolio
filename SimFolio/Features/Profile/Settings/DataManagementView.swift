// DataManagementView.swift
// SimFolio - Data Management Settings
//
// Settings for data export, backup, and storage management.

import SwiftUI

// MARK: - DataManagementView

/// Settings view for data management, export, and storage
struct DataManagementView: View {

    // MARK: - Environment

    @ObservedObject private var metadataManager = MetadataManager.shared

    // MARK: - State

    @State private var showingExportSheet = false
    @State private var showingClearConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var analyticsEnabled: Bool = AnalyticsService.analyticsEnabled
    @State private var showDeleteConfirmation = false
    @State private var showSubscriptionWarning = false
    @State private var isDeletingAccount = false
    @State private var showDeletionComplete = false

    // MARK: - Computed Properties

    private var totalPhotos: Int {
        metadataManager.assetMetadata.count
    }

    private var taggedPhotos: Int {
        metadataManager.assetMetadata.values.filter { metadata in
            metadata.procedure != nil
        }.count
    }

    private var storageUsed: String {
        // Estimate based on metadata entries
        let estimatedBytes = metadataManager.assetMetadata.count * 500 // ~500 bytes per entry
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .file)
    }

    // MARK: - Body

    var body: some View {
        List {
            // Privacy Section
            privacySection

            // Storage Info Section
            storageSection

            // Export Section
            exportSection

            // Danger Zone Section
            dangerZoneSection

            // Account Deletion Section
            if AuthenticationService.shared.authState == .signedIn {
                Section {
                    Button(role: .destructive) {
                        if SubscriptionManager.shared.isSubscribed {
                            showSubscriptionWarning = true
                        } else {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Active Subscription", isPresented: $showSubscriptionWarning) {
            Button("Manage Subscription") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Delete Anyway", role: .destructive) {
                showDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have an active subscription. Deleting your account won't cancel your subscription — you'll need to cancel it separately through Apple. Your billing will continue until you cancel.")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task { await performAccountDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account and all associated data (posts, comments, photos) will be permanently deleted within 24-48 hours. This cannot be undone.")
        }
        .alert("Account Deleted", isPresented: $showDeletionComplete) {
            Button("OK") {}
        } message: {
            Text("Your account and all associated data have been permanently deleted.")
        }
        .alert("Clear All Metadata", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllMetadata()
            }
        } message: {
            Text("This will remove all photo tags and metadata. Your photos will remain in your library but will need to be re-tagged. This cannot be undone.")
        }
        .alert("Reset App", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will clear all data including portfolios, procedures, profile information, and photo metadata. This cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            // Analytics Toggle
            Toggle(isOn: $analyticsEnabled) {
                SettingLabel(
                    icon: "chart.bar.fill",
                    title: "Analytics & Crash Reports",
                    subtitle: "Help improve SimFolio"
                )
            }
            .tint(AppTheme.Colors.primary)
            .onChange(of: analyticsEnabled) { newValue in
                AnalyticsService.setAnalyticsEnabled(newValue)
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("When enabled, anonymous usage data and crash reports are sent to help us improve the app. No personal data is collected.")
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            // Total Photos
            HStack {
                SettingLabel(
                    icon: "photo.on.rectangle",
                    title: "Total Photos",
                    subtitle: nil
                )
                Spacer()
                Text("\(totalPhotos)")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Tagged Photos
            HStack {
                SettingLabel(
                    icon: "tag.fill",
                    title: "Tagged Photos",
                    subtitle: nil
                )
                Spacer()
                Text("\(taggedPhotos)")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Metadata Storage
            HStack {
                SettingLabel(
                    icon: "internaldrive.fill",
                    title: "Metadata Storage",
                    subtitle: nil
                )
                Spacer()
                Text(storageUsed)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        } header: {
            Text("Storage")
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            // Export Metadata
            Button {
                exportMetadata()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Metadata",
                        subtitle: "Save tags as JSON file"
                    )
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isExporting)

            // Export Portfolios
            Button {
                exportPortfolios()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "folder.fill",
                        title: "Export Portfolios",
                        subtitle: "Save portfolio configurations"
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Export")
        } footer: {
            Text("Exported data can be used for backup or transferred to another device.")
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        Section {
            // Clear Metadata
            Button {
                showingClearConfirmation = true
            } label: {
                HStack {
                    SettingLabel(
                        icon: "trash.fill",
                        title: "Clear All Metadata",
                        subtitle: "Remove all photo tags"
                    )
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.error)

            // Reset App
            Button {
                showingResetConfirmation = true
            } label: {
                HStack {
                    SettingLabel(
                        icon: "exclamationmark.triangle.fill",
                        title: "Reset App",
                        subtitle: "Clear all data and settings"
                    )
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.error)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("These actions cannot be undone. Make sure to export your data first if you want to keep it.")
        }
    }

    // MARK: - Actions

    private func exportMetadata() {
        isExporting = true

        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Create export data
            let exportData = ExportData(
                exportDate: Date(),
                metadata: metadataManager.assetMetadata,
                toothHistory: metadataManager.toothHistory
            )

            if let jsonData = try? JSONEncoder().encode(exportData) {
                // Save to temporary file
                let fileName = "simfolio_metadata_\(dateString).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

                do {
                    try jsonData.write(to: tempURL)
                    exportURL = tempURL
                    showingShareSheet = true
                } catch {
                    Task { @MainActor in
                        ErrorHandler.shared.handle(.exportFailed(error.localizedDescription))
                    }
                }
            }

            isExporting = false
        }
    }

    private func exportPortfolios() {
        let portfolioData = PortfolioExportData(
            exportDate: Date(),
            portfolios: metadataManager.portfolios,
            procedures: metadataManager.procedureConfigs
        )

        if let jsonData = try? JSONEncoder().encode(portfolioData) {
            let fileName = "simfolio_config_\(dateString).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try jsonData.write(to: tempURL)
                exportURL = tempURL
                showingShareSheet = true
            } catch {
                Task { @MainActor in
                    ErrorHandler.shared.handle(.exportFailed(error.localizedDescription))
                }
            }
        }
    }

    private func clearAllMetadata() {
        metadataManager.clearAllMetadata()
    }

    private func resetApp() {
        metadataManager.resetAllData()
    }

    private func performAccountDeletion() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await AuthenticationService.shared.deleteAccount()
            UserProfileService.shared.clearProfile()
            AnalyticsService.logEvent(.accountDeleted)
            showDeletionComplete = true
        } catch {
            // Show error - could use existing error handling pattern
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Data Models

/// Container for metadata export
struct ExportData: Codable {
    let exportDate: Date
    let metadata: [String: PhotoMetadata]
    let toothHistory: [String: [ToothEntry]]
}

/// Container for portfolio export
struct PortfolioExportData: Codable {
    let exportDate: Date
    let portfolios: [Portfolio]
    let procedures: [ProcedureConfig]
}

// MARK: - ShareSheet

/// UIKit share sheet wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationView {
        DataManagementView()
    }
}
