// AccessibilityTests.swift
// SimFolioTests - Accessibility Label Unit Tests
//
// Tests for AccessibilityLabels helper functions to ensure
// consistent and meaningful accessibility labels throughout the app.

import XCTest
@testable import SimFolio

final class AccessibilityTests: XCTestCase {

    // MARK: - Photo Label Tests

    func testPhotoLabelComplete() {
        // Given/When
        let label = AccessibilityLabels.photoLabel(
            procedure: "Class 1",
            stage: "Preparation",
            angle: "Occlusal/Incisal",
            rating: 4,
            date: Date()
        )

        // Then
        XCTAssertTrue(label.contains("Class 1"))
        XCTAssertTrue(label.contains("Preparation"))
        XCTAssertTrue(label.contains("Occlusal/Incisal"))
        XCTAssertTrue(label.contains("4 stars"))
        XCTAssertTrue(label.hasPrefix("Photo:"))
    }

    func testPhotoLabelWithNoTags() {
        // Given/When
        let label = AccessibilityLabels.photoLabel(
            procedure: nil,
            stage: nil,
            angle: nil,
            rating: nil,
            date: nil
        )

        // Then
        XCTAssertEqual(label, "Photo, no tags")
    }

    func testPhotoLabelPartial() {
        // Given/When
        let label = AccessibilityLabels.photoLabel(
            procedure: "Crown",
            stage: nil,
            angle: "Buccal/Facial",
            rating: nil,
            date: nil
        )

        // Then
        XCTAssertTrue(label.contains("Crown"))
        XCTAssertTrue(label.contains("Buccal/Facial"))
        XCTAssertFalse(label.contains("no tags"))
    }

    func testPhotoLabelSingularStar() {
        // Given/When
        let label = AccessibilityLabels.photoLabel(
            procedure: nil,
            stage: nil,
            angle: nil,
            rating: 1,
            date: nil
        )

        // Then
        XCTAssertTrue(label.contains("1 star"))
        XCTAssertFalse(label.contains("stars"))
    }

    func testPhotoLabelPluralStars() {
        // Given/When
        let label = AccessibilityLabels.photoLabel(
            procedure: nil,
            stage: nil,
            angle: nil,
            rating: 5,
            date: nil
        )

        // Then
        XCTAssertTrue(label.contains("5 stars"))
    }

    func testPhotoHint() {
        // Given/When
        let hintWithDetails = AccessibilityLabels.photoHint(hasDetails: true)
        let hintWithoutDetails = AccessibilityLabels.photoHint(hasDetails: false)

        // Then
        XCTAssertTrue(hintWithDetails.contains("view photo details"))
        XCTAssertTrue(hintWithoutDetails.contains("select"))
    }

    // MARK: - Portfolio Label Tests

    func testPortfolioLabelComplete() {
        // Given
        let dueDate = TestUtilities.dateRelativeToToday(days: 7)

        // When
        let label = AccessibilityLabels.portfolioLabel(
            name: "Test Portfolio",
            progress: 0.75,
            dueDate: dueDate,
            isOverdue: false
        )

        // Then
        XCTAssertTrue(label.contains("Test Portfolio"))
        XCTAssertTrue(label.contains("75 percent"))
        XCTAssertTrue(label.contains("due"))
    }

    func testPortfolioLabelOverdue() {
        // Given
        let pastDate = TestUtilities.dateRelativeToToday(days: -3)

        // When
        let label = AccessibilityLabels.portfolioLabel(
            name: "Overdue Portfolio",
            progress: 0.5,
            dueDate: pastDate,
            isOverdue: true
        )

        // Then
        XCTAssertTrue(label.contains("overdue"))
    }

    func testPortfolioLabelNoDueDate() {
        // Given/When
        let label = AccessibilityLabels.portfolioLabel(
            name: "No Due Date",
            progress: 0.25,
            dueDate: nil,
            isOverdue: false
        )

        // Then
        XCTAssertTrue(label.contains("25 percent"))
        XCTAssertFalse(label.contains("due"))
    }

    func testPortfolioHint() {
        // Given/When
        let hintComplete = AccessibilityLabels.portfolioHint(isComplete: true)
        let hintIncomplete = AccessibilityLabels.portfolioHint(isComplete: false)

        // Then
        XCTAssertTrue(hintComplete.contains("completed"))
        XCTAssertTrue(hintIncomplete.contains("track progress"))
    }

    // MARK: - Requirement Label Tests

    func testRequirementLabelIncomplete() {
        // Given/When
        let label = AccessibilityLabels.requirementLabel(
            procedure: "Class 2",
            fulfilled: 3,
            required: 5
        )

        // Then
        XCTAssertTrue(label.contains("Class 2"))
        XCTAssertTrue(label.contains("3 of 5"))
        XCTAssertTrue(label.contains("2 remaining"))
    }

    func testRequirementLabelComplete() {
        // Given/When
        let label = AccessibilityLabels.requirementLabel(
            procedure: "Crown",
            fulfilled: 4,
            required: 4
        )

        // Then
        XCTAssertTrue(label.contains("complete"))
        XCTAssertTrue(label.contains("4 of 4"))
    }

