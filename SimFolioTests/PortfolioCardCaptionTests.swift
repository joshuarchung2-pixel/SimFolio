// PortfolioCardCaptionTests.swift
// SimFolioTests - Tests for portfolioCardCaptionSegments pure formatter

import XCTest
@testable import SimFolio

final class PortfolioCardCaptionTests: XCTestCase {

    // Apr 24 2026 — a deterministic future date relative to referenceDate (Jan 15 2025)
    private let sampleDueDate = TestData.date(daysFromReference: 464) // ~15 months ahead

    func testAllSegmentsPresent() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 12,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments.count, 3)
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertEqual(segments[1], "12/30 photos")
        XCTAssertEqual(segments[2], "5 procedures")
    }

    func testNoDueDate_dropsFirstSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: nil,
            photoCount: 12,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments, ["12/30 photos", "5 procedures"])
    }

    func testSingleProcedure_usesSingularLabel() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 3,
            totalPhotos: 10,
            distinctProcedureCount: 1
        )
        XCTAssertEqual(segments.last, "1 procedure")
    }

    func testZeroProcedures_dropsProcedureSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 5,
            totalPhotos: 20,
            distinctProcedureCount: 0
        )
        XCTAssertEqual(segments.count, 2)
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertEqual(segments[1], "5/20 photos")
        XCTAssertFalse(segments.contains(where: { $0.contains("procedure") }))
    }

    func testZeroRequirementsWithDueDate_stillHidesRow() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 0,
            totalPhotos: 0,
            distinctProcedureCount: 0
        )
        XCTAssertTrue(segments.isEmpty)
    }

    func testZeroPhotosWithRequirements_keepsPhotosSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: nil,
            photoCount: 0,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments, ["0/30 photos", "5 procedures"])
    }

    func testDueDateFormatStartsWithDue() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 1,
            totalPhotos: 1,
            distinctProcedureCount: 1
        )
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertGreaterThan(segments[0].count, "Due ".count)
    }
}
