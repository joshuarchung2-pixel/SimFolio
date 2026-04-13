// NavigationRouterTests.swift
// SimFolioTests - NavigationRouter tests using MockNavigationRouter

import XCTest
@testable import SimFolio

final class NavigationRouterTests: XCTestCase {

    var sut: MockNavigationRouter!

    override func setUp() {
        super.setUp()
        sut = MockNavigationRouter()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Default State

    func testDefaultSelectedTab() {
        XCTAssertEqual(sut.selectedTab, .home)
    }

    func testDefaultTabBarVisible() {
        XCTAssertTrue(sut.isTabBarVisible)
    }

    func testDefaultCaptureFlowInactive() {
        XCTAssertFalse(sut.captureFlowActive)
    }

    func testDefaultActiveSheetNil() {
        XCTAssertNil(sut.activeSheet)
    }

    // MARK: - navigateToCapture

    func testNavigateToCaptureSetsTabAndFlow() {
        sut.navigateToCapture(procedure: nil, stage: nil, angle: nil, toothNumber: nil, forPortfolioId: nil)
        XCTAssertEqual(sut.selectedTab, .capture)
        XCTAssertTrue(sut.captureFlowActive)
        XCTAssertEqual(sut.navigateToCaptureCalls.count, 1)
    }

    func testNavigateToCaptureWithProcedureAndStage() {
        sut.navigateToCapture(procedure: "Crown", stage: "Preparation", angle: nil, toothNumber: nil, forPortfolioId: nil)
        XCTAssertEqual(sut.navigateToCaptureCalls.count, 1)
        XCTAssertEqual(sut.navigateToCaptureCalls.first?.procedure, "Crown")
        XCTAssertEqual(sut.navigateToCaptureCalls.first?.stage, "Preparation")
        XCTAssertEqual(sut.selectedTab, .capture)
        XCTAssertTrue(sut.captureFlowActive)
    }

    func testNavigateToCaptureNilArguments() {
        sut.navigateToCapture(procedure: nil, stage: nil, angle: nil, toothNumber: nil, forPortfolioId: nil)
        XCTAssertNil(sut.navigateToCaptureCalls.first?.procedure)
        XCTAssertNil(sut.navigateToCaptureCalls.first?.stage)
    }

    // MARK: - navigateToLibrary

    func testNavigateToLibraryWithoutFilter() {
        sut.navigateToLibrary(filter: nil)
        XCTAssertEqual(sut.selectedTab, .library)
        XCTAssertEqual(sut.navigateToLibraryCalls, 1)
    }

    func testNavigateToLibraryWithFilter() {
        let filter = TestData.createFullFilter()
        sut.navigateToLibrary(filter: filter)
        XCTAssertEqual(sut.selectedTab, .library)
        XCTAssertFalse(sut.libraryFilter.procedures.isEmpty)
    }

    func testNavigateToLibraryNilFilterPreservesExisting() {
        var filter = LibraryFilter()
        filter.procedures = ["Class 1"]
        sut.libraryFilter = filter
        sut.navigateToLibrary(filter: nil)
        // Mock preserves existing filter when nil is passed (no replacement)
        XCTAssertFalse(sut.libraryFilter.procedures.isEmpty)
    }

    // MARK: - navigateToPortfolio

    func testNavigateToPortfolio() {
        sut.navigateToPortfolio(id: "portfolio-123")
        XCTAssertEqual(sut.navigateToPortfolioCalls, ["portfolio-123"])
    }

    func testNavigateToPortfolioMultipleTimes() {
        sut.navigateToPortfolio(id: "p1")
        sut.navigateToPortfolio(id: "p2")
        XCTAssertEqual(sut.navigateToPortfolioCalls, ["p1", "p2"])
    }

    // MARK: - Sheet Management

    func testPresentSheet() {
        sut.presentSheet(.settings)
        XCTAssertEqual(sut.activeSheet, .settings)
        XCTAssertEqual(sut.presentSheetCalls.count, 1)
    }

    func testDismissSheet() {
        sut.presentSheet(.settings)
        sut.dismissSheet()
        XCTAssertNil(sut.activeSheet)
    }

    func testPresentSheetCallTracking() {
        sut.presentSheet(.settings)
        sut.presentSheet(.portfolioDetail(id: "p1"))
        XCTAssertEqual(sut.presentSheetCalls.count, 2)
        XCTAssertEqual(sut.presentSheetCalls[0], .settings)
        XCTAssertEqual(sut.presentSheetCalls[1], .portfolioDetail(id: "p1"))
    }

    // MARK: - Tab Bar Visibility

    func testShowTabBar() {
        sut.isTabBarVisible = false
        sut.showTabBar()
        XCTAssertTrue(sut.isTabBarVisible)
    }

    func testHideTabBar() {
        sut.hideTabBar()
        XCTAssertFalse(sut.isTabBarVisible)
    }

    // MARK: - resetAll

    func testResetAllRestoresDefaults() {
        sut.selectedTab = .library
        sut.navigateToCapture(procedure: "Crown", stage: "Prep", angle: nil, toothNumber: nil, forPortfolioId: nil)
        sut.presentSheet(.settings)
        sut.hideTabBar()

        sut.resetAll()

        XCTAssertEqual(sut.selectedTab, .home)
        XCTAssertFalse(sut.captureFlowActive)
        XCTAssertNil(sut.activeSheet)
        XCTAssertTrue(sut.isTabBarVisible)
    }

    func testResetAllResetsLibraryFilter() {
        sut.libraryFilter = TestData.createFullFilter()
        XCTAssertFalse(sut.libraryFilter.isEmpty)
        sut.resetAll()
        XCTAssertTrue(sut.libraryFilter.isEmpty)
    }
}
