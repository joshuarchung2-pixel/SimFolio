# Portfolio Card Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich `PortfolioRowCard` on the home screen with a merged caption row (`Due · photos · procedures`) and a thumbnail strip showing one representative photo per distinct procedure (max 4 + overflow pill).

**Architecture:** Add one pure helper on `MetadataManager` that computes representative photos by walking `assetMetadata` against a passed-in `[PhotoRecord]`. Add one pure caption formatter as a file-level function in `HomeView.swift`. Add two private SwiftUI subviews (`ProcedureThumbView`, `PortfolioThumbStrip`). Rewrite `PortfolioRowCard.body` to compose title row + caption row + optional thumb strip + progress bar. All heavy state already reactive via existing `@ObservedObject`s.

**Tech Stack:** Swift, SwiftUI, XCTest, `xcodebuild`

**Spec:** `docs/superpowers/specs/2026-04-10-portfolio-card-enrichment-design.md`

---

## File Structure

**Modify:**
- `SimFolio/Services/MetadataManager.swift` — add `ProcedureRepresentative` typealias and `getProcedureRepresentatives(for:photoRecords:)` method
- `SimFolio/Features/Home/HomeView.swift` — add `portfolioCardCaptionSegments` file-level function, add `ProcedureThumbView` and `PortfolioThumbStrip` private structs, rewrite `PortfolioRowCard.body`

**Create:**
- `SimFolioTests/MetadataManagerRepresentativesTests.swift` — unit tests for the new helper
- `SimFolioTests/PortfolioCardCaptionTests.swift` — unit tests for the pure caption formatter

Each file has one clear responsibility. `PortfolioThumbStrip` and `ProcedureThumbView` stay private to `HomeView.swift` (following the precedent of `RecentThumbnailView` at HomeView.swift:257).

---

## Task 1: Add `getProcedureRepresentatives` helper to `MetadataManager` (TDD)

**Files:**
- Create: `SimFolioTests/MetadataManagerRepresentativesTests.swift`
- Modify: `SimFolio/Services/MetadataManager.swift` (add after existing `getPortfolioStats` at line 335)

- [ ] **Step 1: Write the failing tests**

Create `SimFolioTests/MetadataManagerRepresentativesTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/MetadataManagerRepresentativesTests 2>&1 | tail -30
```

Expected: FAIL — compile error `value of type 'MetadataManager' has no member 'getProcedureRepresentatives'`

- [ ] **Step 3: Add the typealias and helper to `MetadataManager`**

In `SimFolio/Services/MetadataManager.swift`, find the existing `typealias PortfolioStats` around line 330. Just below it, add:

```swift
    typealias ProcedureRepresentative = (assetId: String, procedure: String)
```

Then, after the existing `getPortfolioStats(_:)` method ends (around line 358), insert:

```swift
    /// One representative photo per distinct procedure in the portfolio's requirements.
    /// Returns all procedures that have at least one matching photo, ordered newest first.
    /// Matching is procedure-only (stage/angle are ignored by design).
    /// - Parameters:
    ///   - portfolio: The portfolio whose required procedures define the search set.
    ///   - photoRecords: The photo records whose createdDate is used for ordering.
    ///     Pass `PhotoStorageService.shared.records` from view code.
    /// - Returns: One `(assetId, procedure)` per procedure that has photos.
    func getProcedureRepresentatives(
        for portfolio: Portfolio,
        photoRecords: [PhotoRecord]
    ) -> [ProcedureRepresentative] {
        let requiredProcedures = Set(portfolio.requirements.map(\.procedure))
        guard !requiredProcedures.isEmpty else { return [] }

        var photoDates: [String: Date] = [:]
        for record in photoRecords {
            photoDates[record.id.uuidString] = record.createdDate
        }

        // Group matching metadata entries by procedure, keeping the newest per procedure.
        // Tie-break: lexicographically smaller assetId wins.
        var bestPerProcedure: [String: (assetId: String, date: Date)] = [:]
        for (assetId, metadata) in assetMetadata {
            guard let procedure = metadata.procedure,
                  requiredProcedures.contains(procedure),
                  let date = photoDates[assetId]
            else { continue }

            if let current = bestPerProcedure[procedure] {
                if date > current.date {
                    bestPerProcedure[procedure] = (assetId, date)
                } else if date == current.date && assetId < current.assetId {
                    bestPerProcedure[procedure] = (assetId, date)
                }
            } else {
                bestPerProcedure[procedure] = (assetId, date)
            }
        }

        // Sort winners by date desc, tie-break on assetId asc.
        let sorted = bestPerProcedure
            .map { (procedure: $0.key, assetId: $0.value.assetId, date: $0.value.date) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.assetId < rhs.assetId
            }

        return sorted.map { ProcedureRepresentative(assetId: $0.assetId, procedure: $0.procedure) }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/MetadataManagerRepresentativesTests 2>&1 | tail -30
```

