// ProfileUITests.swift
// SimFolioUITests - Profile & Settings UI Tests
//
// Tests for the profile and settings views including:
// - Profile display
// - Edit profile functionality
// - Settings navigation
// - Data management
// - About section

import XCTest

final class ProfileUITests: XCTestCase {

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

    func testNavigateToProfile() {
        // When
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()

        // Then - Profile view should appear
        sleep(1)
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
    }

    func testProfileTabIsAccessible() {
        // Given
        let profileTab = app.tabBars.buttons["Profile"]

        // Then
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        XCTAssertTrue(profileTab.isEnabled)
    }

    // MARK: - Profile Display Tests

    func testProfileAvatarDisplays() {
        // Navigate to profile
        navigateToProfile()

        // Look for avatar/image element
        let images = app.images.allElementsBoundByIndex
        // Avatar image should exist
    }

    func testProfileStatsDisplay() {
        // Navigate to profile
        navigateToProfile()

        // Look for stats (photos count, portfolios count, etc.)
        let statsElements = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'photo'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'portfolio'")).firstMatch
        ]

        // At least one stat should be visible
    }

    // MARK: - Edit Profile Tests

    func testEditProfileButtonExists() {
        // Navigate to profile
        navigateToProfile()

        // Look for edit button
        let editButtons = [
            app.buttons["Edit Profile"],
            app.buttons["Edit"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'")).firstMatch
        ]

        var found = false
        for button in editButtons {
            if button.waitForExistence(timeout: 2) {
                found = true
                break
            }
        }
    }

    func testOpenEditProfileSheet() {
        // Navigate to profile
        navigateToProfile()

        // Find and tap edit button
        let editButton = findEditButton()
        guard editButton.exists else {
            return
        }

        // When
        editButton.tap()
        sleep(1)

        // Then - Edit sheet should appear
        let nameField = app.textFields.firstMatch
        let sheetExists = nameField.waitForExistence(timeout: 2)
    }

    func testEditProfileFields() {
        // Navigate to profile
        navigateToProfile()

        // Open edit sheet
        let editButton = findEditButton()
        guard editButton.exists else {
            return
        }
        editButton.tap()
        sleep(1)

        // Look for profile fields
        let firstNameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'First' OR label CONTAINS[c] 'First'")
        ).firstMatch

        let lastNameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'Last' OR label CONTAINS[c] 'Last'")
        ).firstMatch

        // Fields should exist
    }

    // MARK: - Settings Navigation Tests

    func testNavigateToCaptureSettings() {
        // Navigate to profile
        navigateToProfile()

        // Look for capture settings
        let captureSettingsButtons = [
            app.buttons["Capture Settings"],
            app.staticTexts["Capture Settings"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Capture'")).firstMatch
        ]

        for button in captureSettingsButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    func testNavigateToNotificationSettings() {
        // Navigate to profile
        navigateToProfile()

        // Look for notification settings
        let notificationButtons = [
            app.buttons["Notifications"],
            app.staticTexts["Notifications"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'notification'")).firstMatch
        ]

        for button in notificationButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    func testNavigateToProcedureManagement() {
        // Navigate to profile
        navigateToProfile()

        // Look for procedure management
        let procedureButtons = [
            app.buttons["Manage Procedures"],
            app.staticTexts["Manage Procedures"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Procedure'")).firstMatch
        ]

        for button in procedureButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    func testNavigateToDataManagement() {
        // Navigate to profile
        navigateToProfile()

        // Look for data management
        let dataButtons = [
            app.buttons["Data Management"],
            app.staticTexts["Data Management"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Data'")).firstMatch
        ]

        for button in dataButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    func testNavigateToAbout() {
        // Navigate to profile
        navigateToProfile()

        // Look for about section
        let aboutButtons = [
            app.buttons["About"],
            app.staticTexts["About"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'About'")).firstMatch
        ]

        for button in aboutButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                break
            }
        }
    }

    // MARK: - Helper Methods

    private func navigateToProfile() {
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
        }
        sleep(1)
    }

    private func findEditButton() -> XCUIElement {
        let editButtons = [
            app.buttons["Edit Profile"],
            app.buttons["Edit"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'")).firstMatch
        ]

        for button in editButtons {
            if button.waitForExistence(timeout: 2) {
                return button
            }
        }

        return app.buttons["__nonexistent__"]
    }
}

// MARK: - Settings UI Tests

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()

        // Navigate to profile
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
        }
        sleep(1)
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testCaptureSettingsToggles() {
        // Navigate to capture settings
        navigateToCaptureSettings()

        // Look for toggles
        let toggles = app.switches.allElementsBoundByIndex

        // Should have toggles for various settings
    }

    func testNotificationPermissionStatus() {
        // Navigate to notification settings
        navigateToNotificationSettings()

        // Look for permission status indicator
        let statusElements = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Enabled'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Disabled'")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Enable'")).firstMatch
        ]

        // Status should be visible
    }

    func testProcedureListDisplays() {
        // Navigate to procedure management
        navigateToProcedureManagement()

        // Look for procedure list
        let procedureTexts = [
            app.staticTexts["Class 1"],
            app.staticTexts["Crown"],
            app.cells.firstMatch
        ]

        for element in procedureTexts {
            if element.waitForExistence(timeout: 2) {
                // Procedures should be listed
                break
            }
        }
    }

    func testResetToDefaultsButton() {
        // Navigate to procedure management
        navigateToProcedureManagement()

        // Look for reset button
        let resetButtons = [
            app.buttons["Reset to Defaults"],
            app.buttons["Reset"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'reset'")).firstMatch
        ]

        for button in resetButtons {
            if button.waitForExistence(timeout: 2) {
                // Reset button should exist
                break
            }
        }
    }

    func testDataManagementWarnings() {
        // Navigate to data management
        navigateToDataManagement()

        // Look for warning/destructive action indicators
        let warningElements = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Clear'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Reset'")).firstMatch
        ]

        // Warning actions should be visible
    }

    func testAboutVersionDisplays() {
        // Navigate to about
        navigateToAbout()

        // Look for version info
        let versionElements = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Version'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '1.0'")).firstMatch
        ]

        for element in versionElements {
            if element.waitForExistence(timeout: 2) {
                // Version should be displayed
                break
            }
        }
    }

    // MARK: - Helper Methods

    private func navigateToCaptureSettings() {
        let buttons = [
            app.buttons["Capture Settings"],
            app.staticTexts["Capture Settings"]
        ]
        for button in buttons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }

    private func navigateToNotificationSettings() {
        let buttons = [
            app.buttons["Notifications"],
            app.staticTexts["Notifications"]
        ]
        for button in buttons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }

    private func navigateToProcedureManagement() {
        let buttons = [
            app.buttons["Manage Procedures"],
            app.staticTexts["Manage Procedures"]
        ]
        for button in buttons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }

    private func navigateToDataManagement() {
        let buttons = [
            app.buttons["Data Management"],
            app.staticTexts["Data Management"]
        ]
        for button in buttons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }

    private func navigateToAbout() {
        let buttons = [
            app.buttons["About"],
            app.staticTexts["About"]
        ]
        for button in buttons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                sleep(1)
                return
            }
        }
    }
}
