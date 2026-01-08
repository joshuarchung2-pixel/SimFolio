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

    /// Available procedure types (legacy - for backward compatibility)
    @Published var procedures: [String] = []

    /// Procedure configurations with colors and settings
    @Published var procedureConfigs: [ProcedureConfig] = []

    /// Asset ID -> PhotoMetadata mapping
    @Published var assetMetadata: [String: PhotoMetadata] = [:]

    /// Tooth history by procedure type
    @Published var toothHistory: [String: [ToothEntry]] = [:]

    // MARK: - Constants

    /// Base procedure types that cannot be deleted (legacy)
    static let baseProcedures = ["Class 1", "Class 2", "Class 3", "Crown"]

    /// Available stages for photos
    static let stages = ["Preparation", "Restoration"]

    /// Available angles for photos
    static let angles = ["Occlusal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load procedure configurations
        loadProcedures()

        // Update legacy procedures array for backward compatibility
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
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

    /// Get photo count for a requirement's procedure, stage, and angle
    /// - Parameters:
    ///   - requirement: The portfolio requirement
    ///   - stage: Stage to match
    ///   - angle: Angle to match
    /// - Returns: Number of matching photos
    func getPhotoCount(for requirement: PortfolioRequirement, stage: String, angle: String) -> Int {
        return getMatchingPhotoCount(procedure: requirement.procedure, stage: stage, angle: angle)
    }

    /// Add a new portfolio
    /// - Parameter portfolio: The portfolio to add
    func addPortfolio(_ portfolio: Portfolio) {
        portfolios.append(portfolio)
        // TODO: Persist to storage
    }

    /// Update an existing portfolio
    /// - Parameter portfolio: The updated portfolio (matched by id)
    func updatePortfolio(_ portfolio: Portfolio) {
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
            // TODO: Persist to storage
        }
    }

    /// Delete a portfolio by ID
    /// - Parameter portfolioId: The ID of the portfolio to delete
    func deletePortfolio(_ portfolioId: String) {
        portfolios.removeAll { $0.id == portfolioId }
        // TODO: Persist to storage
    }

    /// Get a portfolio by ID
    /// - Parameter portfolioId: The ID of the portfolio to find
    /// - Returns: The portfolio if found, nil otherwise
    func getPortfolio(by portfolioId: String) -> Portfolio? {
        return portfolios.first { $0.id == portfolioId }
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

    /// Get rating for an asset
    /// - Parameter assetId: The asset's local identifier
    /// - Returns: Rating (1-5) or nil if not rated
    func getRating(for assetId: String) -> Int? {
        return assetMetadata[assetId]?.rating
    }

    /// Set rating for an asset
    /// - Parameters:
    ///   - rating: Rating value (1-5) or nil to clear
    ///   - assetId: The asset's local identifier
    func setRating(_ rating: Int?, for assetId: String) {
        if var metadata = assetMetadata[assetId] {
            metadata.rating = rating
            assetMetadata[assetId] = metadata
        } else {
            // Create new metadata with just the rating
            var metadata = PhotoMetadata()
            metadata.rating = rating
            assetMetadata[assetId] = metadata
        }
    }

    // MARK: - Tooth Entry Methods

    /// Get tooth entries for a specific procedure
    /// - Parameter procedure: The procedure type
    /// - Returns: Array of tooth entries, sorted by date (most recent first)
    func getToothEntries(for procedure: String) -> [ToothEntry] {
        return (toothHistory[procedure] ?? []).sorted { $0.date > $1.date }
    }

    /// Add a new tooth entry
    /// - Parameter entry: The tooth entry to add
    func addToothEntry(_ entry: ToothEntry) {
        if toothHistory[entry.procedure] == nil {
            toothHistory[entry.procedure] = []
        }

        // Check if entry already exists
        if !toothHistory[entry.procedure]!.contains(where: { $0.id == entry.id }) {
            toothHistory[entry.procedure]!.append(entry)
        }
    }

    // MARK: - Procedure Configuration Management

    /// Load procedure configurations from UserDefaults
    func loadProcedures() {
        if let data = UserDefaults.standard.data(forKey: "procedureConfigs"),
           let decoded = try? JSONDecoder().decode([ProcedureConfig].self, from: data) {
            procedureConfigs = decoded.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            // Load defaults on first launch
            procedureConfigs = ProcedureConfig.defaultProcedures
            saveProcedures()
        }

        // Update legacy procedures array
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    /// Save procedure configurations to UserDefaults
    func saveProcedures() {
        if let encoded = try? JSONEncoder().encode(procedureConfigs) {
            UserDefaults.standard.set(encoded, forKey: "procedureConfigs")
        }

        // Update legacy procedures array
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    /// Add a new procedure configuration
    /// - Parameter procedure: The procedure configuration to add
    func addProcedure(_ procedure: ProcedureConfig) {
        var newProcedure = procedure
        newProcedure.sortOrder = (procedureConfigs.map { $0.sortOrder }.max() ?? -1) + 1
        procedureConfigs.append(newProcedure)
        saveProcedures()
    }

    /// Update an existing procedure configuration
    /// - Parameter procedure: The updated procedure (matched by id)
    func updateProcedure(_ procedure: ProcedureConfig) {
        if let index = procedureConfigs.firstIndex(where: { $0.id == procedure.id }) {
            procedureConfigs[index] = procedure
            saveProcedures()
        }
    }

    /// Delete a procedure configuration by ID
    /// - Parameter procedureId: The ID of the procedure to delete
    func deleteProcedure(_ procedureId: String) {
        procedureConfigs.removeAll { $0.id == procedureId }
        saveProcedures()
    }

    /// Reorder procedures via drag and drop
    /// - Parameters:
    ///   - source: Source indices
    ///   - destination: Destination index
    func reorderProcedures(from source: IndexSet, to destination: Int) {
        procedureConfigs.move(fromOffsets: source, toOffset: destination)

        // Update sort orders
        for (index, _) in procedureConfigs.enumerated() {
            procedureConfigs[index].sortOrder = index
        }

        saveProcedures()
    }

    /// Reset procedures to default configurations
    func resetToDefaults() {
        procedureConfigs = ProcedureConfig.defaultProcedures
        saveProcedures()
    }

    /// Get only enabled procedure configurations
    /// - Returns: Array of enabled procedures sorted by sort order
    func getEnabledProcedures() -> [ProcedureConfig] {
        procedureConfigs.filter { $0.isEnabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Get enabled procedure names (for use in pickers)
    /// - Returns: Array of enabled procedure names
    func getEnabledProcedureNames() -> [String] {
        getEnabledProcedures().map { $0.name }
    }

    /// Get color for a procedure by name
    /// - Parameter procedureName: The procedure name to look up
    /// - Returns: The procedure's color, or primary color if not found
    func procedureColor(for procedureName: String) -> Color {
        if let config = procedureConfigs.first(where: { $0.name.lowercased() == procedureName.lowercased() }) {
            return config.color
        }
        return AppTheme.Colors.primary
    }

    /// Get procedure configuration by name
    /// - Parameter name: The procedure name to find
    /// - Returns: The procedure config if found
    func getProcedure(byName name: String) -> ProcedureConfig? {
        procedureConfigs.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Data Management

    /// Clear all photo metadata (keeps portfolios and procedures)
    func clearAllMetadata() {
        assetMetadata.removeAll()
        toothHistory.removeAll()

        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "assetMetadata")
        UserDefaults.standard.removeObject(forKey: "toothHistory")
    }

    /// Reset all app data to defaults
    func resetAllData() {
        // Clear metadata
        assetMetadata.removeAll()
        toothHistory.removeAll()

        // Clear portfolios
        portfolios.removeAll()

        // Reset procedures to defaults
        procedureConfigs = ProcedureConfig.defaultProcedures
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }

        // Clear all UserDefaults keys related to the app
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "assetMetadata")
        defaults.removeObject(forKey: "toothHistory")
        defaults.removeObject(forKey: "portfolios")
        defaults.removeObject(forKey: "procedureConfigs")

        // Clear profile data
        defaults.removeObject(forKey: "userFirstName")
        defaults.removeObject(forKey: "userLastName")
        defaults.removeObject(forKey: "userSchool")
        defaults.removeObject(forKey: "userClassYear")
        defaults.removeObject(forKey: "profileImageData")

        // Reset capture settings
        defaults.removeObject(forKey: "showGridLines")
        defaults.removeObject(forKey: "defaultFlashMode")
        defaults.removeObject(forKey: "captureHaptics")
        defaults.removeObject(forKey: "captureSound")
        defaults.removeObject(forKey: "preCaptureTagging")
        defaults.removeObject(forKey: "rememberLastTags")
        defaults.removeObject(forKey: "autoSaveToLibrary")
        defaults.removeObject(forKey: "imageQuality")

        // Reset notification settings
        defaults.removeObject(forKey: "notificationsEnabled")
        defaults.removeObject(forKey: "dailyReminder")
        defaults.removeObject(forKey: "dailyReminderTime")
        defaults.removeObject(forKey: "weeklyProgress")
        defaults.removeObject(forKey: "portfolioMilestones")
        defaults.removeObject(forKey: "incompleteTagsReminder")

        // Synchronize
        defaults.synchronize()

        // Reload default procedures
        saveProcedures()
    }
}
