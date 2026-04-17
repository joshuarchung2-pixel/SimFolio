# Import Tagging (Pure Inbox) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-batch tag set on Photos import with a "Pure Inbox" model: import is tagless by default, a new "Needs Tagging" surface + `BulkTagSheet` in the Library does the tagging, and nudges (toast, home card, tab badge) route users back to the untagged set.

**Architecture:** Photos land as `PhotoMetadata` rows with nil procedure/stage/angle (the existing data path already does this if `baseMetadata` is all-nil). A new `LibraryFilter.showUntaggedOnly` + a persistent chip bar above the grid surface untagged photos. The existing Library selection mode gets a new "Tag" action that opens `BulkTagSheet`, which writes only the fields the user touches. A home-screen card and a tappable import toast deep-link into the inbox. Portfolio-CTA imports keep the existing tag UX as an exception.

**Tech Stack:** Swift, SwiftUI, iOS 16+, XCTest, XCUITest, UserDefaults, NotificationCenter.

**Reference spec:** `docs/superpowers/specs/2026-04-16-import-tagging-design.md`

---

## File Structure

**Modify:**
- `SimFolio/Core/Navigation.swift` — `LibraryFilter.showUntaggedOnly`, `reset()`
- `SimFolio/Services/MetadataManager.swift` — `isIncomplete(assetId:)`, `incompleteAssetCount`
- `SimFolio/Services/PhotoStorageService.swift` — (no changes; read-only lookup to implement `isIncomplete` fully)
- `SimFolio/Services/AnalyticsService.swift` — extend `logPhotoImported`, add 3 new events
- `SimFolio/Features/Import/ImportFlowView.swift` — pass `isPrefilledFromPortfolio` to review view, toast with tap action
- `SimFolio/Features/Import/ImportReviewView.swift` — conditionally hide tag UI
- `SimFolio/Features/Library/LibraryView.swift` — chip bar, Tag action, `BulkTagSheet` presentation, filter branch
- `SimFolio/App/ContentView.swift` — tab badge wiring, toast tap-action support
- `SimFolio/Features/Home/HomeView.swift` — integrate `UntaggedPhotosCard`
- `SimFolio/SimFolioApp.swift` — decrement session-dismissal counter on launch

**Create:**
- `SimFolio/Features/Library/NeedsTaggingChipBar.swift`
- `SimFolio/Features/Library/BulkTagSheet.swift`
- `SimFolio/Features/Home/UntaggedPhotosCard.swift`
- `SimFolioTests/Features/LibraryFilterTests.swift`
- `SimFolioTests/Features/BulkTagSheetLogicTests.swift`
- `SimFolioTests/Services/MetadataManagerIncompleteTests.swift`
- `SimFolioUITests/BulkTagFlowUITests.swift`

---

## Task 1: Add `showUntaggedOnly` to `LibraryFilter`

**Files:**
- Modify: `SimFolio/Core/Navigation.swift` (around lines 178–277, the `LibraryFilter` struct)
- Create: `SimFolioTests/Features/LibraryFilterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `SimFolioTests/Features/LibraryFilterTests.swift`:

```swift
// LibraryFilterTests.swift
// SimFolio - Tests for LibraryFilter, including showUntaggedOnly behavior.

import XCTest
@testable import SimFolio

final class LibraryFilterTests: XCTestCase {

    func test_defaultFilter_hasUntaggedOnlyFalse() {
        let filter = LibraryFilter()
        XCTAssertFalse(filter.showUntaggedOnly)
    }

    func test_isEmpty_ignoresUntaggedOnly() {
        // The chip bar is a separate surface from the filter sheet; the filter icon
        // should not light up just because the inbox chip is active.
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        XCTAssertTrue(filter.isEmpty)
    }

