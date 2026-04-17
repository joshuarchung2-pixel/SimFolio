// BulkTagFlowUITests.swift
// SimFolio - End-to-end: import untagged photos -> Needs Tagging chip ->
// multi-select -> apply tags -> badge/count drops.

import XCTest

final class BulkTagFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--skip-onboarding",
            "--reset-all-data",
            "--with-sample-data",
            "--mock-photos-picker"
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testImportToBulkTagFlow() throws {
        // 1. Open Capture tab, tap Import From Photos.
        app.tabBars.buttons["Capture"].tap()
        let importButton = app.buttons["capture-import-from-photos"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        // 2. Mock picker seeds candidates; review screen opens without tag UI.
        // Confirm the tag summary bar is NOT present.
        XCTAssertFalse(app.buttons.matching(identifier: "import-tag-summary").firstMatch.exists)

        // 3. Tap the Import primary CTA.
        let importCTA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import'")).firstMatch
        XCTAssertTrue(importCTA.waitForExistence(timeout: 3))
        importCTA.tap()

        // 4. Wait for the post-import toast and tap it to deep-link to Library.
        let toast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tap to tag'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        toast.tap()

        // 5. Library should be on the Needs Tagging chip.
        let chip = app.buttons["needs-tagging-chip-needs-tagging"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))

        // 6. Enter selection mode.
        let selectionToggle = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'Select' OR label CONTAINS 'checkmark'")).firstMatch
        XCTAssertTrue(selectionToggle.waitForExistence(timeout: 3))
        selectionToggle.tap()

        // 7. Tap first two grid cells to select them.
        let cells = app.collectionViews.cells
        if cells.count >= 2 {
            cells.element(boundBy: 0).tap()
            cells.element(boundBy: 1).tap()
        }

        // 8. Tap Tag in the selection action bar.
        app.buttons["Tag"].tap()

        // 9. Bulk tag sheet opens — pick a procedure and apply.
        let firstProcedurePill = app.buttons.matching(NSPredicate(format: "label == 'Class 1'")).firstMatch
        XCTAssertTrue(firstProcedurePill.waitForExistence(timeout: 3))
        firstProcedurePill.tap()

        app.buttons["Apply"].tap()

        // 10. Success toast confirms N photos tagged.
        let successToast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tagged'")).firstMatch
        XCTAssertTrue(successToast.waitForExistence(timeout: 5))
    }
}
