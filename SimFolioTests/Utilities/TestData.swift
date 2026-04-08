// TestData.swift
// SimFolioTests - Test Data Factory
//
// Provides factory methods for creating test data objects.
// Centralizes test fixture creation for consistent testing.

import Foundation
@testable import SimFolio

// MARK: - Test Data Factory

struct TestData {

    // MARK: - Photo Metadata

    /// Create a PhotoMetadata instance with optional parameters
    static func createPhotoMetadata(
        procedure: String? = "Class 1",
        toothNumber: Int? = 14,
        toothDate: Date? = Date(),
        stage: String? = "Preparation",
        angle: String? = "Occlusal/Incisal",
        rating: Int? = 4
    ) -> PhotoMetadata {
        var metadata = PhotoMetadata()
        metadata.procedure = procedure
        metadata.toothNumber = toothNumber
        metadata.toothDate = toothDate
        metadata.stage = stage
        metadata.angle = angle
        metadata.rating = rating
        return metadata
    }

    /// Create an empty/incomplete PhotoMetadata
    static func createEmptyMetadata() -> PhotoMetadata {
        PhotoMetadata()
    }

    /// Create a complete PhotoMetadata with all fields filled
    static func createCompleteMetadata() -> PhotoMetadata {
        createPhotoMetadata(
            procedure: "Crown",
            toothNumber: 30,
            toothDate: Date(),
            stage: "Restoration",
            angle: "Buccal/Facial",
            rating: 5
        )
    }

    // MARK: - Portfolio

    /// Create a Portfolio with optional parameters
    static func createPortfolio(
        id: String = UUID().uuidString,
        name: String = "Test Portfolio",
        createdDate: Date = Date(),
        dueDate: Date? = nil,
        requirements: [PortfolioRequirement] = [],
        notes: String? = nil
    ) -> Portfolio {
        Portfolio(
            id: id,
            name: name,
            createdDate: createdDate,
            dueDate: dueDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            requirements: requirements.isEmpty ? [createRequirement()] : requirements,
            notes: notes
        )
    }

    /// Create a portfolio due in the future
    static func createFuturePortfolio(daysUntilDue: Int = 7) -> Portfolio {
        let dueDate = Calendar.current.date(byAdding: .day, value: daysUntilDue, to: Date())
        return createPortfolio(
            name: "Future Portfolio",
            dueDate: dueDate
        )
    }

    /// Create an overdue portfolio
    static func createOverduePortfolio(daysOverdue: Int = 3) -> Portfolio {
        let dueDate = Calendar.current.date(byAdding: .day, value: -daysOverdue, to: Date())
        return createPortfolio(
            name: "Overdue Portfolio",
            dueDate: dueDate
        )
    }

    /// Create a portfolio due soon (within 7 days)
    static func createDueSoonPortfolio(daysUntilDue: Int = 3) -> Portfolio {
        let dueDate = Calendar.current.date(byAdding: .day, value: daysUntilDue, to: Date())
        return createPortfolio(
            name: "Due Soon Portfolio",
            dueDate: dueDate
        )
    }

    // MARK: - Portfolio Requirement

    /// Create a PortfolioRequirement with optional parameters
    static func createRequirement(
        id: String = UUID().uuidString,
        procedure: String = "Class 1",
        stages: [String] = ["Preparation", "Restoration"],
        angles: [String] = ["Occlusal/Incisal", "Buccal/Facial"],
        angleCounts: [String: Int] = [:]
    ) -> PortfolioRequirement {
        var counts = angleCounts
        if counts.isEmpty {
            for angle in angles {
                counts[angle] = 1
            }
        }
        return PortfolioRequirement(
            id: id,
            procedure: procedure,
            stages: stages,
            angles: angles,
            angleCounts: counts
        )
    }

    /// Create a requirement with multiple photos per angle
    static func createRequirementWithMultiplePhotos(photosPerAngle: Int = 2) -> PortfolioRequirement {
        let angles = ["Occlusal/Incisal", "Buccal/Facial", "Lingual"]
        var angleCounts: [String: Int] = [:]
        for angle in angles {
            angleCounts[angle] = photosPerAngle
        }
        return createRequirement(
            procedure: "Class 2",
            angles: angles,
            angleCounts: angleCounts
        )
    }

    // MARK: - Procedure Config

    /// Create a ProcedureConfig with optional parameters
    static func createProcedureConfig(
        id: String = UUID().uuidString,
        name: String = "Test Procedure",
        colorHex: String = "#3B82F6",
        isDefault: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) -> ProcedureConfig {
        ProcedureConfig(
            id: id,
            name: name,
            colorHex: colorHex,
            isDefault: isDefault,
            isEnabled: isEnabled,
            sortOrder: sortOrder
        )
    }

    /// Create a default procedure config
    static func createDefaultProcedure(name: String = "Class 1") -> ProcedureConfig {
        createProcedureConfig(
            name: name,
            isDefault: true,
            isEnabled: true
        )
    }

