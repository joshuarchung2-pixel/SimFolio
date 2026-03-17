// MetadataManagerTests.swift
// SimFolioTests - MetadataManager Unit Tests
//
// Tests for the MetadataManager service including:
// - Photo metadata CRUD operations
// - Portfolio management
// - Procedure configuration
// - Portfolio statistics

import XCTest
@testable import SimFolio

final class MetadataManagerTests: XCTestCase {

    var sut: MetadataManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = MetadataManager.shared
        // Clear existing data for clean tests
        clearTestData()
    }

    override func tearDown() {
        clearTestData()
        sut = nil
        super.tearDown()
    }

    private func clearTestData() {
        sut.assetMetadata = [:]
        sut.portfolios = []
        sut.toothHistory = [:]
    }

    // MARK: - Photo Metadata Tests

    func testSaveAndRetrieveMetadata() {
        // Given
        let assetId = "test-asset-123"
        let metadata = TestData.createPhotoMetadata(procedure: "Class 1", stage: "Preparation")

        // When
        sut.assetMetadata[assetId] = metadata

        // Then
        let retrieved = sut.getMetadata(for: assetId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.procedure, "Class 1")
        XCTAssertEqual(retrieved?.stage, "Preparation")
    }

    func testDeleteMetadata() {
        // Given
        let assetId = "test-asset-456"
        sut.assetMetadata[assetId] = TestData.createPhotoMetadata()

        // When
        sut.assetMetadata.removeValue(forKey: assetId)

        // Then
        XCTAssertNil(sut.getMetadata(for: assetId))
    }

    func testUpdateMetadata() {
        // Given
        let assetId = "test-asset-789"
        var metadata = TestData.createPhotoMetadata(rating: 3)
        sut.assetMetadata[assetId] = metadata

        // When
        metadata.rating = 5
        sut.assetMetadata[assetId] = metadata

        // Then
        XCTAssertEqual(sut.getMetadata(for: assetId)?.rating, 5)
    }

    func testGetRating() {
        // Given
        let assetId = "test-asset-rating"
        let metadata = TestData.createPhotoMetadata(rating: 4)
        sut.assetMetadata[assetId] = metadata

        // When
        let rating = sut.getRating(for: assetId)

        // Then
        XCTAssertEqual(rating, 4)
    }

    func testSetRating() {
        // Given
        let assetId = "test-asset-set-rating"
        sut.assetMetadata[assetId] = TestData.createPhotoMetadata(rating: 2)

        // When
        sut.setRating(5, for: assetId)

        // Then
        XCTAssertEqual(sut.getRating(for: assetId), 5)
    }

    func testSetRatingCreatesMetadataIfNotExists() {
        // Given
        let assetId = "test-asset-new"
        XCTAssertNil(sut.getMetadata(for: assetId))

        // When
        sut.setRating(3, for: assetId)

        // Then
        XCTAssertNotNil(sut.getMetadata(for: assetId))
        XCTAssertEqual(sut.getRating(for: assetId), 3)
    }

    func testPhotoCountForProcedure() {
        // Given
        sut.assetMetadata = TestData.createMultipleMetadata(count: 10)

        // When
        let class1Count = sut.photoCount(for: "Class 1")

        // Then
        XCTAssertGreaterThan(class1Count, 0)
    }

    func testGetMatchingPhotoCount() {
        // Given
        sut.assetMetadata["photo1"] = TestData.createPhotoMetadata(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )
        sut.assetMetadata["photo2"] = TestData.createPhotoMetadata(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )
        sut.assetMetadata["photo3"] = TestData.createPhotoMetadata(
            procedure: "Class 1",
            stage: "Restoration",
            angle: "Occlusal/Incisal"
        )

        // When
        let count = sut.getMatchingPhotoCount(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )

        // Then
        XCTAssertEqual(count, 2)
    }

    // MARK: - Portfolio Tests

    func testAddPortfolio() {
        // Given
        let portfolio = TestData.createPortfolio(name: "Test Portfolio")

        // When
        sut.addPortfolio(portfolio)

        // Then
        XCTAssertEqual(sut.portfolios.count, 1)
        XCTAssertEqual(sut.portfolios.first?.name, "Test Portfolio")
    }

    func testUpdatePortfolio() {
        // Given
        var portfolio = TestData.createPortfolio(name: "Original Name")
        sut.addPortfolio(portfolio)

        // When
        portfolio = Portfolio(
            id: portfolio.id,
            name: "Updated Name",
            createdDate: portfolio.createdDate,
            dueDate: portfolio.dueDate,
            requirements: portfolio.requirements,
            notes: portfolio.notes
        )
        sut.updatePortfolio(portfolio)

        // Then
        let updated = sut.getPortfolio(by: portfolio.id)
        XCTAssertEqual(updated?.name, "Updated Name")
    }

    func testDeletePortfolio() {
        // Given
        let portfolio = TestData.createPortfolio()
        sut.addPortfolio(portfolio)
        XCTAssertEqual(sut.portfolios.count, 1)

        // When
        sut.deletePortfolio(portfolio.id)

        // Then
        XCTAssertEqual(sut.portfolios.count, 0)
    }

    func testGetPortfolioById() {
        // Given
        let portfolio = TestData.createPortfolio()
        sut.addPortfolio(portfolio)

        // When
        let retrieved = sut.getPortfolio(by: portfolio.id)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, portfolio.id)
    }

    func testGetPortfolioByIdReturnsNilForNonExistent() {
        // When
        let retrieved = sut.getPortfolio(by: "non-existent-id")

        // Then
        XCTAssertNil(retrieved)
    }

    // MARK: - Portfolio Statistics Tests

    func testGetPortfolioStats() {
        // Given
        let requirement = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"],
            angleCounts: ["Occlusal/Incisal": 2]
        )
        let portfolio = TestData.createPortfolio(requirements: [requirement])

        // Add one matching photo
        sut.assetMetadata["photo1"] = TestData.createPhotoMetadata(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )

        // When
        let stats = sut.getPortfolioStats(portfolio)

        // Then
        XCTAssertEqual(stats.total, 2) // 1 stage * 1 angle * 2 photos per angle
        XCTAssertEqual(stats.fulfilled, 1) // 1 matching photo
    }

    func testGetPortfolioStatsWithNoMatchingPhotos() {
        // Given
        let requirement = TestData.createRequirement(
            procedure: "Crown",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"]
        )
        let portfolio = TestData.createPortfolio(requirements: [requirement])

        // When
        let stats = sut.getPortfolioStats(portfolio)

        // Then
        XCTAssertEqual(stats.total, 1)
        XCTAssertEqual(stats.fulfilled, 0)
    }

    func testGetPortfolioCompletionPercentage() {
        // Given
        let requirement = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"],
            angleCounts: ["Occlusal/Incisal": 2]
        )
        let portfolio = TestData.createPortfolio(requirements: [requirement])

        // Add one of two required photos
        sut.assetMetadata["photo1"] = TestData.createPhotoMetadata(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )

        // When
        let percentage = sut.getPortfolioCompletionPercentage(portfolio)

        // Then
        XCTAssertEqual(percentage, 0.5, accuracy: 0.01)
    }

    func testGetPortfolioCompletionPercentageWithEmptyRequirements() {
        // Given
        let portfolio = Portfolio(
            name: "Empty Portfolio",
            requirements: []
        )

        // When
        let percentage = sut.getPortfolioCompletionPercentage(portfolio)

        // Then
        XCTAssertEqual(percentage, 0.0)
    }

    // MARK: - Procedure Configuration Tests

    func testLoadProcedures() {
        // Given
        sut.procedureConfigs = []

        // When
        sut.loadProcedures()

        // Then
        XCTAssertFalse(sut.procedureConfigs.isEmpty)
        XCTAssertTrue(sut.procedureConfigs.contains { $0.name == "Class 1" })
    }

    func testAddProcedure() {
        // Given
        sut.loadProcedures()
        let initialCount = sut.procedureConfigs.count
        let customProcedure = TestData.createCustomProcedure(name: "Custom Procedure")

        // When
        sut.addProcedure(customProcedure)

        // Then
        XCTAssertEqual(sut.procedureConfigs.count, initialCount + 1)
        XCTAssertTrue(sut.procedureConfigs.contains { $0.name == "Custom Procedure" })
    }

    func testUpdateProcedure() {
        // Given
        sut.loadProcedures()
        guard var procedure = sut.procedureConfigs.first else {
            XCTFail("No procedures loaded")
            return
        }

        // When
        procedure = ProcedureConfig(
            id: procedure.id,
            name: procedure.name,
            colorHex: "#FF0000",
            isDefault: procedure.isDefault,
            isEnabled: procedure.isEnabled,
            sortOrder: procedure.sortOrder
        )
        sut.updateProcedure(procedure)

        // Then
        let updated = sut.procedureConfigs.first { $0.id == procedure.id }
        XCTAssertEqual(updated?.colorHex, "#FF0000")
    }

    func testDeleteProcedure() {
        // Given
        let customProcedure = TestData.createCustomProcedure()
        sut.addProcedure(customProcedure)
        let countBefore = sut.procedureConfigs.count

        // When
        sut.deleteProcedure(customProcedure.id)

        // Then
        XCTAssertEqual(sut.procedureConfigs.count, countBefore - 1)
        XCTAssertFalse(sut.procedureConfigs.contains { $0.id == customProcedure.id })
    }

    func testResetToDefaults() {
        // Given
        sut.procedureConfigs = [TestData.createCustomProcedure(name: "Custom Only")]

        // When
        sut.resetToDefaults()

        // Then
        XCTAssertTrue(sut.procedureConfigs.contains { $0.isDefault })
        XCTAssertFalse(sut.procedureConfigs.contains { $0.name == "Custom Only" })
    }

    func testGetEnabledProcedures() {
        // Given
        sut.loadProcedures()
        if let first = sut.procedureConfigs.first {
            var disabled = first
            disabled = ProcedureConfig(
                id: "disabled-id",
                name: "Disabled",
                colorHex: "#000000",
                isDefault: false,
                isEnabled: false,
                sortOrder: 99
            )
            sut.procedureConfigs.append(disabled)
        }

        // When
        let enabled = sut.getEnabledProcedures()

        // Then
        XCTAssertFalse(enabled.contains { $0.name == "Disabled" })
        XCTAssertTrue(enabled.allSatisfy { $0.isEnabled })
    }

    func testGetEnabledProcedureNames() {
        // Given
        sut.loadProcedures()

        // When
        let names = sut.getEnabledProcedureNames()

        // Then
        XCTAssertFalse(names.isEmpty)
        XCTAssertTrue(names.contains("Class 1"))
    }

    func testProcedureColor() {
        // Given
        sut.loadProcedures()

        // When
        let color = sut.procedureColor(for: "Class 1")

        // Then
        XCTAssertNotNil(color)
    }

    // MARK: - Tooth Entry Tests

    func testAddToothEntry() {
        // Given
        let entry = TestData.createToothEntry(procedure: "Class 1", toothNumber: 14)

        // When
        sut.addToothEntry(entry)

        // Then
        let entries = sut.getToothEntries(for: "Class 1")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.toothNumber, 14)
    }

    func testGetToothEntriesSortedByDate() {
        // Given
        let oldEntry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestUtilities.dateRelativeToToday(days: -7)
        )
        let newEntry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 15,
            date: Date()
        )

        sut.addToothEntry(oldEntry)
        sut.addToothEntry(newEntry)

        // When
        let entries = sut.getToothEntries(for: "Class 1")

        // Then
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.toothNumber, 15) // Most recent first
    }

    func testGetToothEntriesForNonExistentProcedure() {
        // When
        let entries = sut.getToothEntries(for: "Non-existent")

        // Then
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Data Management Tests

    func testClearAllMetadata() {
        // Given
        sut.assetMetadata = TestData.createMultipleMetadata(count: 5)
        sut.addToothEntry(TestData.createToothEntry())
        XCTAssertFalse(sut.assetMetadata.isEmpty)

        // When
        sut.clearAllMetadata()

        // Then
        XCTAssertTrue(sut.assetMetadata.isEmpty)
        XCTAssertTrue(sut.toothHistory.isEmpty)
    }

    func testResetAllData() {
        // Given
        sut.assetMetadata = TestData.createMultipleMetadata(count: 5)
        sut.addPortfolio(TestData.createPortfolio())
        sut.addProcedure(TestData.createCustomProcedure())

        // When
        sut.resetAllData()

        // Then
        XCTAssertTrue(sut.assetMetadata.isEmpty)
        XCTAssertTrue(sut.portfolios.isEmpty)
        XCTAssertTrue(sut.procedureConfigs.allSatisfy { $0.isDefault })
    }
}