    func test_activeFilterCount_ignoresUntaggedOnly() {
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func test_reset_clearsUntaggedOnly() {
        var filter = LibraryFilter()
        filter.showUntaggedOnly = true
        filter.reset()
        XCTAssertFalse(filter.showUntaggedOnly)
    }

    func test_isEmpty_stillRespectsOtherFields() {
        var filter = LibraryFilter()
        filter.procedures.insert("Class 1")
        XCTAssertFalse(filter.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: compile error — `Value of type 'LibraryFilter' has no member 'showUntaggedOnly'`.

- [ ] **Step 3: Add the field**

In `SimFolio/Core/Navigation.swift`, inside `struct LibraryFilter`, add a stored property alongside the others (after `portfolioId`):

```swift
/// Restrict the grid to photos with nil procedure/stage/angle (the "Needs Tagging" chip).
/// Treated as a separate surface from the filter sheet; isEmpty/activeFilterCount ignore it.
var showUntaggedOnly: Bool = false
```

- [ ] **Step 4: Extend `reset()`**

Replace the body of `mutating func reset()` to include the new field:

```swift
mutating func reset() {
    procedures = []
    stages = []
    angles = []
    minimumRating = nil
    favoritesOnly = false
    dateRange = nil
    portfolioId = nil
    showUntaggedOnly = false
}
```

- [ ] **Step 5: Verify `isEmpty` and `activeFilterCount` are unchanged**

Read lines 244–266 of `Navigation.swift` and confirm neither property references `showUntaggedOnly`. Per the spec the chip bar is a separate surface, so these two computed properties must not change.

- [ ] **Step 6: Run tests and verify pass**

```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/LibraryFilterTests 2>&1 | tail -20
```

Expected: all 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add SimFolio/Core/Navigation.swift SimFolioTests/Features/LibraryFilterTests.swift
git commit -m "feat: add LibraryFilter.showUntaggedOnly for Needs Tagging chip"
```

---

## Task 2: Add `isIncomplete(assetId:)` and `incompleteAssetCount` to `MetadataManager`

The filter needs to treat a `PhotoRecord` that has *no metadata row at all* as incomplete, not just rows with nil fields. The existing `getIncompleteAssetIds()` iterates `assetMetadata` and therefore misses that case.

**Files:**
- Modify: `SimFolio/Services/MetadataManager.swift` (after `getIncompleteAssetIds()` around line 537)
- Create: `SimFolioTests/Services/MetadataManagerIncompleteTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `SimFolioTests/Services/MetadataManagerIncompleteTests.swift`:

```swift
// MetadataManagerIncompleteTests.swift
// SimFolio - Tests for MetadataManager incomplete/untagged helpers.

import XCTest
@testable import SimFolio

final class MetadataManagerIncompleteTests: XCTestCase {

    private var manager: MetadataManager!

    override func setUp() {
        super.setUp()
        manager = MetadataManager.shared
        manager.assetMetadata.removeAll()
    }

    override func tearDown() {
        manager.assetMetadata.removeAll()
        super.tearDown()
    }

    func test_isIncomplete_trueWhenNoMetadataRow() {
        XCTAssertTrue(manager.isIncomplete(assetId: "unknown-id"))
    }

    func test_isIncomplete_trueWhenProcedureNil() {
        var m = PhotoMetadata()
        m.stage = "Preparation"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func test_isIncomplete_trueWhenStageNil() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func test_isIncomplete_trueWhenAngleNil() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.stage = "Preparation"
        manager.assetMetadata["a"] = m
        XCTAssertTrue(manager.isIncomplete(assetId: "a"))
    }

    func test_isIncomplete_falseWhenProcedureStageAngleAllSet() {
        var m = PhotoMetadata()
        m.procedure = "Class 1"
        m.stage = "Preparation"
        m.angle = "Buccal/Facial"
        manager.assetMetadata["a"] = m
        XCTAssertFalse(manager.isIncomplete(assetId: "a"))
    }

    func test_incompleteAssetCount_reflectsStoredPartialRows() {
        var complete = PhotoMetadata()
        complete.procedure = "Class 1"
        complete.stage = "Preparation"
        complete.angle = "Buccal/Facial"
        manager.assetMetadata["complete"] = complete

        var partial = PhotoMetadata()
        partial.procedure = "Class 1"
        manager.assetMetadata["partial"] = partial

        XCTAssertEqual(manager.incompleteAssetCount, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/MetadataManagerIncompleteTests 2>&1 | tail -20
```

Expected: compile errors — `isIncomplete(assetId:)` and `incompleteAssetCount` do not exist.

- [ ] **Step 3: Add `isIncomplete(assetId:)` and `incompleteAssetCount`**

In `SimFolio/Services/MetadataManager.swift`, inside the `MetadataManager` class, just after `getIncompleteAssetIds()` (~line 547), add:

```swift
/// Whether a given photo asset should be treated as "Needs Tagging".
/// True if there is no metadata row for the asset, or the row is missing
/// procedure / stage / angle. Matches the chip-bar filter semantics.
func isIncomplete(assetId: String) -> Bool {
    guard let metadata = assetMetadata[assetId] else { return true }
    return metadata.procedure == nil || metadata.stage == nil || metadata.angle == nil
}

/// Count of stored metadata rows whose procedure / stage / angle is incomplete.
/// Does NOT include PhotoRecord ids that have no metadata row at all — use this
/// for the tab-bar badge where the storage layer drives the full set.
var incompleteAssetCount: Int {
    getIncompleteAssetIds().count
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/MetadataManagerIncompleteTests 2>&1 | tail -20
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Services/MetadataManager.swift SimFolioTests/Services/MetadataManagerIncompleteTests.swift
git commit -m "feat: add isIncomplete and incompleteAssetCount to MetadataManager"
```

---

## Task 3: Hide tag UI in `ImportReviewView` when not prefilled

The review screen already has `tagSummaryBar` and a `.sheet` presenting `ImportTagEditorSheet`. Both should disappear for backfill imports (no portfolio prefill). When prefilled (from a portfolio CTA), they stay.

**Files:**
- Modify: `SimFolio/Features/Import/ImportReviewView.swift`
- Modify: `SimFolio/Features/Import/ImportFlowView.swift` (to pass the flag in)

- [ ] **Step 1: Add `isPrefilledFromPortfolio` property to `ImportReviewView`**

In `SimFolio/Features/Import/ImportReviewView.swift`, add the property just below the existing `@ObservedObject var importState`:

```swift
/// Whether the import was launched from a portfolio requirement's "Add Photos"
/// CTA. When true, keep the existing tag summary + editor; when false, import is
/// tagless (the Library's Needs Tagging flow handles tagging later).
var isPrefilledFromPortfolio: Bool = false
```

- [ ] **Step 2: Gate the tag summary bar and sheet**

In the `body` of `ImportReviewView`, wrap the `tagSummaryBar` invocation in a conditional:

Replace:
```swift
VStack(spacing: 0) {
    header
    tagSummaryBar
    ScrollView {
```

with:
```swift
VStack(spacing: 0) {
    header
    if isPrefilledFromPortfolio {
        tagSummaryBar
    }
    ScrollView {
```

And gate the `.sheet` presentation:

Replace:
```swift
.sheet(isPresented: $showTagEditor) {
    ImportTagEditorSheet(importState: importState)
        .presentationDetents([.medium])
}
```

with:
```swift
.sheet(isPresented: $showTagEditor) {
    if isPrefilledFromPortfolio {
        ImportTagEditorSheet(importState: importState)
            .presentationDetents([.medium])
    } else {
        EmptyView()
    }
}
```

- [ ] **Step 3: Pass the flag from `ImportFlowView`**

In `SimFolio/Features/Import/ImportFlowView.swift`, find the two places where `ImportReviewView` is constructed (inside the `switch importState.currentStep` `case .review` and `case .importing`).

Replace:
```swift
case .review:
    ImportReviewView(
        importState: importState,
        onCancel: { dismissFlow() },
        onStartImport: { runImport() }
    )
case .importing:
    ImportReviewView(
        importState: importState,
        onCancel: { },
        onStartImport: { }
    )
    .disabled(true)
```

with:
```swift
case .review:
    ImportReviewView(
        importState: importState,
        isPrefilledFromPortfolio: prefilledProcedure != nil,
        onCancel: { dismissFlow() },
        onStartImport: { runImport() }
    )
case .importing:
    ImportReviewView(
        importState: importState,
        isPrefilledFromPortfolio: prefilledProcedure != nil,
        onCancel: { },
        onStartImport: { }
    )
    .disabled(true)
```

- [ ] **Step 4: Build and launch the import flow manually**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: build succeeds.

- [ ] **Step 5: Visual sanity-check**

Run the app in a simulator. From Home / Capture, trigger `Import from Photos`. Confirm:
- No tag summary bar (`"No tags"` row) is visible.
- Primary button still reads `"Import N Photo(s)"` and works.

From a portfolio requirement's "Add photos" CTA (if such a path exists in the UI), confirm the tag summary bar + "Edit" still appears.

Note: if a portfolio → import CTA doesn't exist in the current UI yet, skip the second check; the code path is still exercised once such a CTA is added.

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Import/ImportReviewView.swift SimFolio/Features/Import/ImportFlowView.swift
git commit -m "feat: hide tag UI in import review for non-prefilled backfills"
```

---

## Task 4: Extend analytics events

**Files:**
- Modify: `SimFolio/Services/AnalyticsService.swift`

- [ ] **Step 1: Inspect the existing `logPhotoImported`**

Open `SimFolio/Services/AnalyticsService.swift` and locate `logPhotoImported(count:duplicatesSkipped:failed:)` around line 358. We'll extend the signature.

- [ ] **Step 2: Extend `logPhotoImported`**

Replace the existing function with:

```swift
static func logPhotoImported(
    count: Int,
    duplicatesSkipped: Int,
    failed: Int,
    prefilled: Bool = false
) {
    logEvent(.photoImported, parameters: [
        "count": count,
        "duplicates_skipped": duplicatesSkipped,
        "failed": failed,
        "prefilled": prefilled
    ])
}
```

The default value keeps existing call sites compiling without changes.

- [ ] **Step 3: Add three new convenience methods**

Immediately below `logPhotoImported`, add:

```swift
/// Fired when a bulk-tag apply commits tags to a multi-selection in the Library.
static func logBulkTagApplied(photoCount: Int, fieldsChanged: [String]) {
    logCustomEvent("bulk_tag_applied", parameters: [
        "photo_count": photoCount,
        "fields_changed": fieldsChanged.joined(separator: ",")
    ])
}

/// Fired when the user taps the "Needs Tagging" chip in the Library.
static func logUntaggedFilterViewed() {
    logCustomEvent("untagged_filter_viewed")
}

/// Fired when the user taps the post-import toast to deep-link to the inbox.
static func logImportNudgeTapped() {
    logCustomEvent("import_to_library_nudge_tapped")
}
```

- [ ] **Step 4: Update the import call site**

In `SimFolio/Features/Import/ImportFlowView.swift`, find the call in `finish(with:)`:

```swift
AnalyticsService.logPhotoImported(
    count: result.imported,
    duplicatesSkipped: result.skipped,
    failed: result.failed
)
```

Replace with:

```swift
AnalyticsService.logPhotoImported(
    count: result.imported,
    duplicatesSkipped: result.skipped,
    failed: result.failed,
    prefilled: prefilledProcedure != nil
)
```

- [ ] **Step 5: Build to confirm**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Services/AnalyticsService.swift SimFolio/Features/Import/ImportFlowView.swift
git commit -m "feat: add bulk-tag and nudge analytics events; prefilled flag on import"
```

---

## Task 5: Build `NeedsTaggingChipBar` component

**Files:**
- Create: `SimFolio/Features/Library/NeedsTaggingChipBar.swift`

This is a pure view — no logic beyond rendering. Preview-driven; no unit tests.

- [ ] **Step 1: Create the component**

Create `SimFolio/Features/Library/NeedsTaggingChipBar.swift`:

```swift
// NeedsTaggingChipBar.swift
// SimFolio - Two-chip row above the Library grid: "All" | "Needs Tagging (N)".
//
// The chip bar is a persistent filter surface separate from the filter sheet.
// Toggling it flips `LibraryFilter.showUntaggedOnly`. The untagged count is passed
// in from LibraryView, which binds it to MetadataManager.incompleteAssetCount.

import SwiftUI

struct NeedsTaggingChipBar: View {
    @Binding var showUntaggedOnly: Bool
    let untaggedCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            chip(title: "All", isSelected: !showUntaggedOnly) {
                if showUntaggedOnly {
                    showUntaggedOnly = false
                }
            }
            chip(
                title: untaggedCount > 0
                    ? "Needs Tagging (\(untaggedCount))"
                    : "Needs Tagging",
                isSelected: showUntaggedOnly
            ) {
                if !showUntaggedOnly {
                    showUntaggedOnly = true
                    AnalyticsService.logUntaggedFilterViewed()
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.background)
    }

    @ViewBuilder
    private func chip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(AppTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("needs-tagging-chip-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

#if DEBUG
struct NeedsTaggingChipBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NeedsTaggingChipBar(showUntaggedOnly: .constant(false), untaggedCount: 12)
            NeedsTaggingChipBar(showUntaggedOnly: .constant(true), untaggedCount: 12)
            NeedsTaggingChipBar(showUntaggedOnly: .constant(false), untaggedCount: 0)
        }
        .background(AppTheme.Colors.background)
    }
}
#endif
```

- [ ] **Step 2: Add the file to the Xcode project**

If the project uses folder references (blue folder icon in Xcode), no action needed. If it uses group references (yellow folder), open `SimFolio.xcodeproj` and ensure `NeedsTaggingChipBar.swift` is added to the `SimFolio` target.

Verify by building:

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Expected: compile succeeds. If it fails with "Cannot find 'NeedsTaggingChipBar'", re-add the file to the target.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Library/NeedsTaggingChipBar.swift SimFolio.xcodeproj
git commit -m "feat: add NeedsTaggingChipBar component"
```

---

## Task 6: Wire chip bar + filter branch into `LibraryView`

**Files:**
- Modify: `SimFolio/Features/Library/LibraryView.swift`

- [ ] **Step 1: Add the `showUntaggedOnly` branch to `filteredRecords`**

In `LibraryView.swift`, locate `LibraryViewModel.filteredRecords(from:metadata:filter:)` around line 98. At the top of the function body, **before** `// Filter by procedure`, insert:

```swift
// Filter by "Needs Tagging" chip — applied before other filters so an
// untagged inbox view can still be refined by date/portfolio etc.
if filter.showUntaggedOnly {
    result = result.filter { record in
        metadata.isIncomplete(assetId: record.id.uuidString)
    }
}
```

- [ ] **Step 2: Identify where to insert the chip bar**

`LibraryView` has several rendering paths (procedure grid, library grid, date grid, etc.). The chip bar must appear above the main photo grid. Find the top-level `ScrollView` in `LibraryView`'s `body` that hosts the grid. (Grep for `LazyVGrid` inside `LibraryView`'s body to locate it.)

Document the exact line for the next step:

```bash
grep -n "LazyVGrid\|ScrollView" SimFolio/Features/Library/LibraryView.swift | head -20
```

- [ ] **Step 3: Insert the chip bar**

In `LibraryView.swift`, at the rendering path that shows the main photo grid — just above the `ScrollView` that wraps the grid — insert:

```swift
NeedsTaggingChipBar(
    showUntaggedOnly: $router.libraryFilter.showUntaggedOnly,
    untaggedCount: metadataManager.incompleteAssetCount
)
```

(`metadataManager` is an `@ObservedObject` in `LibraryView`; if the grid rendering is in a sub-view that doesn't already observe `MetadataManager.shared`, pass the count in as a parameter instead. Prefer the parameter route over adding another `@ObservedObject` to avoid double-subscribing.)

- [ ] **Step 4: Ensure empty-state messaging**

Still in `LibraryView.swift`, locate the empty-state view shown when `filteredRecords` returns nothing. Add a special case for when `router.libraryFilter.showUntaggedOnly == true`:

```swift
if router.libraryFilter.showUntaggedOnly {
    VStack(spacing: AppTheme.Spacing.sm) {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 48))
            .foregroundStyle(AppTheme.Colors.success)
        Text("All caught up")
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.Colors.textPrimary)
        Text("Tap All to see your library")
            .font(AppTheme.Typography.subheadline)
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
    .padding(AppTheme.Spacing.xl)
} else {
    // existing empty state
}
```

- [ ] **Step 5: Build and visual check**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15
```

Then run the app with the `--with-sample-data` launch argument (or manually create untagged photos) and verify the chip bar toggles the grid contents. Tap `Needs Tagging` — only photos with nil procedure/stage/angle should appear.

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Library/LibraryView.swift
git commit -m "feat: wire NeedsTaggingChipBar and untagged filter into Library"
```

---

## Task 7: Build `BulkTagSheet` with per-field touched semantics

**Files:**
- Create: `SimFolio/Features/Library/BulkTagSheet.swift`
- Create: `SimFolioTests/Features/BulkTagSheetLogicTests.swift`

We isolate the apply-logic into a plain struct (`BulkTagEdits`) so it's unit-testable independently of the SwiftUI sheet view.

- [ ] **Step 1: Write the failing tests for the apply logic**

Create `SimFolioTests/Features/BulkTagSheetLogicTests.swift`:

```swift
// BulkTagSheetLogicTests.swift
// SimFolio - Tests for BulkTagEdits.apply(to:) — per-field touched semantics.

import XCTest
@testable import SimFolio

final class BulkTagSheetLogicTests: XCTestCase {

    func test_apply_withNoChanges_leavesMetadataAlone() {
        let edits = BulkTagEdits()
        var existing = PhotoMetadata()
        existing.procedure = "Class 1"
        existing.stage = "Preparation"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 1")
        XCTAssertEqual(updated.stage, "Preparation")
    }

    func test_apply_setsProcedure_whenTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        let existing = PhotoMetadata()

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 2")
    }

    func test_apply_overwritesExistingProcedure_whenTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        var existing = PhotoMetadata()
        existing.procedure = "Class 1"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.procedure, "Class 2")
    }

    func test_apply_preservesStage_whenOnlyProcedureTouched() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 2")
        var existing = PhotoMetadata()
        existing.stage = "Preparation"

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.stage, "Preparation")
    }

    func test_apply_setsToothNumberAndDate_whenToothTouched() {
        var edits = BulkTagEdits()
        edits.toothNumber = .set(14)
        edits.toothDateWhenTouched = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = PhotoMetadata()

        let updated = edits.apply(to: existing)

        XCTAssertEqual(updated.toothNumber, 14)
        XCTAssertEqual(updated.toothDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_fieldsChanged_reflectsOnlyTouchedFields() {
        var edits = BulkTagEdits()
        edits.procedure = .set("Class 1")
        edits.angle = .set("Buccal/Facial")

        XCTAssertEqual(Set(edits.fieldsChanged), Set(["procedure", "angle"]))
    }

    func test_hasAnyChange_falseByDefault() {
        XCTAssertFalse(BulkTagEdits().hasAnyChange)
    }

    func test_hasAnyChange_trueWhenAnyFieldTouched() {
        var edits = BulkTagEdits()
        edits.stage = .set("Restoration")
        XCTAssertTrue(edits.hasAnyChange)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/BulkTagSheetLogicTests 2>&1 | tail -20
```

Expected: compile errors — `BulkTagEdits` not defined.

- [ ] **Step 3: Create `BulkTagSheet.swift` with the `BulkTagEdits` struct and the view**

Create `SimFolio/Features/Library/BulkTagSheet.swift`:

```swift
// BulkTagSheet.swift
// SimFolio - Bulk-tag sheet for multi-selected photos in the Library.
//
// Per-field touched semantics:
//   - Fields not touched preserve each photo's existing value.
//   - Fields touched (.set) overwrite that field for all selected photos.
//   - v1 does not support explicit `.cleared` (user can only overwrite or leave).
//
// The apply logic lives in `BulkTagEdits.apply(to:)` — a plain struct so it is
// unit-testable without the SwiftUI view layer.

import SwiftUI

// MARK: - FieldEdit

enum FieldEdit<Value: Equatable>: Equatable {
    case unchanged
    case set(Value)

    var isTouched: Bool {
        if case .unchanged = self { return false }
        return true
    }
}

// MARK: - BulkTagEdits

struct BulkTagEdits {
    var procedure: FieldEdit<String> = .unchanged
    var toothNumber: FieldEdit<Int> = .unchanged
    var stage: FieldEdit<String> = .unchanged
    var angle: FieldEdit<String> = .unchanged

    /// Date used for toothDate when a tooth is set. The sheet captures "now" at
    /// the moment the picker is changed; callers may override for determinism.
    var toothDateWhenTouched: Date = Date()

    var hasAnyChange: Bool {
        procedure.isTouched || toothNumber.isTouched ||
        stage.isTouched || angle.isTouched
    }

    var fieldsChanged: [String] {
        var out: [String] = []
        if procedure.isTouched { out.append("procedure") }
        if toothNumber.isTouched { out.append("tooth") }
        if stage.isTouched { out.append("stage") }
        if angle.isTouched { out.append("angle") }
        return out
    }

    /// Apply the touched fields on top of an existing PhotoMetadata row.
    /// Untouched fields preserve the existing value.
    func apply(to existing: PhotoMetadata) -> PhotoMetadata {
        var updated = existing
        if case let .set(value) = procedure { updated.procedure = value }
        if case let .set(value) = toothNumber {
            updated.toothNumber = value
            updated.toothDate = toothDateWhenTouched
        }
        if case let .set(value) = stage { updated.stage = value }
        if case let .set(value) = angle { updated.angle = value }
        return updated
    }
}

// MARK: - SharedValue helpers

private enum SharedValue<T: Hashable> {
    case none
    case all(T)
    case mixed

    init(_ values: [T?]) {
        let nonNil = values.compactMap { $0 }
        if nonNil.isEmpty { self = .none; return }
        let unique = Set(nonNil)
        if unique.count == 1, nonNil.count == values.count {
            self = .all(unique.first!)
        } else {
            self = .mixed
        }
    }

    var displayedValue: T? {
        if case let .all(v) = self { return v }
        return nil
    }

    var isMixed: Bool {
        if case .mixed = self { return true }
        return false
    }
}

// MARK: - BulkTagSheet View

struct BulkTagSheet: View {
    /// Asset IDs to apply edits to.
    let selectedAssetIds: Set<UUID>

    /// Called after edits are written; used by the caller to exit selection mode.
    var onApplied: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var metadataManager = MetadataManager.shared

    @State private var edits = BulkTagEdits()

    private var selectedIds: [String] {
        selectedAssetIds.map { $0.uuidString }
    }

    private var existingMetadata: [PhotoMetadata] {
        selectedIds.compactMap { metadataManager.getMetadata(for: $0) }
    }

    private var sharedProcedure: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.procedure })
    }

    private var sharedStage: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.stage })
    }

    private var sharedAngle: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.angle })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    procedureSection
                    toothSection
                    stageSection
                    angleSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Tag \(selectedAssetIds.count) Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyEdits() }
                        .fontWeight(.semibold)
                        .disabled(!edits.hasAnyChange)
                }
            }
        }
    }

    // MARK: Sections

    private var procedureSection: some View {
        sectionContainer(title: "PROCEDURE", mixed: sharedProcedure.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledProcedureNames(), id: \.self) { name in
                        DPTagPill(
                            name,
                            color: AppTheme.procedureColor(for: name),
                            isSelected: selectionState(for: edits.procedure, shared: sharedProcedure, value: name)
                        ) {
                            edits.procedure = .set(name)
                        }
                    }
                }
            }
        }
    }

    private var toothSection: some View {
        sectionContainer(title: "TOOTH", mixed: false) {
            Picker("Tooth Number", selection: Binding(
                get: {
                    if case let .set(value) = edits.toothNumber { return Optional(value) }
                    return Int?.none
                },
                set: { newValue in
                    if let v = newValue {
                        edits.toothNumber = .set(v)
                        edits.toothDateWhenTouched = Date()
                    } else {
                        edits.toothNumber = .unchanged
                    }
                }
            )) {
                Text("Unchanged").tag(Int?.none)
                ForEach(1...32, id: \.self) { number in
                    Text("\(number)").tag(Int?.some(number))
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .clipped()
        }
    }

    private var stageSection: some View {
        sectionContainer(title: "STAGE", mixed: sharedStage.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledStages()) { config in
                        DPTagPill(
                            config.name,
                            color: config.color,
                            isSelected: selectionState(for: edits.stage, shared: sharedStage, value: config.name)
                        ) {
                            edits.stage = .set(config.name)
                        }
                    }
                }
            }
        }
    }

    private var angleSection: some View {
        sectionContainer(title: "ANGLE", mixed: sharedAngle.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(MetadataManager.angles, id: \.self) { angle in
                        DPTagPill(
                            angle,
                            color: AppTheme.angleColor(for: angle),
                            isSelected: selectionState(for: edits.angle, shared: sharedAngle, value: angle)
                        ) {
                            edits.angle = .set(angle)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        mixed: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                if mixed {
                    Text("(Mixed)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            content()
        }
    }

    /// Whether a pill for `value` should render as selected.
    /// - Touched with `value` → selected.
    /// - Untouched AND the shared value is `value` → selected (reflects current shared state).
    /// - Otherwise → not selected.
    private func selectionState(
        for field: FieldEdit<String>,
        shared: SharedValue<String>,
        value: String
    ) -> Bool {
        switch field {
        case .set(let v):
            return v == value
        case .unchanged:
            return shared.displayedValue == value
        }
    }

    private func applyEdits() {
        var appliedCount = 0
        for assetId in selectedIds {
            let existing = metadataManager.getMetadata(for: assetId) ?? PhotoMetadata()
            let updated = edits.apply(to: existing)
            metadataManager.assignMetadata(updated, to: assetId)

            if let toothEntry = updated.toothEntry, edits.toothNumber.isTouched {
                metadataManager.addToothEntry(toothEntry)
            }
            appliedCount += 1
        }

        AnalyticsService.logBulkTagApplied(
            photoCount: appliedCount,
            fieldsChanged: edits.fieldsChanged
        )

        onApplied(appliedCount)
        dismiss()
    }
}

#if DEBUG
struct BulkTagSheet_Previews: PreviewProvider {
    static var previews: some View {
        BulkTagSheet(
            selectedAssetIds: [UUID(), UUID()],
            onApplied: { _ in }
        )
    }
}
#endif
```

- [ ] **Step 4: Run the logic tests and verify they pass**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/BulkTagSheetLogicTests 2>&1 | tail -20
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Library/BulkTagSheet.swift SimFolioTests/Features/BulkTagSheetLogicTests.swift SimFolio.xcodeproj
git commit -m "feat: add BulkTagSheet with per-field touched semantics"
```

---

## Task 8: Add "Tag" action to `SelectionActionBar` and present `BulkTagSheet`

**Files:**
- Modify: `SimFolio/Features/Library/LibraryView.swift` (`SelectionActionBar` around line 3605; the two selection-mode `safeAreaInset` sites around lines 649–659 and 745–754)

- [ ] **Step 1: Extend `SelectionActionBar` to accept an `onTag` callback**

Locate `struct SelectionActionBar: View` around line 3605. Replace its property declarations and `HStack` body to:

```swift
struct SelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void
    let onTag: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if selectedCount > 0 {
                Text("\(selectedCount) photo\(selectedCount == 1 ? "" : "s") selected")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.sm)
            }

            Divider()
                .padding(.top, AppTheme.Spacing.sm)

            HStack(spacing: AppTheme.Spacing.lg) {
                ActionBarButton(
                    icon: "tag",
                    label: "Tag",
                    isDisabled: selectedCount == 0,
                    action: onTag
                )

                ActionBarButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    isDisabled: selectedCount == 0,
                    action: onShare
                )

                ActionBarButton(
                    icon: "heart",
                    label: "Favorite",
                    isDisabled: selectedCount == 0,
                    action: onFavorite
                )

                ActionBarButton(
                    icon: "trash",
                    label: "Delete",
                    isDisabled: selectedCount == 0,
                    isDestructive: true,
                    action: onDelete
                )
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.surface)
        }
    }
}
```

- [ ] **Step 2: Add `showBulkTagSheet` state and present the sheet**

In `LibraryView`'s main `View` struct (not the view model), add a `@State` property near the other selection-related state:

```swift
@State private var showBulkTagSheet = false
```

Find the two `SelectionActionBar(...)` call sites (around lines 649 and 745). Update both to include `onTag`:

```swift
SelectionActionBar(
    selectedCount: viewModel.selectedAssetIds.count,
    onDelete: { showDeleteConfirmation = true },
    onShare: onShare,
    onFavorite: onFavorite,
    onTag: { showBulkTagSheet = true }
)
```

- [ ] **Step 3: Present the `BulkTagSheet`**

In the same view(s), add a `.sheet(isPresented: $showBulkTagSheet)` modifier beside the existing `.alert` / selection modifiers:

```swift
.sheet(isPresented: $showBulkTagSheet) {
    BulkTagSheet(
        selectedAssetIds: viewModel.selectedAssetIds,
        onApplied: { appliedCount in
            viewModel.exitSelectionMode()
            NotificationCenter.default.post(
                name: .showGlobalToast,
                object: nil,
                userInfo: [
                    "message": "Tagged \(appliedCount) photo\(appliedCount == 1 ? "" : "s")",
                    "type": "success"
                ]
            )
        }
    )
}
```

(`exitSelectionMode()` already exists on the view model — see lines 291–297 of the file.)

- [ ] **Step 4: Build**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15
```

