// BulkTagSheetLogicTests.swift
// SimFolio - Tests for BulkTagEdits.apply(to:) — per-field touched semantics.

import XCTest
@testable import SimFolio

final class BulkTagSheetLogicTests: XCTestCase {

    func testApply_withNoChanges_leavesMetadataAlone() {
        let edits = BulkTagEdits()
        var existing = PhotoMetadata()
        existing.procedure = "Class 1"
        existing.stage = "Preparation"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 1")
        XCTAssertEqual(updated.stage, "Preparation")
    }

    func testApply_setsProcedure_whenTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        let existing = PhotoMetadata()

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 2")
    }

    func testApply_overwritesExistingProcedure_whenTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        var existing = PhotoMetadata()
        existing.procedure = "Class 1"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 2")
    }

    func testApply_preservesStage_whenOnlyProcedureTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        var existing = PhotoMetadata()
        existing.stage = "Preparation"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.stage, "Preparation")
    }

    func testApply_setsToothNumberAndDate_whenToothTouched() {
        var edits = BulkTagEdits()
        edits.toothNumber = .set(14)
        edits.toothDateWhenTouched = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = PhotoMetadata()

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.toothNumber, 14)
        XCTAssertEqual(updated.toothDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testFieldsChanged_reflectsOnlyTouchedFields() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 1")
        edits.angle = .set("Buccal/Facial")

        XCTAssertEqual(Set(edits.fieldsChanged), Set(["procedure", "angle"]))
    }

    func testHasAnyChange_falseByDefault() {
        XCTAssertFalse(BulkTagEdits().hasAnyChange)
    }

    func testHasAnyChange_trueWhenAnyFieldTouched() {
        var edits = BulkTagEdits()
        edits.stage = .set("Restoration")
        XCTAssertTrue(edits.hasAnyChange)
    }
}
