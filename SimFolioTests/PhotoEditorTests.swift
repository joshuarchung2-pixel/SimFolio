// PhotoEditorTests.swift
// SimFolioTests - Photo Editor Unit Tests
//
// Tests for photo editing functionality including:
// - ImageAdjustments model
// - ImageTransform model
// - EditState model
// - EditHistory management
// - ImageProcessingService

import XCTest
@testable import SimFolio

// MARK: - ImageAdjustments Tests

final class ImageAdjustmentsTests: XCTestCase {

    func testDefaultValues() {
        // Given
        let adjustments = ImageAdjustments()

        // Then
        XCTAssertEqual(adjustments.brightness, 0)
        XCTAssertEqual(adjustments.exposure, 0)
        XCTAssertEqual(adjustments.highlights, 0)
        XCTAssertEqual(adjustments.shadows, 0)
        XCTAssertEqual(adjustments.contrast, 1.0)
        XCTAssertEqual(adjustments.blackPoint, 0)
        XCTAssertEqual(adjustments.saturation, 1.0)
        XCTAssertEqual(adjustments.brilliance, 0)
        XCTAssertEqual(adjustments.sharpness, 0)
        XCTAssertEqual(adjustments.definition, 0)
    }

    func testHasChangesWhenDefault() {
        // Given
        let adjustments = ImageAdjustments()

        // Then
        XCTAssertFalse(adjustments.hasChanges)
    }

    func testHasChangesWhenModified() {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.brightness = 0.5

        // Then
        XCTAssertTrue(adjustments.hasChanges)
    }

    func testHasChangesForContrast() {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.contrast = 1.2

        // Then
        XCTAssertTrue(adjustments.hasChanges)
    }

    func testHasChangesForSaturation() {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.saturation = 1.5

        // Then
        XCTAssertTrue(adjustments.hasChanges)
    }

    func testReset() {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.brightness = 0.5
        adjustments.contrast = 1.3
        adjustments.saturation = 0.8
        adjustments.sharpness = 1.0

        // When
        adjustments.reset()

        // Then
        XCTAssertFalse(adjustments.hasChanges)
        XCTAssertEqual(adjustments.brightness, 0)
        XCTAssertEqual(adjustments.contrast, 1.0)
        XCTAssertEqual(adjustments.saturation, 1.0)
        XCTAssertEqual(adjustments.sharpness, 0)
    }

    func testEncoding() throws {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.brightness = 0.3
        adjustments.exposure = -0.5
        adjustments.contrast = 1.2

        // When
        let encoded = try JSONEncoder().encode(adjustments)
        let decoded = try JSONDecoder().decode(ImageAdjustments.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.brightness, adjustments.brightness)
        XCTAssertEqual(decoded.exposure, adjustments.exposure)
        XCTAssertEqual(decoded.contrast, adjustments.contrast)
    }

    func testEquality() {
        // Given
        var adjustments1 = ImageAdjustments()
        adjustments1.brightness = 0.5

        var adjustments2 = ImageAdjustments()
        adjustments2.brightness = 0.5

        var adjustments3 = ImageAdjustments()
        adjustments3.brightness = 0.6

        // Then
        XCTAssertEqual(adjustments1, adjustments2)
        XCTAssertNotEqual(adjustments1, adjustments3)
    }

    func testDefaultStatic() {
        // Given
        let adjustments = ImageAdjustments.default

        // Then
        XCTAssertFalse(adjustments.hasChanges)
    }
}

// MARK: - ImageTransform Tests

final class ImageTransformTests: XCTestCase {

    func testDefaultValues() {
        // Given
        let transform = ImageTransform()

        // Then
        XCTAssertNil(transform.cropRect)
        XCTAssertEqual(transform.fineRotation, 0)
        XCTAssertEqual(transform.rotation90Count, 0)
    }

    func testHasChangesWhenDefault() {
        // Given
        let transform = ImageTransform()

        // Then
        XCTAssertFalse(transform.hasChanges)
    }

    func testHasChangesWithCrop() {
        // Given
        var transform = ImageTransform()
        transform.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

        // Then
        XCTAssertTrue(transform.hasChanges)
    }

    func testHasChangesWithFineRotation() {
        // Given
        var transform = ImageTransform()
        transform.fineRotation = 5.0

        // Then
        XCTAssertTrue(transform.hasChanges)
    }