Expected: build succeeds. If you hit a "missing argument for parameter 'onTag'" error, you missed a `SelectionActionBar` call site — search for all occurrences and update.

- [ ] **Step 5: Visual check**

Run the app, enter selection mode from the Library toolbar, select a couple of photos, and verify:
- The action bar now shows Tag / Share / Favorite / Delete.
- Tapping Tag opens `BulkTagSheet`.
- Tapping a procedure pill and then Apply writes the tag and shows a success toast.
- Selection mode exits after apply.

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Library/LibraryView.swift
git commit -m "feat: wire BulkTagSheet into Library selection mode"
```

---

## Task 9: Add Library tab badge in `ContentView`

**Files:**
- Modify: `SimFolio/App/ContentView.swift`

- [ ] **Step 1: Observe `MetadataManager` in `ContentView` if not already**

In `ContentView.swift`, confirm a `@StateObject` or `@ObservedObject` reference to `MetadataManager.shared` exists in the `ContentView` struct. If not, add:

```swift
@ObservedObject private var metadataManager = MetadataManager.shared
```

alongside the other `@ObservedObject`/`@StateObject` declarations near the top of the struct.

- [ ] **Step 2: Add `.badge` to the Library tab**

Find the `NavigationView { LibraryView() }` block around line 186. Its `.tabItem { ... }` currently renders a `Label`. Add `.badge(metadataManager.incompleteAssetCount)` after `.tabItem { ... }`:

```swift
NavigationView {
    LibraryView()
}
.navigationViewStyle(StackNavigationViewStyle())
.tabItem {
    Label("Library", systemImage: router.selectedTab == .library ? "photo.on.rectangle.fill" : "photo.on.rectangle")
}
.badge(metadataManager.incompleteAssetCount)
.tag(MainTab.library)
```

(iOS 15+ supports `.badge(Int)` on tab items. When the int is 0, no badge is rendered — no conditional needed.)

- [ ] **Step 3: Build and check**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Run the app with sample data that includes untagged photos. Confirm a red badge with the count appears on the Library tab; confirm it drops to zero after bulk-tagging all untagged photos.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/App/ContentView.swift
git commit -m "feat: show untagged count as Library tab badge"
```

