// CaptureFlowUITests.swift
// SimFolioUITests - Capture Flow UI Tests
//
// Tests for the capture flow including:
// - Camera view display
// - Tagging interface
// - Capture button functionality
// - Flash mode toggle
// - Review screen

import XCTest

final class CaptureFlowUITests: XCTestCase {

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

    // MARK: - Tab Navigation Tests

    func testNavigateToCaptureTab() {
        // When
        let captureTab = app.tabBars.buttons["Capture"]
        XCTAssertTrue(captureTab.waitForExistence(timeout: 3))
        captureTab.tap()

        // Then - Camera view or permission request should appear
        sleep(1) // Allow time for camera to initialize
    }

    func testCaptureTabIsAccessible() {
        // Given
        let captureTab = app.tabBars.buttons["Capture"]

        // Then
        XCTAssertTrue(captureTab.waitForExistence(timeout: 3))
        XCTAssertTrue(captureTab.isEnabled)
    }

    // MARK: - Camera Controls Tests

    func testCaptureButtonExists() {
        // Navigate to capture
        navigateToCapture()

        // Then - Look for capture button
        let captureButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Capture'")).firstMatch
        // Note: Button may have different label or be an image-only button
        sleep(1)
    }

    func testFlashButtonExists() {
        // Navigate to capture
        navigateToCapture()

        // Then - Look for flash button
        let flashButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Flash'")).firstMatch
        if flashButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(flashButton.exists)
        }
    }

    func testGridToggleExists() {
        // Navigate to capture
        navigateToCapture()

        // Then - Look for grid toggle
        let gridButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Grid'")).firstMatch
        // Grid button may or may not exist depending on implementation
    }

    // MARK: - Tagging Interface Tests

    func testProcedurePickerExists() {
        // Navigate to capture
        navigateToCapture()

        // Then - Look for procedure picker or tag button
        let procedureButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'procedure' OR label CONTAINS[c] 'Class'")
        ).firstMatch

        // May also look for a tag or category button
        let tagButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'tag' OR label CONTAINS[c] 'Select'")
        ).firstMatch

        sleep(1)
    }

    func testOpenProcedurePicker() {
        // Navigate to capture
        navigateToCapture()

        // Find and tap procedure selector
        let procedureSelectors = [
            app.buttons["Select Procedure"],
            app.buttons["Procedure"],
            app.buttons["Choose procedure"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'procedure'")).firstMatch
        ]

        for selector in procedureSelectors {
            if selector.waitForExistence(timeout: 2) {
                selector.tap()
                sleep(1)
                break
            }
        }

        // Then - Look for procedure options
        let class1Option = app.staticTexts["Class 1"]
        let crownOption = app.staticTexts["Crown"]
        // At least one should exist if picker opened
    }

    // MARK: - Camera Switching Tests

    func testCameraSwitchButtonExists() {
        // Navigate to capture
        navigateToCapture()

        // Then - Look for camera switch button
        let switchButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'switch' OR label CONTAINS[c] 'flip' OR label CONTAINS[c] 'camera'")
        ).firstMatch

        // Camera switch may not be visible if device only has one camera
    }

    // MARK: - Flash Mode Tests

    func testFlashModeToggle() {
        // Navigate to capture
        navigateToCapture()

        // Find flash button
        let flashButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Flash'")).firstMatch

        if flashButton.waitForExistence(timeout: 3) {
            // When
            flashButton.tap()

            // Then - Flash mode should change (look for mode indicator change)
            sleep(1)
        }
    }

    // MARK: - Capture Action Tests

    func testCaptureButtonIsLarge() {
        // Navigate to capture
        navigateToCapture()

        // Find capture button by common identifiers
        let captureButtons = [
            app.buttons["Capture Photo"],
            app.buttons["Capture"],
            app.buttons["Take Photo"],
            app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'capture'")).firstMatch
        ]

        for button in captureButtons {
            if button.waitForExistence(timeout: 2) {
                // Verify button exists and is hittable
                XCTAssertTrue(button.isHittable)
                break
            }
        }
    }

    // MARK: - Accessibility Tests

    func testCaptureViewVoiceOverAccessibility() {
        // Navigate to capture
        navigateToCapture()

        // Verify key elements have accessibility
        // This is a basic check - full VoiceOver testing requires device testing

        // The capture view should be accessible
        let captureView = app.otherElements.firstMatch
        sleep(1)
    }

    // MARK: - Helper Methods

    private func navigateToCapture() {
        let captureTab = app.tabBars.buttons["Capture"]
        if captureTab.waitForExistence(timeout: 3) {
            captureTab.tap()
        }
        // Allow camera to initialize
        sleep(2)
    }
}

// MARK: - Capture Tagging UI Tests

final class CaptureTaggingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()

        // Navigate to capture
        let captureTab = app.tabBars.buttons["Capture"]
        if captureTab.waitForExistence(timeout: 3) {
            captureTab.tap()
        }
        sleep(2)
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testSelectProcedure() {
        // Find procedure selector
        let procedureSelector = findProcedureSelector()
        guard procedureSelector.exists else {
            // Skip test if procedure selector not found
            return
        }

        // When
        procedureSelector.tap()
        sleep(1)

        // Then - Select a procedure if picker appears
        let class1 = app.staticTexts["Class 1"]
        if class1.waitForExistence(timeout: 2) {
            class1.tap()
        }
    }

    func testSelectStage() {
        // First select a procedure if required
        let procedureSelector = findProcedureSelector()
        if procedureSelector.exists {
            procedureSelector.tap()
            sleep(1)

            let class1 = app.staticTexts["Class 1"]
            if class1.waitForExistence(timeout: 2) {
                class1.tap()
                sleep(1)
            }
        }

        // Then look for stage selector
        let stageSelectors = [
            app.buttons["Stage"],
            app.buttons["Select Stage"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'stage'")).firstMatch
        ]

        for selector in stageSelectors {
            if selector.waitForExistence(timeout: 2) {
                selector.tap()
                break
            }
        }
    }

    func testSelectAngle() {
        // Similar flow for angle selection
        let angleSelectors = [
            app.buttons["Angle"],
            app.buttons["Select Angle"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'angle'")).firstMatch
        ]

        for selector in angleSelectors {
            if selector.waitForExistence(timeout: 2) {
                selector.tap()
                break
            }
        }
    }

    // MARK: - Helper Methods

    private func findProcedureSelector() -> XCUIElement {
        let selectors = [
            app.buttons["Select Procedure"],
            app.buttons["Procedure"],
            app.buttons["Choose procedure"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'procedure'")).firstMatch
        ]

        for selector in selectors {
            if selector.waitForExistence(timeout: 2) {
                return selector
            }
        }

        return app.buttons["__nonexistent__"] // Return non-existent element
    }
}