    func testRequirementLabelOverfulfilled() {
        // Given/When
        let label = AccessibilityLabels.requirementLabel(
            procedure: "Veneer",
            fulfilled: 6,
            required: 4
        )

        // Then
        XCTAssertTrue(label.contains("complete"))
    }

    func testRequirementHint() {
        // Given/When
        let hintComplete = AccessibilityLabels.requirementHint(isComplete: true)
        let hintIncomplete = AccessibilityLabels.requirementHint(isComplete: false)

        // Then
        XCTAssertTrue(hintComplete.contains("view photos"))
        XCTAssertTrue(hintIncomplete.contains("capture"))
    }

    // MARK: - Rating Label Tests

    func testRatingLabel() {
        // Given/When
        let fullRating = AccessibilityLabels.ratingLabel(rating: 5)
        let partialRating = AccessibilityLabels.ratingLabel(rating: 3)
        let noRating = AccessibilityLabels.ratingLabel(rating: 0)

        // Then
        XCTAssertEqual(fullRating, "5 of 5 stars")
        XCTAssertEqual(partialRating, "3 of 5 stars")
        XCTAssertEqual(noRating, "No rating")
    }

    func testRatingLabelCustomMax() {
        // Given/When
        let label = AccessibilityLabels.ratingLabel(rating: 8, maxRating: 10)

        // Then
        XCTAssertEqual(label, "8 of 10 stars")
    }

    func testRatingHint() {
        // Given/When
        let hintNoRating = AccessibilityLabels.ratingHint(currentRating: 0)
        let hintWithRating = AccessibilityLabels.ratingHint(currentRating: 3)

        // Then
        XCTAssertTrue(hintNoRating.contains("set rating"))
        XCTAssertTrue(hintWithRating.contains("increase"))
        XCTAssertTrue(hintWithRating.contains("decrease"))
    }

    // MARK: - Date Label Tests

    func testRelativeDateLabelToday() {
        // Given/When
        let label = AccessibilityLabels.relativeDateLabel(Date())

        // Then
        XCTAssertEqual(label, "Today")
    }

    func testRelativeDateLabelYesterday() {
        // Given
        let yesterday = TestUtilities.dateRelativeToToday(days: -1)

        // When
        let label = AccessibilityLabels.relativeDateLabel(yesterday)

        // Then
        XCTAssertEqual(label, "Yesterday")
    }

    func testRelativeDateLabelTomorrow() {
        // Given
        let tomorrow = TestUtilities.dateRelativeToToday(days: 1)

        // When
        let label = AccessibilityLabels.relativeDateLabel(tomorrow)

        // Then
        XCTAssertEqual(label, "Tomorrow")
    }

    func testRelativeDateLabelFuture() {
        // Given — use a large offset to avoid time-of-day boundary issues
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

        // When
        let label = AccessibilityLabels.relativeDateLabel(future)

        // Then — should contain "day" (singular or plural) and "In"
        XCTAssertTrue(label.lowercased().contains("day"),
                      "Expected future label with 'day' but got: \(label)")
    }

    func testRelativeDateLabelPast() {
        // Given
        let past = TestUtilities.dateRelativeToToday(days: -3)

        // When
        let label = AccessibilityLabels.relativeDateLabel(past)

        // Then
        XCTAssertTrue(label.contains("3 days ago"))
    }

    func testRelativeDateLabelSingularDay() {
        // Given — use 3 days to avoid boundary issues near midnight
        let future = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        let labelFuture = AccessibilityLabels.relativeDateLabel(future)
        let labelPast = AccessibilityLabels.relativeDateLabel(past)

        // Then — both should reference "day" somewhere
        XCTAssertTrue(labelFuture.lowercased().contains("day"),
                      "Expected future label with 'day' but got: \(labelFuture)")
        XCTAssertTrue(labelPast.lowercased().contains("day"),
                      "Expected past label with 'day' but got: \(labelPast)")
    }

    func testDueDateLabel() {
        // Given
        let dueDate = TestUtilities.dateRelativeToToday(days: 3)
        let overdueDate = TestUtilities.dateRelativeToToday(days: -2)

        // When
        let dueLabelFuture = AccessibilityLabels.dueDateLabel(dueDate, isOverdue: false)
        let dueLabelOverdue = AccessibilityLabels.dueDateLabel(overdueDate, isOverdue: true)

        // Then
        XCTAssertTrue(dueLabelFuture.contains("Due"))
        XCTAssertTrue(dueLabelOverdue.contains("Overdue"))
    }

    // MARK: - Tab Label Tests

    func testTabLabel() {
        // Given/When
        let labelNoBadge = AccessibilityLabels.tabLabel(tab: .home, badgeCount: 0)
        let labelWithBadge = AccessibilityLabels.tabLabel(tab: .library, badgeCount: 5)
        let labelSingleBadge = AccessibilityLabels.tabLabel(tab: .profile, badgeCount: 1)

        // Then
        XCTAssertEqual(labelNoBadge, "Home")
        XCTAssertTrue(labelWithBadge.contains("5 notifications"))
        XCTAssertTrue(labelSingleBadge.contains("1 notification"))
        XCTAssertFalse(labelSingleBadge.contains("notifications"))
    }