---

## Task 10: Add toast tap-action support and wire post-import deep-link

**Files:**
- Modify: `SimFolio/App/ContentView.swift`
- Modify: `SimFolio/Features/Import/ImportFlowView.swift`

- [ ] **Step 1: Add a state property to hold the current toast's tap action**

In `ContentView.swift`, near the other toast state (around line 49), add:

```swift
@State private var globalToastTapAction: (() -> Void)?
```

- [ ] **Step 2: Update the toast-receiving `onReceive` to read the tap action**

Replace the `onReceive` block around line 149:

```swift
.onReceive(NotificationCenter.default.publisher(for: .showGlobalToast)) { notification in
    if let userInfo = notification.userInfo,
       let message = userInfo["message"] as? String {
        let typeString = userInfo["type"] as? String ?? "info"
        let type: DPToast.ToastType
        switch typeString {
        case "success": type = .success
        case "warning": type = .warning
        case "error": type = .error
        default: type = .info
        }
        let tapAction = userInfo["onTap"] as? () -> Void
        showToast(type: type, message: message, onTap: tapAction)
    }
}
```

- [ ] **Step 3: Update `showToast` to accept and store the tap action**

Find the `showToast(type:message:)` function around line 582. Update its signature and body:

```swift
private func showToast(type: DPToast.ToastType, message: String, onTap: (() -> Void)? = nil) {
    globalToastType = type
    globalToastMessage = message
    globalToastTapAction = onTap

    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        showGlobalToast = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
        withAnimation {
            showGlobalToast = false
            globalToastTapAction = nil
        }
    }
}
```

