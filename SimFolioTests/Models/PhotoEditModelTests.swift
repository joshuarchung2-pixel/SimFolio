// PhotoEditModelTests.swift
// SimFolioTests/Models — Unit tests for photo editing models

import XCTest
@testable import SimFolio

// MARK: - ImageAdjustments Tests

final class ImageAdjustmentsTests: XCTestCase {

    func testDefaultValues() {
        let adj = ImageAdjustments()
        XCTAssertEqual(adj.brightness, 0)
        XCTAssertEqual(adj.exposure, 0)
        XCTAssertEqual(adj.highlights, 0)
        XCTAssertEqual(adj.shadows, 0)
        XCTAssertEqual(adj.contrast, 1.0)
        XCTAssertEqual(adj.blackPoint, 0)
        XCTAssertEqual(adj.saturation, 1.0)
        XCTAssertEqual(adj.brilliance, 0)
        XCTAssertEqual(adj.sharpness, 0)
        XCTAssertEqual(adj.definition, 0)
    }

    func testHasChanges_falseByDefault() {
        XCTAssertFalse(ImageAdjustments().hasChanges)
    }

    func testHasChanges_trueAfterBrightnessChange() {
        var adj = ImageAdjustments()
        adj.brightness = 0.5
        XCTAssertTrue(adj.hasChanges)
    }

    func testHasChanges_trueAfterContrastChange() {
        var adj = ImageAdjustments()
        adj.contrast = 1.2
        XCTAssertTrue(adj.hasChanges)
    }

    func testHasChanges_trueAfterSaturationChange() {
        var adj = ImageAdjustments()
        adj.saturation = 0.8
        XCTAssertTrue(adj.hasChanges)
    }

    func testReset_restoresDefaults() {
        var adj = ImageAdjustments()
        adj.brightness = 0.5
        adj.contrast = 1.3
        adj.saturation = 0.8
        adj.sharpness = 1.0
        adj.reset()

        XCTAssertFalse(adj.hasChanges)
        XCTAssertEqual(adj.brightness, 0)
        XCTAssertEqual(adj.contrast, 1.0)
        XCTAssertEqual(adj.saturation, 1.0)
        XCTAssertEqual(adj.sharpness, 0)
    }

    func testStaticDefault_hasNoChanges() {
        XCTAssertFalse(ImageAdjustments.default.hasChanges)
    }

    func testEncoding() throws {
        var adj = ImageAdjustments()
        adj.brightness = 0.3
        adj.exposure = -0.5
        adj.contrast = 1.2

        let decoded = try JSONDecoder().decode(ImageAdjustments.self, from: JSONEncoder().encode(adj))

        XCTAssertEqual(decoded.brightness, adj.brightness)
        XCTAssertEqual(decoded.exposure,   adj.exposure)
        XCTAssertEqual(decoded.contrast,   adj.contrast)
    }

    func testEquality() {
        var adj1 = ImageAdjustments(); adj1.brightness = 0.5
        var adj2 = ImageAdjustments(); adj2.brightness = 0.5
        var adj3 = ImageAdjustments(); adj3.brightness = 0.6
        XCTAssertEqual(adj1, adj2)
        XCTAssertNotEqual(adj1, adj3)
    }
}

// MARK: - ImageTransform Tests

final class ImageTransformTests: XCTestCase {

    func testDefaultValues() {
        let t = ImageTransform()
        XCTAssertNil(t.cropRect)
        XCTAssertEqual(t.fineRotation, 0)
        XCTAssertEqual(t.rotation90Count, 0)
    }

    func testHasChanges_falseByDefault() {
        XCTAssertFalse(ImageTransform().hasChanges)
    }

    func testHasChanges_withCropRect() {
        var t = ImageTransform()
        t.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        XCTAssertTrue(t.hasChanges)
    }

    func testHasChanges_withFineRotation() {
        var t = ImageTransform()
        t.fineRotation = 5.0
        XCTAssertTrue(t.hasChanges)
    }

    func testHasChanges_with90DegreeRotation() {
        var t = ImageTransform()
        t.rotation90Count = 1
        XCTAssertTrue(t.hasChanges)
    }

