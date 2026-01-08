// ToothEntry.swift
// Tooth entry model
//
// Represents a specific tooth worked on at a specific date.
// Used to group photos of the same tooth across stages and angles.
//
// Properties:
// - id: Computed from procedure + toothNumber + date (unique identifier)
// - procedure: The procedure type (e.g., "Class 1", "Crown")
// - toothNumber: Universal tooth numbering (1-32)
// - date: Date the work was performed
//
// Computed Properties:
// - dateString: Formatted date for display
// - displayString: "Tooth X - MM/DD/YY" format
//
// Usage:
// - Created when user enters a new tooth during capture
// - Stored in MetadataManager.toothHistory
// - Referenced by PhotoMetadata.toothEntry

import Foundation

struct ToothEntry: Codable, Hashable, Identifiable {
    var id: String { "\(procedure)-\(toothNumber)-\(dateString)" }
    let procedure: String
    let toothNumber: Int
    let date: Date

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    var displayString: String {
        "Tooth \(toothNumber) - \(dateString)"
    }
}