(Keep any other behavior in the existing function — only adjust the signature, the initial state update, and the auto-dismiss cleanup.)

- [ ] **Step 4: Update the toast tap handler in the overlay**

Around line 136 where the toast has `.onTapGesture`, update:

```swift
.onTapGesture {
    globalToastTapAction?()
    withAnimation {
        showGlobalToast = false
        globalToastTapAction = nil
    }
}
```

- [ ] **Step 5: Post the tappable toast from import**

In `SimFolio/Features/Import/ImportFlowView.swift`, locate `finish(with:)` and the existing toast dispatch:

```swift
let message = toastMessage(for: result, total: total)
dismissFlow()

DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    NotificationCenter.default.post(
        name: .showGlobalToast,
        object: nil,
        userInfo: [
            "message": message,
            "type": result.imported > 0 ? "success" : "info"
        ]
    )
}
```

Replace with a version that includes a deep-link tap action when at least one photo was imported:

```swift
let importedOk = result.imported > 0
let toastMessage: String
if importedOk {
    toastMessage = "\(result.imported) imported · Tap to tag"
} else {
    toastMessage = self.toastMessage(for: result, total: total)
}

dismissFlow()

DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    var userInfo: [AnyHashable: Any] = [
        "message": toastMessage,
        "type": importedOk ? "success" : "info"
    ]
    if importedOk {
        let onTap: () -> Void = {
            AnalyticsService.logImportNudgeTapped()
            var filter = LibraryFilter()
            filter.showUntaggedOnly = true
            NavigationRouter.shared.navigateToLibrary(filter: filter)
        }
        userInfo["onTap"] = onTap
    }
    NotificationCenter.default.post(
        name: .showGlobalToast,
        object: nil,
        userInfo: userInfo
    )
}
```

