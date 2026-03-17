// NotificationManager.swift
// SimFolio - Due Date Reminder System
//
// Handles scheduling and management of portfolio due date reminders.
// Simplified notification system that sends reminders at specific intervals:
// - 30 days before due
// - 7 days before due
// - Daily when < 7 days away (6, 5, 4, 3, 2, 1, 0 days)
// - Single overdue notification (1 day after due date)

import UserNotifications
import SwiftUI
import Combine

// MARK: - NotificationManager

/// Manages due date reminder notifications for portfolios
@MainActor
class NotificationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Published State

    /// Whether due date reminders are enabled (ON by default)
    @AppStorage("dueDateRemindersEnabled") var dueDateRemindersEnabled = true

    /// Whether system notification permission has been granted
    @Published var permissionGranted = false

    // MARK: - Constants

    /// Reminder days before due date
    private static let reminderDays: [Int] = [30, 7, 6, 5, 4, 3, 2, 1, 0]

    /// Days after due date to send overdue notification
    private static let overdueDays: Int = -1

    /// Maximum notifications to schedule (iOS limit is 64, leaving buffer)
    private static let maxNotifications: Int = 60

    /// Hour to send notifications (9 AM)
    private static let notificationHour: Int = 9
    private static let notificationMinute: Int = 0

    // MARK: - Initialization

    private init() {
        Task {
            await checkPermissionStatus()
        }
    }

    // MARK: - Permission Management

    /// Request notification permission from the user
    /// - Returns: Whether permission was granted
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted
            return granted
        } catch {
            #if DEBUG
            print("NotificationManager: Failed to request permission: \(error)")
            #endif
            permissionGranted = false
            return false
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    /// Schedule all reminders for a portfolio
    /// - Parameter portfolio: The portfolio to schedule reminders for
    func scheduleReminders(for portfolio: Portfolio) async {
        guard dueDateRemindersEnabled else { return }

        // Check permission status if not already granted (fixes race condition)
        if !permissionGranted {
            await checkPermissionStatus()
        }
        guard permissionGranted else { return }

        // Only schedule for incomplete portfolios with due dates
        guard let dueDate = portfolio.dueDate else { return }

        let stats = MetadataManager.shared.getPortfolioStats(portfolio)
        guard stats.fulfilled < stats.total else {
            // Portfolio is complete, cancel any existing reminders
            cancelReminders(for: portfolio.id)
            return
        }

        let missingPhotos = stats.total - stats.fulfilled
        let calendar = Calendar.current
        let now = Date()

        // Cancel existing reminders for this portfolio first
        cancelReminders(for: portfolio.id)

        // Calculate days until due
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDueDate = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0

        var scheduledRequests: [UNNotificationRequest] = []

        // Schedule reminders for each day in the schedule
        for daysBefore in Self.reminderDays {
            guard scheduledRequests.count < Self.maxNotifications else { break }

            // Calculate notification date
            let notificationDaysUntilDue = daysBefore
            let daysFromNow = daysUntilDue - notificationDaysUntilDue

            // Skip if notification date is in the past
            if daysFromNow < 0 { continue }

            // Create notification date at 9 AM
            guard let notificationDate = calendar.date(byAdding: .day, value: daysFromNow, to: startOfToday) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: notificationDate)
            components.hour = Self.notificationHour
            components.minute = Self.notificationMinute

            // Note: We don't skip "today" notifications even if past 9 AM.
            // iOS will handle past-time triggers appropriately, and skipping here
            // causes issues when rescheduleAllReminders() cancels existing notifications
            // that may have already fired or are about to fire.

            let content = createNotificationContent(
                portfolio: portfolio,
                daysRemaining: daysBefore,
                missingPhotos: missingPhotos
            )

            let identifier = notificationIdentifier(for: portfolio.id, daysRemaining: daysBefore)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            scheduledRequests.append(request)
        }

        // Schedule overdue notification if due date is in the future or today
        if daysUntilDue >= 0 {
            guard scheduledRequests.count < Self.maxNotifications else { return }

            // Schedule for 1 day after due date
            let daysFromNowForOverdue = daysUntilDue + 1

            guard let overdueDatee = calendar.date(byAdding: .day, value: daysFromNowForOverdue, to: startOfToday) else { return }
            var overdueComponents = calendar.dateComponents([.year, .month, .day], from: overdueDatee)
            overdueComponents.hour = Self.notificationHour
            overdueComponents.minute = Self.notificationMinute

            let overdueContent = createNotificationContent(
                portfolio: portfolio,
                daysRemaining: Self.overdueDays,
                missingPhotos: missingPhotos
            )

            let overdueIdentifier = notificationIdentifier(for: portfolio.id, daysRemaining: Self.overdueDays)
            let overdueTrigger = UNCalendarNotificationTrigger(dateMatching: overdueComponents, repeats: false)
            let overdueRequest = UNNotificationRequest(identifier: overdueIdentifier, content: overdueContent, trigger: overdueTrigger)

            scheduledRequests.append(overdueRequest)
        } else if daysUntilDue == -1 {
            // Due date was yesterday, schedule overdue notification for today
            // (iOS will handle if the time has already passed)
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: startOfToday)
            todayComponents.hour = Self.notificationHour
            todayComponents.minute = Self.notificationMinute

            let overdueContent = createNotificationContent(
                portfolio: portfolio,
                daysRemaining: Self.overdueDays,
                missingPhotos: missingPhotos
            )

            let overdueIdentifier = notificationIdentifier(for: portfolio.id, daysRemaining: Self.overdueDays)
            let overdueTrigger = UNCalendarNotificationTrigger(dateMatching: todayComponents, repeats: false)
            let overdueRequest = UNNotificationRequest(identifier: overdueIdentifier, content: overdueContent, trigger: overdueTrigger)

            scheduledRequests.append(overdueRequest)
        }
        // If more than 1 day overdue, no notifications are scheduled

        // Add all scheduled requests
        let center = UNUserNotificationCenter.current()
        for request in scheduledRequests {
            do {
                try await center.add(request)
                #if DEBUG
                print("NotificationManager: Scheduled reminder '\(request.identifier)'")
                #endif
            } catch {
                #if DEBUG
                print("NotificationManager: Failed to schedule '\(request.identifier)': \(error)")
                #endif
            }
        }
    }

    /// Cancel all reminders for a specific portfolio
    /// - Parameter portfolioId: The ID of the portfolio
    func cancelReminders(for portfolioId: String) {
        let center = UNUserNotificationCenter.current()

        // Generate all possible identifiers for this portfolio
        var identifiers: [String] = Self.reminderDays.map { days in
            notificationIdentifier(for: portfolioId, daysRemaining: days)
        }

        // Add overdue identifier
        identifiers.append(notificationIdentifier(for: portfolioId, daysRemaining: Self.overdueDays))

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        #if DEBUG
        print("NotificationManager: Cancelled reminders for portfolio '\(portfolioId)'")
        #endif
    }

    /// Cancel all pending notifications
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        #if DEBUG
        print("NotificationManager: Cancelled all reminders")
        #endif
    }

    /// Reschedule reminders for all incomplete portfolios
    func rescheduleAllReminders() async {
        guard SubscriptionManager.shared.isSubscribed else {
            cancelAllReminders()
            return
        }

        guard dueDateRemindersEnabled else {
            cancelAllReminders()
            return
        }

        if !permissionGranted {
            await checkPermissionStatus()
        }
        guard permissionGranted else { return }

        // Cancel all existing notifications first
        cancelAllReminders()

        // Get all incomplete portfolios with due dates
        let portfolios = MetadataManager.shared.portfolios
            .filter { portfolio in
                guard portfolio.dueDate != nil else { return false }
                let stats = MetadataManager.shared.getPortfolioStats(portfolio)
                return stats.fulfilled < stats.total
            }
            .sorted { p1, p2 in
                // Sort by due date (earliest first) to prioritize closer deadlines
                guard let d1 = p1.dueDate, let d2 = p2.dueDate else { return false }
                return d1 < d2
            }

        // Schedule reminders for each portfolio
        // The 60 notification cap is handled within scheduleReminders
        for portfolio in portfolios {
            await scheduleReminders(for: portfolio)
        }

        #if DEBUG
        print("NotificationManager: Rescheduled reminders for \(portfolios.count) portfolios")
        #endif
    }

    // MARK: - Private Helpers

    /// Create notification identifier
    private func notificationIdentifier(for portfolioId: String, daysRemaining: Int) -> String {
        return "portfolio_due_\(portfolioId)_\(daysRemaining)"
    }

    /// Create notification content
    private func createNotificationContent(
        portfolio: Portfolio,
        daysRemaining: Int,
        missingPhotos: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = portfolio.name
        content.sound = .default

        let photoText = missingPhotos == 1 ? "photo" : "photos"

        switch daysRemaining {
        case 30:
            content.body = "Due in 30 days. \(missingPhotos) \(photoText) remaining."
        case 7:
            content.body = "Due in 1 week! \(missingPhotos) \(photoText) still needed."
        case 6, 5, 4, 3, 2:
            content.body = "Due in \(daysRemaining) days! \(missingPhotos) \(photoText) still needed."
        case 1:
            content.body = "Due tomorrow! \(missingPhotos) \(photoText) still needed."
        case 0:
            content.body = "Due today! \(missingPhotos) \(photoText) still needed."
        case -1:
            content.body = "This portfolio is overdue! \(missingPhotos) \(photoText) still needed."
        default:
            content.body = "\(missingPhotos) \(photoText) remaining."
        }

        content.userInfo = [
            "type": "due_date_reminder",
            "portfolioId": portfolio.id
        ]

        return content
    }
}