    func testHasChangesWith90DegreeRotation() {
        // Given
        var transform = ImageTransform()
        transform.rotation90Count = 1

        // Then
        XCTAssertTrue(transform.hasChanges)
    }

    func testRotate90Clockwise() {
        // Given
        var transform = ImageTransform()

        // When
        transform.rotate90Clockwise()

        // Then
        XCTAssertEqual(transform.rotation90Count, 1)

        // When - rotate again
        transform.rotate90Clockwise()
        transform.rotate90Clockwise()
        transform.rotate90Clockwise()

        // Then - should wrap around
        XCTAssertEqual(transform.rotation90Count, 0)
    }

    func testRotate90CounterClockwise() {
        // Given
        var transform = ImageTransform()

        // When
        transform.rotate90CounterClockwise()

        // Then
        XCTAssertEqual(transform.rotation90Count, 3) // 270 degrees
    }

    func testTotalRotationDegrees() {
        // Given
        var transform = ImageTransform()
        transform.rotation90Count = 1
        transform.fineRotation = 15.0

        // Then
        XCTAssertEqual(transform.totalRotationDegrees, 105.0) // 90 + 15
    }

    func testTotalRotationRadians() {
        // Given
        var transform = ImageTransform()
        transform.rotation90Count = 2 // 180 degrees

        // Then
        XCTAssertEqual(transform.totalRotationRadians, .pi, accuracy: 0.001)
    }

    func testReset() {
        // Given
        var transform = ImageTransform()
        transform.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        transform.fineRotation = 10.0
        transform.rotation90Count = 2

        // When
        transform.reset()

        // Then
        XCTAssertFalse(transform.hasChanges)
        XCTAssertNil(transform.cropRect)
        XCTAssertEqual(transform.fineRotation, 0)
        XCTAssertEqual(transform.rotation90Count, 0)
    }

    func testEncoding() throws {
        // Given
        var transform = ImageTransform()
        transform.cropRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        transform.fineRotation = 5.5
        transform.rotation90Count = 1

        // When
        let encoded = try JSONEncoder().encode(transform)
        let decoded = try JSONDecoder().decode(ImageTransform.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.cropRect, transform.cropRect)
        XCTAssertEqual(decoded.fineRotation, transform.fineRotation)
        XCTAssertEqual(decoded.rotation90Count, transform.rotation90Count)
    }
}

// MARK: - EditState Tests

final class EditStateTests: XCTestCase {

    func testCreation() {
        // Given
        let state = EditState(assetId: "test-asset-123")

        // Then
        XCTAssertEqual(state.assetId, "test-asset-123")
        XCTAssertFalse(state.hasChanges)
    }

    func testHasChangesWithAdjustments() {
        // Given
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5

        // Then
        XCTAssertTrue(state.hasChanges)
    }

    func testHasChangesWithTransform() {
        // Given
        var state = EditState(assetId: "test")
        state.transform.rotation90Count = 1

        // Then
        XCTAssertTrue(state.hasChanges)
    }

    func testResetAll() {
        // Given
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1

        // When
        state.resetAll()

        // Then
        XCTAssertFalse(state.hasChanges)
    }

    func testResetAdjustmentsOnly() {
        // Given
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1

        // When
        state.resetAdjustments()

        // Then
        XCTAssertTrue(state.hasChanges) // Transform still modified
        XCTAssertFalse(state.adjustments.hasChanges)
        XCTAssertTrue(state.transform.hasChanges)
    }

    func testResetTransformOnly() {
        // Given
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1

        // When
        state.resetTransform()

        // Then
        XCTAssertTrue(state.hasChanges) // Adjustments still modified
        XCTAssertTrue(state.adjustments.hasChanges)
        XCTAssertFalse(state.transform.hasChanges)
    }

    func testEncoding() throws {
        // Given
        var state = EditState(assetId: "test-123")
        state.adjustments.brightness = 0.3
        state.transform.fineRotation = 5.0

        // When
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditState.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.assetId, state.assetId)
        XCTAssertEqual(decoded.adjustments.brightness, state.adjustments.brightness)
        XCTAssertEqual(decoded.transform.fineRotation, state.transform.fineRotation)
    }
}

// MARK: - EditHistory Tests

final class EditHistoryTests: XCTestCase {

