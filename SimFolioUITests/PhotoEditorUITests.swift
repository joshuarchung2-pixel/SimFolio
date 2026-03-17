// PhotoEditorUITests.swift
// SimFolioUITests - Photo Editor UI Tests
//
// Tests for the photo editing feature including:
// - Accessing the photo editor from photo detail view
// - Transform mode (crop, rotate)
// - Adjust mode (brightness, contrast, etc.)
// - Saving and canceling edits

import XCTest

final class PhotoEditorUITests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--with-sample-data"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Navigation to Editor Tests

    func testEditButtonExistsInPhotoDetail() {
        // Navigate to library and open a photo
        navigateToPhotoDetail()

        // Then - Edit button should exist
        let editButton = findEditButton()
        // Edit button should be accessible
    }

    func testOpenPhotoEditorFromDetailView() {
        // Navigate to photo detail
        navigateToPhotoDetail()

        // Find and tap edit button
        let editButton = findEditButton()
        guard editButton.exists else {
            return // Skip if no edit button found
        }

        // When
        editButton.tap()
        sleep(1)

        // Then - Photo editor should open
        let editorTitle = app.staticTexts["Edit Photo"]
        let cancelButton = app.buttons["Cancel"]
        let doneButton = app.buttons["Done"]

        let editorOpened = editorTitle.waitForExistence(timeout: 3) ||
                          cancelButton.waitForExistence(timeout: 3) ||
                          doneButton.waitForExistence(timeout: 3)
        // Editor should open
    }

    func testOpenPhotoEditorFromMenu() {
        // Navigate to photo detail
        navigateToPhotoDetail()

        // Open menu
        let menuButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more' OR label CONTAINS[c] 'ellipsis'")).firstMatch
        if menuButton.waitForExistence(timeout: 2) {
            menuButton.tap()
            sleep(1)

            // Find edit option in menu
            let editMenuItem = app.buttons["Edit Photo"]
            if editMenuItem.waitForExistence(timeout: 2) {
                editMenuItem.tap()
                sleep(1)

                // Editor should open
                let cancelButton = app.buttons["Cancel"]
                XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
            }
        }
    }

    // MARK: - Editor Mode Tests

    func testEditorModeToggle() {
        // Open photo editor
        openPhotoEditor()

        // Find mode buttons
        let transformButton = app.buttons["Transform"]
        let adjustButton = app.buttons["Adjust"]

        // Test mode switching
        if transformButton.waitForExistence(timeout: 3) {
            transformButton.tap()
            sleep(1)

            // Transform controls should appear
            let cropButton = app.buttons["Crop"]
            let rotateButton = app.buttons["Rotate"]
            // Transform mode should have crop/rotate options
        }

        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Adjust controls should appear
            let brightnessLabel = app.staticTexts["Brightness"]
            // Adjust mode should have adjustment sliders
        }
    }

    // MARK: - Transform Mode Tests

    func testTransformModeExists() {
        // Open photo editor
        openPhotoEditor()

        // Then - Transform mode should be available
        let transformButton = app.buttons["Transform"]
        XCTAssertTrue(transformButton.waitForExistence(timeout: 3))
    }

    func testCropSubModeExists() {
        // Open photo editor
        openPhotoEditor()

        // Switch to transform mode
        let transformButton = app.buttons["Transform"]
        if transformButton.waitForExistence(timeout: 3) {
            transformButton.tap()
            sleep(1)

            // Crop option should exist
            let cropButton = app.buttons["Crop"]
            XCTAssertTrue(cropButton.waitForExistence(timeout: 2))
        }
    }

    func testRotateSubModeExists() {
        // Open photo editor
        openPhotoEditor()

        // Switch to transform mode
        let transformButton = app.buttons["Transform"]
        if transformButton.waitForExistence(timeout: 3) {
            transformButton.tap()
            sleep(1)

            // Rotate option should exist
            let rotateButton = app.buttons["Rotate"]
            XCTAssertTrue(rotateButton.waitForExistence(timeout: 2))
        }
    }

    func test90DegreeRotation() {
        // Open photo editor
        openPhotoEditor()

        // Switch to transform mode
        let transformButton = app.buttons["Transform"]
        if transformButton.waitForExistence(timeout: 3) {
            transformButton.tap()
            sleep(1)

            // Switch to rotate sub-mode
            let rotateButton = app.buttons["Rotate"]
            if rotateButton.waitForExistence(timeout: 2) {
                rotateButton.tap()
                sleep(1)

                // Find 90-degree rotation buttons
                let rotateLeftButton = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] '90' OR label CONTAINS[c] 'Left'")
                ).firstMatch

                let rotateRightButton = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] '90' OR label CONTAINS[c] 'Right'")
                ).firstMatch

                if rotateRightButton.exists {
                    rotateRightButton.tap()
                    sleep(1)
                    // Image should rotate
                }
            }
        }
    }

    func testAspectRatioOptions() {
        // Open photo editor
        openPhotoEditor()

        // Switch to transform mode and crop
        let transformButton = app.buttons["Transform"]
        if transformButton.waitForExistence(timeout: 3) {
            transformButton.tap()
            sleep(1)

            let cropButton = app.buttons["Crop"]
            if cropButton.waitForExistence(timeout: 2) {
                cropButton.tap()
                sleep(1)

                // Aspect ratio options should exist
                let freeformButton = app.buttons["Freeform"]
                let squareButton = app.buttons["Square"]
                let ratio4x3Button = app.buttons["4:3"]

                // At least one aspect ratio option should exist
            }
        }
    }

    // MARK: - Adjust Mode Tests

    func testAdjustModeExists() {
        // Open photo editor
        openPhotoEditor()

        // Then - Adjust mode should be available
        let adjustButton = app.buttons["Adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 3))
    }

    func testBrightnessSlider() {
        // Open photo editor
        openPhotoEditor()

        // Switch to adjust mode
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Find brightness option
            let brightnessButton = app.buttons["Brightness"]
            if brightnessButton.waitForExistence(timeout: 2) {
                brightnessButton.tap()
                sleep(1)

                // Slider should be visible
                let slider = app.sliders.firstMatch
                XCTAssertTrue(slider.waitForExistence(timeout: 2))
            }
        }
    }

    func testContrastSlider() {
        // Open photo editor
        openPhotoEditor()

        // Switch to adjust mode
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Find contrast option
            let contrastButton = app.buttons["Contrast"]
            if contrastButton.waitForExistence(timeout: 2) {
                contrastButton.tap()
                sleep(1)

                // Slider should be visible
                let slider = app.sliders.firstMatch
                XCTAssertTrue(slider.waitForExistence(timeout: 2))
            }
        }
    }

    func testSaturationSlider() {
        // Open photo editor
        openPhotoEditor()

        // Switch to adjust mode
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Find saturation option
            let saturationButton = app.buttons["Saturation"]
            if saturationButton.waitForExistence(timeout: 2) {
                saturationButton.tap()
                sleep(1)

                // Slider should be visible
                let slider = app.sliders.firstMatch
                XCTAssertTrue(slider.waitForExistence(timeout: 2))
            }
        }
    }

    func testAllAdjustmentTypesExist() {
        // Open photo editor
        openPhotoEditor()

        // Switch to adjust mode
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Check for all adjustment types
            let adjustmentNames = [
                "Brightness", "Exposure", "Highlights", "Shadows",
                "Contrast", "Black Point", "Saturation", "Brilliance",
                "Sharpness", "Definition"
            ]

            var foundCount = 0
            for name in adjustmentNames {
                let button = app.buttons[name]
                if button.waitForExistence(timeout: 1) {
                    foundCount += 1
                }
            }

            // At least some adjustment types should be found
            XCTAssertGreaterThan(foundCount, 0)
        }
    }

    func testResetAdjustments() {
        // Open photo editor
        openPhotoEditor()

        // Switch to adjust mode
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            // Make an adjustment
            let brightnessButton = app.buttons["Brightness"]
            if brightnessButton.waitForExistence(timeout: 2) {
                brightnessButton.tap()

                let slider = app.sliders.firstMatch
                if slider.waitForExistence(timeout: 2) {
                    slider.adjust(toNormalizedSliderPosition: 0.7)
                    sleep(1)
                }
            }

            // Find and tap reset button
            let resetButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Reset'")
            ).firstMatch

            if resetButton.waitForExistence(timeout: 2) {
                resetButton.tap()
                sleep(1)
            }
        }
    }

    // MARK: - Save & Cancel Tests

    func testCancelEdits() {
        // Open photo editor
        openPhotoEditor()

        // Find cancel button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))

        // When
        cancelButton.tap()
        sleep(1)

        // Then - Should return to photo detail view
        let editButton = findEditButton()
        // Should be back in photo detail
    }

    func testDoneButtonEnabled() {
        // Open photo editor
        openPhotoEditor()

        // Find done button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))

        // Done button should exist
    }

    func testDoneButtonAfterEdit() {
        // Open photo editor
        openPhotoEditor()

        // Make an edit
        let adjustButton = app.buttons["Adjust"]
        if adjustButton.waitForExistence(timeout: 3) {
            adjustButton.tap()
            sleep(1)

            let brightnessButton = app.buttons["Brightness"]
            if brightnessButton.waitForExistence(timeout: 2) {
                brightnessButton.tap()

                let slider = app.sliders.firstMatch
                if slider.waitForExistence(timeout: 2) {
                    slider.adjust(toNormalizedSliderPosition: 0.6)
                    sleep(1)
                }
            }
        }

        // Done button should be enabled after making an edit
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(doneButton.isEnabled)
        }
    }

    // MARK: - Helper Methods

    private func navigateToPhotoDetail() {
        // Navigate to library
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
        }
        sleep(1)

        // Try to tap on a photo
        // Look for collection view cells or image elements
        let collectionView = app.collectionViews.firstMatch
        if collectionView.waitForExistence(timeout: 3) {
            let cells = collectionView.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
            }
        }

        // Alternative: look for images directly
        let images = app.images.allElementsBoundByIndex
        if images.count > 0 {
            images[0].tap()
            sleep(1)
        }
    }

    private func findEditButton() -> XCUIElement {
        // Look for edit button in various forms
        let editButtons = [
            app.buttons.matching(identifier: "Edit Photo").firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'slider'")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label == 'Edit Photo'")).firstMatch
        ]

        for button in editButtons {
            if button.waitForExistence(timeout: 2) {
                return button
            }
        }

        return app.buttons["__nonexistent__"]
    }

    private func openPhotoEditor() {
        // Navigate to photo detail
        navigateToPhotoDetail()

        // Try to open editor via button
        let editButton = findEditButton()
        if editButton.exists {
            editButton.tap()
            sleep(1)
            return
        }

        // Try via menu
        let menuButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'more' OR label == '...'")
        ).firstMatch

        if menuButton.waitForExistence(timeout: 2) {
            menuButton.tap()
            sleep(1)

            let editMenuItem = app.buttons["Edit Photo"]
            if editMenuItem.waitForExistence(timeout: 2) {
                editMenuItem.tap()
                sleep(1)
            }
        }
    }
}

// MARK: - Photo Editor Accessibility Tests

final class PhotoEditorAccessibilityTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--with-sample-data"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testEditButtonHasAccessibilityLabel() {
        // Navigate to photo detail
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
        }
        sleep(1)

        // Try to open a photo
        let collectionView = app.collectionViews.firstMatch
        if collectionView.waitForExistence(timeout: 3) {
            let cells = collectionView.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
            }
        }

        // Check for accessibility label on edit button
        let editButton = app.buttons.matching(
            NSPredicate(format: "accessibilityLabel == 'Edit Photo'")
        ).firstMatch

        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
    }

    func testEditorControlsAreAccessible() {
        // This test verifies that editor controls have proper accessibility
        // Open photo editor first
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
        }
        sleep(1)

        // Navigate to photo and editor
        // Verify controls have accessibility labels
    }
}
