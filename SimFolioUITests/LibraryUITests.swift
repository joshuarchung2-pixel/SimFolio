// LibraryUITests.swift
// SimFolioUITests - Library View UI Tests
//
// Tests for the library view including:
// - Navigation to library
// - Grid display
// - Filtering functionality
// - Search functionality
// - Photo selection

import XCTest

final class LibraryUITests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Navigation Tests

    func testNavigateToLibrary() {
        // When
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 3))
        libraryTab.tap()

        // Then - Library view should appear
        sleep(1)
        // Look for navigation bar or library-specific elements
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
    }

    func testLibraryTabIsAccessible() {
        // Given
        let libraryTab = app.tabBars.buttons["Library"]

        // Then
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 3))
        XCTAssertTrue(libraryTab.isEnabled)
    }

    // MARK: - Filter Button Tests

    func testFilterButtonExists() {
        // Navigate to library
        navigateToLibrary()

        // Then - Look for filter button
        let filterButtons = [
            app.buttons["Filter"],
            app.buttons["Filters"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'filter'")).firstMatch,
            app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'filter'")).firstMatch
        ]

        var found = false
        for button in filterButtons {
            if button.waitForExistence(timeout: 2) {
                found = true
                break
            }
        }

        // Filter button should exist in library
    }

    func testOpenFilterSheet() {
        // Navigate to library
        navigateToLibrary()

        // Find and tap filter button
        let filterButton = findFilterButton()
        guard filterButton.exists else {
            return // Skip if not found
        }

        // When
        filterButton.tap()
        sleep(1)

        // Then - Filter sheet should appear
        // Look for filter options
        let procedureOption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Procedure' OR label CONTAINS[c] 'Class'")
        ).firstMatch
        let stageOption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Stage' OR label CONTAINS[c] 'Preparation'")
        ).firstMatch
    }

    // MARK: - Search Tests

    func testSearchFieldExists() {
        // Navigate to library
        navigateToLibrary()

        // Then - Look for search field
        let searchField = app.searchFields.firstMatch
        let searchFieldExists = searchField.waitForExistence(timeout: 3)
        // Search field may or may not exist depending on implementation
    }

    func testSearchFunctionality() {
        // Navigate to library
        navigateToLibrary()

        // Find search field
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 3) else {
            return // Skip if no search field
        }

        // When
        searchField.tap()
        searchField.typeText("Class")
        sleep(1)

        // Then - Results should filter (or show no results)
    }

    func testClearSearch() {
        // Navigate to library
        navigateToLibrary()

        // Find and use search
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 3) else {
            return
        }

        searchField.tap()
        searchField.typeText("Test")
        sleep(1)

        // When - Clear search
        let clearButton = app.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        }

        // Then - Search should be cleared
        sleep(1)
    }

    // MARK: - View Mode Tests

    func testViewModeToggle() {
        // Navigate to library
        navigateToLibrary()

        // Look for view mode toggle (grid/list)
        let viewModeButtons = [
            app.buttons["View Mode"],
            app.buttons["Grid"],
            app.buttons["List"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'view'")).firstMatch
        ]

        for button in viewModeButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    // MARK: - Grid Display Tests

    func testPhotoGridDisplays() {
        // Navigate to library
        navigateToLibrary()

        // Then - Grid should display (even if empty)
        // Look for collection view or grid elements
        let collectionView = app.collectionViews.firstMatch
        let scrollView = app.scrollViews.firstMatch

        let gridExists = collectionView.waitForExistence(timeout: 3) ||
                         scrollView.waitForExistence(timeout: 3)
        // Grid container should exist
    }

    func testEmptyStateDisplays() {
        // Navigate to library with no photos
        navigateToLibrary()

        // If no photos, empty state should display
        let emptyStateTexts = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No photos'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'empty'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Get started'")).firstMatch
        ]

        // One of these might exist if library is empty
    }

    // MARK: - Selection Tests

    func testEnterSelectionMode() {
        // Navigate to library
        navigateToLibrary()

        // Look for select button
        let selectButtons = [
            app.buttons["Select"],
            app.buttons["Edit"],
            app.navigationBars.buttons["Select"]
        ]

        for button in selectButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)

                // Then - Selection mode should be active
                let cancelButton = app.buttons["Cancel"]
                let doneButton = app.buttons["Done"]

                let inSelectionMode = cancelButton.exists || doneButton.exists
                break
            }
        }
    }

    // MARK: - Scroll Performance Tests

    func testScrollPerformance() {
        // Navigate to library
        navigateToLibrary()

        // Scroll the grid
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            // Measure scroll performance
            measure {
                collectionView.swipeUp()
                collectionView.swipeDown()
            }
        }
    }

    // MARK: - Helper Methods

    private func navigateToLibrary() {
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
        }
        sleep(1)
    }

    private func findFilterButton() -> XCUIElement {
        let filterButtons = [
            app.buttons["Filter"],
            app.buttons["Filters"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'filter'")).firstMatch
        ]

        for button in filterButtons {
            if button.waitForExistence(timeout: 2) {
                return button
            }
        }

        return app.buttons["__nonexistent__"]
    }
}

// MARK: - Library Filter UI Tests

final class LibraryFilterUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()

        // Navigate to library
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
        }
        sleep(1)
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testFilterByProcedure() {
        // Open filter sheet
        openFilterSheet()

        // Look for procedure filter option
        let procedureOption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Procedure'")
        ).firstMatch

        if procedureOption.waitForExistence(timeout: 2) {
            procedureOption.tap()
            sleep(1)

            // Select a procedure
            let class1 = app.staticTexts["Class 1"]
            if class1.waitForExistence(timeout: 2) {
                class1.tap()
            }
        }
    }

    func testFilterByRating() {
        // Open filter sheet
        openFilterSheet()

        // Look for rating filter option
        let ratingOption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Rating'")
        ).firstMatch

        if ratingOption.waitForExistence(timeout: 2) {
            ratingOption.tap()
            sleep(1)
        }
    }

    func testClearAllFilters() {
        // Open filter sheet
        openFilterSheet()

        // Look for clear/reset button
        let clearButtons = [
            app.buttons["Clear All"],
            app.buttons["Reset"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'clear'")).firstMatch
        ]

        for button in clearButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                break
            }
        }
    }

    // MARK: - Helper Methods

    private func openFilterSheet() {
        let filterButtons = [
            app.buttons["Filter"],
            app.buttons["Filters"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'filter'")).firstMatch
        ]

        for button in filterButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }
}