    func testInitialState() {
        // Given
        let history = EditHistory()

        // Then
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testRecordState() {
        // Given
        let history = EditHistory()
        let state = EditState(assetId: "test")

        // When
        history.record(state)

        // Then
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testUndo() {
        // Given
        let history = EditHistory()
        var state1 = EditState(assetId: "test")
        state1.adjustments.brightness = 0.2

        var state2 = EditState(assetId: "test")
        state2.adjustments.brightness = 0.5

        history.record(state1)

        // When
        let previousState = history.undo(currentState: state2)

        // Then
        XCTAssertNotNil(previousState)
        XCTAssertEqual(previousState?.adjustments.brightness, 0.2)
        XCTAssertTrue(history.canRedo)
    }

    func testRedo() {
        // Given
        let history = EditHistory()
        var state1 = EditState(assetId: "test")
        state1.adjustments.brightness = 0.2

        var state2 = EditState(assetId: "test")
        state2.adjustments.brightness = 0.5

        history.record(state1)
        _ = history.undo(currentState: state2)

        // When
        let nextState = history.redo(currentState: state1)

        // Then
        XCTAssertNotNil(nextState)
        XCTAssertEqual(nextState?.adjustments.brightness, 0.5)
    }

    func testRecordClearsRedoStack() {
        // Given
        let history = EditHistory()
        let state1 = EditState(assetId: "test")
        var state2 = EditState(assetId: "test")
        state2.adjustments.brightness = 0.5

        history.record(state1)
        _ = history.undo(currentState: state2)
        XCTAssertTrue(history.canRedo)

        // When
        history.record(state1)

        // Then
        XCTAssertFalse(history.canRedo)
    }

    func testClear() {
        // Given
        let history = EditHistory()
        history.record(EditState(assetId: "test"))
        history.record(EditState(assetId: "test"))

        // When
        history.clear()

        // Then
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testUndoWithEmptyStack() {
        // Given
        let history = EditHistory()
        let state = EditState(assetId: "test")

        // When
        let result = history.undo(currentState: state)

        // Then
        XCTAssertNil(result)
    }

    func testRedoWithEmptyStack() {
        // Given
        let history = EditHistory()
        let state = EditState(assetId: "test")

        // When
        let result = history.redo(currentState: state)

        // Then
        XCTAssertNil(result)
    }
}

// MARK: - AdjustmentType Tests

final class AdjustmentTypeTests: XCTestCase {

    func testDefaultValues() {
        // Then
        XCTAssertEqual(AdjustmentType.brightness.defaultValue, 0)
        XCTAssertEqual(AdjustmentType.contrast.defaultValue, 1.0)
        XCTAssertEqual(AdjustmentType.saturation.defaultValue, 1.0)
        XCTAssertEqual(AdjustmentType.exposure.defaultValue, 0)
    }

    func testValueRanges() {
        // Then - reduced ranges by 50% for finer control
        XCTAssertEqual(AdjustmentType.brightness.minValue, -0.5)
        XCTAssertEqual(AdjustmentType.brightness.maxValue, 0.5)

        XCTAssertEqual(AdjustmentType.exposure.minValue, -1.0)
        XCTAssertEqual(AdjustmentType.exposure.maxValue, 1.0)

        XCTAssertEqual(AdjustmentType.contrast.minValue, 0.75)
        XCTAssertEqual(AdjustmentType.contrast.maxValue, 1.25)

        XCTAssertEqual(AdjustmentType.highlights.minValue, -0.5)
        XCTAssertEqual(AdjustmentType.highlights.maxValue, 0.5)

        XCTAssertEqual(AdjustmentType.shadows.minValue, -0.5)
        XCTAssertEqual(AdjustmentType.shadows.maxValue, 0.5)

        XCTAssertEqual(AdjustmentType.blackPoint.minValue, 0)
        XCTAssertEqual(AdjustmentType.blackPoint.maxValue, 0.25)

        XCTAssertEqual(AdjustmentType.saturation.minValue, 0.5)
        XCTAssertEqual(AdjustmentType.saturation.maxValue, 1.5)

        XCTAssertEqual(AdjustmentType.brilliance.minValue, -0.5)
        XCTAssertEqual(AdjustmentType.brilliance.maxValue, 0.5)

        XCTAssertEqual(AdjustmentType.sharpness.minValue, 0)
        XCTAssertEqual(AdjustmentType.sharpness.maxValue, 1.0)

        XCTAssertEqual(AdjustmentType.definition.minValue, 0)
        XCTAssertEqual(AdjustmentType.definition.maxValue, 1.0)
    }

    func testGetValue() {
        // Given
        var adjustments = ImageAdjustments()
        adjustments.brightness = 0.5

        // Then
        XCTAssertEqual(AdjustmentType.brightness.getValue(from: adjustments), 0.5)
    }

    func testSetValue() {
        // Given
        var adjustments = ImageAdjustments()

        // When
        AdjustmentType.brightness.setValue(0.7, in: &adjustments)

        // Then
        XCTAssertEqual(adjustments.brightness, 0.7)
    }

    func testAllCasesHaveIcons() {
        // Then
        for type in AdjustmentType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func testAllCasesHaveIds() {
        // Then
        for type in AdjustmentType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }
}

// MARK: - AspectRatioPreset Tests

final class AspectRatioPresetTests: XCTestCase {

    func testFreeformRatio() {
        // Given
        let preset = AspectRatioPreset.freeform

        // Then
        XCTAssertNil(preset.ratio(originalAspect: 1.5))
    }

    func testOriginalRatio() {
        // Given
        let preset = AspectRatioPreset.original
        let originalAspect: CGFloat = 1.5

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: originalAspect), originalAspect)
    }

    func testSquareRatio() {
        // Given
        let preset = AspectRatioPreset.square

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: 1.5), 1.0)
    }