If `NavigationRouter` has no shared instance, the closure should capture the router via its `@EnvironmentObject`. Check at the top of `ImportFlowView` — a `@EnvironmentObject var router: NavigationRouter` already exists. Capture that in the closure:

```swift
let router = self.router
let onTap: () -> Void = {
    AnalyticsService.logImportNudgeTapped()
    var filter = LibraryFilter()
    filter.showUntaggedOnly = true
    router.navigateToLibrary(filter: filter)
}
```

- [ ] **Step 6: Build and test the flow manually**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Run the app. Import a couple of photos. Verify:
- Toast reads "N imported · Tap to tag".
- Tapping the toast switches to the Library tab with the `Needs Tagging` chip active.

- [ ] **Step 7: Commit**

```bash
git add SimFolio/App/ContentView.swift SimFolio/Features/Import/ImportFlowView.swift
git commit -m "feat: make global toast tappable; deep-link import toast to Needs Tagging"
```

---

## Task 11: Build `UntaggedPhotosCard` with 2-session dismissal

**Files:**
- Create: `SimFolio/Features/Home/UntaggedPhotosCard.swift`

Dismissal mechanics:
- `UserDefaults` key `untaggedCardDismissedRemainingSessions: Int`.
- On dismiss: set to `2`.
- On each `SimFolioApp` launch (Task 12): if value > 0, decrement by 1 and save.
- The card is suppressed while the value is > 0.

