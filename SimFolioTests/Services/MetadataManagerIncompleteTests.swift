// MetadataManagerIncompleteTests.swift
// SimFolio - Tests for MetadataManager incomplete/untagged helpers.

import XCTest
@testable import SimFolio

final class MetadataManagerIncompleteTests: XCTestCase {

    private var manager: MetadataManager!

    override func setUp() {
        super.setUp()
        manager = MetadataManager.shared
        manager.assetMetadata.removeAll()
    }

    override func tearDown() {
        manager.assetMetadata.removeAll()
        super.tearDown()
    }

    // MARK: - isIncomplete(assetId:)

    func testIsIncompleteWhenNoMetadataRowIsTrue() {
        XCTAssertTrue(manager.isIncomplete(assetId: "unknown-id"))
    }

    func testIsIncompleteWhenProcedureNilIsTrue() {
        var m = PhotoMetadata()
        m.stage = "Preparation"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func testIsIncompleteWhenStageNilIsTrue() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func testIsIncompleteWhenAngleNilIsTrue() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.stage = "Preparation"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func testIsIncompleteWhenAllTagsSetIsFalse() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.stage = "Preparation"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertFalse(manager.isIncomplete(assetId: "a"))
    }

    // MARK: - incompleteAssetCount

    func testIncompleteAssetCountCountsOnlyPartialRows() {
        var complete = PhotoMetadata()
        complete.procedure = "Class 1"
        complete.stage = "Preparation"
        complete.angle = "Buccal/Facial"
        manager.assetMetadata["complete"] = complete

        var partial = PhotoMetadata()
        partial.procedure = "Class 1"
        manager.assetMetadata["partial"] = partial

        XCTAssertEqual(manager.incompleteAssetCount, 1)
    }
}
