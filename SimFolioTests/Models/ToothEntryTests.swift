// ToothEntryTests.swift
// SimFolioTests/Models — Unit tests for ToothEntry model

import XCTest
@testable import SimFolio

final class ToothEntryTests: XCTestCase {

    // MARK: - Creation

    func testCreation_storesProperties() {
        let entry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestData.referenceDate
        )
        XCTAssertEqual(entry.procedure, "Class 1")
        XCTAssertEqual(entry.toothNumber, 14)
        XCTAssertEqual(entry.date, TestData.referenceDate)
    }

    // MARK: - Identifiable (id is computed: procedure-toothNumber-dateString)

    func testIdentifiable_idComputedFromComponents() {
        let entry = TestData.createToothEntry(
            procedure: "Crown",
            toothNumber: 30,
            date: TestData.referenceDate
        )
        XCTAssertTrue(entry.id.contains("Crown"))
        XCTAssertTrue(entry.id.contains("30"))
        // The date portion comes from dateString (short style) — just ensure id is non-empty
        XCTAssertFalse(entry.id.isEmpty)
    }

    func testIdentifiable_sameComponentsProduceSameId() {
        let entry1 = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestData.referenceDate
        )
        let entry2 = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestData.referenceDate
        )
        XCTAssertEqual(entry1.id, entry2.id)
    }

    func testIdentifiable_differentToothNumberProducesDifferentId() {
        let entry1 = TestData.createToothEntry(procedure: "Class 1", toothNumber: 14, date: TestData.referenceDate)
        let entry2 = TestData.createToothEntry(procedure: "Class 1", toothNumber: 15, date: TestData.referenceDate)
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testIdentifiable_differentProcedureProducesDifferentId() {
        let entry1 = TestData.createToothEntry(procedure: "Class 1", toothNumber: 14, date: TestData.referenceDate)
        let entry2 = TestData.createToothEntry(procedure: "Crown",   toothNumber: 14, date: TestData.referenceDate)
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    // MARK: - Encoding / Decoding

    func testEncoding() throws {
        let entry = TestData.createToothEntry(
            procedure: "Crown",
            toothNumber: 30,
            date: TestData.referenceDate
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ToothEntry.self, from: encoded)

        XCTAssertEqual(decoded.procedure, entry.procedure)
        XCTAssertEqual(decoded.toothNumber, entry.toothNumber)
        // Dates may differ by sub-second precision; compare at second granularity
        XCTAssertEqual(decoded.dateString, entry.dateString)
    }

    // MARK: - displayString

    func testDisplayString_containsToothNumber() {
        let entry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestData.referenceDate
        )
        XCTAssertTrue(entry.displayString.contains("14"))
        XCTAssertTrue(entry.displayString.hasPrefix("Tooth "))
    }

    func testDisplayString_containsDateString() {
        let entry = TestData.createToothEntry(
            procedure: "Class 1",
            toothNumber: 14,
            date: TestData.referenceDate
        )
        // displayString is "Tooth N - <dateString>", so it contains the dateString
        XCTAssertTrue(entry.displayString.contains(entry.dateString))
    }
}