- [ ] **Step 1: Create the card**

Create `SimFolio/Features/Home/UntaggedPhotosCard.swift`:

```swift
// UntaggedPhotosCard.swift
// SimFolio - Home-screen nudge card for untagged imported photos.
//
// Shown when MetadataManager.shared.incompleteAssetCount > 0 AND the dismissal
// counter (UserDefaults: "untaggedCardDismissedRemainingSessions") is 0.
// Tapping "Tag now" deep-links to the Library with showUntaggedOnly = true.
// Tapping dismiss sets the counter to 2 — the card stays hidden for the next
// two app launches, then returns.

import SwiftUI

enum UntaggedCardDismissal {
    static let userDefaultsKey = "untaggedCardDismissedRemainingSessions"

    /// Called when the user taps the dismiss button.
    static func dismiss() {
        UserDefaults.standard.set(2, forKey: userDefaultsKey)
    }

    /// Called once per `SimFolioApp` launch — decrements the remaining sessions.
    static func tickDownOnLaunch() {
        let remaining = UserDefaults.standard.integer(forKey: userDefaultsKey)
        if remaining > 0 {
            UserDefaults.standard.set(remaining - 1, forKey: userDefaultsKey)
        }
    }

    /// Whether the card is currently suppressed by the dismissal counter.
    static var isSuppressed: Bool {
        UserDefaults.standard.integer(forKey: userDefaultsKey) > 0
    }
}

struct UntaggedPhotosCard: View {
    let count: Int
    let onTagNow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "tag.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.primary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("\(count) photo\(count == 1 ? "" : "s") need tagging")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Tag them so they count toward your portfolios")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button(action: onTagNow) {
                    Text("Tag now")
                        .font(AppTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.top, AppTheme.Spacing.xs)
                }
                .accessibilityIdentifier("untagged-card-tag-now")
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .padding(AppTheme.Spacing.xs)
            }
            .accessibilityLabel("Dismiss for a couple of sessions")
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
        )
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

#if DEBUG
struct UntaggedPhotosCard_Previews: PreviewProvider {
    static var previews: some View {
        UntaggedPhotosCard(count: 12, onTagNow: {}, onDismiss: {})
            .padding()
            .background(AppTheme.Colors.background)
    }
}
#endif
```

- [ ] **Step 2: Build**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Expected: build succeeds (component is unused at this point).

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Home/UntaggedPhotosCard.swift SimFolio.xcodeproj
git commit -m "feat: add UntaggedPhotosCard with 2-session dismissal helpers"
```

---

## Task 12: Integrate `UntaggedPhotosCard` into `HomeView` and tick down on launch

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift`
- Modify: `SimFolio/SimFolioApp.swift`

- [ ] **Step 1: Tick down the dismissal counter at app launch**

In `SimFolio/SimFolioApp.swift`, find the `init()` of `SimFolioApp` (around line 56). At the end of the initializer, after existing setup, add:

```swift
// Decrement the "Untagged photos" card dismissal counter once per launch so
// the card re-emerges after the user has skipped it for two sessions.
UntaggedCardDismissal.tickDownOnLaunch()
```

- [ ] **Step 2: Add a transient @State for session-level hiding in HomeView**

In `SimFolio/Features/Home/HomeView.swift`, inside `HomeView`'s struct body, add:

```swift
@ObservedObject private var metadataManager = MetadataManager.shared
@State private var dismissedUntaggedCardThisSession = false
```

If `metadataManager` is already observed, omit that line.

- [ ] **Step 3: Compute whether the card should be shown**

Just below the state properties, add a computed property:

```swift
private var shouldShowUntaggedCard: Bool {
    !dismissedUntaggedCardThisSession &&
    !UntaggedCardDismissal.isSuppressed &&
    metadataManager.incompleteAssetCount > 0
}
```

- [ ] **Step 4: Place the card below the existing home header**

Locate the top of `HomeView`'s main vertical stack — just below whatever renders the header/title — and insert:

```swift
if shouldShowUntaggedCard {
    UntaggedPhotosCard(
        count: metadataManager.incompleteAssetCount,
        onTagNow: {
            var filter = LibraryFilter()
            filter.showUntaggedOnly = true
            router.navigateToLibrary(filter: filter)
        },
        onDismiss: {
            UntaggedCardDismissal.dismiss()
            withAnimation {
                dismissedUntaggedCardThisSession = true
            }
        }
    )
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.bottom, AppTheme.Spacing.sm)
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

`router` is already an `@EnvironmentObject var router: NavigationRouter` in most top-level views. If `HomeView` does not already have it, add:

```swift
@EnvironmentObject var router: NavigationRouter
```

near the other environment objects.

- [ ] **Step 5: Build and manually verify**

```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Visual verification (with untagged sample data):
1. Launch the app — the card appears with the current untagged count.
2. Tap `Tag now` — navigates to Library with chip active.
3. Return to Home — card still appears.
4. Tap the dismiss `X` — card fades out.
5. Kill and relaunch the app — card stays hidden.
6. Kill and relaunch again — card stays hidden.
7. Kill and relaunch a third time — card reappears (counter has decremented from 2 → 1 → 0).

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift SimFolio/SimFolioApp.swift
git commit -m "feat: show UntaggedPhotosCard on Home with 2-session dismissal"
```

---

## Task 13: UI test for end-to-end bulk-tag flow

**Files:**
- Create: `SimFolioUITests/BulkTagFlowUITests.swift`

Note: The project already has `--with-sample-data` and `--mock-photos-picker` launch arguments. Leverage those so the test is deterministic.

- [ ] **Step 1: Inspect existing UI tests for launch-argument conventions**

```bash
ls SimFolioUITests/
```

Open one of the existing UI test files (e.g., `ImportFlowUITests.swift`) and note how it sets launch arguments and taps elements by `accessibilityIdentifier`.

- [ ] **Step 2: Write the UI test**

Create `SimFolioUITests/BulkTagFlowUITests.swift`:

```swift
// BulkTagFlowUITests.swift
// SimFolio - End-to-end: import untagged photos -> Needs Tagging chip ->
// multi-select -> apply tags -> badge/count drops.

import XCTest

