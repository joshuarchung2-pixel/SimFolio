// ProcedureConfigTests.swift
// SimFolioTests/Models — Unit tests for ProcedureConfig model

import XCTest
@testable import SimFolio

final class ProcedureConfigTests: XCTestCase {

    // MARK: - defaultProcedures

    func testDefaultProcedures_notEmpty() {
        XCTAssertFalse(ProcedureConfig.defaultProcedures.isEmpty)
    }

    func testDefaultProcedures_allMarkedAsDefault() {
        XCTAssertTrue(ProcedureConfig.defaultProcedures.allSatisfy { $0.isDefault })
    }

    func testDefaultProcedures_containsExpectedProcedures() {
        let names = ProcedureConfig.defaultProcedures.map { $0.name }
        XCTAssertTrue(names.contains("Class 1"))
        XCTAssertTrue(names.contains("Crown"))
        XCTAssertTrue(names.contains("Root Canal"))
        XCTAssertTrue(names.contains("Extraction"))
    }

    func testDefaultProcedures_sortOrderMatchesIndex() {
        for (index, procedure) in ProcedureConfig.defaultProcedures.enumerated() {
            XCTAssertEqual(procedure.sortOrder, index, "\(procedure.name) has unexpected sortOrder")
        }
    }

    func testDefaultProcedures_count() {
        // 12 default procedures per source file
        XCTAssertEqual(ProcedureConfig.defaultProcedures.count, 12)
    }

    // MARK: - Encoding / Decoding

    func testEncoding() throws {
        let procedure = TestData.createProcedureConfig(
            name: "Test Procedure",
            colorHex: "#FF0000",
            isDefault: false
        )

        let encoded = try JSONEncoder().encode(procedure)
        let decoded = try JSONDecoder().decode(ProcedureConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, procedure.id)
        XCTAssertEqual(decoded.name, procedure.name)
        XCTAssertEqual(decoded.colorHex, procedure.colorHex)
        XCTAssertEqual(decoded.isDefault, procedure.isDefault)
        XCTAssertEqual(decoded.isEnabled, procedure.isEnabled)
        XCTAssertEqual(decoded.sortOrder, procedure.sortOrder)
    }

    func testEncoding_preservesEnabledState() throws {
        let procedure = ProcedureConfig(name: "Disabled", colorHex: "#000000", isEnabled: false)

        let encoded = try JSONEncoder().encode(procedure)
        let decoded = try JSONDecoder().decode(ProcedureConfig.self, from: encoded)

        XCTAssertFalse(decoded.isEnabled)
    }

    // MARK: - Equality (value-based via Equatable)

    func testEquality_sameValues() {
        let proc1 = TestData.createProcedureConfig(id: "test-id", name: "Test")
        let proc2 = TestData.createProcedureConfig(id: "test-id", name: "Test")
        XCTAssertEqual(proc1, proc2)
    }

    func testEquality_differentId() {
        let proc1 = TestData.createProcedureConfig(id: "id-1", name: "Test")
        let proc2 = TestData.createProcedureConfig(id: "id-2", name: "Test")
        XCTAssertNotEqual(proc1, proc2)
    }

    func testEquality_differentName() {
        let proc1 = TestData.createProcedureConfig(id: "id-1", name: "Alpha")
        let proc2 = TestData.createProcedureConfig(id: "id-1", name: "Beta")
        XCTAssertNotEqual(proc1, proc2)
    }

    // MARK: - Custom procedures

    func testCustomProcedure_isNotDefault() {
        let custom = TestData.createCustomProcedure(name: "My Procedure")
        XCTAssertFalse(custom.isDefault)
    }

    func testCustomProcedure_isEnabled() {
        let custom = TestData.createCustomProcedure()
        XCTAssertTrue(custom.isEnabled)
    }
}
