// AccessibilityLabels.swift
// Dental Portfolio - Accessibility Label Generators
//
// Helper functions for generating consistent accessibility labels.
// Provides semantic descriptions for all app elements.
//
// Contents:
// - Photo labels
// - Portfolio labels
// - Requirement labels
// - Button labels
// - Rating labels
// - Date labels
// - Tab labels
// - Stats labels

import SwiftUI

// MARK: - Accessibility Label Helpers

/// Central location for generating accessibility labels
struct AccessibilityLabels {

    // MARK: - Photo Labels

    /// Generate accessibility label for a photo
    /// - Parameters:
    ///   - procedure: The procedure type (e.g., "Class I")
    ///   - stage: The stage (e.g., "Pre-op")
    ///   - angle: The angle (e.g., "Buccal")
    ///   - rating: Star rating (1-5)
    ///   - date: Date the photo was taken
    /// - Returns: Complete accessibility label
    static func photoLabel(
        procedure: String?,
        stage: String?,
        angle: String?,
        rating: Int?,
        date: Date?
    ) -> String {
        var components: [String] = []

        if let procedure = procedure, !procedure.isEmpty {
            components.append("\(procedure) procedure")
        }

        if let stage = stage, !stage.isEmpty {
            components.append("\(stage) stage")
        }

        if let angle = angle, !angle.isEmpty {
            components.append("\(angle) angle")
        }

        if let rating = rating, rating > 0 {
            components.append("\(rating) star\(rating == 1 ? "" : "s")")
        }

        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            components.append("taken \(formatter.string(from: date))")
        }

        if components.isEmpty {
            return "Photo, no tags"
        }

