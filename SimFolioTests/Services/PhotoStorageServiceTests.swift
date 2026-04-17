// PhotoStorageServiceTests.swift
// SimFolioTests - PhotoStorage tests using MockPhotoStorage

import XCTest
import UIKit
@testable import SimFolio

final class PhotoStorageServiceTests: XCTestCase {

    var sut: MockPhotoStorage!

    override func setUp() {
        super.setUp()
        sut = MockPhotoStorage()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Save Photo

    func testSavePhotoCreatesRecord() {
        let image = TestUtilities.generateTestImage()
        let record = sut.savePhoto(image, compressionQuality: 0.8)
        XCTAssertTrue(sut.records.contains(where: { $0.id == record.id }))
        XCTAssertGreaterThan(record.fileSize, 0)
        XCTAssertEqual(sut.savePhotoCalls.count, 1)
    }

    func testSavePhotoMultipleTimes() {
        let image = TestUtilities.generateTestImage()
        let r1 = sut.savePhoto(image, compressionQuality: 0.8)
        let r2 = sut.savePhoto(image, compressionQuality: 0.8)
        XCTAssertNotEqual(r1.id, r2.id)
        XCTAssertEqual(sut.records.count, 2)
        XCTAssertEqual(sut.savePhotoCalls.count, 2)
    }

    // MARK: - Delete Photo

    func testDeletePhoto() {
        let image = TestUtilities.generateTestImage()
        let record = sut.savePhoto(image, compressionQuality: 0.8)
        sut.deletePhoto(id: record.id)
        XCTAssertFalse(sut.records.contains(where: { $0.id == record.id }))
        XCTAssertNil(sut.loadImage(id: record.id))
        XCTAssertEqual(sut.deletePhotoCalls, [record.id])
    }

    func testDeleteMultiplePhotos() {
        let image = TestUtilities.generateTestImage()
        let r1 = sut.savePhoto(image, compressionQuality: 0.8)
        let r2 = sut.savePhoto(image, compressionQuality: 0.8)
        let r3 = sut.savePhoto(image, compressionQuality: 0.8)
        sut.deletePhotos(ids: [r1.id, r2.id])
        XCTAssertEqual(sut.records.count, 1)
        XCTAssertEqual(sut.records.first?.id, r3.id)
        XCTAssertEqual(sut.deletePhotoCalls.count, 2)
        XCTAssertTrue(sut.deletePhotoCalls.contains(r1.id))
        XCTAssertTrue(sut.deletePhotoCalls.contains(r2.id))
    }

    func testDeleteNonExistentPhotoIsNoop() {
        let fakeId = UUID()
        sut.deletePhoto(id: fakeId)
        XCTAssertTrue(sut.records.isEmpty)
    }

    // MARK: - Load Thumbnail

    func testLoadThumbnailReturnsImage() {
        let image = TestUtilities.generateTestImage()
        let record = sut.savePhoto(image, compressionQuality: 0.8)
        let thumb = sut.loadThumbnail(id: record.id)
        XCTAssertNotNil(thumb)
    }

    func testLoadThumbnailReturnsNilForMissingId() {
        let thumb = sut.loadThumbnail(id: UUID())
        XCTAssertNil(thumb)
    }

    // MARK: - Load Image

    func testLoadImageReturnsStoredImage() {
        let image = TestUtilities.generateTestImage()
        let record = sut.savePhoto(image, compressionQuality: 0.8)
        let loaded = sut.loadImage(id: record.id)
        XCTAssertNotNil(loaded)
    }

    func testLoadImageReturnsNilAfterDelete() {
        let image = TestUtilities.generateTestImage()
        let record = sut.savePhoto(image, compressionQuality: 0.8)
        sut.deletePhoto(id: record.id)
        XCTAssertNil(sut.loadImage(id: record.id))
    }
}