    func test4x3Ratio() {
        // Given
        let preset = AspectRatioPreset.ratio4x3

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: 1.0), 4.0 / 3.0, accuracy: 0.001)
    }

    func test3x4Ratio() {
        // Given
        let preset = AspectRatioPreset.ratio3x4

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: 1.0), 3.0 / 4.0, accuracy: 0.001)
    }

    func test16x9Ratio() {
        // Given
        let preset = AspectRatioPreset.ratio16x9

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: 1.0), 16.0 / 9.0, accuracy: 0.001)
    }

    func test9x16Ratio() {
        // Given
        let preset = AspectRatioPreset.ratio9x16

        // Then
        XCTAssertEqual(preset.ratio(originalAspect: 1.0), 9.0 / 16.0, accuracy: 0.001)
    }

    func testAllCasesHaveIds() {
        // Then
        for preset in AspectRatioPreset.allCases {
            XCTAssertEqual(preset.id, preset.rawValue)
        }
    }
}

// MARK: - EditorMode Tests

final class EditorModeTests: XCTestCase {

    func testAllCasesHaveIcons() {
        // Then
        for mode in EditorMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    func testAllCasesHaveIds() {
        // Then
        for mode in EditorMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }
}

// MARK: - TransformSubMode Tests

final class TransformSubModeTests: XCTestCase {

    func testAllCasesHaveIcons() {
        // Then
        for mode in TransformSubMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    func testAllCasesHaveIds() {
        // Then
        for mode in TransformSubMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }
}

// MARK: - PhotoEditPersistenceService Tests

final class PhotoEditPersistenceServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any existing edit states for clean tests
        PhotoEditPersistenceService.shared.deleteAllEditStates()
    }

    override func tearDown() {
        // Clean up after tests
        PhotoEditPersistenceService.shared.deleteAllEditStates()
        super.tearDown()
    }

