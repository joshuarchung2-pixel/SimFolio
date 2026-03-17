// NavigationRouterTests.swift
// SimFolioTests - NavigationRouter Unit Tests
//
// Tests for the NavigationRouter service including:
// - Tab navigation
// - Capture flow management
// - Portfolio navigation
// - Sheet presentation
// - Alert management

import XCTest
@testable import SimFolio

final class NavigationRouterTests: XCTestCase {

    var sut: NavigationRouter!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        sut = NavigationRouter()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialTab() {
        XCTAssertEqual(sut.selectedTab, .home)
    }

    func testInitialTabBarVisibility() {
        XCTAssertTrue(sut.isTabBarVisible)
    }

    func testInitialCaptureFlowState() {
        XCTAssertFalse(sut.captureFlowActive)
        XCTAssertNil(sut.capturePrefilledProcedure)
        XCTAssertNil(sut.capturePrefilledStage)
        XCTAssertNil(sut.capturePrefilledAngle)
    }

    func testInitialAlertState() {
        XCTAssertFalse(sut.showAlert)
        XCTAssertEqual(sut.alertTitle, "")
        XCTAssertEqual(sut.alertMessage, "")
    }

    // MARK: - Tab Navigation Tests

    func testNavigateToHome() {
        // Given
        sut.selectedTab = .library

        // When
        sut.navigateToHome()

        // Then
        XCTAssertEqual(sut.selectedTab, .home)
    }

    func testNavigateToLibrary() {
        // Given
        sut.selectedTab = .home

        // When
        sut.navigateToLibrary()

        // Then
        XCTAssertEqual(sut.selectedTab, .library)
    }

    func testNavigateToLibraryWithFilter() {
        // Given
        let filter = TestData.createFullFilter()

        // When
        sut.navigateToLibrary(filter: filter)

        // Then
        XCTAssertEqual(sut.selectedTab, .library)
        XCTAssertFalse(sut.libraryFilter.procedures.isEmpty)
    }

    // MARK: - Capture Navigation Tests

    func testNavigateToCapture() {
        // When
        sut.navigateToCapture()

        // Then
        XCTAssertEqual(sut.selectedTab, .capture)
        XCTAssertTrue(sut.captureFlowActive)
    }

    func testNavigateToCaptureWithPresets() {
        // When
        sut.navigateToCapture(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal",
            toothNumber: 14
        )

        // Then
        XCTAssertEqual(sut.selectedTab, .capture)
        XCTAssertTrue(sut.captureFlowActive)
        XCTAssertEqual(sut.capturePrefilledProcedure, "Class 1")
        XCTAssertEqual(sut.capturePrefilledStage, "Preparation")
        XCTAssertEqual(sut.capturePrefilledAngle, "Occlusal/Incisal")
        XCTAssertEqual(sut.capturePrefilledToothNumber, 14)
    }

    func testNavigateToCaptureForPortfolio() {
        // Given
        let portfolioId = "test-portfolio-id"

        // When
        sut.navigateToCapture(
            procedure: "Crown",
            forPortfolioId: portfolioId
        )

        // Then
        XCTAssertEqual(sut.captureFromPortfolioId, portfolioId)
    }

    func testResetCaptureState() {
        // Given
        sut.navigateToCapture(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal",
            toothNumber: 14,
            forPortfolioId: "portfolio-id"
        )

        // When
        sut.resetCaptureState()

        // Then
        XCTAssertFalse(sut.captureFlowActive)
        XCTAssertNil(sut.capturePrefilledProcedure)
        XCTAssertNil(sut.capturePrefilledStage)
        XCTAssertNil(sut.capturePrefilledAngle)
        XCTAssertNil(sut.capturePrefilledToothNumber)
        XCTAssertNil(sut.captureFromPortfolioId)
    }

    // MARK: - Portfolio Navigation Tests

    func testNavigateToPortfolio() {
        // Given
        let portfolioId = "test-portfolio-id"

        // When
        sut.navigateToPortfolio(id: portfolioId)

        // Then
        XCTAssertEqual(sut.selectedPortfolioId, portfolioId)
        XCTAssertEqual(sut.activeSheet, .portfolioDetail(id: portfolioId))
    }

    func testNavigateToPhotoDetail() {
        // Given
        let photoId = "test-photo-id"

        // When
        sut.navigateToPhotoDetail(id: photoId)

        // Then
        XCTAssertEqual(sut.activeSheet, .photoDetail(id: photoId))
    }

    // MARK: - Sheet Management Tests

    func testPresentSheet() {
        // When
        sut.presentSheet(.settings)

        // Then
        XCTAssertEqual(sut.activeSheet, .settings)
    }

    func testDismissSheet() {
        // Given
        sut.presentSheet(.settings)

        // When
        sut.dismissSheet()

        // Then
        XCTAssertNil(sut.activeSheet)
    }

    func testSheetTypeEquality() {
        // Given
        let sheet1 = NavigationRouter.SheetType.photoDetail(id: "123")
        let sheet2 = NavigationRouter.SheetType.photoDetail(id: "123")
        let sheet3 = NavigationRouter.SheetType.photoDetail(id: "456")

        // Then
        XCTAssertEqual(sheet1, sheet2)
        XCTAssertNotEqual(sheet1, sheet3)
    }

    func testSheetTypeIdentifiable() {
        // Given
        let sheets: [NavigationRouter.SheetType] = [
            .settings,
            .photoDetail(id: "123"),
            .portfolioDetail(id: "456"),
            .shareSheet(photoIds: ["a", "b"])
        ]

        // Then
        let uniqueIds = Set(sheets.map { $0.id })
        XCTAssertEqual(uniqueIds.count, sheets.count)
    }