        return "Photo: " + components.joined(separator: ", ")
    }

    /// Generate hint for photo actions
    static func photoHint(hasDetails: Bool = true) -> String {
        if hasDetails {
            return "Double tap to view photo details"
        }
        return "Double tap to select"
    }

    // MARK: - Portfolio Labels

    /// Generate accessibility label for a portfolio
    /// - Parameters:
    ///   - name: Portfolio name
    ///   - progress: Progress value (0.0 to 1.0)
    ///   - dueDate: Due date if any
    ///   - isOverdue: Whether past due date
    /// - Returns: Complete accessibility label
    static func portfolioLabel(
        name: String,
        progress: Double,
        dueDate: Date?,
        isOverdue: Bool
    ) -> String {
        var label = "\(name) portfolio, \(Int(progress * 100)) percent complete"

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium

            if isOverdue {
                label += ", overdue since \(formatter.string(from: dueDate))"
            } else {
                label += ", due \(formatter.string(from: dueDate))"
            }
        }

        return label
    }

    /// Generate hint for portfolio actions
    static func portfolioHint(isComplete: Bool) -> String {
        if isComplete {
            return "Double tap to view completed portfolio"
        }
        return "Double tap to view portfolio details and track progress"
    }

    // MARK: - Requirement Labels

    /// Generate accessibility label for a requirement
    /// - Parameters:
    ///   - procedure: Procedure name
    ///   - fulfilled: Number of photos captured
    ///   - required: Number of photos required
    /// - Returns: Complete accessibility label
    static func requirementLabel(
        procedure: String,
        fulfilled: Int,
        required: Int
    ) -> String {
        let remaining = required - fulfilled

        if remaining <= 0 {
            return "\(procedure), complete, \(fulfilled) of \(required) photos"
        }

        return "\(procedure), \(fulfilled) of \(required) photos, \(remaining) remaining"
    }

    /// Generate hint for requirement actions
    static func requirementHint(isComplete: Bool) -> String {
        if isComplete {
            return "Double tap to view photos"
        }
        return "Double tap to capture photos for this requirement"
    }

    // MARK: - Button Labels

    /// Generate accessibility label for capture button
    /// - Parameters:
    ///   - hasPresets: Whether capture has preset values
    ///   - procedure: Preset procedure if any
    /// - Returns: Accessibility label
    static func captureButtonLabel(hasPresets: Bool, procedure: String?) -> String {
        if hasPresets, let procedure = procedure {
            return "Capture photo for \(procedure)"
        }
        return "Capture photo"
    }

    /// Generate label for action buttons
    static func actionButtonLabel(action: String, target: String? = nil) -> String {
        if let target = target {
            return "\(action) \(target)"
        }
        return action
    }

    // MARK: - Rating Labels

    /// Generate accessibility label for star rating
    /// - Parameters:
    ///   - rating: Current rating value
    ///   - maxRating: Maximum rating (default 5)
    /// - Returns: Accessibility label
    static func ratingLabel(rating: Int, maxRating: Int = 5) -> String {
        if rating == 0 {
            return "No rating"
        }
        return "\(rating) of \(maxRating) stars"
    }

    /// Generate hint for rating control
    static func ratingHint(currentRating: Int) -> String {
        if currentRating == 0 {
            return "Swipe up or down to set rating"
        }
        return "Swipe up to increase, down to decrease"
    }

    // MARK: - Date Labels

    /// Generate relative date description
    /// - Parameter date: The date to describe
    /// - Returns: Relative date string
    static func relativeDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0

            if days > 0 && days <= 7 {
                return "In \(days) day\(days == 1 ? "" : "s")"
            } else if days < 0 && days >= -7 {
                return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") ago"
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    /// Generate due date description
    /// - Parameters:
    ///   - date: Due date
    ///   - isOverdue: Whether past due
    /// - Returns: Due date label
    static func dueDateLabel(_ date: Date, isOverdue: Bool) -> String {
        let relative = relativeDateLabel(date)

        if isOverdue {
            return "Overdue, was due \(relative)"
        }
        return "Due \(relative)"
    }

    // MARK: - Tab Labels

    /// Generate accessibility label for tab bar item
    /// - Parameters:
    ///   - tab: The tab
    ///   - badgeCount: Number of notifications
    /// - Returns: Tab accessibility label
    static func tabLabel(tab: Tab, badgeCount: Int = 0) -> String {
        var label = tab.title

        if badgeCount > 0 {
            label += ", \(badgeCount) notification\(badgeCount == 1 ? "" : "s")"
        }

        return label
    }

    /// Generate hint for tab item
    static func tabHint(isSelected: Bool, tabName: String) -> String {
        if isSelected {
            return "Currently selected"
        }
        return "Double tap to switch to \(tabName)"
    }

    // MARK: - Stats Labels

    /// Generate accessibility label for a statistic
    /// - Parameters:
    ///   - value: The stat value
    ///   - label: What the stat represents
    ///   - detail: Additional detail
    /// - Returns: Stats accessibility label
    static func statLabel(value: String, label: String, detail: String? = nil) -> String {
        var result = "\(value) \(label)"

        if let detail = detail {
            result += ", \(detail)"
        }

        return result
    }

    // MARK: - Count Labels

    /// Generate label for item counts
    /// - Parameters:
    ///   - count: Number of items
    ///   - singular: Singular form (e.g., "photo")
    ///   - plural: Plural form (e.g., "photos")
    /// - Returns: Count label
    static func countLabel(count: Int, singular: String, plural: String? = nil) -> String {
        let pluralForm = plural ?? "\(singular)s"
        return "\(count) \(count == 1 ? singular : pluralForm)"
    }

    // MARK: - Selection Labels

    /// Generate label for selection state
    /// - Parameters:
    ///   - itemName: Name of the item
    ///   - isSelected: Whether selected
    /// - Returns: Selection label
    static func selectionLabel(itemName: String, isSelected: Bool) -> String {
        if isSelected {
            return "\(itemName), selected"
        }
        return itemName
    }

    /// Generate hint for selectable items
    static func selectionHint(isSelected: Bool) -> String {
        if isSelected {
            return "Double tap to deselect"
        }
        return "Double tap to select"
    }

    // MARK: - Filter Labels

    /// Generate label for filter state
    /// - Parameters:
    ///   - filterName: Name of the filter
    ///   - isActive: Whether filter is active
    ///   - resultCount: Number of results
    /// - Returns: Filter label
    static func filterLabel(filterName: String, isActive: Bool, resultCount: Int? = nil) -> String {
        var label = "\(filterName) filter"

        if isActive {
            label += ", active"
        }

        if let count = resultCount {
            label += ", \(count) result\(count == 1 ? "" : "s")"
        }

        return label
    }

    // MARK: - Loading/State Labels

    /// Generate label for loading state
    static func loadingLabel(context: String? = nil) -> String {
        if let context = context {
            return "Loading \(context)"
        }
        return "Loading"
    }

    /// Generate label for error state
    static func errorLabel(message: String) -> String {
        return "Error: \(message)"
    }

    /// Generate label for empty state
    static func emptyLabel(context: String) -> String {
        return "No \(context) available"
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AccessibilityLabels_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Photo Labels").font(.headline)

                    Text(AccessibilityLabels.photoLabel(
                        procedure: "Class I",
                        stage: "Pre-op",
                        angle: "Buccal",
                        rating: 4,
                        date: Date()
                    ))
                    .font(.caption)
                }

                Divider()

                Group {
                    Text("Portfolio Labels").font(.headline)

                    Text(AccessibilityLabels.portfolioLabel(
                        name: "Fall 2024",
                        progress: 0.75,
                        dueDate: Date().addingTimeInterval(86400 * 7),
                        isOverdue: false
                    ))
                    .font(.caption)
                }

                Divider()

                Group {
                    Text("Requirement Labels").font(.headline)

                    Text(AccessibilityLabels.requirementLabel(
                        procedure: "Class II",
                        fulfilled: 3,
                        required: 5
                    ))
                    .font(.caption)
                }

                Divider()

                Group {
                    Text("Rating Labels").font(.headline)

                    Text(AccessibilityLabels.ratingLabel(rating: 4))
                        .font(.caption)
                }

                Divider()

                Group {
                    Text("Date Labels").font(.headline)

                    Text(AccessibilityLabels.relativeDateLabel(Date()))
                        .font(.caption)

                    Text(AccessibilityLabels.dueDateLabel(
                        Date().addingTimeInterval(86400 * 3),
                        isOverdue: false
                    ))
                    .font(.caption)
                }
            }
            .padding()
        }
    }
}
#endif