    func testSaveAndRetrieveEditState() {
        // Given
        var state = EditState(assetId: "test-asset-1")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1

        // When
        PhotoEditPersistenceService.shared.saveEditState(state, for: "test-asset-1")
        let retrieved = PhotoEditPersistenceService.shared.getEditState(for: "test-asset-1")

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.adjustments.brightness, 0.5)
        XCTAssertEqual(retrieved?.transform.rotation90Count, 1)
    }

    func testHasEditState() {
        // Given
        var state = EditState(assetId: "test-asset-2")
        state.adjustments.brightness = 0.3

        // When
        PhotoEditPersistenceService.shared.saveEditState(state, for: "test-asset-2")

        // Then
        XCTAssertTrue(PhotoEditPersistenceService.shared.hasEditState(for: "test-asset-2"))
        XCTAssertFalse(PhotoEditPersistenceService.shared.hasEditState(for: "nonexistent"))
    }

    func testDeleteEditState() {
        // Given
        var state = EditState(assetId: "test-asset-3")
        state.adjustments.brightness = 0.3
        PhotoEditPersistenceService.shared.saveEditState(state, for: "test-asset-3")
        XCTAssertTrue(PhotoEditPersistenceService.shared.hasEditState(for: "test-asset-3"))

        // When
        PhotoEditPersistenceService.shared.deleteEditState(for: "test-asset-3")

        // Then
        XCTAssertFalse(PhotoEditPersistenceService.shared.hasEditState(for: "test-asset-3"))
    }

    func testSaveWithNoChangesRemovesState() {
        // Given
        var state = EditState(assetId: "test-asset-4")
        state.adjustments.brightness = 0.5
        PhotoEditPersistenceService.shared.saveEditState(state, for: "test-asset-4")
        XCTAssertTrue(PhotoEditPersistenceService.shared.hasEditState(for: "test-asset-4"))

        // When - save state with no changes
        let cleanState = EditState(assetId: "test-asset-4")
        PhotoEditPersistenceService.shared.saveEditState(cleanState, for: "test-asset-4")

        // Then
        XCTAssertFalse(PhotoEditPersistenceService.shared.hasEditState(for: "test-asset-4"))
    }

    func testEditStateCount() {
        // Given
        var state1 = EditState(assetId: "test-1")
        state1.adjustments.brightness = 0.1

        var state2 = EditState(assetId: "test-2")
        state2.adjustments.brightness = 0.2

        // When
        PhotoEditPersistenceService.shared.saveEditState(state1, for: "test-1")
        PhotoEditPersistenceService.shared.saveEditState(state2, for: "test-2")

        // Then
        XCTAssertEqual(PhotoEditPersistenceService.shared.editStateCount, 2)
    }

    func testCleanupOrphanedEditStates() {
        // Given
        var state1 = EditState(assetId: "existing-1")
        state1.adjustments.brightness = 0.1

        var state2 = EditState(assetId: "orphan-1")
        state2.adjustments.brightness = 0.2

        PhotoEditPersistenceService.shared.saveEditState(state1, for: "existing-1")
        PhotoEditPersistenceService.shared.saveEditState(state2, for: "orphan-1")

        // When
        PhotoEditPersistenceService.shared.cleanupOrphanedEditStates(existingAssetIds: Set(["existing-1"]))

        // Then
        XCTAssertTrue(PhotoEditPersistenceService.shared.hasEditState(for: "existing-1"))
        XCTAssertFalse(PhotoEditPersistenceService.shared.hasEditState(for: "orphan-1"))
    }

    func testGetEditSummary() {
        // Given
        var state = EditState(assetId: "test-summary")
        state.adjustments.brightness = 0.3
        state.adjustments.contrast = 1.2
        state.transform.rotation90Count = 1
        PhotoEditPersistenceService.shared.saveEditState(state, for: "test-summary")

        // When
        let summary = PhotoEditPersistenceService.shared.getEditSummary(for: "test-summary")

        // Then
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary!.contains("Rotated"))
        XCTAssertTrue(summary!.contains("adjustment"))
    }

    func testGetEditSummaryForNonexistent() {
        // When
        let summary = PhotoEditPersistenceService.shared.getEditSummary(for: "nonexistent")

        // Then
        XCTAssertNil(summary)
    }
}

// MARK: - ImageProcessingService Crop Tests

final class ImageProcessingCropTests: XCTestCase {

    /// Creates a test image with specified size and color
    private func createTestImage(width: CGFloat, height: CGFloat, color: UIColor = .red) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    /// Creates a test image with quadrant colors for visual verification
    /// Top-left: Red, Top-right: Green, Bottom-left: Blue, Bottom-right: Yellow
    private func createQuadrantTestImage(size: CGFloat = 100) -> UIImage {
        let imageSize = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 1.0)

