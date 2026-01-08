// NotificationSettingsView.swift
// Dental Portfolio - Notification Settings Configuration
//
// Settings for reminder notifications and portfolio progress alerts.

import SwiftUI

// MARK: - NotificationSettingsView

/// Settings view for configuring notifications
struct NotificationSettingsView: View {

    // MARK: - Notification Settings

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("dailyReminderTime") private var dailyReminderTime = defaultReminderTime
    @AppStorage("weeklyProgress") private var weeklyProgress = true
    @AppStorage("portfolioMilestones") private var portfolioMilestones = true
    @AppStorage("incompleteTagsReminder") private var incompleteTagsReminder = true

    // MARK: - State

    @State private var showingTimePicker = false

    // MARK: - Default Time

    private static var defaultReminderTime: Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    // MARK: - Body

    var body: some View {
        List {
            // Master Toggle Section
            masterToggleSection

            if notificationsEnabled {
                // Reminders Section
                remindersSection

                // Progress Section
                progressSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(selectedTime: $dailyReminderTime)
        }
    }

    // MARK: - Master Toggle Section

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                SettingLabel(
                    icon: "bell.fill",
                    title: "Enable Notifications",
                    subtitle: "Receive reminders and alerts"
                )
            }
            .tint(AppTheme.Colors.primary)
        } footer: {
            if !notificationsEnabled {
                Text("Turn on notifications to receive capture reminders and progress updates.")
            }
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        Section {
            // Daily Reminder Toggle
            Toggle(isOn: $dailyReminder) {
                SettingLabel(
                    icon: "clock.fill",
                    title: "Daily Reminder",
                    subtitle: "Remind to capture photos"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Reminder Time (only shown when daily reminder is on)
            if dailyReminder {
                Button {
                    showingTimePicker = true
                } label: {
                    HStack {
                        SettingLabel(
                            icon: "alarm.fill",
                            title: "Reminder Time",
                            subtitle: nil
                        )

                        Spacer()

                        Text(timeFormatter.string(from: dailyReminderTime))
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.primary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Incomplete Tags Reminder
            Toggle(isOn: $incompleteTagsReminder) {
                SettingLabel(
                    icon: "tag.slash.fill",
                    title: "Incomplete Tags",
                    subtitle: "Remind about untagged photos"
                )
            }
            .tint(AppTheme.Colors.primary)
        } header: {
            Text("Reminders")
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        Section {
            // Weekly Progress Toggle
            Toggle(isOn: $weeklyProgress) {
                SettingLabel(
                    icon: "chart.bar.fill",
                    title: "Weekly Progress",
                    subtitle: "Summary of your weekly activity"
                )
            }
            .tint(AppTheme.Colors.primary)

            // Portfolio Milestones Toggle
            Toggle(isOn: $portfolioMilestones) {
                SettingLabel(
                    icon: "flag.fill",
                    title: "Portfolio Milestones",
                    subtitle: "Celebrate completion progress"
                )
            }
            .tint(AppTheme.Colors.primary)
        } header: {
            Text("Progress Updates")
        } footer: {
            Text("Get notified when you reach portfolio milestones like 25%, 50%, 75%, and 100% completion.")
        }
    }
}

// MARK: - TimePickerSheet

/// Sheet for selecting reminder time
struct TimePickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTime: Date

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Reminder Time")
                    .font(AppTheme.Typography.title2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, AppTheme.Spacing.xl)

                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
