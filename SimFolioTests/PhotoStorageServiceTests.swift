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

    // Mirrors the real save→display path that PhotoDetailView and the grid use.
    func testLoadEditedImageAppliesPersistedBrightness() {
        let persistence = PhotoEditPersistenceService.shared
        let image = TestUtilities.generateTestImage()
        let record = service.savePhoto(image)
        defer {
            persistence.deleteEditState(for: record.id.uuidString)
            service.deletePhoto(id: record.id)
        }

        var state = EditState(assetId: record.id.uuidString)
        state.adjustments.brightness = -0.4
        persistence.saveEditState(state, for: record.id.uuidString)

        XCTAssertTrue(persistence.hasEditState(for: record.id.uuidString))

        guard let rawLoaded = service.loadImage(id: record.id) else {
            return XCTFail("loadImage returned nil")
        }
        guard let edited = service.loadEditedImage(id: record.id) else {
            return XCTFail("loadEditedImage returned nil")
        }

        let rawRed = centerRedSample(of: rawLoaded)
        let editedRed = centerRedSample(of: edited)
        XCTAssertLessThan(
            editedRed,
            rawRed - 20,
            "Edited full image center should be darker than raw. raw=\(rawRed) edited=\(editedRed)"
        )

        guard let rawThumb = service.loadThumbnail(id: record.id) else {
            return XCTFail("loadThumbnail returned nil")
        }
        guard let editedThumb = service.loadEditedThumbnail(id: record.id) else {
            return XCTFail("loadEditedThumbnail returned nil")
        }

        let rawThumbRed = centerRedSample(of: rawThumb)
        let editedThumbRed = centerRedSample(of: editedThumb)
        XCTAssertLessThan(
            editedThumbRed,
            rawThumbRed - 20,
            "Edited thumbnail center should be darker than raw. raw=\(rawThumbRed) edited=\(editedThumbRed)"
        )
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func centerRedSample(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return -1 }
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (height / 2) * width * 4 + (width / 2) * 4
        return Int(buffer[offset])
    }
}