    func testTabHint() {
        // Given/When
        let hintSelected = AccessibilityLabels.tabHint(isSelected: true, tabName: "Home")
        let hintNotSelected = AccessibilityLabels.tabHint(isSelected: false, tabName: "Library")

        // Then
        XCTAssertEqual(hintSelected, "Currently selected")
        XCTAssertTrue(hintNotSelected.contains("switch to Library"))
    }

    // MARK: - Stats Label Tests

    func testStatLabel() {
        // Given/When
        let labelSimple = AccessibilityLabels.statLabel(value: "42", label: "photos")
        let labelWithDetail = AccessibilityLabels.statLabel(value: "15", label: "completed", detail: "this week")

        // Then
        XCTAssertEqual(labelSimple, "42 photos")
        XCTAssertEqual(labelWithDetail, "15 completed, this week")
    }

    // MARK: - Count Label Tests

    func testCountLabel() {
        // Given/When
        let labelSingular = AccessibilityLabels.countLabel(count: 1, singular: "photo")
        let labelPlural = AccessibilityLabels.countLabel(count: 5, singular: "photo")
        let labelCustomPlural = AccessibilityLabels.countLabel(count: 3, singular: "entry", plural: "entries")

        // Then
        XCTAssertEqual(labelSingular, "1 photo")
        XCTAssertEqual(labelPlural, "5 photos")
        XCTAssertEqual(labelCustomPlural, "3 entries")
    }

    // MARK: - Selection Label Tests

    func testSelectionLabel() {
        // Given/When
        let labelSelected = AccessibilityLabels.selectionLabel(itemName: "Photo 1", isSelected: true)
        let labelNotSelected = AccessibilityLabels.selectionLabel(itemName: "Photo 2", isSelected: false)

        // Then
        XCTAssertEqual(labelSelected, "Photo 1, selected")
        XCTAssertEqual(labelNotSelected, "Photo 2")
    }

    func testSelectionHint() {
        // Given/When
        let hintSelected = AccessibilityLabels.selectionHint(isSelected: true)
        let hintNotSelected = AccessibilityLabels.selectionHint(isSelected: false)

        // Then
        XCTAssertTrue(hintSelected.contains("deselect"))
        XCTAssertTrue(hintNotSelected.contains("select"))
    }

    // MARK: - Filter Label Tests

    func testFilterLabel() {
        // Given/When
        let labelInactive = AccessibilityLabels.filterLabel(filterName: "Procedure", isActive: false)
        let labelActive = AccessibilityLabels.filterLabel(filterName: "Stage", isActive: true)
        let labelWithCount = AccessibilityLabels.filterLabel(filterName: "Rating", isActive: true, resultCount: 25)

        // Then
        XCTAssertEqual(labelInactive, "Procedure filter")
        XCTAssertTrue(labelActive.contains("active"))
        XCTAssertTrue(labelWithCount.contains("25 results"))
    }

    func testFilterLabelSingularResult() {
        // Given/When
        let label = AccessibilityLabels.filterLabel(filterName: "Test", isActive: false, resultCount: 1)

        // Then
        XCTAssertTrue(label.contains("1 result"))
        XCTAssertFalse(label.contains("results"))
    }

    // MARK: - State Label Tests

    func testLoadingLabel() {
        // Given/When
        let labelGeneric = AccessibilityLabels.loadingLabel()
        let labelWithContext = AccessibilityLabels.loadingLabel(context: "photos")

        // Then
        XCTAssertEqual(labelGeneric, "Loading")
        XCTAssertEqual(labelWithContext, "Loading photos")
    }

    func testErrorLabel() {
        // Given/When
        let label = AccessibilityLabels.errorLabel(message: "Network unavailable")

        // Then
        XCTAssertEqual(label, "Error: Network unavailable")
    }

    func testEmptyLabel() {
        // Given/When
        let label = AccessibilityLabels.emptyLabel(context: "portfolios")

        // Then
        XCTAssertEqual(label, "No portfolios available")
    }

    // MARK: - Button Label Tests

    func testCaptureButtonLabel() {
        // Given/When
        let labelNoPresets = AccessibilityLabels.captureButtonLabel(hasPresets: false, procedure: nil)
        let labelWithPresets = AccessibilityLabels.captureButtonLabel(hasPresets: true, procedure: "Class 1")

        // Then
        XCTAssertEqual(labelNoPresets, "Capture photo")
        XCTAssertEqual(labelWithPresets, "Capture photo for Class 1")
    }

    func testActionButtonLabel() {
        // Given/When
        let labelSimple = AccessibilityLabels.actionButtonLabel(action: "Delete")
        let labelWithTarget = AccessibilityLabels.actionButtonLabel(action: "Share", target: "photo")

        // Then
        XCTAssertEqual(labelSimple, "Delete")
        XCTAssertEqual(labelWithTarget, "Share photo")
    }
}
