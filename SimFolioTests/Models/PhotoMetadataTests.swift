// PhotoMetadataTests.swift
// SimFolioTests/Models — Unit tests for PhotoMetadata model

import XCTest
@testable import SimFolio

final class PhotoMetadataTests: XCTestCase {

    // MARK: - Encoding / Decoding

    func testEncoding() throws {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            toothDate: TestData.referenceDate,
            stage: "Preparation",
            angle: "Occlusal/Incisal",
            rating: 4
        )

        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(PhotoMetadata.self, from: encoded)

        XCTAssertEqual(decoded.procedure, metadata.procedure)
        XCTAssertEqual(decoded.toothNumber, metadata.toothNumber)
        XCTAssertEqual(decoded.stage, metadata.stage)
        XCTAssertEqual(decoded.angle, metadata.angle)
        XCTAssertEqual(decoded.rating, metadata.rating)
    }

    // MARK: - Equatable

    func testEquality() {
        let metadata1 = TestData.createPhotoMetadata(procedure: "Class 1", rating: 4)
        let metadata2 = TestData.createPhotoMetadata(procedure: "Class 1", rating: 4)
        let metadata3 = TestData.createPhotoMetadata(procedure: "Class 2", rating: 4)

        XCTAssertEqual(metadata1, metadata2)
        XCTAssertNotEqual(metadata1, metadata3)
    }

    // MARK: - isComplete

    func testIsComplete_whenAllFieldsPresent() {
        let metadata = TestData.createCompleteMetadata()
        XCTAssertTrue(metadata.isComplete)
    }

    func testIsComplete_whenEmpty() {
        let metadata = TestData.createEmptyMetadata()
        XCTAssertFalse(metadata.isComplete)
    }

    func testIsComplete_whenToothNumberMissing() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: nil,
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )
        XCTAssertFalse(metadata.isComplete)
    }

    func testIsComplete_whenToothDateMissing() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            toothDate: nil,
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )
        XCTAssertFalse(metadata.isComplete)
    }

    func testIsComplete_whenStageMissing() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            toothDate: TestData.referenceDate,
            stage: nil,
            angle: "Occlusal/Incisal"
        )
        XCTAssertFalse(metadata.isComplete)
    }

    // MARK: - summaryText

    func testSummaryText_allFields() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            stage: "Preparation",
            angle: "Occlusal/Incisal"
        )
        let summary = metadata.summaryText
        XCTAssertTrue(summary.contains("Class 1"))
        XCTAssertTrue(summary.contains("#14"))
        XCTAssertTrue(summary.contains("Prep"))
        XCTAssertTrue(summary.contains("Occlusal/Incisal"))
    }

    func testSummaryText_empty() {
        let metadata = TestData.createEmptyMetadata()
        XCTAssertEqual(metadata.summaryText, "Choose procedure")
    }

    func testSummaryText_restorationAbbreviatesAsResto() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Crown",
            toothNumber: 30,
            stage: "Restoration",
            angle: "Buccal/Facial"
        )
        XCTAssertTrue(metadata.summaryText.contains("Resto"))
    }

    func testSummaryText_procedureOnly() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 2",
            toothNumber: nil,
            stage: nil,
            angle: nil
        )
        XCTAssertEqual(metadata.summaryText, "Class 2")
    }

    // MARK: - toothEntry

    func testToothEntry_whenAllFieldsPresent() {
        let metadata = TestData.createPhotoMetadata(
            procedure: "Class 1",
            toothNumber: 14,
            toothDate: TestData.referenceDate
        )
        XCTAssertNotNil(metadata.toothEntry)
        XCTAssertEqual(metadata.toothEntry?.procedure, "Class 1")
        XCTAssertEqual(metadata.toothEntry?.toothNumber, 14)
    }

    func testToothEntry_nilWhenProcedureMissing() {
        let metadata = TestData.createPhotoMetadata(procedure: nil, toothNumber: 14, toothDate: TestData.referenceDate)
        XCTAssertNil(metadata.toothEntry)
    }

    func testToothEntry_nilWhenToothNumberMissing() {
        let metadata = TestData.createPhotoMetadata(procedure: "Class 1", toothNumber: nil, toothDate: TestData.referenceDate)
        XCTAssertNil(metadata.toothEntry)
    }

    func testToothEntry_nilWhenDateMissing() {
        let metadata = TestData.createPhotoMetadata(procedure: "Class 1", toothNumber: 14, toothDate: nil)
        XCTAssertNil(metadata.toothEntry)
    }
}