    // MARK: - Tab Bar Visibility Tests

    func testHideTabBar() {
        // When
        sut.hideTabBar()

        // Then
        XCTAssertFalse(sut.isTabBarVisible)
    }

    func testShowTabBar() {
        // Given
        sut.hideTabBar()

        // When
        sut.showTabBar()

        // Then
        XCTAssertTrue(sut.isTabBarVisible)
    }

    func testSetTabBarVisible() {
        // When
        sut.setTabBarVisible(false)

        // Then
        XCTAssertFalse(sut.isTabBarVisible)

        // When
        sut.setTabBarVisible(true)

        // Then
        XCTAssertTrue(sut.isTabBarVisible)
    }

    // MARK: - Alert Tests

    func testShowAlertDialog() {
        // When
        sut.showAlertDialog(
            title: "Test Title",
            message: "Test Message"
        )

        // Then
        XCTAssertTrue(sut.showAlert)
        XCTAssertEqual(sut.alertTitle, "Test Title")
        XCTAssertEqual(sut.alertMessage, "Test Message")
    }

    func testShowConfirmation() {
        // Given
        var confirmed = false

        // When
        sut.showConfirmation(
            title: "Confirm",
            message: "Are you sure?"
        ) {
            confirmed = true
        }

        // Execute the action
        sut.alertPrimaryAction?()

        // Then
        XCTAssertTrue(sut.showAlert)
        XCTAssertTrue(confirmed)
    }

    func testDismissAlert() {
        // Given
        sut.showAlertDialog(title: "Test", message: "Test")

        // When
        sut.dismissAlert()

        // Then
        XCTAssertFalse(sut.showAlert)
        XCTAssertEqual(sut.alertTitle, "")
        XCTAssertEqual(sut.alertMessage, "")
        XCTAssertNil(sut.alertPrimaryAction)
        XCTAssertNil(sut.alertSecondaryAction)
    }

    // MARK: - Reset Tests

    func testResetAll() {
        // Given
        sut.selectedTab = .library
        sut.navigateToCapture(procedure: "Class 1")
        sut.presentSheet(.settings)
        sut.hideTabBar()
        sut.showAlertDialog(title: "Test", message: "Test")

        // When
        sut.resetAll()

        // Then
        XCTAssertEqual(sut.selectedTab, .home)
        XCTAssertFalse(sut.captureFlowActive)
        XCTAssertNil(sut.capturePrefilledProcedure)
        XCTAssertNil(sut.activeSheet)
        XCTAssertTrue(sut.isTabBarVisible)
        XCTAssertFalse(sut.showAlert)
    }

    // MARK: - Library Filter Tests

    func testLibraryFilterReset() {
        // Given
        sut.libraryFilter = TestData.createFullFilter()
        XCTAssertFalse(sut.libraryFilter.isEmpty)

        // When
        sut.libraryFilter.reset()

        // Then
        XCTAssertTrue(sut.libraryFilter.isEmpty)
    }

    func testLibraryFilterActiveCount() {
        // Given
        var filter = LibraryFilter()
        XCTAssertEqual(filter.activeFilterCount, 0)

        // When
        filter.procedures = ["Class 1"]
        filter.stages = ["Preparation"]
        filter.minimumRating = 3

        // Then
        XCTAssertEqual(filter.activeFilterCount, 3)
    }

    func testLibraryFilterDateRange() {
        // Given
        let filter = TestData.createLibraryFilter(dateRange: .lastMonth)

        // Then
        XCTAssertNotNil(filter.dateRange)
        XCTAssertEqual(filter.dateRange?.displayName, "Last Month")

        let dates = filter.dateRange?.dates
        XCTAssertNotNil(dates)
        XCTAssertLessThan(dates!.start, dates!.end)
    }
}

// MARK: - MainTab Tests

final class MainTabTests: XCTestCase {

    func testTabCount() {
        XCTAssertEqual(MainTab.allCases.count, 4)
    }

    func testTabTitles() {
        XCTAssertEqual(MainTab.home.title, "Home")
        XCTAssertEqual(MainTab.capture.title, "Capture")
        XCTAssertEqual(MainTab.library.title, "Library")
        XCTAssertEqual(MainTab.profile.title, "Profile")
    }

    func testTabIcons() {
        XCTAssertEqual(MainTab.home.icon, "house")
        XCTAssertEqual(MainTab.capture.icon, "camera")
        XCTAssertEqual(MainTab.library.icon, "photo.on.rectangle")
        XCTAssertEqual(MainTab.profile.icon, "person")
    }

    func testTabSelectedIcons() {
        XCTAssertEqual(MainTab.home.selectedIcon, "house.fill")
        XCTAssertEqual(MainTab.capture.selectedIcon, "camera.fill")
        XCTAssertEqual(MainTab.library.selectedIcon, "photo.on.rectangle.fill")
        XCTAssertEqual(MainTab.profile.selectedIcon, "person.fill")
    }

    func testTabRawValues() {
        XCTAssertEqual(MainTab.home.rawValue, 0)
        XCTAssertEqual(MainTab.capture.rawValue, 1)
        XCTAssertEqual(MainTab.library.rawValue, 2)
        XCTAssertEqual(MainTab.profile.rawValue, 3)
    }

    func testTabAccessibilityHint() {
        XCTAssertEqual(MainTab.home.accessibilityHint, "Double tap to switch to Home")
        XCTAssertEqual(MainTab.library.accessibilityHint, "Double tap to switch to Library")
    }
}
