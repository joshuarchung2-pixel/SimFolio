// MetadataManagerCleanupTests.swift
// SimFolioTests - Verifies that in-app photo metadata is preserved across launches
// and that explicit cleanup only removes truly orphaned entries.
//
// Background: a previous bug ran a destructive `cleanupOrphanedData` on every
// app launch from a detached Task; under any race or PhotoKit flake it wiped
// users' photo tags. The cleanup was removed; these tests guard against
// re-introducing implicit-cleanup-on-launch and document the remaining
// explicit cleanup function's contract.

import XCTest
@testable import SimFolio

@MainActor
final class MetadataManagerCleanupTests: XCTestCase {

    private var manager: MetadataManager!
    private var photoStorage: PhotoStorageService!

    private var savedMetadata: [String: PhotoMetadata]!
    private var savedRecords: [PhotoRecord]!

    override func setUp() {
        super.setUp()
        manager = MetadataManager.shared
        photoStorage = PhotoStorageService.shared
        savedMetadata = manager.assetMetadata
        savedRecords = photoStorage.records
        manager.assetMetadata.removeAll()
        photoStorage.records.removeAll()
    }

    override func tearDown() {
        manager.assetMetadata = savedMetadata
        photoStorage.records = savedRecords
        super.tearDown()
    }

    // MARK: - Implicit-cleanup guard

    /// Even when a metadata key has no corresponding PhotoRecord (e.g. legacy
    /// PHAsset-keyed entries left over from earlier versions), the manager must
    /// not implicitly wipe it — only an explicit cleanup call may do so. This
    /// is the smoking-gun scenario the original bug deleted.
    func testMetadataWithoutMatchingPhotoRecordIsNotImplicitlyRemoved() {
        let validId = UUID()
        photoStorage.records = [
            PhotoRecord(id: validId, createdDate: TestData.referenceDate, fileSize: 100)
        ]

        let meta = TestData.createPhotoMetadata()
        manager.assetMetadata[validId.uuidString] = meta
        manager.assetMetadata["legacy-phasset-id"] = meta

        XCTAssertEqual(manager.assetMetadata.count, 2)
        XCTAssertNotNil(manager.assetMetadata[validId.uuidString])
        XCTAssertNotNil(manager.assetMetadata["legacy-phasset-id"])
    }

    // MARK: - Explicit cleanup contract

    /// `cleanupOrphanedAppStorageData()` removes only metadata whose key does not
    /// match any current PhotoRecord. Valid in-app metadata must be kept.
    func testCleanupOrphanedAppStorageDataRemovesOnlyOrphans() {
        let validId = UUID()
        photoStorage.records = [
            PhotoRecord(id: validId, createdDate: TestData.referenceDate, fileSize: 100)
        ]

        let meta = TestData.createPhotoMetadata(procedure: "Crown")
        manager.assetMetadata[validId.uuidString] = meta
        manager.assetMetadata["bogus-key-1"] = meta
        manager.assetMetadata["bogus-key-2"] = meta

        manager.cleanupOrphanedAppStorageData()

        XCTAssertEqual(manager.assetMetadata.count, 1)
        XCTAssertNotNil(manager.assetMetadata[validId.uuidString])
        XCTAssertNil(manager.assetMetadata["bogus-key-1"])
        XCTAssertNil(manager.assetMetadata["bogus-key-2"])
    }

    func testCleanupOrphanedAppStorageDataIsNoopWhenAllValid() {
        let id1 = UUID()
        let id2 = UUID()
        photoStorage.records = [
            PhotoRecord(id: id1, createdDate: TestData.referenceDate, fileSize: 100),
            PhotoRecord(id: id2, createdDate: TestData.referenceDate, fileSize: 100),
        ]

        let meta = TestData.createPhotoMetadata()
        manager.assetMetadata[id1.uuidString] = meta
        manager.assetMetadata[id2.uuidString] = meta

        manager.cleanupOrphanedAppStorageData()

        XCTAssertEqual(manager.assetMetadata.count, 2)
        XCTAssertNotNil(manager.assetMetadata[id1.uuidString])
        XCTAssertNotNil(manager.assetMetadata[id2.uuidString])
    }
}
