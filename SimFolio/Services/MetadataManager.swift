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
// - angles: ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]
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
import Combine
import Photos

// MARK: - MetadataManager

/// Central manager for photo metadata and portfolio storage
/// Singleton accessible via MetadataManager.shared
class MetadataManager: ObservableObject, MetadataManaging {

    // MARK: - Singleton

    static let shared = MetadataManager()

    // MARK: - Published State

    /// All portfolios
    @Published var portfolios: [Portfolio] = []

    /// Available procedure types (legacy - for backward compatibility)
    @Published var procedures: [String] = []

    /// Procedure configurations with colors and settings
    @Published var procedureConfigs: [ProcedureConfig] = []

    /// Stage configurations with colors and settings
    @Published var stageConfigs: [StageConfig] = []

    /// Asset ID -> PhotoMetadata mapping
    @Published var assetMetadata: [String: PhotoMetadata] = [:]

    /// Tooth history by procedure type
    @Published var toothHistory: [String: [ToothEntry]] = [:]

    // MARK: - Constants

    /// Base procedure types that cannot be deleted (legacy)
    static let baseProcedures = ["Class 1", "Class 2", "Class 3", "Crown"]

    /// Available stages for photos (legacy - for backward compatibility)
    /// Use getEnabledStageNames() instead for dynamic stages
    static var stages: [String] {
        shared.getEnabledStageNames()
    }

