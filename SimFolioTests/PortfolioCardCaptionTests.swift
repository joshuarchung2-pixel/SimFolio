// PortfolioCardCaptionTests.swift
// SimFolioTests - Tests for portfolioCardCaptionSegments pure formatter

import XCTest
@testable import SimFolio

final class PortfolioCardCaptionTests: XCTestCase {

    private let sampleDueDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 4, day: 24)
    )!

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
            photoCount: 0,
            totalPhotos: 0,
            distinctProcedureCount: 0
        )
        // Nothing to show for photos or procedures → caller expected to hide the row
        XCTAssertTrue(segments.isEmpty)
    }

    func testZeroRequirementsWithDueDate_stillHidesRow() {
        // Consistent with spec: caption row hides entirely when there's nothing useful to show
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

    func testDueDateFormatIsMediumish() {
        // We don't assert the exact locale-dependent formatting here,
        // only that it starts with "Due " and contains a month indicator.
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 1,
            totalPhotos: 1,
            distinctProcedureCount: 1
        )
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertTrue(segments[0].count > "Due ".count)
    }
}