final class BulkTagFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testImportToBulkTagFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--skip-onboarding",
            "--reset-all-data",
            "--with-sample-data",
            "--mock-photos-picker"
        ]
        app.launch()

        // 1. Open Capture tab, tap Import From Photos.
        app.tabBars.buttons["Capture"].tap()
        let importButton = app.buttons["capture-import-from-photos"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        // 2. Mock picker seeds candidates; review screen opens without tag UI.
        // Confirm the tag summary bar is NOT present.
        XCTAssertFalse(app.buttons.matching(identifier: "import-tag-summary").firstMatch.exists)

        // 3. Tap the Import primary CTA.
        let importCTA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import'")).firstMatch
        XCTAssertTrue(importCTA.waitForExistence(timeout: 3))
        importCTA.tap()

        // 4. Wait for the post-import toast and tap it to deep-link to Library.
        let toast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tap to tag'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        toast.tap()

        // 5. Library should be on the Needs Tagging chip.
        let chip = app.buttons["needs-tagging-chip-needs-tagging-3"]
        // The exact label may vary; fall back to a predicate if the count differs.
        if !chip.exists {
            let fallbackChip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'needs-tagging-chip-needs-tagging'")).firstMatch
            XCTAssertTrue(fallbackChip.waitForExistence(timeout: 3))
        }

        // 6. Enter selection mode.
        let selectionToggle = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'Select' OR label CONTAINS 'checkmark'")).firstMatch
        XCTAssertTrue(selectionToggle.waitForExistence(timeout: 3))
        selectionToggle.tap()

        // 7. Tap first two grid cells to select them.
        let cells = app.collectionViews.cells
        if cells.count >= 2 {
            cells.element(boundBy: 0).tap()
            cells.element(boundBy: 1).tap()
        }

        // 8. Tap Tag in the selection action bar.
        app.buttons["Tag"].tap()

        // 9. Bulk tag sheet opens — pick a procedure and apply.
        let firstProcedurePill = app.buttons.matching(NSPredicate(format: "label == 'Class 1'")).firstMatch
        XCTAssertTrue(firstProcedurePill.waitForExistence(timeout: 3))
        firstProcedurePill.tap()

        app.buttons["Apply"].tap()

        // 10. Success toast confirms N photos tagged.
        let successToast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tagged'")).firstMatch
        XCTAssertTrue(successToast.waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 3: Build the test target and run**

This project's `CLAUDE.md` notes UI tests may not currently be wired in the scheme. If the UI test target isn't in the scheme, skip step 3 and leave the test file in place — it will run once the target is added. Otherwise:

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioUITests/BulkTagFlowUITests 2>&1 | tail -40
```

Expected: test passes. If the launch arguments don't already seed untagged photos, augment `--with-sample-data` (or add a new `--seed-untagged-photos` flag in `SimFolioApp.swift`'s arg handling).

- [ ] **Step 4: Commit**

```bash
git add SimFolioUITests/BulkTagFlowUITests.swift
git commit -m "test: end-to-end UI test for bulk-tag flow"
```

---

## Task 14: Final integration check — full test suite and visual sweep

- [ ] **Step 1: Run the full unit test suite**

```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40
```

Expected: all existing tests plus the new `LibraryFilterTests`, `MetadataManagerIncompleteTests`, and `BulkTagSheetLogicTests` pass.

- [ ] **Step 2: Manual smoke test on device / simulator**

Walk the full flow:

1. Launch with `--reset-all-data --with-sample-data --skip-onboarding`.
2. Tap Import from Photos (from Capture tab).
3. Select a few photos (via mock picker or real picker), confirm no tag UI shown.
4. Import → toast → tap toast → lands on Library with Needs Tagging chip.
5. Verify badge on Library tab matches chip count.
6. Enter selection mode, select 3+ photos.
7. Open `BulkTagSheet`, touch procedure only, apply.
8. Confirm success toast, selection exits, badge drops by N.
9. Toggle to `All` chip — see all photos including newly-tagged ones.
10. Return Home → confirm untagged card still appears until count hits 0.
11. Tag all remaining → card disappears.
12. Dismiss the card while count > 0 → relaunch twice → confirm card stays hidden → third relaunch shows card again.

- [ ] **Step 3: Final commit if any lint/cleanup emerged**

If anything stayed out-of-tree, commit it:

```bash
git status
git diff --stat
```

If clean, no commit needed.

---

## Self-Review

**Spec coverage check** (walking the spec section-by-section):

- A1 `ImportReviewView` gate — Task 3.
- A2 `ImportFlowView` passes flag — Task 3.
- A3 `PhotoImportService` unchanged — explicitly called out in Task 3 (no changes needed).
- A4 Post-import toast — Task 10.
- A5 `prefilled` analytics — Task 4.
- B1 Untagged definition + `isIncomplete` + `incompleteAssetCount` — Task 2.
- B2 Chip bar — Tasks 5 + 6.
- B3 `LibraryFilter` extension — Task 1.
- B4 `filteredRecords` branch — Task 6.
- B5 `SelectionActionBar` Tag action — Task 8.
- B6 `BulkTagSheet` with touched semantics — Task 7.
- B7 Tab bar badge — Task 9.
- B8 Analytics events — Task 4.
- C1 Home card + 2-session dismissal — Tasks 11 + 12.
- C2 Toast tap — Task 10.
- C3 Edge cases — covered by `isIncomplete` (no-metadata-row case), empty state in Task 6, `applyEdits` creates fresh row in Task 7.
- C4 Files — mapped across Tasks 1–12.
- C5 Out of scope — none of these tasks touch those items.

No gaps.

**Placeholder scan:** No TBDs, no "implement later", no "similar to Task N" references. All code blocks are complete.

**Type consistency:**
- `BulkTagEdits` / `FieldEdit<Value>` — defined in Task 7, used only in Tasks 7's tests and view.
- `UntaggedCardDismissal.dismiss()` / `.tickDownOnLaunch()` / `.isSuppressed` — defined in Task 11, used in Tasks 11 and 12.
- `MetadataManager.isIncomplete(assetId:)` / `incompleteAssetCount` — defined in Task 2, used in Tasks 6, 7, 9, 11, 12.
- `LibraryFilter.showUntaggedOnly` — defined in Task 1, used in Tasks 6, 10, 12.
- `NeedsTaggingChipBar` — defined in Task 5, used in Task 6.
- `BulkTagSheet` — defined in Task 7, used in Task 8.
- `UntaggedPhotosCard` — defined in Task 11, used in Task 12.
- `AnalyticsService.logBulkTagApplied` / `logUntaggedFilterViewed` / `logImportNudgeTapped` — defined in Task 4, used in Tasks 5, 7, 10.
- `SelectionActionBar.onTag` — defined in Task 8, used in the same task.

Consistent across tasks.
