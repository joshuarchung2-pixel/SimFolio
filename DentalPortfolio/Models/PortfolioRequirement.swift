// PortfolioRequirement.swift
// Portfolio requirement model
//
// Defines a specific photo requirement within a portfolio.
// Specifies what procedure, stages, and angles are needed.
//
// Properties:
// - id: Unique identifier (UUID string)
// - procedure: Required procedure type (e.g., "Class 1", "Crown")
// - stages: Required stages (e.g., ["Preparation", "Restoration"])
// - angles: Required angles (e.g., ["Occlusal", "Buccal/Facial"])
// - angleCounts: Number of photos needed per angle (defaults to 1)
//
// Computed Properties:
// - totalRequired: Total photos needed (stages.count * sum of angleCounts)
// - displayString: Human-readable summary (e.g., "Class 1 · Both Stages · All Angles")
//
// Usage:
// - Created when user adds a requirement to a portfolio
// - Used to calculate portfolio completion percentage
// - Matched against PhotoMetadata to find fulfilling photos

import Foundation

struct PortfolioRequirement: Codable, Identifiable, Hashable {
    let id: String
    var procedure: String           // e.g., "Class 1", "Crown"
    var stages: [String]            // e.g., ["Preparation", "Restoration"]
    var angles: [String]            // e.g., ["Occlusal", "Buccal/Facial"]
    var angleCounts: [String: Int]  // Per-angle photo counts, e.g., ["Occlusal": 2, "Buccal/Facial": 1]

    init(id: String = UUID().uuidString, procedure: String, stages: [String], angles: [String], angleCounts: [String: Int] = [:]) {
        self.id = id
        self.procedure = procedure
        self.stages = stages
        self.angles = angles
        // Default to 1 for any angle without a specified count
        var counts = angleCounts
        for angle in angles {
            if counts[angle] == nil {
                counts[angle] = 1
            }
        }
        self.angleCounts = counts
    }

    // Total number of photos required for this requirement
    var totalRequired: Int {
        var total = 0
        for angle in angles {
            let count = angleCounts[angle] ?? 1
            total += stages.count * count
        }
        return total
    }

    // Display string for the requirement
    var displayString: String {
        let stageText = stages.count == 2 ? "Both Stages" : stages.joined(separator: ", ")
        let angleText = angles.count == 7 ? "All Angles" : angles.joined(separator: ", ")
        return "\(procedure) · \(stageText) · \(angleText)"
    }
}