Expected: PASS — all 9 tests green.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Services/MetadataManager.swift SimFolioTests/MetadataManagerRepresentativesTests.swift
git commit -m "$(cat <<'EOF'
feat: add getProcedureRepresentatives helper to MetadataManager

Returns one representative photo per distinct procedure in a
portfolio's requirements, ordered newest first. Pure function —
takes photo records as a parameter to stay decoupled from
PhotoStorageService's actor isolation.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add pure caption formatter (TDD)

**Files:**
- Create: `SimFolioTests/PortfolioCardCaptionTests.swift`
- Modify: `SimFolio/Features/Home/HomeView.swift` (add file-level function near the bottom, before the Preview Provider)

- [ ] **Step 1: Write the failing tests**

Create `SimFolioTests/PortfolioCardCaptionTests.swift`:

```swift
// PortfolioCardCaptionTests.swift
// SimFolioTests - Tests for portfolioCardCaptionSegments pure formatter

import XCTest
@testable import SimFolio

final class PortfolioCardCaptionTests: XCTestCase {

    private let sampleDueDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 4, day: 24)
    )!

    func testAllSegmentsPresent() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 12,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments.count, 3)
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertEqual(segments[1], "12/30 photos")
        XCTAssertEqual(segments[2], "5 procedures")
    }

    func testNoDueDate_dropsFirstSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: nil,
            photoCount: 12,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments, ["12/30 photos", "5 procedures"])
    }

    func testSingleProcedure_usesSingularLabel() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 3,
            totalPhotos: 10,
            distinctProcedureCount: 1
        )
        XCTAssertEqual(segments.last, "1 procedure")
    }

    func testZeroProcedures_dropsProcedureSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 0,
            totalPhotos: 0,
            distinctProcedureCount: 0
        )
        // Nothing to show for photos or procedures → caller expected to hide the row
        XCTAssertTrue(segments.isEmpty)
    }

    func testZeroRequirementsWithDueDate_stillHidesRow() {
        // Consistent with spec: caption row hides entirely when there's nothing useful to show
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 0,
            totalPhotos: 0,
            distinctProcedureCount: 0
        )
        XCTAssertTrue(segments.isEmpty)
    }

    func testZeroPhotosWithRequirements_keepsPhotosSegment() {
        let segments = portfolioCardCaptionSegments(
            dueDate: nil,
            photoCount: 0,
            totalPhotos: 30,
            distinctProcedureCount: 5
        )
        XCTAssertEqual(segments, ["0/30 photos", "5 procedures"])
    }

    func testDueDateFormatIsMediumish() {
        // We don't assert the exact locale-dependent formatting here,
        // only that it starts with "Due " and contains a month indicator.
        let segments = portfolioCardCaptionSegments(
            dueDate: sampleDueDate,
            photoCount: 1,
            totalPhotos: 1,
            distinctProcedureCount: 1
        )
        XCTAssertTrue(segments[0].hasPrefix("Due "))
        XCTAssertTrue(segments[0].count > "Due ".count)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/PortfolioCardCaptionTests 2>&1 | tail -30
```

Expected: FAIL — compile error `cannot find 'portfolioCardCaptionSegments' in scope`.

- [ ] **Step 3: Add the formatter to `HomeView.swift`**

Open `SimFolio/Features/Home/HomeView.swift`. Find the `// MARK: - Preview Provider` section near the bottom (around line 336). Just above it, add a new MARK section and the function:

```swift
// MARK: - Portfolio Card Caption

/// Pure formatter for the portfolio card's caption row.
/// Returns segment strings to join with " · ". Returns empty array if the row
/// would be empty (caller should hide the row entirely).
func portfolioCardCaptionSegments(
    dueDate: Date?,
    photoCount: Int,
    totalPhotos: Int,
    distinctProcedureCount: Int
) -> [String] {
    var segments: [String] = []

    if let dueDate = dueDate {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        segments.append("Due \(formatter.string(from: dueDate))")
    }

    if totalPhotos > 0 {
        segments.append("\(photoCount)/\(totalPhotos) photos")
    }

    if distinctProcedureCount > 0 {
        let noun = distinctProcedureCount == 1 ? "procedure" : "procedures"
        segments.append("\(distinctProcedureCount) \(noun)")
    }

    // Hide row if only the due date is left — due date already gives context,
    // but without any photo/procedure info the row would just repeat what's implicit.
    // Spec: hide when totalPhotos == 0 AND distinctProcedureCount == 0.
    if totalPhotos == 0 && distinctProcedureCount == 0 {
        return []
    }

    return segments
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/PortfolioCardCaptionTests 2>&1 | tail -30
```

