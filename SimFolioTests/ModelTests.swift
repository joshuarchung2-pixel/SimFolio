// ModelTests.swift
// SimFolioTests - Data Model Unit Tests
//
// Tests for core data models including:
// - PhotoMetadata
// - Portfolio
// - PortfolioRequirement
// - ProcedureConfig
// - ToothEntry

import XCTest
@testable import SimFolio

// MARK: - PhotoMetadata Tests

final class PhotoMetadataTests: XCTestCase {

    func testPhotoMetadataEncoding() throws {
        // Given
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            stage: "Preparation",
            angle: "Occlusal/Incisal",
            rating: 4
        )

        // When
        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(PhotoMetadata.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.procedure, metadata.procedure)
        XCTAssertEqual(decoded.toothNumber, metadata.toothNumber)
        XCTAssertEqual(decoded.stage, metadata.stage)
        XCTAssertEqual(decoded.angle, metadata.angle)
        XCTAssertEqual(decoded.rating, metadata.rating)
    }

    func testIsComplete() {
        // Given
        let complete = TestData.createCompleteMetadata()
        let incomplete = TestData.createEmptyMetadata()
        let partiallyComplete = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: nil, // Missing tooth number
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )

        // Then
        XCTAssertTrue(complete.isComplete)
        XCTAssertFalse(incomplete.isComplete)
        XCTAssertFalse(partiallyComplete.isComplete)
    }

    func testSummaryTextComplete() {
        // Given
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )

        // Then
        let summary = metadata.summaryText
        XCTAssertTrue(summary.contains("Class 1"))
        XCTAssertTrue(summary.contains("#14"))
        XCTAssertTrue(summary.contains("Prep"))
        XCTAssertTrue(summary.contains("Occlusal/Incisal"))
    }

    func testSummaryTextEmpty() {
        // Given
        let metadata = TestData.createEmptyMetadata()

        // Then
        XCTAssertEqual(metadata.summaryText, "Choose procedure")
    }

    func testSummaryTextRestorationStage() {
        // Given
        let metadata = TestData.createPhotoMetadata(stage: "Restoration")

        // Then
        XCTAssertTrue(metadata.summaryText.contains("Resto"))
    }

    func testToothEntry() {
        // Given
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            toothDate: Date()
        )

        // Then
        XCTAssertNotNil(metadata.toothEntry)
        XCTAssertEqual(metadata.toothEntry?.procedure, "Class 1")
        XCTAssertEqual(metadata.toothEntry?.toothNumber, 14)
    }

    func testToothEntryNilWhenIncomplete() {
        // Given
        let metadataNoNumber = TestData.createPhotoMetadata(toothNumber: nil)
        let metadataNoDate = TestData.createPhotoMetadata(toothDate: nil)
        let metadataNoProcedure = TestData.createPhotoMetadata(procedure: nil)

        // Then
        XCTAssertNil(metadataNoNumber.toothEntry)
        XCTAssertNil(metadataNoDate.toothEntry)
        XCTAssertNil(metadataNoProcedure.toothEntry)
    }

    func testEquality() {
        // Given
        let metadata1 = TestData.createPhotoMetadata(procedure: "Class 1", rating: 4)
        let metadata2 = TestData.createPhotoMetadata(procedure: "Class 1", rating: 4)
        let metadata3 = TestData.createPhotoMetadata(procedure: "Class 2", rating: 4)

        // Then
        XCTAssertEqual(metadata1, metadata2)
        XCTAssertNotEqual(metadata1, metadata3)
    }
}

// MARK: - Portfolio Tests

final class PortfolioTests: XCTestCase {

    func testPortfolioEncoding() throws {
        // Given
        let portfolio = TestData.createPortfolio(name: "Test Portfolio")

        // When
        let encoded = try JSONEncoder().encode(portfolio)
        let decoded = try JSONDecoder().decode(Portfolio.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.name, portfolio.name)
        XCTAssertEqual(decoded.id, portfolio.id)
        XCTAssertEqual(decoded.requirements.count, portfolio.requirements.count)
    }

    func testPortfolioIdentifiable() {
        // Given
        let portfolio1 = TestData.createPortfolio()
        let portfolio2 = TestData.createPortfolio()

        // Then
        XCTAssertNotEqual(portfolio1.id, portfolio2.id)
    }

    func testPortfolioHashable() {
        // Given
        let portfolio1 = TestData.createPortfolio(id: "same-id")
        let portfolio2 = Portfolio(id: "same-id", name: "Different Name")

        // Then
        var set = Set<Portfolio>()
        set.insert(portfolio1)
        set.insert(portfolio2)
        XCTAssertEqual(set.count, 1) // Same ID = same portfolio
    }

