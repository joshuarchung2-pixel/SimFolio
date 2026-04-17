// LibraryFilterTests.swift
// SimFolioTests/Models — Unit tests for LibraryFilter model

import XCTest
@testable import SimFolio

final class LibraryFilterTests: XCTestCase {

    // MARK: - isEmpty

    func testEmpty_defaultFilterIsEmpty() {
        let filter = LibraryFilter()
        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testEmpty_withProcedures_notEmpty() {
        var filter = LibraryFilter()
        filter.procedures = ["Class 1"]
        XCTAssertFalse(filter.isEmpty)
    }

    func testEmpty_withFavoritesOnly_notEmpty() {
        var filter = LibraryFilter()
        filter.favoritesOnly = true
        XCTAssertFalse(filter.isEmpty)
    }

    func testEmpty_withPortfolioId_notEmpty() {
        var filter = LibraryFilter()
        filter.portfolioId = "portfolio-123"
        XCTAssertFalse(filter.isEmpty)
    }

    // MARK: - activeFilterCount

    func testActiveFilterCount_singleProcedureIsOneFilter() {
        var filter = LibraryFilter()
        filter.procedures = ["Class 1", "Crown"]
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testActiveFilterCount_multipleFilterTypes() {
        var filter = LibraryFilter()
        filter.procedures = ["Class 1"]
        filter.stages = ["Preparation"]
        filter.angles = ["Occlusal/Incisal"]
        filter.minimumRating = 3
        filter.dateRange = .lastMonth
        filter.portfolioId = "test-id"
        // procedures(1) + stages(1) + angles(1) + rating(1) + dateRange(1) + portfolio(1) = 6
        XCTAssertEqual(filter.activeFilterCount, 6)
    }

    func testActiveFilterCount_favoritesOnly() {
        var filter = LibraryFilter()
        filter.favoritesOnly = true
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testActiveFilterCount_fullFilter() {
        var filter = TestData.createFullFilter()
        // createFullFilter sets procedures, stages, angles, minimumRating, dateRange (5)
        // favoritesOnly and portfolioId are not set by default
        XCTAssertGreaterThanOrEqual(filter.activeFilterCount, 5)
    }

    // MARK: - reset

    func testReset_clearsAllFilters() {
        var filter = TestData.createFullFilter()
        filter.portfolioId = "some-id"
        filter.favoritesOnly = true

        filter.reset()

        XCTAssertTrue(filter.isEmpty)
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testReset_fromEmptyIsNoOp() {
        var filter = LibraryFilter()
        filter.reset()
        XCTAssertTrue(filter.isEmpty)
    }

    // MARK: - DateRange

    func testDateRange_lastWeek_displayName() {
        XCTAssertEqual(LibraryFilter.DateRange.lastWeek.displayName, "Last Week")
    }

    func testDateRange_lastMonth_displayName() {
        XCTAssertEqual(LibraryFilter.DateRange.lastMonth.displayName, "Last Month")
    }

    func testDateRange_last3Months_displayName() {
        XCTAssertEqual(LibraryFilter.DateRange.last3Months.displayName, "Last 3 Months")
    }

    func testDateRange_lastYear_displayName() {
        XCTAssertEqual(LibraryFilter.DateRange.lastYear.displayName, "Last Year")
    }

    func testDateRange_custom_displayName() {
        let range = LibraryFilter.DateRange.custom(start: TestData.referenceDate, end: TestData.referenceDate)
        XCTAssertEqual(range.displayName, "Custom Range")
    }

    func testDateRange_lastWeek_datesSpan7Days() {
        let range = LibraryFilter.DateRange.lastWeek
        let dates = range.dates
        let daysDiff = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        XCTAssertEqual(daysDiff, 7)
    }

    func testDateRange_custom_returnsSameDates() {
        let start = TestUtilities.dateRelativeToToday(days: -10)
        let end   = TestUtilities.dateRelativeToToday(days: 0)
        let range = LibraryFilter.DateRange.custom(start: start, end: end)
        XCTAssertEqual(range.dates.start, start)
        XCTAssertEqual(range.dates.end,   end)
    }

    // MARK: - showUntaggedOnly

    func testDefault_showUntaggedOnly_isFalse() {
        let filter = LibraryFilter()
        XCTAssertFalse(filter.showUntaggedOnly)
    }

    func testIsEmpty_withUntaggedOnly_isTrue() {
        // The chip bar is a separate surface from the filter sheet; the filter icon
        // should not light up just because the inbox chip is active.
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        XCTAssertTrue(filter.isEmpty)
    }

    func testActiveFilterCount_withUntaggedOnly_isZero() {
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testReset_clearsUntaggedOnly() {
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        filter.reset()
        XCTAssertFalse(filter.showUntaggedOnly)
    }

    func testIsEmpty_withUntaggedOnlyAndProcedures_isFalse() {
        // Chip bar is a separate surface, but isEmpty should still return false
        // when a real filter field is set, regardless of the chip state.
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        filter.procedures.insert("Class 1")
        XCTAssertFalse(filter.isEmpty)
    }
}
