// ImportFlowUITests.swift
// SimFolioUITests - Import from Photos flow UI tests
//
// Note: requires a SimFolioUITests Xcode target. These tests use the --mock-photos-picker
// launch argument which swaps the PhotosPicker for deterministic in-memory candidates
// (see SimFolioApp.makeMockImportCandidates).

import XCTest

final class ImportFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--skip-onboarding",
            "--reset-all-data",
            "--mock-photos-picker"
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Entry via Home

    func testHomeImportEntryLaunchesFlow() {
        // Home empty-state import button exists and is tappable.
        let homeImportButton = app.buttons["home-import-from-photos"]
        XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
        homeImportButton.tap()

        // With the mock picker override in place, the flow jumps straight to the review
        // screen; the primary "Import N Photos" button should surface.
        let importPrimary = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Import '")
        ).firstMatch
        XCTAssertTrue(importPrimary.waitForExistence(timeout: 5))
    }

    // MARK: - Full Flow

    func testSelectReviewTagImportFlow() {
        let homeImportButton = app.buttons["home-import-from-photos"]
        XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
        homeImportButton.tap()

        // Kick off the import from the review screen. Three mock candidates are seeded.
        let importPrimary = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Import '")
        ).firstMatch
        XCTAssertTrue(importPrimary.waitForExistence(timeout: 5))
        importPrimary.tap()

        // Success toast should reference the import count.
        let toast = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'imported'")
        ).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 8))
    }

    // MARK: - Dedup

    func testReimportReportsAlreadyInLibrary() {
        // First import run.
        let homeImportButton = app.buttons["home-import-from-photos"]
        XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
        homeImportButton.tap()

        let importPrimary = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Import '")
        ).firstMatch
        XCTAssertTrue(importPrimary.waitForExistence(timeout: 5))
        importPrimary.tap()

        // Wait for the first toast to come and go.
        let toast = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'imported'")
        ).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 8))

        // Second import run — same mock assets, should surface "already in library".
        XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
        homeImportButton.tap()

        let importPrimary2 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Import '")
        ).firstMatch
        XCTAssertTrue(importPrimary2.waitForExistence(timeout: 5))
        importPrimary2.tap()

        let dedupeToast = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'already in library'")
        ).firstMatch
        XCTAssertTrue(dedupeToast.waitForExistence(timeout: 8))
    }

    // MARK: - Library Empty State Entry

    func testLibraryEmptyStateExposesImport() {
        app.tabBars.buttons["Library"].tap()

        let libraryImportButton = app.buttons["library-import-from-photos"]
        XCTAssertTrue(libraryImportButton.waitForExistence(timeout: 5))
    }

    // MARK: - Capture Entry

    func testCaptureScreenExposesImport() {
        app.tabBars.buttons["Capture"].tap()

        let captureImportButton = app.buttons["capture-import-from-photos"]
        // Capture screen may take a moment to render behind a permission prompt; allow margin.
        XCTAssertTrue(captureImportButton.waitForExistence(timeout: 8))
    }
}