Expected: PASS — all 7 tests green.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift SimFolioTests/PortfolioCardCaptionTests.swift
git commit -m "$(cat <<'EOF'
feat: add portfolioCardCaptionSegments pure formatter

Builds the dot-separated caption ("Due Apr 24 · 12/30 photos ·
5 procedures") with graceful degradation for missing due date,
singular/plural handling, and a hide signal (empty array) when
the row would carry no useful info.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `ProcedureThumbView` subview

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift` (add private struct near `RecentThumbnailView` at line 257)

No unit tests for this task — it is view code. A compile + manual visual check is the verification.

- [ ] **Step 1: Add the `ProcedureThumbView` private struct**

In `SimFolio/Features/Home/HomeView.swift`, after the existing `RecentThumbnailView` struct (ends around line 282), insert:

```swift
// MARK: - Procedure Thumb View

/// 44pt square thumbnail used inside PortfolioThumbStrip.
/// Loads the thumbnail on appear and renders a procedure-colored border.
/// On load failure, falls back to a solid procedure-color square.
private struct ProcedureThumbView: View {
    let assetId: String
    let procedure: String
    @State private var image: UIImage?
    @State private var didAttemptLoad: Bool = false

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if didAttemptLoad {
                // Load failed — fall back to solid procedure color
                AppTheme.procedureBackgroundColor(for: procedure)
            } else {
                AppTheme.Colors.surface
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.procedureBorderColor(for: procedure), lineWidth: 2)
        )
        .onAppear {
            guard !didAttemptLoad else { return }
            didAttemptLoad = true
            if let uuid = UUID(uuidString: assetId) {
                image = PhotoStorageService.shared.loadThumbnail(id: uuid)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. No warnings about unused declarations (acceptable if the struct is unused at this point — it will be consumed in Task 4).

If Xcode complains about the private struct being unused, that is informational only and does not fail the build.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
feat: add ProcedureThumbView subview for portfolio card

44pt square thumbnail with procedure-colored border; falls back
to a solid procedure-color square if the thumbnail fails to load.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add `PortfolioThumbStrip` subview

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift` (add private struct right after `ProcedureThumbView`)

No unit tests for this task — it is view composition. Compile verification only.

- [ ] **Step 1: Add the `PortfolioThumbStrip` private struct**

In `SimFolio/Features/Home/HomeView.swift`, immediately after the `ProcedureThumbView` struct added in Task 3, insert:

```swift
// MARK: - Portfolio Thumb Strip

/// Horizontal strip of up to 4 ProcedureThumbView + optional "+N" overflow pill.
/// Caller is responsible for slicing `visibleRepresentatives` to at most 4 entries.
private struct PortfolioThumbStrip: View {
    let visibleRepresentatives: [MetadataManager.ProcedureRepresentative]
    let overflowCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visibleRepresentatives, id: \.assetId) { rep in
                ProcedureThumbView(assetId: rep.assetId, procedure: rep.procedure)
            }
            if overflowCount > 0 {
                overflowPill
            }
        }
    }

    private var overflowPill: some View {
        Text("+\(overflowCount)")
            .font(AppTheme.Typography.caption.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
feat: add PortfolioThumbStrip subview with overflow pill

HStack of up to 4 ProcedureThumbViews plus an optional "+N"
capsule pill when the portfolio spans more distinct procedures
than fit in the strip.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Wire the new components into `PortfolioRowCard`

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift` (rewrite `PortfolioRowCard` at lines 287-332)

This task rewrites the card body. No new unit tests — the pure pieces are already covered.

- [ ] **Step 1: Replace `PortfolioRowCard` with the enriched version**

In `SimFolio/Features/Home/HomeView.swift`, find the existing `PortfolioRowCard` struct (starts at line 287 with `/// Card row for a single portfolio...`). Replace the entire struct definition (from the `///` doc comment through the closing `}` of the struct) with:

```swift
// MARK: - Portfolio Row Card

/// Card row for a single portfolio with name, merged caption, thumbnail strip, and progress bar.
struct PortfolioRowCard: View {
    let portfolio: Portfolio
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var photoStorage = PhotoStorageService.shared

    // MARK: - Derived

    private var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    private var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    private var completionPercentage: Int {
        Int(progress * 100)
    }

    private var distinctProcedureCount: Int {
        Set(portfolio.requirements.map(\.procedure)).count
    }

    private var allRepresentatives: [MetadataManager.ProcedureRepresentative] {
        metadataManager.getProcedureRepresentatives(
            for: portfolio,
            photoRecords: photoStorage.records
        )
    }

    private var visibleRepresentatives: [MetadataManager.ProcedureRepresentative] {
        Array(allRepresentatives.prefix(4))
    }

    private var overflowCount: Int {
        max(0, allRepresentatives.count - 4)
    }

    private var captionSegments: [String] {
        portfolioCardCaptionSegments(
            dueDate: portfolio.dueDate,
            photoCount: stats.fulfilled,
            totalPhotos: stats.total,
            distinctProcedureCount: distinctProcedureCount
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Title row
            HStack {
                Text(portfolio.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(completionPercentage)%")
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Caption row (hidden if no segments)
            if !captionSegments.isEmpty {
                captionRow
            }

            // Thumbnail strip (hidden if no representatives)
            if !visibleRepresentatives.isEmpty {
                PortfolioThumbStrip(
                    visibleRepresentatives: visibleRepresentatives,
                    overflowCount: overflowCount
                )
            }

            // Progress bar
            DPProgressBar(progress: progress)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
    }

    private var captionRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(captionSegments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text("·")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                Text(segment)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Run the full unit test suite**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40
```

Expected: all tests pass, including the pre-existing `MetadataManagerTests` (we did not change any existing API).

- [ ] **Step 4: Manual visual verification in the simulator**

Launch the app in the simulator with sample data:

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
open -a Simulator
xcrun simctl launch booted com.joshuachung.simfolio --with-sample-data
```

Visually verify on the Home tab:
- Portfolio cards now show a caption row (`Due ... · N/M photos · K procedures`)
- Cards with captured photos show a thumbnail strip below the caption, each thumb bordered in its procedure color
- Cards with zero captured photos show no thumb strip (card is short)
- Portfolios with >4 distinct procedures (if any in sample data) show a `+N` capsule pill
- Tapping a card still navigates to the portfolio detail (interaction unchanged)
- Dark mode: toggle simulator appearance and confirm thumb borders and caption remain legible

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
feat: enrich PortfolioRowCard with caption row and thumb strip

Wires portfolioCardCaptionSegments and PortfolioThumbStrip into
the home screen card. Caption shows due date, photo count, and
procedure count; thumb strip shows up to 4 procedure
representatives with an optional +N pill for overflow.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (already done)

**Spec coverage:**
- Layout (title row + caption + thumb strip + progress bar): Task 5
- Merged caption with graceful degradation: Task 2 + Task 5 (wiring)
- Thumb strip 44pt, procedure-colored border: Task 3
- Overflow `+N` pill: Task 4
- `getProcedureRepresentatives` helper with procedure-only matching and tie-break: Task 1
- Hide strip when zero matching photos: Task 5 (`if !visibleRepresentatives.isEmpty`)
- Hide caption when both counts zero: Task 2 (formatter returns `[]`) + Task 5 (wiring)
- Empty `assetMetadata` error case: Task 1 tests `testZeroMatchingPhotos_returnsEmpty`
- Missing `PhotoRecord` for metadata: Task 1 tests `testMetadataWithoutMatchingRecord_isExcluded`
- Load failure fallback (solid procedure color square): Task 3 (`didAttemptLoad` gate)
- Unit tests enumerated in spec §Testing: Task 1 covers all 7 cases

**Placeholder scan:** No TBD/TODO. No generic "handle edge cases" — each edge case is named and tested.

**Type consistency:**
- `ProcedureRepresentative` typealias defined in Task 1, used in Tasks 4 and 5
- `getProcedureRepresentatives(for:photoRecords:)` signature defined in Task 1, called in Task 5
- `portfolioCardCaptionSegments(dueDate:photoCount:totalPhotos:distinctProcedureCount:)` signature defined in Task 2, called in Task 5
- `PortfolioThumbStrip(visibleRepresentatives:overflowCount:)` defined in Task 4, instantiated in Task 5
- `ProcedureThumbView(assetId:procedure:)` defined in Task 3, used in Task 4
- `photoStorage` `@ObservedObject` added to `PortfolioRowCard` in Task 5 — not present in the original card; needed so the card recomputes representatives when new photos are captured