    func testRotate90Clockwise_wrapsAt4() {
        var t = ImageTransform()
        t.rotate90Clockwise()
        XCTAssertEqual(t.rotation90Count, 1)
        t.rotate90Clockwise()
        t.rotate90Clockwise()
        t.rotate90Clockwise()
        XCTAssertEqual(t.rotation90Count, 0)
    }

    func testRotate90CounterClockwise_wrapsTo3() {
        var t = ImageTransform()
        t.rotate90CounterClockwise()
        XCTAssertEqual(t.rotation90Count, 3)
    }

    func testTotalRotationDegrees() {
        var t = ImageTransform()
        t.rotation90Count = 1
        t.fineRotation = 15.0
        XCTAssertEqual(t.totalRotationDegrees, 105.0)
    }

    func testTotalRotationRadians() {
        var t = ImageTransform()
        t.rotation90Count = 2 // 180°
        XCTAssertEqual(t.totalRotationRadians, .pi, accuracy: 0.001)
    }

    func testReset_clearsAll() {
        var t = ImageTransform()
        t.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        t.fineRotation = 10.0
        t.rotation90Count = 2
        t.reset()

        XCTAssertFalse(t.hasChanges)
        XCTAssertNil(t.cropRect)
        XCTAssertEqual(t.fineRotation, 0)
        XCTAssertEqual(t.rotation90Count, 0)
    }

    func testStaticDefault_hasNoChanges() {
        XCTAssertFalse(ImageTransform.default.hasChanges)
    }

    func testEncoding() throws {
        var t = ImageTransform()
        t.cropRect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        t.fineRotation = 5.5
        t.rotation90Count = 1

        let decoded = try JSONDecoder().decode(ImageTransform.self, from: JSONEncoder().encode(t))

        XCTAssertEqual(decoded.cropRect, t.cropRect)
        XCTAssertEqual(decoded.fineRotation, t.fineRotation)
        XCTAssertEqual(decoded.rotation90Count, t.rotation90Count)
    }
}

// MARK: - EditState Tests

final class EditStateTests: XCTestCase {

    func testCreation_defaultHasNoChanges() {
        let state = EditState(assetId: "test-asset-123")
        XCTAssertEqual(state.assetId, "test-asset-123")
        XCTAssertFalse(state.hasChanges)
    }

    func testHasChanges_withAdjustments() {
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        XCTAssertTrue(state.hasChanges)
    }

    func testHasChanges_withTransform() {
        var state = EditState(assetId: "test")
        state.transform.rotation90Count = 1
        XCTAssertTrue(state.hasChanges)
    }

    func testResetAll_clearsEverything() {
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1
        state.resetAll()
        XCTAssertFalse(state.hasChanges)
    }

    func testResetAdjustmentsOnly_keepTransform() {
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1
        state.resetAdjustments()
        XCTAssertTrue(state.hasChanges)
        XCTAssertFalse(state.adjustments.hasChanges)
        XCTAssertTrue(state.transform.hasChanges)
    }

    func testResetTransformOnly_keepAdjustments() {
        var state = EditState(assetId: "test")
        state.adjustments.brightness = 0.5
        state.transform.rotation90Count = 1
        state.resetTransform()
        XCTAssertTrue(state.hasChanges)
        XCTAssertTrue(state.adjustments.hasChanges)
        XCTAssertFalse(state.transform.hasChanges)
    }

    func testEncoding() throws {
        var state = EditState(assetId: "test-123")
        state.adjustments.brightness = 0.3
        state.transform.fineRotation = 5.0

        let decoded = try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state))

        XCTAssertEqual(decoded.assetId, state.assetId)
        XCTAssertEqual(decoded.adjustments.brightness, state.adjustments.brightness)
        XCTAssertEqual(decoded.transform.fineRotation, state.transform.fineRotation)
    }
}

// MARK: - EditHistory Tests

final class EditHistoryTests: XCTestCase {

