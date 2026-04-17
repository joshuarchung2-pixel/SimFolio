// PortfolioRequirementTests.swift
// SimFolioTests/Models — Unit tests for PortfolioRequirement model

import XCTest
@testable import SimFolio

final class PortfolioRequirementTests: XCTestCase {

    // MARK: - totalRequired (default counts)

    func testTotalRequired_defaultCounts() {
        // 1 stage × 2 angles × 1 each = 2
        let req = TestData.createRequirement(
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: [:]
        )
        XCTAssertEqual(req.totalRequired, 2)
    }

    func testTotalRequired_twoStagesDefaultCounts() {
        // 2 stages × 2 angles × 1 each = 4
        let req = TestData.createRequirement(
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: [:]
        )
        XCTAssertEqual(req.totalRequired, 4)
    }

    // MARK: - totalRequired (custom angleCounts)

    func testTotalRequired_customAngleCounts() {
        // 2 stages × (2 for Occlusal/Incisal + 1 for Buccal/Facial) = 2 × 3 = 6
        let req = TestData.createRequirement(
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: ["Occlusal/Incisal": 2, "Buccal/Facial": 1]
        )
        XCTAssertEqual(req.totalRequired, 6)
    }

    func testTotalRequired_singleStageCustomCounts() {
        // 1 stage × (3 + 2) = 5
        let req = TestData.createRequirement(
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"],
            angleCounts: ["Occlusal/Incisal": 3, "Buccal/Facial": 2]
        )
        XCTAssertEqual(req.totalRequired, 5)
    }

    // MARK: - Hashable (id-based)

    func testHashable_sameIdCountsOnce() {
        let req1 = TestData.createRequirement(id: "same-id")
        let req2 = PortfolioRequirement(
            id: "same-id",
            procedure: "Different",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"]
        )
        var set = Set<PortfolioRequirement>()
        set.insert(req1)
        set.insert(req2)
        XCTAssertEqual(set.count, 1)
    }

    func testHashable_differentIdsAreSeparate() {
        let req1 = TestData.createRequirement()
        let req2 = TestData.createRequirement()
        var set = Set<PortfolioRequirement>()
        set.insert(req1)
        set.insert(req2)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Encoding / Decoding

    func testEncoding() throws {
        let req = TestData.createRequirement(
            procedure: "Crown",
            stages: ["Preparation"],
            angles: ["Buccal/Facial"]
        )

        let encoded = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(PortfolioRequirement.self, from: encoded)

        XCTAssertEqual(decoded.id, req.id)
        XCTAssertEqual(decoded.procedure, req.procedure)
        XCTAssertEqual(decoded.stages, req.stages)
        XCTAssertEqual(decoded.angles, req.angles)
        XCTAssertEqual(decoded.angleCounts, req.angleCounts)
    }

    // MARK: - displayString

    func testDisplayString_bothStages() {
        let req = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation", "Restoration"],
            angles: ["Occlusal/Incisal"]
        )
        XCTAssertTrue(req.displayString.contains("Class 1"))
        XCTAssertTrue(req.displayString.contains("Both Stages"))
        XCTAssertTrue(req.displayString.contains("Occlusal/Incisal"))
    }

    func testDisplayString_singleStage() {
        let req = TestData.createRequirement(
            procedure: "Crown",
            stages: ["Restoration"],
            angles: ["Buccal/Facial", "Lingual"]
        )
        XCTAssertTrue(req.displayString.contains("Crown"))
        XCTAssertTrue(req.displayString.contains("Restoration"))
        XCTAssertFalse(req.displayString.contains("Both Stages"))
    }

    func testDisplayString_allAnglesWhenSevenAngles() {
        let req = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal", "Buccal/Facial", "Lingual", "Mesial", "Distal", "Proximal", "Facial"]
        )
        // 7 angles => "All Angles"
        XCTAssertTrue(req.displayString.contains("All Angles"))
    }

    // MARK: - Identifiable

    func testIdentifiable_uniqueIds() {
        let req1 = TestData.createRequirement()
        let req2 = TestData.createRequirement()
        XCTAssertNotEqual(req1.id, req2.id)
    }

    // MARK: - Default angle counts fill-in

    func testDefaultAngleCountFillIn() {
        let req = PortfolioRequirement(
            procedure: "Class 1",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal", "Buccal/Facial"]
        )
        // Both angles should default to 1
        XCTAssertEqual(req.angleCounts["Occlusal/Incisal"], 1)
        XCTAssertEqual(req.angleCounts["Buccal/Facial"], 1)
    }
}