    /// Create a custom (non-default) procedure config
    static func createCustomProcedure(name: String = "Custom Procedure") -> ProcedureConfig {
        createProcedureConfig(
            name: name,
            colorHex: "#FF6B6B",
            isDefault: false,
            isEnabled: true
        )
    }

    /// Create a disabled procedure config
    static func createDisabledProcedure(name: String = "Disabled Procedure") -> ProcedureConfig {
        createProcedureConfig(
            name: name,
            isDefault: false,
            isEnabled: false
        )
    }

    // MARK: - Tooth Entry

    /// Create a ToothEntry with optional parameters
    static func createToothEntry(
        procedure: String = "Class 1",
        toothNumber: Int = 14,
        date: Date = Date()
    ) -> ToothEntry {
        ToothEntry(
            procedure: procedure,
            toothNumber: toothNumber,
            date: date
        )
    }

    // MARK: - Batch Creation

    /// Create multiple portfolios
    static func createMultiplePortfolios(count: Int) -> [Portfolio] {
        (0..<count).map { index in
            createPortfolio(
                name: "Portfolio \(index + 1)",
                dueDate: Calendar.current.date(byAdding: .day, value: index + 1, to: Date())
            )
        }
    }

    /// Create multiple photo metadata entries
    static func createMultipleMetadata(count: Int) -> [String: PhotoMetadata] {
        var result: [String: PhotoMetadata] = [:]

        let procedures = ["Class 1", "Class 2", "Class 3", "Crown", "Veneer"]
        let stages = ["Preparation", "Restoration"]
        let angles = ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Proximal"]

        for i in 0..<count {
            let assetId = "test-asset-\(i)"
            result[assetId] = createPhotoMetadata(
                procedure: procedures[i % procedures.count],
                toothNumber: (i % 32) + 1,
                stage: stages[i % stages.count],
                angle: angles[i % angles.count],
                rating: (i % 5) + 1
            )
        }

        return result
    }

    /// Create multiple procedure configs
    static func createMultipleProcedures(count: Int) -> [ProcedureConfig] {
        let colors = ["#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EF4444"]

        return (0..<count).map { index in
            createProcedureConfig(
                name: "Procedure \(index + 1)",
                colorHex: colors[index % colors.count],
                sortOrder: index
            )
        }
    }

    /// Create multiple tooth entries for a procedure
    static func createMultipleToothEntries(count: Int, procedure: String = "Class 1") -> [ToothEntry] {
        (0..<count).map { index in
            createToothEntry(
                procedure: procedure,
                toothNumber: (index % 32) + 1,
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            )
        }
    }

    // MARK: - Library Filter

    /// Create a LibraryFilter with optional parameters
    static func createLibraryFilter(
        procedures: Set<String> = [],
        stages: Set<String> = [],
        angles: Set<String> = [],
        minimumRating: Int? = nil,
        dateRange: LibraryFilter.DateRange? = nil,
        portfolioId: String? = nil
    ) -> LibraryFilter {
        var filter = LibraryFilter()
        filter.procedures = procedures
        filter.stages = stages
        filter.angles = angles
        filter.minimumRating = minimumRating
        filter.dateRange = dateRange
        filter.portfolioId = portfolioId
        return filter
    }

    /// Create a filter with all options set
    static func createFullFilter() -> LibraryFilter {
        createLibraryFilter(
            procedures: ["Class 1", "Crown"],
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"],
            minimumRating: 3,
            dateRange: .lastMonth
        )
    }

    // MARK: - Test Scenarios

    /// Create a complete test scenario with portfolios, metadata, and procedures
    static func createTestScenario() -> (
        portfolios: [Portfolio],
        metadata: [String: PhotoMetadata],
        procedures: [ProcedureConfig]
    ) {
        let procedures = ProcedureConfig.defaultProcedures

        let requirements = [
            createRequirement(procedure: "Class 1"),
            createRequirement(procedure: "Crown", stages: ["Preparation"])
        ]

        let portfolios = [
            createPortfolio(name: "Test Portfolio 1", requirements: requirements),
            createFuturePortfolio(daysUntilDue: 14),
            createDueSoonPortfolio(daysUntilDue: 2)
        ]

        let metadata = createMultipleMetadata(count: 20)

        return (portfolios: portfolios, metadata: metadata, procedures: procedures)
    }
}

// MARK: - Test Data Extensions

extension TestData {

    /// All default stages
    static let allStages = ["Preparation", "Restoration"]

    /// All default angles
    static let allAngles = ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Proximal", "Mesial", "Distal", "Other"]

    /// Sample procedure names
    static let sampleProcedures = ["Class 1", "Class 2", "Class 3", "Crown", "Bridge", "Veneer"]

    /// Valid tooth numbers (1-32)
    static let validToothNumbers = Array(1...32)

    /// Valid ratings (1-5)
    static let validRatings = Array(1...5)
}
