// AboutView.swift
// Dental Portfolio - About & App Information
//
// App version, credits, support links, and legal information.

import SwiftUI

// MARK: - AboutView

/// About view with app information, credits, and support links
struct AboutView: View {

    // MARK: - Constants

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - State

    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
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
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentSheet(title: "Privacy Policy", content: privacyPolicyText)
        }
        .sheet(isPresented: $showingTermsOfService) {
            LegalDocumentSheet(title: "Terms of Service", content: termsOfServiceText)
        }
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsSheet()
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section {
            VStack(spacing: AppTheme.Spacing.md) {
                // App Icon
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.top, AppTheme.Spacing.md)

                // App Name
                Text("Dental Portfolio")
                    .font(AppTheme.Typography.title2)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                // Version
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                // Tagline
                Text("Document your dental work with precision")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
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
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
                showingPrivacyPolicy = true
            } label: {
                HStack {
                    SettingLabel(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Terms of Service
            Button {
                showingTermsOfService = true
            } label: {
                HStack {
                    SettingLabel(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
                        .foregroundColor(AppTheme.Colors.textTertiary)
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
                Text("Made with care for dental professionals")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("2025 Dental Portfolio")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Actions

    private func openEmail() {
        if let url = URL(string: "mailto:support@dentalportfolio.app") {
            UIApplication.shared.open(url)
        }
    }

    private func openAppStore() {
        // Replace with actual App Store ID when available
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id000000000?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func shareApp() {
        let text = "Check out Dental Portfolio - a great app for documenting dental procedures!"
        let url = URL(string: "https://apps.apple.com/app/id000000000")! // Replace with actual URL

        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Legal Text

    private var privacyPolicyText: String {
        """
        Privacy Policy

        Last updated: January 2025

        Your Privacy Matters

        Dental Portfolio is designed with your privacy in mind. All your photos and metadata are stored locally on your device and are never uploaded to our servers.

        Data Collection

        We do not collect, store, or transmit any personal information or photos from your device. Your dental procedure photos and associated metadata remain entirely on your device.

        Photo Library Access

        The app requests access to your photo library solely for the purpose of importing and organizing your dental procedure photos. This data is never shared with third parties.

        Analytics

        We may collect anonymous usage analytics to improve the app experience. This data cannot be used to identify you personally.

        Contact Us

        If you have questions about this privacy policy, please contact us at support@dentalportfolio.app
        """
    }

    private var termsOfServiceText: String {
        """
        Terms of Service

        Last updated: January 2025

        Acceptance of Terms

        By using Dental Portfolio, you agree to these terms of service.

        Use of the App

        Dental Portfolio is intended for personal use by dental professionals to document and organize their clinical work. You are responsible for ensuring that your use of the app complies with all applicable laws and professional regulations.

        Patient Privacy

        You are solely responsible for obtaining appropriate consent from patients before photographing dental procedures. The app does not automatically de-identify or anonymize images.

        Disclaimer

        The app is provided "as is" without warranties of any kind. We are not liable for any loss of data or other damages arising from use of the app.

        Changes to Terms

        We may update these terms from time to time. Continued use of the app constitutes acceptance of the updated terms.

        Contact Us

        If you have questions about these terms, please contact us at support@dentalportfolio.app
        """
    }
}

// MARK: - LegalDocumentSheet

/// Sheet for displaying legal documents
struct LegalDocumentSheet: View {

    @Environment(\.dismiss) private var dismiss

    let title: String
    let content: String

    var body: some View {
        NavigationView {
            ScrollView {
                Text(content)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(AppTheme.Spacing.md)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
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
                    Text("Dental Portfolio is built with the following open source technologies:")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
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
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text("who make these tools available.")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
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
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }

    private func acknowledgementRow(_ name: String, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
