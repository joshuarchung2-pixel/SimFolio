// PhotoMetadata.swift
// Photo metadata model
//
// Stores all tagging information for a captured photo.
// Persisted in MetadataManager.assetMetadata keyed by PHAsset.localIdentifier.
//
// Properties:
// - procedure: Optional procedure type (e.g., "Class 1", "Crown")
// - toothNumber: Optional tooth number (1-32)
// - toothDate: Optional date of the procedure
// - stage: Optional stage ("Preparation" or "Restoration")
// - angle: Optional angle ("Occlusal", "Buccal/Facial", etc.)
// - rating: Optional 1-5 star rating
//
// Computed Properties:
// - toothEntry: Constructs a ToothEntry if procedure, toothNumber, and toothDate are set
// - isComplete: True if all required fields (procedure, toothNumber, toothDate, stage, angle) are set
// - summaryText: Human-readable summary for display (e.g., "Class 1 · #14 · Prep · Occlusal")
//
// Usage:
// - Created during photo capture with user-selected tags
// - Stored in MetadataManager, retrieved by asset ID
// - Used for filtering, grouping, and portfolio matching

import Foundation

struct PhotoMetadata: Codable, Equatable {
    var procedure: String?
    var toothNumber: Int?
    var toothDate: Date?
    var stage: String?  // "Preparation" or "Restoration"
    var angle: String?  // "Occlusal", "Buccal/Facial", etc.
    var rating: Int?    // 1-5 stars

    var toothEntry: ToothEntry? {
        guard let proc = procedure, let num = toothNumber, let date = toothDate else { return nil }
        return ToothEntry(procedure: proc, toothNumber: num, date: date)
    }

    var isComplete: Bool {
        procedure != nil && toothNumber != nil && toothDate != nil && stage != nil && angle != nil
    }

    var summaryText: String {
        var parts: [String] = []
        if let p = procedure { parts.append(p) }
        if let t = toothNumber { parts.append("#\(t)") }
        if let s = stage { parts.append(s == "Preparation" ? "Prep" : "Resto") }
        if let a = angle { parts.append(a) }
        return parts.isEmpty ? "Choose procedure" : parts.joined(separator: " · ")
    }
}
