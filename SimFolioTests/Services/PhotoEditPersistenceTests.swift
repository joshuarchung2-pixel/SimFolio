// PhotoEditPersistenceTests.swift
// SimFolioTests - Edit state persistence tests using MockEditStatePersistence

import XCTest
@testable import SimFolio

final class PhotoEditPersistenceTests: XCTestCase {

    var sut: MockEditStatePersistence!

    override func setUp() {
        super.setUp()
        sut = MockEditStatePersistence()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Save and Retrieve

    func testSaveAndRetrieveEditState() {
        let state = TestData.createEditState(assetId: "asset-1", brightness: 0.3)
        sut.saveEditState(state, for: "asset-1")
        let retrieved = sut.getEditState(for: "asset-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.assetId, "asset-1")
        XCTAssertEqual(retrieved?.adjustments.brightness, 0.3)
        XCTAssertEqual(sut.saveCalls.count, 1)
        XCTAssertEqual(sut.saveCalls.first?.assetId, "asset-1")
    }

    func testGetEditStateReturnsNilWhenAbsent() {
        XCTAssertNil(sut.getEditState(for: "missing-asset"))
    }

    func testSaveOverwritesPreviousEditState() {
        let state1 = TestData.createEditState(assetId: "asset-2", brightness: 0.1)
        let state2 = TestData.createEditState(assetId: "asset-2", brightness: 0.5)
        sut.saveEditState(state1, for: "asset-2")
        sut.saveEditState(state2, for: "asset-2")
        let retrieved = sut.getEditState(for: "asset-2")
        XCTAssertEqual(retrieved?.adjustments.brightness, 0.5)
        XCTAssertEqual(sut.saveCalls.count, 2)
    }

    // MARK: - hasEditState

    func testHasEditStateReturnsTrueAfterSave() {
        let state = TestData.createEditState(assetId: "asset-3")
        sut.saveEditState(state, for: "asset-3")
        XCTAssertTrue(sut.hasEditState(for: "asset-3"))
    }

    func testHasEditStateReturnsFalseWhenAbsent() {
        XCTAssertFalse(sut.hasEditState(for: "not-saved"))
    }

    func testHasEditStateReturnsFalseAfterDelete() {
        let state = TestData.createEditState(assetId: "asset-4")
        sut.saveEditState(state, for: "asset-4")
        sut.deleteEditState(for: "asset-4")
        XCTAssertFalse(sut.hasEditState(for: "asset-4"))
    }

    // MARK: - Delete

    func testDeleteEditState() {
        let state = TestData.createEditState(assetId: "asset-5")
        sut.saveEditState(state, for: "asset-5")
        sut.deleteEditState(for: "asset-5")
        XCTAssertNil(sut.getEditState(for: "asset-5"))
        XCTAssertEqual(sut.deleteCalls, ["asset-5"])
    }

    func testDeleteNonExistentIsNoop() {
        sut.deleteEditState(for: "never-saved")
        XCTAssertEqual(sut.deleteCalls, ["never-saved"])
        XCTAssertNil(sut.getEditState(for: "never-saved"))
    }

    // MARK: - Edit Summary

    func testEditSummaryNilWhenNoChanges() {
        // An EditState with default values has hasChanges == false
        let state = EditState(assetId: "asset-6")
        sut.saveEditState(state, for: "asset-6")
        let summary = sut.getEditSummary(for: "asset-6")
        XCTAssertNil(summary)
    }

    func testEditSummaryPresentWhenChanged() {
        var state = EditState(assetId: "asset-7")
        state.adjustments.brightness = 0.4
        sut.saveEditState(state, for: "asset-7")
        let summary = sut.getEditSummary(for: "asset-7")
        XCTAssertNotNil(summary)
    }

    func testEditSummaryNilWhenAbsent() {
        let summary = sut.getEditSummary(for: "missing")
        XCTAssertNil(summary)
    }
}