    /// Available angles for photos
    static let angles = ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]

    private let notificationDebouncer = DebouncedSaveManager(delay: 2.0)

    // MARK: - Initialization

    private init() {
        loadData()
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load procedure configurations
        loadProcedures()

        // Load stage configurations
        loadStages()

        // Load portfolios
        loadPortfolios()

        // Load asset metadata
        loadAssetMetadata()

        // Load tooth history
        loadToothHistory()

        // Update legacy procedures array for backward compatibility
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }

        // Clean up orphaned data from photos deleted before bug fix
        cleanupOrphanedData()
    }

    /// Remove metadata and edit states for photos that no longer exist in the photo library.
    /// Runs on a background task to avoid blocking app launch.
    private func cleanupOrphanedData() {
        Task {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else { return }

            let fetchResult = PHAsset.fetchAssets(with: nil)
            var existingIds = Set<String>()
            fetchResult.enumerateObjects { asset, _, _ in
                existingIds.insert(asset.localIdentifier)
            }

            let orphanedMetadataIds = Set(assetMetadata.keys).subtracting(existingIds)
            guard !orphanedMetadataIds.isEmpty else {
                PhotoEditPersistenceService.shared.cleanupOrphanedEditStates(existingAssetIds: existingIds)
                return
            }

            await MainActor.run {
                for id in orphanedMetadataIds {
                    assetMetadata.removeValue(forKey: id)
                }
                saveAssetMetadata()
            }

            PhotoEditPersistenceService.shared.cleanupOrphanedEditStates(existingAssetIds: existingIds)
        }
    }

    // MARK: - Key Remapping (for migration)

    /// Remap assetMetadata keys from old identifiers to new ones
    func remapMetadataKeys(_ mapping: [String: UUID]) {
        var newMetadata: [String: PhotoMetadata] = [:]
        for (oldKey, metadata) in assetMetadata {
            if let newId = mapping[oldKey] {
                newMetadata[newId.uuidString] = metadata
            } else {
                // Keep unmapped entries (shouldn't happen, but safe)
                newMetadata[oldKey] = metadata
            }
        }
        assetMetadata = newMetadata
        saveAssetMetadata()
    }

    /// Clean up metadata entries that have no corresponding PhotoRecord
    func cleanupOrphanedAppStorageData() {
        let validIds = Set(PhotoStorageService.shared.records.map { $0.id.uuidString })
        let orphanedKeys = assetMetadata.keys.filter { !validIds.contains($0) }
        for key in orphanedKeys {
            assetMetadata.removeValue(forKey: key)
        }
        if !orphanedKeys.isEmpty {
            saveAssetMetadata()
        }
    }

    // MARK: - Portfolio Persistence

    /// Load portfolios from UserDefaults
    private func loadPortfolios() {
        if let data = UserDefaults.standard.data(forKey: "portfolios"),
           let decoded = try? JSONDecoder().decode([Portfolio].self, from: data) {
            portfolios = decoded
            migratePortfolioAngles()
        }
    }

    /// Migrate old angle names in portfolio requirements to new combined "Occlusal/Incisal" format
    private func migratePortfolioAngles() {
        var needsSave = false

        for (portfolioIndex, portfolio) in portfolios.enumerated() {
            for (reqIndex, requirement) in portfolio.requirements.enumerated() {
                var migratedAngles: [String] = []
                var migratedAngleCounts: [String: Int] = [:]
                var requirementChanged = false

                for angle in requirement.angles {
                    let lowercased = angle.lowercased()
                    if lowercased == "occlusal" || lowercased == "incisal" {
                        // Only add "Occlusal/Incisal" once
                        if !migratedAngles.contains("Occlusal/Incisal") {
                            migratedAngles.append("Occlusal/Incisal")
                            // Combine counts if both existed
                            let count = requirement.angleCounts[angle] ?? 1
                            migratedAngleCounts["Occlusal/Incisal"] = max(
                                migratedAngleCounts["Occlusal/Incisal"] ?? 0,
                                count
                            )
                        }
                        requirementChanged = true
                    } else {
                        migratedAngles.append(angle)
                        migratedAngleCounts[angle] = requirement.angleCounts[angle] ?? 1
                    }
                }

                if requirementChanged {
                    let migratedRequirement = PortfolioRequirement(
                        id: requirement.id,
                        procedure: requirement.procedure,
                        stages: requirement.stages,
                        angles: migratedAngles.sorted(),
                        angleCounts: migratedAngleCounts
                    )
                    portfolios[portfolioIndex].requirements[reqIndex] = migratedRequirement
                    needsSave = true
                }
            }
        }

        if needsSave {
            savePortfolios()
        }
    }

    /// Save portfolios to UserDefaults
    func savePortfolios() {
        if let encoded = try? JSONEncoder().encode(portfolios) {
            UserDefaults.standard.set(encoded, forKey: "portfolios")
        }
    }

    // MARK: - Asset Metadata Persistence

    /// Load asset metadata from UserDefaults
    private func loadAssetMetadata() {
        if let data = UserDefaults.standard.data(forKey: "assetMetadata"),
           let decoded = try? JSONDecoder().decode([String: PhotoMetadata].self, from: data) {
            assetMetadata = decoded
            migrateAssetMetadataAngles()
        }
    }

    /// Migrate old angle names to new combined "Occlusal/Incisal" format
    private func migrateAssetMetadataAngles() {
        var needsSave = false

        for (assetId, var metadata) in assetMetadata {
            if let angle = metadata.angle {
                let lowercased = angle.lowercased()
                if lowercased == "occlusal" || lowercased == "incisal" {
                    metadata.angle = "Occlusal/Incisal"
                    assetMetadata[assetId] = metadata
                    needsSave = true
                }
            }
        }

        if needsSave {
            saveAssetMetadata()
        }
    }

    /// Save asset metadata to UserDefaults
    func saveAssetMetadata() {
        if let encoded = try? JSONEncoder().encode(assetMetadata) {
            UserDefaults.standard.set(encoded, forKey: "assetMetadata")
        }

        // Debounce notification rescheduling to avoid storm on batch operations
        Task {
            await notificationDebouncer.scheduleSave {
                await NotificationManager.shared.rescheduleAllReminders()
            }
        }
    }

    // MARK: - Tooth History Persistence

    /// Load tooth history from UserDefaults
    private func loadToothHistory() {
        if let data = UserDefaults.standard.data(forKey: "toothHistory"),
           let decoded = try? JSONDecoder().decode([String: [ToothEntry]].self, from: data) {
            toothHistory = decoded
        }
    }

    /// Save tooth history to UserDefaults
    func saveToothHistory() {
        if let encoded = try? JSONEncoder().encode(toothHistory) {
            UserDefaults.standard.set(encoded, forKey: "toothHistory")
        }
    }

    // MARK: - Portfolio Methods

    /// Portfolio statistics tuple
    typealias PortfolioStats = (fulfilled: Int, total: Int)

    /// One representative photo per distinct required procedure
    typealias ProcedureRepresentative = (assetId: String, procedure: String)

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

    /// One representative photo per distinct procedure in the portfolio's requirements.
    /// Returns all procedures that have at least one matching photo, ordered newest first.
    /// Matching is procedure-only (stage/angle are ignored by design).
    /// - Parameters:
    ///   - portfolio: The portfolio whose required procedures define the search set.
    ///   - photoRecords: The photo records whose createdDate is used for ordering.
    ///     Pass `PhotoStorageService.shared.records` from view code.
    /// - Returns: One `(assetId, procedure)` per procedure that has photos.
    func getProcedureRepresentatives(
        for portfolio: Portfolio,
        photoRecords: [PhotoRecord]
    ) -> [ProcedureRepresentative] {
        let requiredProcedures = Set(portfolio.requirements.map(\.procedure))
        guard !requiredProcedures.isEmpty else { return [] }

        var photoDates: [String: Date] = [:]
        for record in photoRecords {
            photoDates[record.id.uuidString] = record.createdDate
        }

        // Group matching metadata entries by procedure, keeping the newest per procedure.
        // Tie-break: lexicographically smaller assetId wins.
        var bestPerProcedure: [String: (assetId: String, date: Date)] = [:]
        for (assetId, metadata) in assetMetadata {
            guard let procedure = metadata.procedure,
                  requiredProcedures.contains(procedure),
                  let date = photoDates[assetId]
            else { continue }

            if let current = bestPerProcedure[procedure] {
                if date > current.date {
                    bestPerProcedure[procedure] = (assetId, date)
                } else if date == current.date && assetId < current.assetId {
                    bestPerProcedure[procedure] = (assetId, date)
                }
            } else {
                bestPerProcedure[procedure] = (assetId, date)
            }
        }

        // Sort winners by date desc, tie-break on assetId asc.
        let sorted = bestPerProcedure
            .map { (procedure: $0.key, assetId: $0.value.assetId, date: $0.value.date) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.assetId < rhs.assetId
            }

        return sorted.map { ProcedureRepresentative(assetId: $0.assetId, procedure: $0.procedure) }
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
        savePortfolios()

        // Schedule notifications for the new portfolio
        Task { @MainActor in
            await NotificationManager.shared.scheduleReminders(for: portfolio)
        }
    }

    /// Update an existing portfolio
    /// - Parameter portfolio: The updated portfolio (matched by id)
    func updatePortfolio(_ portfolio: Portfolio) {
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
            savePortfolios()

            // Reschedule notifications for the updated portfolio
            Task { @MainActor in
                await NotificationManager.shared.scheduleReminders(for: portfolio)
            }
        }
    }

    /// Delete a portfolio by ID
    /// - Parameter portfolioId: The ID of the portfolio to delete
    func deletePortfolio(_ portfolioId: String) {
        portfolios.removeAll { $0.id == portfolioId }
        savePortfolios()

        // Cancel notifications for the deleted portfolio
        Task { @MainActor in
            NotificationManager.shared.cancelReminders(for: portfolioId)
        }
    }

    /// Get a portfolio by ID
    /// - Parameter portfolioId: The ID of the portfolio to find
    /// - Returns: The portfolio if found, nil otherwise
    func getPortfolio(by portfolioId: String) -> Portfolio? {
        return portfolios.first { $0.id == portfolioId }
    }

    // MARK: - Metadata Methods

    /// Get asset IDs with incomplete metadata
    /// - Returns: Array of asset IDs that have incomplete procedure/stage/angle tags
    func getIncompleteAssetIds() -> [String] {
        return assetMetadata.compactMap { (assetId, metadata) in
            // Consider incomplete if missing procedure, stage, or angle
            if metadata.procedure == nil ||
               metadata.stage == nil ||
               metadata.angle == nil {
                return assetId
            }
            return nil
        }
    }

    /// Get asset IDs matching a procedure, optionally prioritizing a specific tooth number
    /// - Parameters:
    ///   - procedure: Procedure type to match
    ///   - prioritizingTooth: Optional tooth number to sort first
    /// - Returns: Array of matching asset local identifiers
    func getMatchingAssetIds(procedure: String, prioritizingTooth: Int? = nil) -> [String] {
        let matching = assetMetadata.filter { $0.value.procedure == procedure }

        guard let tooth = prioritizingTooth else {
            return Array(matching.keys)
        }

        var withTooth: [String] = []
        var withoutTooth: [String] = []
        for (key, value) in matching {
            if value.toothNumber == tooth {
                withTooth.append(key)
            } else {
                withoutTooth.append(key)
            }
        }
        return withTooth + withoutTooth
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
        saveAssetMetadata()
    }

    /// Assign metadata to an asset
    /// - Parameters:
    ///   - metadata: The metadata to assign
    ///   - assetId: The asset's local identifier
    func assignMetadata(_ metadata: PhotoMetadata, to assetId: String) {
        assetMetadata[assetId] = metadata
        saveAssetMetadata()
    }

    /// Delete metadata for an asset
    /// - Parameter assetId: The asset's local identifier
    func deleteMetadata(for assetId: String) {
        assetMetadata.removeValue(forKey: assetId)
        saveAssetMetadata()
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

        // Check if entry already exists and add it safely
        if var entries = toothHistory[entry.procedure],
           !entries.contains(where: { $0.id == entry.id }) {
            entries.append(entry)
            toothHistory[entry.procedure] = entries
            saveToothHistory()
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

    // MARK: - Stage Configuration Management

    /// Load stage configurations from UserDefaults
    func loadStages() {
        if let data = UserDefaults.standard.data(forKey: "stageConfigs"),
           let decoded = try? JSONDecoder().decode([StageConfig].self, from: data) {
            stageConfigs = decoded.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            // Load defaults on first launch
            stageConfigs = StageConfig.defaultStages
            saveStages()
        }
    }

    /// Save stage configurations to UserDefaults
    func saveStages() {
        if let encoded = try? JSONEncoder().encode(stageConfigs) {
            UserDefaults.standard.set(encoded, forKey: "stageConfigs")
        }
    }

    /// Add a new stage configuration
    /// - Parameter stage: The stage configuration to add
    func addStage(_ stage: StageConfig) {
        var newStage = stage
        newStage.sortOrder = (stageConfigs.map { $0.sortOrder }.max() ?? -1) + 1
        stageConfigs.append(newStage)
        saveStages()
    }

    /// Add a new custom stage by name
    /// - Parameter name: The name for the new stage
    /// - Returns: The created stage configuration
    @discardableResult
    func addCustomStage(name: String) -> StageConfig {
        let stage = StageConfig(
            name: name,
            colorHex: StageConfig.defaultCustomColorHex,
            iconName: StageConfig.defaultCustomIconName,
            isDefault: false,
            isEnabled: true,
            sortOrder: (stageConfigs.map { $0.sortOrder }.max() ?? -1) + 1
        )
        stageConfigs.append(stage)
        saveStages()
        return stage
    }

    /// Delete a stage configuration by ID (only non-default stages can be deleted)
    /// - Parameter stageId: The ID of the stage to delete
    /// - Returns: True if deleted, false if stage is default or not found
    @discardableResult
    func deleteStage(_ stageId: String) -> Bool {
        guard let index = stageConfigs.firstIndex(where: { $0.id == stageId }),
              !stageConfigs[index].isDefault else {
            return false
        }
        stageConfigs.remove(at: index)
        saveStages()
        return true
    }

    /// Delete a stage by name (only non-default stages can be deleted)
    /// - Parameter name: The name of the stage to delete
    /// - Returns: True if deleted, false if stage is default or not found
    @discardableResult
    func deleteStage(byName name: String) -> Bool {
        guard let config = stageConfigs.first(where: { $0.name.lowercased() == name.lowercased() }),
              !config.isDefault else {
            return false
        }
        return deleteStage(config.id)
    }

    /// Get only enabled stage configurations
    /// - Returns: Array of enabled stages sorted by sort order
    func getEnabledStages() -> [StageConfig] {
        stageConfigs.filter { $0.isEnabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Get enabled stage names (for use in pickers)
    /// - Returns: Array of enabled stage names
    func getEnabledStageNames() -> [String] {
        getEnabledStages().map { $0.name }
    }

    /// Get color for a stage by name
    /// - Parameter stageName: The stage name to look up
    /// - Returns: The stage's color, or gray for inactive/unknown stages
    func stageColor(for stageName: String) -> Color {
        if let config = stageConfigs.first(where: { $0.name.lowercased() == stageName.lowercased() }) {
            return config.color
        }
        // Return neutral gray for stages that no longer exist (deleted custom stages)
        return Color(hex: StageConfig.inactiveColorHex)
    }

    /// Get icon name for a stage by name
    /// - Parameter stageName: The stage name to look up
    /// - Returns: The stage's icon name, or default tag icon for unknown stages
    func stageIcon(for stageName: String) -> String {
        if let config = stageConfigs.first(where: { $0.name.lowercased() == stageName.lowercased() }) {
            return config.iconName
        }
        return StageConfig.defaultCustomIconName
    }

    /// Get stage configuration by name
    /// - Parameter name: The stage name to find
    /// - Returns: The stage config if found
    func getStage(byName name: String) -> StageConfig? {
        stageConfigs.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Check if a stage name exists and is active
    /// - Parameter stageName: The stage name to check
    /// - Returns: True if the stage exists and is enabled
    func isStageActive(_ stageName: String) -> Bool {
        guard let config = stageConfigs.first(where: { $0.name.lowercased() == stageName.lowercased() }) else {
            return false
        }
        return config.isEnabled
    }

    /// Check if a stage name already exists (case-insensitive)
    /// - Parameter name: The name to check
    /// - Returns: True if a stage with this name exists
    func stageExists(name: String) -> Bool {
        stageConfigs.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Reset stages to default configurations
    func resetStagesToDefaults() {
        stageConfigs = StageConfig.defaultStages
        saveStages()
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

        // Reset stages to defaults
        stageConfigs = StageConfig.defaultStages

        // Clear all UserDefaults keys related to the app
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "assetMetadata")
        defaults.removeObject(forKey: "toothHistory")
        defaults.removeObject(forKey: "portfolios")
        defaults.removeObject(forKey: "procedureConfigs")
        defaults.removeObject(forKey: "stageConfigs")

        // Clear profile data
        defaults.removeObject(forKey: "userFirstName")
        defaults.removeObject(forKey: "userLastName")
        defaults.removeObject(forKey: "userSchool")
        defaults.removeObject(forKey: "userClassYear")
        defaults.removeObject(forKey: "profileImageData")

        // Clear ghost reference map
        defaults.removeObject(forKey: "ghostReferenceMap")

        // Reset capture settings
        defaults.removeObject(forKey: "showGridLines")
        defaults.removeObject(forKey: "defaultFlashMode")
        defaults.removeObject(forKey: "captureSound")
        defaults.removeObject(forKey: "preCaptureTagging")
        defaults.removeObject(forKey: "rememberLastTags")
        defaults.removeObject(forKey: "autoSaveToLibrary")
        defaults.removeObject(forKey: "imageQuality")

        // Reset notification settings
        defaults.removeObject(forKey: "dueDateRemindersEnabled")

        // Cancel all pending notifications
        Task { @MainActor in
            NotificationManager.shared.cancelAllReminders()
        }

        // Synchronize
        defaults.synchronize()

        // Reload default procedures
        saveProcedures()
    }
}
