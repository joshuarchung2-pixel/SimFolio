// CaptureSettingsView.swift
// Dental Portfolio - Capture Settings Configuration
//
// Settings for camera capture, haptics, sounds, and tagging behavior.

import SwiftUI

// MARK: - CaptureSettingsView

/// Settings view for configuring capture behavior
struct CaptureSettingsView: View {

    // MARK: - Camera Settings

    @AppStorage("showGridLines") private var showGridLines = true
    @AppStorage("defaultFlashMode") private var defaultFlashMode = "Auto"

    // MARK: - Feedback Settings

    @AppStorage("captureHaptics") private var captureHaptics = true
    @AppStorage("captureSound") private var captureSound = true

    // MARK: - Tagging Settings

    @AppStorage("preCaptureTagging") private var preCaptureTagging = true
    @AppStorage("rememberLastTags") private var rememberLastTags = true

    // MARK: - Saving Settings

    @AppStorage("autoSaveToLibrary") private var autoSaveToLibrary = true
    @AppStorage("imageQuality") private var imageQuality = "High"

    // MARK: - Flash Options

    private let flashOptions = ["Auto", "On", "Off"]

    // MARK: - Quality Options

    private let qualityOptions = ["Maximum", "High", "Medium"]

    // MARK: - Body

    var body: some View {
        List {
            // Camera Section
            cameraSection

            // Feedback Section
            feedbackSection

            // Tagging Section
            taggingSection

            // Saving Section
            savingSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Capture Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        Section {
            // Grid Lines Toggle
            Toggle(isOn: $showGridLines) {
                SettingLabel(
                    icon: "grid",
                    title: "Grid Lines",
                    subtitle: "Show composition grid overlay"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Default Flash Picker
            HStack {
                SettingLabel(
                    icon: "bolt.fill",
                    title: "Default Flash",
                    subtitle: nil
                )

                Spacer()

                Picker("Flash", selection: $defaultFlashMode) {
                    ForEach(flashOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primary)
            }
        } header: {
            Text("Camera")
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        Section {
            // Haptic Feedback Toggle
            Toggle(isOn: $captureHaptics) {
                SettingLabel(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback",
                    subtitle: "Vibrate on capture"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Capture Sound Toggle
            Toggle(isOn: $captureSound) {
                SettingLabel(
                    icon: "speaker.wave.2.fill",
                    title: "Capture Sound",
                    subtitle: "Play shutter sound"
                )
            }
            .tint(AppTheme.Colors.primary)
        } header: {
            Text("Feedback")
        }
    }

    // MARK: - Tagging Section

    private var taggingSection: some View {
        Section {
            // Pre-Capture Tagging Toggle
            Toggle(isOn: $preCaptureTagging) {
                SettingLabel(
                    icon: "tag.fill",
                    title: "Pre-Capture Tagging",
                    subtitle: "Set tags before taking photo"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Remember Last Tags Toggle
            Toggle(isOn: $rememberLastTags) {
                SettingLabel(
                    icon: "clock.arrow.circlepath",
                    title: "Remember Last Tags",
                    subtitle: "Auto-fill previous selections"
                )
            }
            .tint(AppTheme.Colors.primary)
        } header: {
            Text("Tagging")
        } footer: {
            Text("Pre-capture tagging lets you assign procedure, stage, and angle before capturing. Remember last tags will pre-fill your previous selections.")
        }
    }

    // MARK: - Saving Section

    private var savingSection: some View {
        Section {
            // Auto-Save Toggle
            Toggle(isOn: $autoSaveToLibrary) {
                SettingLabel(
                    icon: "square.and.arrow.down.fill",
                    title: "Auto-Save to Photos",
                    subtitle: "Save captures to photo library"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Image Quality Picker
            HStack {
                SettingLabel(
                    icon: "photo.fill",
                    title: "Image Quality",
                    subtitle: nil
                )

                Spacer()

                Picker("Quality", selection: $imageQuality) {
                    ForEach(qualityOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primary)
            }
        } header: {
            Text("Saving")
        } footer: {
            Text("Higher quality images take more storage space. Maximum quality preserves full resolution.")
        }
    }
}

// MARK: - SettingLabel

/// Reusable label component for settings rows
struct SettingLabel: View {

    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CaptureSettingsView()
    }
}
