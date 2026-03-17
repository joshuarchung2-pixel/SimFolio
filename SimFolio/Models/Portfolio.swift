// Portfolio.swift
// Portfolio data model
//
// Represents a collection of photo requirements for an assignment or project.
// Contains metadata about the portfolio and its requirements.
//
// Properties:
// - id: Unique identifier (UUID string)
// - name: Portfolio name (e.g., "Restorative Dentistry Final")
// - createdDate: When the portfolio was created
// - dueDate: Optional deadline for the portfolio
// - requirements: Array of PortfolioRequirement defining needed photos
// - notes: Optional notes about the portfolio
//
// Computed Properties:
// - dateString: Formatted creation date
// - dueDateString: Formatted due date (nil if no due date)
// - daysUntilDue: Days remaining until due date (nil if no due date)
// - isOverdue: True if past due date
// - isDueSoon: True if due within 7 days
//
// Usage:
// - Created by user in AddPortfolioSheet
// - Stored in MetadataManager.portfolios
// - Displayed in PortfoliosView with progress tracking
// - Triggers notifications via NotificationManager

import Foundation

struct Portfolio: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var createdDate: Date
    var dueDate: Date?
    var requirements: [PortfolioRequirement]
    var notes: String?

    init(id: String = UUID().uuidString, name: String, createdDate: Date = Date(), dueDate: Date? = nil, requirements: [PortfolioRequirement] = [], notes: String? = nil) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.dueDate = dueDate
        self.requirements = requirements
        self.notes = notes
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdDate)
    }

    var dueDateString: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }

    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDueDate = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day
    }

    var isOverdue: Bool {
        guard let days = daysUntilDue else { return false }
        return days < 0
    }

    var isDueSoon: Bool {
        guard let days = daysUntilDue else { return false }
        return days >= 0 && days <= 7
    }
}