    func testInitialState() {
        let history = EditHistory()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testRecord_enablesUndo() {
        let history = EditHistory()
        history.record(EditState(assetId: "test"))
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testUndo_returnsPreviousState() {
        let history = EditHistory()
        var state1 = EditState(assetId: "test"); state1.adjustments.brightness = 0.2
        var state2 = EditState(assetId: "test"); state2.adjustments.brightness = 0.5

        history.record(state1)
        let result = history.undo(currentState: state2)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.adjustments.brightness, 0.2)
        XCTAssertTrue(history.canRedo)
    }

    func testRedo_returnsForwardState() {
        let history = EditHistory()
        var state1 = EditState(assetId: "test"); state1.adjustments.brightness = 0.2
        var state2 = EditState(assetId: "test"); state2.adjustments.brightness = 0.5

        history.record(state1)
        _ = history.undo(currentState: state2)
        let result = history.redo(currentState: state1)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.adjustments.brightness, 0.5)
    }

    func testRecord_clearsRedoStack() {
        let history = EditHistory()
        let state1 = EditState(assetId: "test")
        var state2 = EditState(assetId: "test"); state2.adjustments.brightness = 0.5

        history.record(state1)
        _ = history.undo(currentState: state2)
        XCTAssertTrue(history.canRedo)

        history.record(state1)
        XCTAssertFalse(history.canRedo)
    }

    func testClear_removesAllHistory() {
        let history = EditHistory()
        history.record(EditState(assetId: "test"))
        history.record(EditState(assetId: "test"))
        history.clear()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testUndo_nilWhenEmpty() {
        let history = EditHistory()
        XCTAssertNil(history.undo(currentState: EditState(assetId: "test")))
    }

    func testRedo_nilWhenEmpty() {
        let history = EditHistory()
        XCTAssertNil(history.redo(currentState: EditState(assetId: "test")))
    }
}

// MARK: - EditorMode Tests

final class EditorModeTests: XCTestCase {

    func testCaseCount_threeModesExist() {
        XCTAssertEqual(EditorMode.allCases.count, 3)
    }

    func testCases_includeExpectedModes() {
        let cases = EditorMode.allCases
        XCTAssertTrue(cases.contains(.transform))
        XCTAssertTrue(cases.contains(.adjust))
        XCTAssertTrue(cases.contains(.markup))
    }

    func testIdentifiable_idIsRawValue() {
        XCTAssertEqual(EditorMode.transform.id, "Transform")
        XCTAssertEqual(EditorMode.adjust.id,    "Adjust")
        XCTAssertEqual(EditorMode.markup.id,    "Markup")
    }

    func testIcons_nonEmpty() {
        for mode in EditorMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) should have a non-empty icon")
        }
    }
}

// MARK: - AdjustmentType Tests

final class AdjustmentTypeTests: XCTestCase {

    func testCaseCount_tenTypes() {
        XCTAssertEqual(AdjustmentType.allCases.count, 10)
    }

    func testDefaultValues() {
        XCTAssertEqual(AdjustmentType.brightness.defaultValue, 0)
        XCTAssertEqual(AdjustmentType.contrast.defaultValue, 1.0)
        XCTAssertEqual(AdjustmentType.saturation.defaultValue, 1.0)
        XCTAssertEqual(AdjustmentType.exposure.defaultValue, 0)
    }

    func testValueRanges_brightness() {
        XCTAssertEqual(AdjustmentType.brightness.minValue, -0.5)
        XCTAssertEqual(AdjustmentType.brightness.maxValue,  0.5)
    }

    func testValueRanges_exposure() {
        XCTAssertEqual(AdjustmentType.exposure.minValue, -1.0)
        XCTAssertEqual(AdjustmentType.exposure.maxValue,  1.0)
    }

    func testValueRanges_contrast() {
        XCTAssertEqual(AdjustmentType.contrast.minValue, 0.75)
        XCTAssertEqual(AdjustmentType.contrast.maxValue, 1.25)
    }

    func testValueRanges_saturation() {
        XCTAssertEqual(AdjustmentType.saturation.minValue, 0.5)
        XCTAssertEqual(AdjustmentType.saturation.maxValue, 1.5)
    }

    func testValueRanges_blackPoint() {
        XCTAssertEqual(AdjustmentType.blackPoint.minValue, 0)
        XCTAssertEqual(AdjustmentType.blackPoint.maxValue, 0.25)
    }

