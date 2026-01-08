// MetadataManager.swift
// Metadata persistence and retrieval
//
// Will contain:
//
// MetadataManager (ObservableObject, singleton):
//
// Published State:
// - procedures: [String] - Available procedure types
// - toothHistory: [String: [ToothEntry]] - Procedure -> tooth entries
// - assetMetadata: [String: PhotoMetadata] - Asset ID -> metadata
// - folderColors: [String: String] - Procedure -> hex color
// - portfolios: [Portfolio] - All portfolios
//
// Constants:
// - baseProcedures: ["Class 1", "Class 2", "Class 3", "Crown"]
// - stages: ["Preparation", "Restoration"]
// - angles: ["Occlusal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]
// - defaultColors: Dictionary of procedure -> default color
//
// Procedure Management:
// - addProcedure(_:), deleteProcedure(_:), renameProcedure(_:to:)
// - canDeleteProcedure(_:), canRenameProcedure(_:)
// - photoCount(for:)
//
// Metadata Operations:
// - assignMetadata(_:to:), getMetadata(for:)
// - setRating(_:for:), getRating(for:)
// - movePhotos(assetIds:to:)
// - movePhotosWithMetadata(assetIds:to:toothEntry:stage:angle:)
// - deleteMetadata(for:)
// - getIncompleteAssetIds()
//
// Tooth Entry Management:
// - addToothEntry(_:), getToothEntries(for:)
//
// Folder Colors:
// - getFolderColor(for:), setFolderColor(_:for:)
//
// Portfolio Management:
// - addPortfolio(_:), updatePortfolio(_:), deletePortfolio(_:)
// - getPortfolio(by:)
// - addRequirement(to:requirement:), removeRequirement(from:requirementId:)
// - updateRequirement(in:requirement:)
// - getPhotoCount(for:stage:angle:), getMatchingAssetIDs(procedure:stage:angle:)
// - getFulfilledCount(for:), isRequirementFulfilled(_:)
// - getPortfolioStats(_:), getPortfolioCompletionPercentage(_:)
//
// Persistence:
// - Private save/load methods for UserDefaults
//
// Migration notes:
// - Extract MetadataManager from gem1 lines 1306-1749
// - Consider migrating from UserDefaults to SwiftData/CoreData
// - Add migration strategy for schema changes
// - Remove circular dependency with NotificationManager

import SwiftUI

// MARK: - MetadataManager

/// Central manager for photo metadata and portfolio storage
/// Singleton accessible via MetadataManager.shared
class MetadataManager: ObservableObject {

    // MARK: - Singleton

    static let shared = MetadataManager()

    // MARK: - Published State

    /// All portfolios
    @Published var portfolios: [Portfolio] = []

    /// Available procedure types
    @Published var procedures: [String] = []

    /// Asset ID -> PhotoMetadata mapping
    @Published var assetMetadata: [String: PhotoMetadata] = [:]

    // MARK: - Constants

    /// Base procedure types that cannot be deleted
    static let baseProcedures = ["Class 1", "Class 2", "Class 3", "Crown"]

    /// Available stages for photos
    static let stages = ["Preparation", "Restoration"]

    /// Available angles for photos
    static let angles = ["Occlusal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Data Loading (Placeholder)

    private func loadData() {
        // TODO: Load from UserDefaults or persistent storage
        // For now, initialize with base procedures
        procedures = Self.baseProcedures
    }

    // MARK: - Portfolio Methods

    /// Portfolio statistics tuple
    typealias PortfolioStats = (fulfilled: Int, total: Int)

    /// Get statistics for a portfolio (fulfilled vs total requirements)
    /// - Parameter portfolio: The portfolio to get stats for
    /// - Returns: Tuple of (fulfilled count, total required count)
    func getPortfolioStats(_ portfolio: Portfolio) -> PortfolioStats {
        var totalRequired = 0
        var fulfilledCount = 0

        for requirement in portfolio.requirements {
            let requiredForThis = requirement.totalRequired
            totalRequired += requiredForThis

            // Count matching photos for this requirement
            for stage in requirement.stages {
                for angle in requirement.angles {
                    let count = requirement.angleCounts[angle] ?? 1
                    let matchingPhotos = getMatchingPhotoCount(
                        procedure: requirement.procedure,
                        stage: stage,
                        angle: angle
                    )
                    fulfilledCount += min(matchingPhotos, count)
                }
            }
        }

        return (fulfilled: fulfilledCount, total: totalRequired)
    }

    /// Get completion percentage for a portfolio
    func getPortfolioCompletionPercentage(_ portfolio: Portfolio) -> Double {
        let stats = getPortfolioStats(portfolio)
        guard stats.total > 0 else { return 0.0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    /// Get number of fulfilled requirements for a portfolio
    func getFulfilledCount(for portfolio: Portfolio) -> Int {
        return getPortfolioStats(portfolio).fulfilled
    }

    /// Count photos matching specific criteria
    /// - Parameters:
    ///   - procedure: Procedure type to match
    ///   - stage: Stage to match
    ///   - angle: Angle to match
    /// - Returns: Number of matching photos
    func getMatchingPhotoCount(procedure: String, stage: String, angle: String) -> Int {
        return assetMetadata.values.filter { metadata in
            metadata.procedure == procedure &&
            metadata.stage == stage &&
            metadata.angle == angle
        }.count
    }

    // MARK: - Metadata Methods (Placeholder)

    /// Get asset IDs with incomplete metadata
    func getIncompleteAssetIds() -> [String] {
        // TODO: Implement actual logic
        return []
    }

    /// Get metadata for an asset
    func getMetadata(for assetId: String) -> PhotoMetadata? {
        return assetMetadata[assetId]
    }

    /// Get photo count for a procedure type
    /// - Parameter procedure: The procedure name
    /// - Returns: Number of photos with this procedure
    func photoCount(for procedure: String) -> Int {
        return assetMetadata.values.filter { $0.procedure == procedure }.count
    }
}
