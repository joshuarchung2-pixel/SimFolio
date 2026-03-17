// NotificationSettingsView.swift
// SimFolio - Notification Settings Configuration
//
// Settings view for due date reminder notifications.

import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsView

/// Settings view for configuring due date reminders
struct NotificationSettingsView: View {

    // MARK: - State

    @StateObject private var notificationManager = NotificationManager.shared
    @State private var systemPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionDeniedAlert = false
    @State private var showPremiumPaywall = false

    // MARK: - Body

    var body: some View {
        List {
            // Master Toggle Section
            masterToggleSection

            if notificationManager.dueDateRemindersEnabled {
                // Reminder Schedule Info Section
                reminderScheduleInfoSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications Disabled", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to receive reminders.")
        }
        .premiumGate(for: .dueDateReminders, showPaywall: $showPremiumPaywall)
        .onAppear {
            checkSystemPermission()
        }
    }

    // MARK: - System Permission

    /// Check the current system notification permission status
    private func checkSystemPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                systemPermissionStatus = settings.authorizationStatus
                // Sync app-level toggle with system permission
                if settings.authorizationStatus == .denied {
                    notificationManager.dueDateRemindersEnabled = false
                }
            }
        }
    }

    /// Request notification permission from the system
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationManager.requestPermission()
            await MainActor.run {
                checkSystemPermission()
                notificationManager.dueDateRemindersEnabled = granted
                if granted {
                    Task {
                        await notificationManager.rescheduleAllReminders()
                    }
                }
            }
        }
    }

    // MARK: - Master Toggle Section

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { notificationManager.dueDateRemindersEnabled },
                set: { newValue in
                    handleMasterToggleChange(newValue)
                }
            )) {
                HStack {
                    SettingLabel(
                        icon: "bell.fill",
                        title: "Due Date Reminders",
                        subtitle: systemPermissionStatus == .denied
                            ? "Disabled in System Settings"
                            : "Get reminded as portfolio deadlines approach"
                    )

                    if !SubscriptionManager.shared.isSubscribed {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
            .tint(AppTheme.Colors.primary)
        } footer: {
            if systemPermissionStatus == .denied {
                Text("Notifications are disabled in System Settings. Tap to open Settings and enable them.")
            } else if !notificationManager.dueDateRemindersEnabled {
                Text("Turn on due date reminders to receive notifications before portfolio deadlines.")
            }
        }
    }

    /// Handle master toggle changes with system permission awareness
    private func handleMasterToggleChange(_ newValue: Bool) {
        if newValue {
            // Check premium access first
            guard FeatureGateService.isAvailable(.dueDateReminders) else {
                AnalyticsService.logEvent(.paywallViewed, parameters: [
                    "trigger_feature": PremiumFeature.dueDateReminders.rawValue
                ])
                showPremiumPaywall = true
                return
            }

            switch systemPermissionStatus {
            case .notDetermined:
                // Request permission from system
                requestNotificationPermission()
            case .denied:
                // Show alert to direct user to Settings
                showingPermissionDeniedAlert = true
            case .authorized, .provisional, .ephemeral:
                // System permission granted, enable app-level preference
                notificationManager.dueDateRemindersEnabled = true
                Task {
                    await notificationManager.rescheduleAllReminders()
                }
            @unknown default:
                notificationManager.dueDateRemindersEnabled = true
                Task {
                    await notificationManager.rescheduleAllReminders()
                }
            }
        } else {
            // User is disabling - cancel all notifications
            notificationManager.dueDateRemindersEnabled = false
            notificationManager.cancelAllReminders()
        }
    }

    // MARK: - Reminder Schedule Info Section

    private var reminderScheduleInfoSection: some View {
        Section {
            ScheduleRow(icon: "30.circle.fill", text: "30 days before due date")
            ScheduleRow(icon: "7.circle.fill", text: "7 days before due date")
            ScheduleRow(icon: "calendar.badge.clock", text: "Daily when less than 7 days away")
            ScheduleRow(icon: "exclamationmark.circle.fill", text: "Once if overdue")
        } header: {
            Text("Reminder Schedule")
        } footer: {
            Text("Reminders are only sent for incomplete portfolios with due dates. Notifications are delivered at 9:00 AM.")
        }
    }
}

// MARK: - ScheduleRow

/// A row displaying a schedule item with an icon
private struct ScheduleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 28)

            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
