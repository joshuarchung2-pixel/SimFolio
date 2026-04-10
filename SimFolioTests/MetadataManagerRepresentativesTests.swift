// MetadataManagerRepresentativesTests.swift
// SimFolioTests - Tests for getProcedureRepresentatives helper

import XCTest
@testable import SimFolio

final class MetadataManagerRepresentativesTests: XCTestCase {

    var sut: MetadataManager!

    override func setUp() {
        super.setUp()
        sut = MetadataManager.shared
        sut.assetMetadata = [:]
        sut.portfolios = []
    }

    override func tearDown() {
        sut.assetMetadata = [:]
        sut.portfolios = []
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makePortfolio(procedures: [String]) -> Portfolio {
        let reqs = procedures.map { proc in
            TestData.createRequirement(procedure: proc)
        }
        return TestData.createPortfolio(requirements: reqs)
    }

    private func makeRecord(id: UUID, daysAgo: Int) -> PhotoRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return PhotoRecord(id: id, createdDate: date, fileSize: 1000)
    }

    private func addMetadata(assetId: String, procedure: String) {
        sut.assetMetadata[assetId] = TestData.createPhotoMetadata(procedure: procedure)
    }

    // MARK: - Tests

    func testZeroMatchingPhotos_returnsEmpty() {
        let portfolio = makePortfolio(procedures: ["Class 1", "Crown"])
        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testOnePhotoPerProcedure_returnsAllOrderedByDateDesc() {
        let portfolio = makePortfolio(procedures: ["Class 1", "Crown", "Veneer"])

        let id1 = UUID()  // Class 1, 3 days ago
        let id2 = UUID()  // Crown, 1 day ago (newest)
        let id3 = UUID()  // Veneer, 5 days ago (oldest)

        addMetadata(assetId: id1.uuidString, procedure: "Class 1")
        addMetadata(assetId: id2.uuidString, procedure: "Crown")
        addMetadata(assetId: id3.uuidString, procedure: "Veneer")

        let records = [
            makeRecord(id: id1, daysAgo: 3),
            makeRecord(id: id2, daysAgo: 1),
            makeRecord(id: id3, daysAgo: 5)
        ]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.procedure), ["Crown", "Class 1", "Veneer"])
    }

    func testMultiplePhotosForSameProcedure_returnsOnlyNewest() {
        let portfolio = makePortfolio(procedures: ["Class 1"])

        let old = UUID()
        let new = UUID()

        addMetadata(assetId: old.uuidString, procedure: "Class 1")
        addMetadata(assetId: new.uuidString, procedure: "Class 1")

        let records = [
            makeRecord(id: old, daysAgo: 10),
            makeRecord(id: new, daysAgo: 1)
        ]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.assetId, new.uuidString)
    }

    func testSixProceduresWithPhotos_returnsAllSortedByDateDesc() {
        let procedures = ["Class 1", "Class 2", "Class 3", "Crown", "Veneer", "Bridge"]
        let portfolio = makePortfolio(procedures: procedures)

        var records: [PhotoRecord] = []
        for (index, proc) in procedures.enumerated() {
            let id = UUID()
            addMetadata(assetId: id.uuidString, procedure: proc)
            // index 0 is newest (1 day ago), index 5 is oldest (6 days ago)
            records.append(makeRecord(id: id, daysAgo: index + 1))
        }

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result.map(\.procedure), procedures)
    }

    func testMetadataWithoutMatchingRecord_isExcluded() {
        let portfolio = makePortfolio(procedures: ["Class 1", "Crown"])

        let orphanId = UUID()  // metadata exists but no PhotoRecord
        let realId = UUID()

        addMetadata(assetId: orphanId.uuidString, procedure: "Class 1")
        addMetadata(assetId: realId.uuidString, procedure: "Crown")

        let records = [makeRecord(id: realId, daysAgo: 1)]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.procedure, "Crown")
    }

    func testRequiredProcedureWithoutPhotos_isExcluded() {
        // Portfolio has 3 required procedures, but only 1 has photos
        let portfolio = makePortfolio(procedures: ["Class 1", "Crown", "Veneer"])

        let id = UUID()
        addMetadata(assetId: id.uuidString, procedure: "Class 1")

        let records = [makeRecord(id: id, daysAgo: 1)]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.procedure, "Class 1")
    }

    func testPhotoForNonRequiredProcedure_isExcluded() {
        let portfolio = makePortfolio(procedures: ["Class 1"])

        let id1 = UUID()
        let id2 = UUID()

        addMetadata(assetId: id1.uuidString, procedure: "Class 1")
        addMetadata(assetId: id2.uuidString, procedure: "Crown")  // not in requirements

        let records = [
            makeRecord(id: id1, daysAgo: 2),
            makeRecord(id: id2, daysAgo: 1)
        ]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.procedure, "Class 1")
    }

    func testEmptyRequirements_returnsEmptyAndExitsEarly() {
        // Portfolio with zero requirements — exercises the guard early-exit
        // branch. TestData.createPortfolio injects a default requirement when
        // passed an empty array, so we construct Portfolio directly.
        let portfolio = Portfolio(
            id: UUID().uuidString,
            name: "Empty",
            createdDate: Date(),
            dueDate: nil,
            requirements: [],
            notes: nil
        )

        // Even with matching metadata and records in the store, an empty
        // requirements list should return [] without scanning anything.
        let id = UUID()
        addMetadata(assetId: id.uuidString, procedure: "Class 1")
        let records = [makeRecord(id: id, daysAgo: 1)]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertTrue(result.isEmpty)
    }

    func testSameDateTie_lexicographicallySmallerAssetIdWins() {
        let portfolio = makePortfolio(procedures: ["Class 1"])

        // Force identical dates and ordered UUIDs
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sameDate = Date()

        addMetadata(assetId: idA.uuidString, procedure: "Class 1")
        addMetadata(assetId: idB.uuidString, procedure: "Class 1")

        let records = [
            PhotoRecord(id: idA, createdDate: sameDate, fileSize: 1000),
            PhotoRecord(id: idB, createdDate: sameDate, fileSize: 1000)
        ]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.assetId, idA.uuidString)
    }

    func testSameDateBetweenProcedures_lexicographicallySmallerAssetIdWins() {
        let portfolio = makePortfolio(procedures: ["Class 1", "Crown"])

        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sameDate = Date()

        addMetadata(assetId: idA.uuidString, procedure: "Crown")
        addMetadata(assetId: idB.uuidString, procedure: "Class 1")

        let records = [
            PhotoRecord(id: idA, createdDate: sameDate, fileSize: 1000),
            PhotoRecord(id: idB, createdDate: sameDate, fileSize: 1000)
        ]

        let result = sut.getProcedureRepresentatives(for: portfolio, photoRecords: records)

        XCTAssertEqual(result.count, 2)
        // Same date → lexicographically smaller assetId wins the overall ordering
        XCTAssertEqual(result.first?.assetId, idA.uuidString)
    }
}
