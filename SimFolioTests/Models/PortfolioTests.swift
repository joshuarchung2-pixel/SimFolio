// PortfolioTests.swift
// SimFolioTests/Models — Unit tests for Portfolio model

import XCTest
@testable import SimFolio

final class PortfolioTests: XCTestCase {

    // MARK: - Encoding / Decoding

    func testEncoding() throws {
        let portfolio = TestData.createPortfolio(name: "Test Portfolio")

        let encoded = try JSONEncoder().encode(portfolio)
        let decoded = try JSONDecoder().decode(Portfolio.self, from: encoded)

        XCTAssertEqual(decoded.id, portfolio.id)
        XCTAssertEqual(decoded.name, portfolio.name)
        XCTAssertEqual(decoded.requirements.count, portfolio.requirements.count)
    }

    // MARK: - Identifiable

    func testIdentifiable_eachInstanceHasUniqueId() {
        let portfolio1 = TestData.createPortfolio()
        let portfolio2 = TestData.createPortfolio()

        XCTAssertNotEqual(portfolio1.id, portfolio2.id)
    }

    // MARK: - Hashable (id-based)

    func testHashable_sameIdCountsAsOneSetEntry() {
        let portfolio1 = TestData.createPortfolio(id: "same-id")
        let portfolio2 = Portfolio(id: "same-id", name: "Different Name")

        var set = Set<Portfolio>()
        set.insert(portfolio1)
        set.insert(portfolio2)
        XCTAssertEqual(set.count, 1)
    }

    func testHashable_differentIdsAreSeparateEntries() {
        let portfolio1 = TestData.createPortfolio()
        let portfolio2 = TestData.createPortfolio()

        var set = Set<Portfolio>()
        set.insert(portfolio1)
        set.insert(portfolio2)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - dateString

    func testDateString_nonEmpty() {
        let portfolio = TestData.createPortfolio(createdDate: TestData.referenceDate)
        XCTAssertFalse(portfolio.dateString.isEmpty)
    }

    func testDateString_deterministicWithReferenceDate() {
        // The formatted string should contain "2025" since referenceDate is Jan 15 2025
        let portfolio = TestData.createPortfolio(createdDate: TestData.referenceDate)
        XCTAssertTrue(portfolio.dateString.contains("2025"))
    }

    // MARK: - daysUntilDue

    func testDaysUntilDue_future() {
        let portfolio = TestData.createFuturePortfolio(daysUntilDue: 7)
        XCTAssertEqual(portfolio.daysUntilDue, 7)
    }

    func testDaysUntilDue_overdue() {
        let portfolio = TestData.createOverduePortfolio(daysOverdue: 3)
        XCTAssertEqual(portfolio.daysUntilDue, -3)
    }

    func testDaysUntilDue_noDueDate() {
        let portfolio = Portfolio(name: "No Due Date")
        XCTAssertNil(portfolio.daysUntilDue)
    }

    func testDueDateString_presentWhenDueDateSet() {
        let portfolio = TestData.createPortfolio(dueDate: TestUtilities.dateRelativeToToday(days: 7))
        XCTAssertNotNil(portfolio.dueDateString)
    }

    func testDueDateString_nilWhenNoDueDate() {
        let portfolio = Portfolio(name: "No Due Date")
        XCTAssertNil(portfolio.dueDateString)
    }

    // MARK: - isOverdue

    func testIsOverdue_whenPastDueDate() {
        let portfolio = TestData.createOverduePortfolio(daysOverdue: 3)
        XCTAssertTrue(portfolio.isOverdue)
    }

    func testIsOverdue_whenFutureDueDate() {
        let portfolio = TestData.createFuturePortfolio(daysUntilDue: 7)
        XCTAssertFalse(portfolio.isOverdue)
    }

    func testIsOverdue_whenNoDueDate() {
        let portfolio = Portfolio(name: "No Due Date")
        XCTAssertFalse(portfolio.isOverdue)
    }

    // MARK: - isDueSoon

    func testIsDueSoon_when3DaysOut() {
        let portfolio = TestData.createDueSoonPortfolio(daysUntilDue: 3)
        XCTAssertTrue(portfolio.isDueSoon)
    }

    func testIsDueSoon_exactly7Days() {
        let portfolio = TestData.createFuturePortfolio(daysUntilDue: 7)
        XCTAssertTrue(portfolio.isDueSoon)
    }

    func testIsDueSoon_falseWhen8Days() {
        let portfolio = TestData.createFuturePortfolio(daysUntilDue: 14)
        XCTAssertFalse(portfolio.isDueSoon)
    }

    func testIsDueSoon_falseWhenOverdue() {
        let portfolio = TestData.createOverduePortfolio(daysOverdue: 1)
        XCTAssertFalse(portfolio.isDueSoon)
    }

    func testIsDueSoon_falseWhenNoDueDate() {
        let portfolio = Portfolio(name: "No Due Date")
        XCTAssertFalse(portfolio.isDueSoon)
    }
}