        // Top-left: Red
        UIColor.red.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size/2, height: size/2))

        // Top-right: Green
        UIColor.green.setFill()
        UIRectFill(CGRect(x: size/2, y: 0, width: size/2, height: size/2))

        // Bottom-left: Blue
        UIColor.blue.setFill()
        UIRectFill(CGRect(x: 0, y: size/2, width: size/2, height: size/2))

        // Bottom-right: Yellow
        UIColor.yellow.setFill()
        UIRectFill(CGRect(x: size/2, y: size/2, width: size/2, height: size/2))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    func testCropTopLeftQuadrant() {
        // Given - 100x100 image
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        // Crop to top-left quadrant (0-50% width, 0-50% height in UI coordinates)
        state.transform.cropRect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 50, accuracy: 1)
        XCTAssertEqual(result!.size.height, 50, accuracy: 1)
    }

    func testCropBottomRightQuadrant() {
        // Given - 100x100 image
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        // Crop to bottom-right quadrant (50-100% width, 50-100% height in UI coordinates)
        state.transform.cropRect = CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 50, accuracy: 1)
        XCTAssertEqual(result!.size.height, 50, accuracy: 1)
    }

    func testCropCenterRegion() {
        // Given - 100x100 image
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        // Crop to center (25-75% both dimensions)
        state.transform.cropRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 50, accuracy: 1)
        XCTAssertEqual(result!.size.height, 50, accuracy: 1)
    }

    func testCropRectangularRegion() {
        // Given - 200x100 image (wide)
        let testImage = createTestImage(width: 200, height: 100)

        var state = EditState(assetId: "test")
        // Crop to left half
        state.transform.cropRect = CGRect(x: 0, y: 0, width: 0.5, height: 1.0)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testCropAfterRotation90() {
        // Given - 200x100 image
        let testImage = createTestImage(width: 200, height: 100)

        var state = EditState(assetId: "test")
        // Rotate 90 degrees clockwise - image becomes 100x200
        state.transform.rotation90Count = 1
        // Crop top half (after rotation)
        state.transform.cropRect = CGRect(x: 0, y: 0, width: 1.0, height: 0.5)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        // After 90° rotation: 200x100 becomes 100x200
        // After crop (top half): 100x100
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testNoCropWhenNil() {
        // Given
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        state.transform.cropRect = nil

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testFullImageCrop() {
        // Given - full image crop (0,0,1,1)
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        state.transform.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testCropWithFineRotation() {
        // Given
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        state.transform.fineRotation = 5.0 // 5 degrees
        state.transform.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        // Size should be approximately 80x80 (80% of 100)
        XCTAssertEqual(result!.size.width, 80, accuracy: 5)
        XCTAssertEqual(result!.size.height, 80, accuracy: 5)
    }

    func testCropWithAdjustments() {
        // Given
        let testImage = createTestImage(width: 100, height: 100)

        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.3
        state.adjustments.contrast = 1.2
        state.transform.cropRect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 50, accuracy: 1)
        XCTAssertEqual(result!.size.height, 50, accuracy: 1)
    }

    func testPreviewGeneration() {
        // Given
        let testImage = createTestImage(width: 1000, height: 1000)

        var state = EditState(assetId: "test")
        state.transform.cropRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        // When
        let preview = ImageProcessingService.shared.generatePreview(
            from: testImage,
            editState: state,
            maxDimension: 400
        )

        // Then
        XCTAssertNotNil(preview)
        // Preview should be smaller than original
        XCTAssertLessThanOrEqual(max(preview!.size.width, preview!.size.height), 400)
    }

    func testCropPreservesAspectRatio() {
        // Given - 200x100 image
        let testImage = createTestImage(width: 200, height: 100)

        var state = EditState(assetId: "test")
        // Crop to maintain 2:1 aspect ratio
        state.transform.cropRect = CGRect(x: 0.25, y: 0, width: 0.5, height: 1.0)

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        // 50% of 200 = 100 width, 100% of 100 = 100 height
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
        // Result should be 1:1 aspect ratio
        let aspectRatio = result!.size.width / result!.size.height
        XCTAssertEqual(aspectRatio, 1.0, accuracy: 0.01)
    }

    func testMultiple90DegreeRotations() {
        // Given - 200x100 image
        let testImage = createTestImage(width: 200, height: 100)

        var state = EditState(assetId: "test")
        // Rotate 180 degrees (2 x 90)
        state.transform.rotation90Count = 2

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        // 180 degree rotation keeps same dimensions
        XCTAssertEqual(result!.size.width, 200, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testRotation270Degrees() {
        // Given - 200x100 image
        let testImage = createTestImage(width: 200, height: 100)

        var state = EditState(assetId: "test")
        // Rotate 270 degrees (3 x 90)
        state.transform.rotation90Count = 3

        // When
        let result = ImageProcessingService.shared.applyEdits(to: testImage, editState: state)

        // Then
        XCTAssertNotNil(result)
        // 270 degree rotation swaps dimensions
        XCTAssertEqual(result!.size.width, 100, accuracy: 1)
        XCTAssertEqual(result!.size.height, 200, accuracy: 1)
    }
}
