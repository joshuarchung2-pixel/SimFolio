// MetadataManagerTests.swift
// SimFolioTests - MetadataManager tests using MockMetadataManager

import XCTest
@testable import SimFolio

final class MetadataManagerTests: XCTestCase {

    var sut: MockMetadataManager!

    override func setUp() {
        super.setUp()
        sut = MockMetadataManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Portfolio CRUD

    func testAddPortfolio() {
        let portfolio = TestData.createPortfolio(name: "Fall 2024")
        sut.addPortfolio(portfolio)
        XCTAssertEqual(sut.portfolios.count, 1)
        XCTAssertEqual(sut.portfolios.first?.name, "Fall 2024")
        XCTAssertEqual(sut.addPortfolioCalls.count, 1)
    }

    func testUpdatePortfolio() {
        var portfolio = TestData.createPortfolio(name: "Original")
        sut.addPortfolio(portfolio)

        portfolio = Portfolio(
            id: portfolio.id,
            name: "Updated",
            createdDate: portfolio.createdDate,
            dueDate: portfolio.dueDate,
            requirements: portfolio.requirements,
            notes: portfolio.notes
        )
        sut.updatePortfolio(portfolio)

        XCTAssertEqual(sut.updatePortfolioCalls.count, 1)
        XCTAssertEqual(sut.getPortfolio(by: portfolio.id)?.name, "Updated")
    }

    func testDeletePortfolio() {
        let portfolio = TestData.createPortfolio()
        sut.addPortfolio(portfolio)
        sut.deletePortfolio(portfolio.id)
        XCTAssertTrue(sut.portfolios.isEmpty)
        XCTAssertEqual(sut.deletePortfolioCalls, [portfolio.id])
    }

    func testGetPortfolioById() {
        let portfolio = TestData.createPortfolio()
        sut.addPortfolio(portfolio)
        let retrieved = sut.getPortfolio(by: portfolio.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, portfolio.id)
    }

    func testGetPortfolioByIdReturnsNilForMissing() {
        XCTAssertNil(sut.getPortfolio(by: "non-existent"))
    }

    // MARK: - Metadata CRUD

    func testAssignMetadata() {
        let metadata = TestData.createPhotoMetadata(procedure: "Crown")
        sut.assignMetadata(metadata, to: "asset-1")
        XCTAssertEqual(sut.assignMetadataCalls.count, 1)
        XCTAssertEqual(sut.getMetadata(for: "asset-1")?.procedure, "Crown")
    }

    func testGetMetadataReturnsNilWhenAbsent() {
        XCTAssertNil(sut.getMetadata(for: "missing"))
    }

    func testDeleteMetadata() {
        let metadata = TestData.createPhotoMetadata()
        sut.assignMetadata(metadata, to: "asset-2")
        sut.deleteMetadata(for: "asset-2")
        XCTAssertNil(sut.getMetadata(for: "asset-2"))
        XCTAssertEqual(sut.deleteMetadataCalls, ["asset-2"])
    }

    // MARK: - Ratings

    func testSetRating() {
        let metadata = TestData.createPhotoMetadata(rating: 2)
        sut.assignMetadata(metadata, to: "asset-3")
        sut.setRating(5, for: "asset-3")
        XCTAssertEqual(sut.getRating(for: "asset-3"), 5)
        XCTAssertEqual(sut.setRatingCalls.count, 1)
        XCTAssertEqual(sut.setRatingCalls.first?.rating, 5)
        XCTAssertEqual(sut.setRatingCalls.first?.assetId, "asset-3")
    }

    func testGetRatingReturnsNilWhenAbsent() {
        XCTAssertNil(sut.getRating(for: "no-asset"))
    }

    func testSetRatingToNil() {
        let metadata = TestData.createPhotoMetadata(rating: 4)
        sut.assignMetadata(metadata, to: "asset-4")
        sut.setRating(nil, for: "asset-4")
        XCTAssertNil(sut.getRating(for: "asset-4"))
    }

    // MARK: - Photo Count

    func testPhotoCountForProcedure() {
        sut.assignMetadata(TestData.createPhotoMetadata(procedure: "Class 1"), to: "a1")
        sut.assignMetadata(TestData.createPhotoMetadata(procedure: "Class 1"), to: "a2")
        sut.assignMetadata(TestData.createPhotoMetadata(procedure: "Crown"), to: "a3")
        XCTAssertEqual(sut.photoCount(for: "Class 1"), 2)
        XCTAssertEqual(sut.photoCount(for: "Crown"), 1)
        XCTAssertEqual(sut.photoCount(for: "Veneer"), 0)
    }

    // MARK: - Portfolio Stats

    func testPortfolioStatsWithEmptyRequirements() {
        let portfolio = Portfolio(name: "Empty", requirements: [])
        let stats = sut.getPortfolioStats(portfolio)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.fulfilled, 0)
    }

    func testPortfolioStatsWithRequirements() {
        let req = TestData.createRequirement(
            procedure: "Class 1",
            stages: ["Preparation"],
            angles: ["Occlusal/Incisal"],
            angleCounts: ["Occlusal/Incisal": 3]
        )
        let portfolio = TestData.createPortfolio(requirements: [req])
        let stats = sut.getPortfolioStats(portfolio)
        // Mock always returns fulfilled=0 and total = sum of required counts
        XCTAssertEqual(stats.fulfilled, 0)
        XCTAssertEqual(stats.total, 3)
    }

    func testPortfolioCompletionPercentageEmptyRequirements() {
        let portfolio = Portfolio(name: "Empty", requirements: [])
        let pct = sut.getPortfolioCompletionPercentage(portfolio)
        XCTAssertEqual(pct, 0.0)
    }

    // MARK: - Call Tracking

    func testAddPortfolioCallTracking() {
        let p1 = TestData.createPortfolio(name: "P1")
        let p2 = TestData.createPortfolio(name: "P2")
        sut.addPortfolio(p1)
        sut.addPortfolio(p2)
        XCTAssertEqual(sut.addPortfolioCalls.count, 2)
        XCTAssertEqual(sut.addPortfolioCalls[0].name, "P1")
        XCTAssertEqual(sut.addPortfolioCalls[1].name, "P2")
    }

    func testDeletePortfolioCallTracking() {
        let p = TestData.createPortfolio()
        sut.addPortfolio(p)
        sut.deletePortfolio(p.id)
        XCTAssertEqual(sut.deletePortfolioCalls.count, 1)
        XCTAssertEqual(sut.deletePortfolioCalls.first, p.id)
    }

    func testAssignMetadataCallTracking() {
        let metadata = TestData.createPhotoMetadata()
        sut.assignMetadata(metadata, to: "asset-5")
        sut.assignMetadata(metadata, to: "asset-6")
        XCTAssertEqual(sut.assignMetadataCalls.count, 2)
        XCTAssertEqual(sut.assignMetadataCalls[0].assetId, "asset-5")
        XCTAssertEqual(sut.assignMetadataCalls[1].assetId, "asset-6")
    }
}
