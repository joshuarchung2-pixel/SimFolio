// AboutView.swift
// SimFolio - About & App Information
//
// App version, credits, support links, and legal information.

import SwiftUI

// MARK: - AboutView

/// About view with app information, credits, and support links
struct AboutView: View {

    // MARK: - State

    @State private var showingAcknowledgements = false

    // MARK: - Body

    var body: some View {
        List {
            // App Info Section
            appInfoSection

            // Support Section
            supportSection

            // Legal Section
            legalSection

            // Credits Section
            creditsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsSheet()
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section {
            VStack(spacing: AppTheme.Spacing.md) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .padding(.top, AppTheme.Spacing.md)

                // App Name
                Text(AppVersion.appName)
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Version
                Text("Version \(AppVersion.fullVersion)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                // Environment badge (only show in non-App Store builds)
                if !AppVersion.isAppStore {
                    Text(AppVersion.environment)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppVersion.isDebug ? AppTheme.Colors.warning : .purple)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            (AppVersion.isDebug ? AppTheme.Colors.warning : Color.purple).opacity(0.1)
                        )
                        .cornerRadius(4)
                }

                // Tagline
                Text("Dental Portfolio Manager")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .padding(.bottom, AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            // Contact Support
            Button {
                openEmail()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "envelope.fill",
                        title: "Contact Support",
                        subtitle: "Get help with the app"
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Rate App
            Button {
                openAppStore()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "star.fill",
                        title: "Rate on App Store",
                        subtitle: "Share your feedback"
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Share App
            Button {
                shareApp()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "square.and.arrow.up.fill",
                        title: "Share App",
                        subtitle: "Tell your colleagues"
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Copy Support Info (for bug reports)
            Button {
                copySupportInfo()
            } label: {
                HStack {
                    SettingLabel(
                        icon: "doc.on.clipboard.fill",
                        title: "Copy Support Info",
                        subtitle: "For bug reports"
                    )
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Support")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            // Privacy Policy
            Button {
                if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/privacy.html") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    SettingLabel(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Terms of Service
            Button {
                if let url = URL(string: "https://joshuarchung2-pixel.github.io/SimFolio-legal/terms.html") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    SettingLabel(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Acknowledgements
            Button {
                showingAcknowledgements = true
            } label: {
                HStack {
                    SettingLabel(
                        icon: "heart.fill",
                        title: "Acknowledgements",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Legal")
        }
    }

    // MARK: - Credits Section

    private var creditsSection: some View {
        Section {
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Made with care for professionals")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)

                Text("2025 SimFolio")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Actions

    private func openEmail() {
        // Include support info for easier debugging
        let subject = "SimFolio Support"
        let body = "\n\n---\n\(AppVersion.copyableSupportInfo)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@simfolio.app?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    private func openAppStore() {
        AppVersion.openAppStoreForReview()
    }

    private func shareApp() {
        let text = "Check out SimFolio - the essential dental portfolio manager for students and professionals!"

        var items: [Any] = [text]
        if let url = AppVersion.appStoreURL {
            items.append(url)
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // For iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copySupportInfo() {
        UIPasteboard.general.string = AppVersion.copyableSupportInfo
    }
}

// MARK: - AcknowledgementsSheet

/// Sheet showing open source acknowledgements
struct AcknowledgementsSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("SimFolio is built with the following open source technologies:")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .listRowBackground(Color.clear)
                }

                Section("Apple Frameworks") {
                    acknowledgementRow("SwiftUI", description: "Modern UI framework")
                    acknowledgementRow("PhotosUI", description: "Photo library integration")
                    acknowledgementRow("AVFoundation", description: "Camera capture")
                    acknowledgementRow("CoreImage", description: "Image processing")
                }

                Section("Design") {
                    acknowledgementRow("SF Symbols", description: "Apple's icon library")
                }

                Section {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("Thank you to all the developers and designers")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        Text("who make these tools available.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
    }

    private func acknowledgementRow(_ name: String, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AboutView()
    }
}
