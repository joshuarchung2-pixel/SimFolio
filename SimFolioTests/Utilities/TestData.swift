import Foundation
@testable import SimFolio

struct TestData {

    // MARK: - Reference Date

    /// Fixed reference date for all test data — never use Date()
    static let referenceDate: Date = {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "2025-01-15T12:00:00Z")!
    }()

    /// Create a date offset from referenceDate
    static func date(daysFromReference days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: referenceDate)!
    }

    // MARK: - Photo Metadata

    static func createPhotoMetadata(
        procedure: String? = "Class 1",
        toothNumber: Int? = 14,
        toothDate: Date? = referenceDate,
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

    static func createEmptyMetadata() -> PhotoMetadata {
        PhotoMetadata()
    }

    static func createCompleteMetadata() -> PhotoMetadata {
        createPhotoMetadata(
            procedure: "Crown",
            toothNumber: 30,
            toothDate: referenceDate,
            stage: "Restoration",
            angle: "Buccal/Facial",
            rating: 5
        )
    }

    // MARK: - Portfolio

    static func createPortfolio(
        id: String = UUID().uuidString,
        name: String = "Test Portfolio",
        createdDate: Date = referenceDate,
        dueDate: Date? = nil,
        requirements: [PortfolioRequirement] = [],
        notes: String? = nil
    ) -> Portfolio {
        Portfolio(
            id: id,
            name: name,
            createdDate: createdDate,
            dueDate: dueDate,
            requirements: requirements,
            notes: notes
        )
    }

    static func createFuturePortfolio() -> Portfolio {
        createPortfolio(
            name: "Future Portfolio",
            dueDate: date(daysFromReference: 30)
        )
    }

    static func createOverduePortfolio() -> Portfolio {
        createPortfolio(
            name: "Overdue Portfolio",
            dueDate: date(daysFromReference: -5)
        )
    }

    static func createDueSoonPortfolio() -> Portfolio {
        createPortfolio(
            name: "Due Soon Portfolio",
            dueDate: date(daysFromReference: 3)
        )
    }

    // MARK: - Portfolio Requirement

    static func createRequirement(
        id: String = UUID().uuidString,
        procedure: String = "Class 1",
        stages: [String] = ["Preparation", "Restoration"],
        angles: [String] = ["Occlusal/Incisal", "Buccal/Facial"],
        angleCounts: [String: Int] = [:]
    ) -> PortfolioRequirement {
        PortfolioRequirement(
            id: id,
            procedure: procedure,
            stages: stages,
            angles: angles,
            angleCounts: angleCounts
        )
    }

    // MARK: - Procedure Config

    static func createProcedureConfig(
        id: String = UUID().uuidString,
        name: String = "Class 1",
        colorHex: String = "#3B82F6",
        isDefault: Bool = true,
        isEnabled: Bool = true
    ) -> ProcedureConfig {
        ProcedureConfig(id: id, name: name, colorHex: colorHex, isDefault: isDefault, isEnabled: isEnabled)
    }

    // MARK: - Tooth Entry

    static func createToothEntry(
        procedure: String = "Class 1",
        toothNumber: Int = 14,
        date: Date = referenceDate
    ) -> ToothEntry {
        ToothEntry(procedure: procedure, toothNumber: toothNumber, date: date)
    }

    // MARK: - Portfolio (parametrized overloads for existing tests)

    static func createFuturePortfolio(daysUntilDue: Int) -> Portfolio {
        createPortfolio(
            name: "Future Portfolio",
            createdDate: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: daysUntilDue, to: Date())
        )
    }

    static func createOverduePortfolio(daysOverdue: Int) -> Portfolio {
        createPortfolio(
            name: "Overdue Portfolio",
            createdDate: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: -daysOverdue, to: Date())
        )
    }

    static func createDueSoonPortfolio(daysUntilDue: Int) -> Portfolio {
        createPortfolio(
            name: "Due Soon Portfolio",
            createdDate: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: daysUntilDue, to: Date())
        )
    }

    // MARK: - Library Filter

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

    static func createFullFilter() -> LibraryFilter {
        createLibraryFilter(
            procedures: ["Class 1", "Crown"],
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"],
            minimumRating: 3,
            dateRange: .lastMonth
        )
    }

    // MARK: - Procedure Config (additional helpers for existing tests)

    static func createCustomProcedure(name: String = "Custom Procedure") -> ProcedureConfig {
        ProcedureConfig(name: name, colorHex: "#FF6B6B", isDefault: false, isEnabled: true)
    }

    // MARK: - Batch Creation (helpers for existing tests)

    static func createMultipleMetadata(count: Int) -> [String: PhotoMetadata] {
        let procedures = ["Class 1", "Class 2", "Class 3", "Crown", "Veneer"]
        let stages = ["Preparation", "Restoration"]
        let angles = ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Proximal"]
        var result: [String: PhotoMetadata] = [:]
        for i in 0..<count {
            let assetId = "test-asset-\(i)"
            result[assetId] = createPhotoMetadata(
                procedure: procedures[i % procedures.count],
                toothNumber: (i % 32) + 1,
                toothDate: date(daysFromReference: -i),
                stage: stages[i % stages.count],
                angle: angles[i % angles.count],
                rating: (i % 5) + 1
            )
        }
        return result
    }

    // MARK: - Edit State

    static func createEditState(
        assetId: String = "test-asset",
        brightness: Double = 0,
        contrast: Double = 1.0
    ) -> EditState {
        var state = EditState(assetId: assetId)
        state.adjustments.brightness = brightness
        state.adjustments.contrast = contrast
        return state
    }
}
