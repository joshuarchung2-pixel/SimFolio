// PhotoImportServiceTests.swift
// SimFolioTests - PhotoImportService behavior using protocol mocks

import XCTest
import UIKit
@testable import SimFolio

final class PhotoImportServiceTests: XCTestCase {

    var storage: MockPhotoStorage!
    var metadata: MockMetadataManager!
    var sut: PhotoImportService!

    override func setUp() {
        super.setUp()
        storage = MockPhotoStorage()
        metadata = MockMetadataManager()
        sut = PhotoImportService(photoStorage: storage, metadata: metadata)
    }

    override func tearDown() {
        storage = nil
        metadata = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCandidate(
        pHAssetId: String? = UUID().uuidString,
        image: UIImage? = TestUtilities.generateTestImage(),
        originalCapturedDate: Date? = TestData.referenceDate,
        rating: Int = 0,
        shouldKeep: Bool = true,
        loadError: Error? = nil
    ) -> ImportCandidate {
        ImportCandidate(
            pickerItemId: pHAssetId,
            image: image,
            pHAssetId: pHAssetId,
            originalCapturedDate: originalCapturedDate,
            rating: rating,
            shouldKeep: shouldKeep,
            loadError: loadError
        )
    }

    private func runImport(
        candidates: [ImportCandidate],
        metadataToAttach: PhotoMetadata = TestData.createPhotoMetadata(),
        isCancelled: @escaping () -> Bool = { false }
    ) async -> (result: ImportResult, progressSnapshots: [ImportProgress]) {
        var snapshots: [ImportProgress] = []
        let result = await sut.importCandidates(
            candidates,
            metadata: metadataToAttach,
            onProgress: { snapshots.append($0) },
            isCancelled: isCancelled
        )
        return (result, snapshots)
    }

    // MARK: - Happy Path

    func testHappyPathImportsEachCandidate() async {
        let candidates = [makeCandidate(), makeCandidate(), makeCandidate()]

        let (result, snapshots) = await runImport(candidates: candidates)

        XCTAssertEqual(result.imported, 3)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(storage.records.count, 3)
        XCTAssertEqual(metadata.assignMetadataCalls.count, 3)
        XCTAssertEqual(metadata.markImportedCalls.count, 3)
        XCTAssertEqual(snapshots.last?.completed, 3)
        XCTAssertEqual(snapshots.last?.total, 3)
    }

    func testPreservesOriginalCapturedDate() async {
        let customDate = TestData.date(daysFromReference: -42)
        let candidates = [makeCandidate(originalCapturedDate: customDate)]

        _ = await runImport(candidates: candidates)

        XCTAssertEqual(storage.savePhotoWithDateCalls.count, 1)
        XCTAssertEqual(storage.savePhotoWithDateCalls.first?.createdDate, customDate)
        XCTAssertEqual(storage.records.first?.createdDate, customDate)
    }

    // MARK: - Dedup

    func testSkipsAlreadyImportedAssetIds() async {
        metadata.importedAssetIds.insert("duplicate-asset")
        let candidates = [
            makeCandidate(pHAssetId: "duplicate-asset"),
            makeCandidate(pHAssetId: "fresh-asset")
        ]

        let (result, _) = await runImport(candidates: candidates)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(storage.records.count, 1)
    }

    func testMarksImportedAssetsForFutureDedup() async {
        let candidates = [makeCandidate(pHAssetId: "asset-xyz")]

        _ = await runImport(candidates: candidates)

        XCTAssertTrue(metadata.hasImported(assetId: "asset-xyz"))
        XCTAssertEqual(metadata.markImportedCalls, ["asset-xyz"])
    }

    // MARK: - Cancel

    func testCancellationStopsMidBatch() async {
        let cancelFlag = Box(value: false)
        let candidates = (0..<5).map { _ in makeCandidate() }

        var progressSnapshots: [ImportProgress] = []
        let result = await sut.importCandidates(
            candidates,
            metadata: TestData.createPhotoMetadata(),
            onProgress: { snapshot in
                progressSnapshots.append(snapshot)
                if snapshot.completed == 2 {
                    cancelFlag.value = true
                }
            },
            isCancelled: { cancelFlag.value }
        )

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(storage.records.count, 2)
        XCTAssertLessThan(progressSnapshots.last?.completed ?? 0, 5)
    }

    // MARK: - Fallback Date

    func testMissingCreationDateFallsBackToNow() async {
        let before = Date()
        let candidates = [makeCandidate(originalCapturedDate: nil)]

        _ = await runImport(candidates: candidates)
        let after = Date()

        guard let saved = storage.savePhotoWithDateCalls.first else {
            XCTFail("Expected photo to be saved with a fallback date")
            return
        }
        XCTAssertGreaterThanOrEqual(saved.createdDate, before)
        XCTAssertLessThanOrEqual(saved.createdDate, after)
    }

    // MARK: - Load Error

    func testCandidateWithLoadErrorCountsAsFailed() async {
        let failing = makeCandidate(image: nil, loadError: ImportError.loadFailed)
        let succeeding = makeCandidate()

        let (result, _) = await runImport(candidates: [failing, succeeding])

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(storage.records.count, 1)
    }

    func testCandidateWithNilImageCountsAsFailed() async {
        let candidates = [makeCandidate(image: nil)]

        let (result, _) = await runImport(candidates: candidates)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.failed, 1)
        XCTAssertTrue(storage.records.isEmpty)
    }

    // MARK: - Empty Input

    func testEmptyInputReturnsZeroCounts() async {
        let (result, snapshots) = await runImport(candidates: [])

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.failed, 0)
        XCTAssertTrue(snapshots.isEmpty)
    }

    // MARK: - Rating Per Candidate

    func testPerCandidateRatingOverridesBaseMetadataRating() async {
        let base = TestData.createPhotoMetadata(rating: 1)
        let candidates = [
            makeCandidate(rating: 5),
            makeCandidate(rating: 0)   // zero rating keeps base rating
        ]

        _ = await runImport(candidates: candidates, metadataToAttach: base)

        XCTAssertEqual(metadata.assignMetadataCalls.count, 2)
        XCTAssertEqual(metadata.assignMetadataCalls[0].metadata.rating, 5)
        XCTAssertEqual(metadata.assignMetadataCalls[1].metadata.rating, 1)
    }
}

// MARK: - Test Helpers

/// Mutable reference cell usable inside @Sendable closures passed to the SUT.
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
}