    func testGetValue_fromAdjustments() {
        var adj = ImageAdjustments()
        adj.brightness = 0.3
        adj.contrast   = 1.1
        XCTAssertEqual(AdjustmentType.brightness.getValue(from: adj), 0.3)
        XCTAssertEqual(AdjustmentType.contrast.getValue(from: adj),   1.1)
    }

    func testSetValue_inAdjustments() {
        var adj = ImageAdjustments()
        AdjustmentType.exposure.setValue(0.7, in: &adj)
        XCTAssertEqual(adj.exposure, 0.7)
    }

    func testIsPremium_brightnessAndContrastAreFree() {
        XCTAssertFalse(AdjustmentType.brightness.isPremium)
        XCTAssertFalse(AdjustmentType.contrast.isPremium)
    }

    func testIsPremium_otherTypesArePremium() {
        XCTAssertTrue(AdjustmentType.exposure.isPremium)
        XCTAssertTrue(AdjustmentType.saturation.isPremium)
    }
}

// MARK: - AspectRatioPreset Tests

final class AspectRatioPresetTests: XCTestCase {

    func testCaseCount_sevenPresets() {
        XCTAssertEqual(AspectRatioPreset.allCases.count, 7)
    }

    func testFreeform_returnsNilRatio() {
        XCTAssertNil(AspectRatioPreset.freeform.ratio(originalAspect: 1.5))
    }

    func testSquare_returns1() {
        XCTAssertEqual(AspectRatioPreset.square.ratio(originalAspect: 1.5), 1.0)
    }

    func testRatio4x3_returnsCorrectValue() {
        let ratio = AspectRatioPreset.ratio4x3.ratio(originalAspect: 1.0)
        XCTAssertNotNil(ratio)
        XCTAssertEqual(ratio!, 4.0 / 3.0, accuracy: 0.0001)
    }

    func testRatio16x9_returnsCorrectValue() {
        let ratio = AspectRatioPreset.ratio16x9.ratio(originalAspect: 1.0)
        XCTAssertNotNil(ratio)
        XCTAssertEqual(ratio!, 16.0 / 9.0, accuracy: 0.0001)
    }

    func testOriginal_returnsPassedAspect() {
        let aspect: CGFloat = 1.777
        XCTAssertEqual(AspectRatioPreset.original.ratio(originalAspect: aspect), aspect)
    }

    func testIdentifiable_idIsRawValue() {
        XCTAssertEqual(AspectRatioPreset.square.id, "Square")
        XCTAssertEqual(AspectRatioPreset.freeform.id, "Freeform")
    }
}

// MARK: - MainTab Tests

final class MainTabTests: XCTestCase {

    func testCaseCount_fiveTabs() {
        XCTAssertEqual(MainTab.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(MainTab.home.rawValue,    0)
        XCTAssertEqual(MainTab.capture.rawValue, 1)
        XCTAssertEqual(MainTab.library.rawValue, 2)
        XCTAssertEqual(MainTab.feed.rawValue,    3)
        XCTAssertEqual(MainTab.profile.rawValue, 4)
    }

    func testTitles() {
        XCTAssertEqual(MainTab.home.title,    "Home")
        XCTAssertEqual(MainTab.capture.title, "Capture")
        XCTAssertEqual(MainTab.library.title, "Library")
        XCTAssertEqual(MainTab.feed.title,    "Feed")
        XCTAssertEqual(MainTab.profile.title, "Profile")
    }

    func testIcons_nonEmpty() {
        for tab in MainTab.allCases {
            XCTAssertFalse(tab.icon.isEmpty,         "\(tab) icon should be non-empty")
            XCTAssertFalse(tab.selectedIcon.isEmpty, "\(tab) selectedIcon should be non-empty")
        }
    }

    func testIdentifiable_idIsRawValue() {
        XCTAssertEqual(MainTab.home.id, 0)
        XCTAssertEqual(MainTab.feed.id, 3)
    }

    func testFeedTabExists() {
        XCTAssertNotNil(MainTab(rawValue: 3))
        XCTAssertEqual(MainTab(rawValue: 3), .feed)
    }
}