    func testDateString() {
        // Given
        let portfolio = TestData.createPortfolio()

        // Then
        XCTAssertFalse(portfolio.dateString.isEmpty)
    }

    func testDueDateString() {
        // Given
        let portfolioWithDue = TestData.createPortfolio(
            dueDate: TestUtilities.dateRelativeToToday(days: 7)
        )
        let portfolioWithoutDue = Portfolio(name: "No Due Date")

        // Then
        XCTAssertNotNil(portfolioWithDue.dueDateString)
        XCTAssertNil(portfolioWithoutDue.dueDateString)
    }

    func testDaysUntilDue() {
        // Given
        let portfolioFuture = TestData.createFuturePortfolio(daysUntilDue: 7)
        let portfolioPast = TestData.createOverduePortfolio(daysOverdue: 3)
        let portfolioNoDue = Portfolio(name: "No Due Date")

        // Then
        XCTAssertEqual(portfolioFuture.daysUntilDue, 7)
        XCTAssertEqual(portfolioPast.daysUntilDue, -3)
        XCTAssertNil(portfolioNoDue.daysUntilDue)
    }

    func testIsOverdue() {
        // Given
        let overduePortfolio = TestData.createOverduePortfolio(daysOverdue: 3)
        let activePortfolio = TestData.createFuturePortfolio(daysUntilDue: 7)
        let noDueDatePortfolio = Portfolio(name: "No Due Date")

        // Then
        XCTAssertTrue(overduePortfolio.isOverdue)
        XCTAssertFalse(activePortfolio.isOverdue)
        XCTAssertFalse(noDueDatePortfolio.isOverdue)
    }

    func testIsDueSoon() {
        // Given
        let dueSoonPortfolio = TestData.createDueSoonPortfolio(daysUntilDue: 3)
        let dueLaterPortfolio = TestData.createFuturePortfolio(daysUntilDue: 14)
        let overduePortfolio = TestData.createOverduePortfolio(daysOverdue: 1)

        // Then
        XCTAssertTrue(dueSoonPortfolio.isDueSoon)
        XCTAssertFalse(dueLaterPortfolio.isDueSoon)
        XCTAssertFalse(overduePortfolio.isDueSoon)
    }
}

// MARK: - PortfolioRequirement Tests

final class PortfolioRequirementTests: XCTestCase {

    func testRequirementEncoding() throws {
        // Given
        let requirement = TestData.createRequirement()

        // When
        let encoded = try JSONEncoder().encode(requirement)
        let decoded = try JSONDecoder().decode(PortfolioRequirement.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.id, requirement.id)
        XCTAssertEqual(decoded.procedure, requirement.procedure)
        XCTAssertEqual(decoded.stages, requirement.stages)
        XCTAssertEqual(decoded.angles, requirement.angles)
    }

    func testTotalRequired() {
        // Given
        let requirement = TestData.createRequirement(
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: ["Occlusal/Incisal": 2, "Buccal/Facial": 1]
        )

        // Then
        // 2 stages * (2 for Occlusal/Incisal + 1 for Buccal/Facial) = 2 * 3 = 6
        XCTAssertEqual(requirement.totalRequired, 6)
    }

    func testTotalRequiredWithDefaultCounts() {
        // Given
        let requirement = TestData.createRequirement(
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: [:]
        )

        // Then
        // 1 stage * 2 angles * 1 photo each = 2
        XCTAssertEqual(requirement.totalRequired, 2)
    }

    func testDisplayString() {
        // Given
        let requirementBothStages = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal"]
        )

        let requirementSingleStage = TestData.createRequirement(
            procedure: "Crown",
            stages: ["Restoration"],
            angles: ["Buccal/Facial", "Lingual"]
        )

