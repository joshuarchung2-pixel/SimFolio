// PhotoMigrationServiceTests.swift
// SimFolioTests - Unit tests for PhotoMigrationService key remapping logic

import XCTest
@testable import SimFolio

final class PhotoMigrationServiceTests: XCTestCase {

    func testBuildKeyMappingCreatesCorrectMapping() {
        // Given old asset IDs and new UUIDs
        let oldIds = ["old-asset-1", "old-asset-2", "old-asset-3"]
        let newIds = [UUID(), UUID(), UUID()]

        let mapping = PhotoMigrationService.buildKeyMapping(
            oldAssetIds: oldIds,
            newPhotoIds: newIds
        )

        XCTAssertEqual(mapping.count, 3)
        XCTAssertEqual(mapping["old-asset-1"], newIds[0])
        XCTAssertEqual(mapping["old-asset-2"], newIds[1])
        XCTAssertEqual(mapping["old-asset-3"], newIds[2])
    }

    func testBuildKeyMappingWithMoreOldIdsThanNew() {
        // Extra old IDs beyond the new list should be dropped
        let oldIds = ["old-1", "old-2", "old-3"]
        let newIds = [UUID(), UUID()]

        let mapping = PhotoMigrationService.buildKeyMapping(
            oldAssetIds: oldIds,
            newPhotoIds: newIds
        )

        XCTAssertEqual(mapping.count, 2)
        XCTAssertEqual(mapping["old-1"], newIds[0])
        XCTAssertEqual(mapping["old-2"], newIds[1])
        XCTAssertNil(mapping["old-3"])
    }

    func testBuildKeyMappingWithEmptyInputs() {
        let mapping = PhotoMigrationService.buildKeyMapping(
            oldAssetIds: [],
            newPhotoIds: []
        )

        XCTAssertTrue(mapping.isEmpty)
    }

    func testRemapEditStateKeys() {
        let oldKey = "old-asset-1"
        let newId = UUID()
        let mapping: [String: UUID] = [oldKey: newId]

        var editStates: [String: EditState] = [:]
        let editState = EditState(assetId: oldKey)
        editStates[oldKey] = editState

        let remapped = PhotoMigrationService.remapEditStateKeys(editStates, mapping: mapping)

        XCTAssertNil(remapped[oldKey])
        XCTAssertNotNil(remapped[newId.uuidString])
    }

    func testRemapEditStateKeysPreservesUnmappedKeys() {
        // Keys not in the mapping should be kept as-is
        let unmappedKey = "unmapped-asset"
        let mapping: [String: UUID] = [:]

        let editState = EditState(assetId: unmappedKey)
        let editStates: [String: EditState] = [unmappedKey: editState]

        let remapped = PhotoMigrationService.remapEditStateKeys(editStates, mapping: mapping)

        XCTAssertNotNil(remapped[unmappedKey])
    }

    func testRemapEditStateKeysWithMultipleEntries() {
        let oldKey1 = "old-asset-1"
        let oldKey2 = "old-asset-2"
        let unmappedKey = "unmapped-asset"
        let newId1 = UUID()
        let newId2 = UUID()
        let mapping: [String: UUID] = [oldKey1: newId1, oldKey2: newId2]

        let editStates: [String: EditState] = [
            oldKey1: EditState(assetId: oldKey1),
            oldKey2: EditState(assetId: oldKey2),
            unmappedKey: EditState(assetId: unmappedKey)
        ]

        let remapped = PhotoMigrationService.remapEditStateKeys(editStates, mapping: mapping)

        XCTAssertEqual(remapped.count, 3)
        XCTAssertNil(remapped[oldKey1])
        XCTAssertNil(remapped[oldKey2])
        XCTAssertNotNil(remapped[newId1.uuidString])
        XCTAssertNotNil(remapped[newId2.uuidString])
        XCTAssertNotNil(remapped[unmappedKey])
    }
}
