// PhotoStorageServiceTests.swift

import XCTest
@testable import SimFolio

final class PhotoStorageServiceTests: XCTestCase {
    var service: PhotoStorageService!

    override func setUp() {
        super.setUp()
        service = PhotoStorageService.shared
        // Clean up any test data
        for record in service.records {
            service.deletePhoto(id: record.id)
        }
    }

    func testSavePhotoCreatesRecord() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        XCTAssertNotNil(record)
        XCTAssertTrue(service.records.contains(where: { $0.id == record.id }))
        XCTAssertTrue(record.fileSize > 0)
    }

    func testLoadImageReturnsImage() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        let loaded = service.loadImage(id: record.id)
        XCTAssertNotNil(loaded)
    }

    func testLoadThumbnailReturnsImage() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        let thumbnail = service.loadThumbnail(id: record.id)
        XCTAssertNotNil(thumbnail)
    }

    func testDeletePhotoRemovesFiles() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        service.deletePhoto(id: record.id)

        XCTAssertNil(service.loadImage(id: record.id))
        XCTAssertNil(service.loadThumbnail(id: record.id))
        XCTAssertFalse(service.records.contains(where: { $0.id == record.id }))
    }

    func testRecordsPersistAcrossLoads() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        // Force reload from UserDefaults
        service.reloadRecords()

        XCTAssertTrue(service.records.contains(where: { $0.id == record.id }))
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }
}