        // Then
        XCTAssertTrue(requirementBothStages.displayString.contains("Class 1"))
        XCTAssertTrue(requirementBothStages.displayString.contains("Both Stages"))
        XCTAssertTrue(requirementSingleStage.displayString.contains("Restoration"))
    }

    func testRequirementIdentifiable() {
        // Given
        let requirement1 = TestData.createRequirement()
        let requirement2 = TestData.createRequirement()

        // Then
        XCTAssertNotEqual(requirement1.id, requirement2.id)
    }

    func testRequirementHashable() {
        // Given
        let requirement1 = TestData.createRequirement(id: "same-id")
        let requirement2 = PortfolioRequirement(
            id: "same-id",
            procedure: "Different",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"]
        )

        // Then
        var set = Set<PortfolioRequirement>()
        set.insert(requirement1)
        set.insert(requirement2)
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - ProcedureConfig Tests

final class ProcedureConfigTests: XCTestCase {

    func testProcedureConfigEncoding() throws {
        // Given
        let procedure = TestData.createProcedureConfig(
            name: "Test Procedure",
            colorHex: "#FF0000"
        )

        // When
        let encoded = try JSONEncoder().encode(procedure)
        let decoded = try JSONDecoder().decode(ProcedureConfig.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.name, procedure.name)
        XCTAssertEqual(decoded.colorHex, procedure.colorHex)
        XCTAssertEqual(decoded.isDefault, procedure.isDefault)
        XCTAssertEqual(decoded.isEnabled, procedure.isEnabled)
    }

    func testColor() {
        // Given
        let procedure = TestData.createProcedureConfig(colorHex: "#3B82F6")

        // Then
        XCTAssertNotNil(procedure.color)
    }

    func testDefaultProcedures() {
        // Given
        let defaults = ProcedureConfig.defaultProcedures

        // Then
        XCTAssertFalse(defaults.isEmpty)
        XCTAssertTrue(defaults.allSatisfy { $0.isDefault })
        XCTAssertTrue(defaults.contains { $0.name == "Class 1" })
        XCTAssertTrue(defaults.contains { $0.name == "Crown" })
    }

    func testDefaultProceduresSortOrder() {
        // Given
        let defaults = ProcedureConfig.defaultProcedures

        // Then
        for (index, procedure) in defaults.enumerated() {
            XCTAssertEqual(procedure.sortOrder, index)
        }
    }

    func testProcedureEquality() {
        // Given
        let procedure1 = TestData.createProcedureConfig(id: "test-id", name: "Test")
        let procedure2 = TestData.createProcedureConfig(id: "test-id", name: "Test")
        let procedure3 = TestData.createProcedureConfig(id: "other-id", name: "Test")

        // Then
        XCTAssertEqual(procedure1, procedure2)
        XCTAssertNotEqual(procedure1, procedure3)
    }
}

// MARK: - ToothEntry Tests

final class ToothEntryTests: XCTestCase {

    func testToothEntryCreation() {
        // Given
        let entry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14
        )

        // Then
        XCTAssertEqual(entry.procedure, "Class 1")
        XCTAssertEqual(entry.toothNumber, 14)
        XCTAssertNotNil(entry.date)
    }

    func testToothEntryIdentifiable() {
        // Given
        let entry1 = TestData.createToothEntry()
        let entry2 = TestData.createToothEntry()

        // Then
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testToothEntryEncoding() throws {
        // Given
        let entry = TestData.createToothEntry(
            procedure: "Crown",
            toothNumber: 30,
            date: Date()
        )

        // When
        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ToothEntry.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.procedure, entry.procedure)
        XCTAssertEqual(decoded.toothNumber, entry.toothNumber)
    }
}

// MARK: - LibraryFilter Tests

final class LibraryFilterTests: XCTestCase {

    func testEmptyFilter() {
        // Given
        let filter = LibraryFilter()

        // Then
        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testFilterWithProcedures() {
        // Given
        var filter = LibraryFilter()
        filter.procedures = ["Class 1", "Crown"]

        // Then
        XCTAssertFalse(filter.isEmpty)
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testFilterReset() {
        // Given
        var filter = TestData.createFullFilter()
        XCTAssertFalse(filter.isEmpty)

        // When
        filter.reset()

        // Then
        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testDateRangeLastWeek() {
        // Given
        let dateRange = LibraryFilter.DateRange.lastWeek

        // Then
        XCTAssertEqual(dateRange.displayName, "Last Week")
        let dates = dateRange.dates
        let daysDiff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        XCTAssertEqual(daysDiff, 7)
    }

    func testDateRangeLastMonth() {
        // Given
        let dateRange = LibraryFilter.DateRange.lastMonth

        // Then
        XCTAssertEqual(dateRange.displayName, "Last Month")
    }

    func testDateRangeCustom() {
        // Given
        let start = TestUtilities.dateRelativeToToday(days: -10)
        let end = Date()
        let dateRange = LibraryFilter.DateRange.custom(start: start, end: end)

        // Then
        XCTAssertEqual(dateRange.displayName, "Custom Range")
        XCTAssertEqual(dateRange.dates.start, start)
        XCTAssertEqual(dateRange.dates.end, end)
    }

    func testActiveFilterCountMultiple() {
        // Given
        var filter = LibraryFilter()
        filter.procedures = ["Class 1"]
        filter.stages = ["Preparation"]
        filter.angles = ["Occlusal/Incisal"]
        filter.minimumRating = 3
        filter.dateRange = .lastMonth
        filter.portfolioId = "test-id"

        // Then
        XCTAssertEqual(filter.activeFilterCount, 6)
    }
}
