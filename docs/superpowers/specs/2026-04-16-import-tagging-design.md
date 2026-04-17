# Import Tagging Design — Pure Inbox Model

**Date:** 2026-04-16
**Branch context:** `feature/import-from-photos`
**Scope:** How users tag photos imported from the system Photos library.

## Problem

The current Photos import flow (`ImportFlowView` → `ImportReviewView`) applies a single shared tag set (procedure, tooth, stage, angle) to every selected photo. For the primary use case — a student backfilling weeks of sim-lab photos from a mixed grab-bag across multiple procedures, teeth, and sessions — that model is wrong: no single tag set applies to the whole batch.

Forcing per-photo tagging at import would create a friction wall that blocks the user from ever seeing their photos in the app. We want a design that lets a user import fast, then tag at their own pace.

## Decision

**Pure Inbox model (Variant 1).** Import is dumb and fast; detailed tagging happens later in the Library via bulk-tag tools.

- **Import**: no tagging UI in the default path. Photos land untagged.
- **Library**: a persistent "Needs Tagging" chip surfaces untagged photos. Existing selection mode gains a "Tag" action that opens a `BulkTagSheet`.
- **Nudges**: a tappable import toast, a Library tab badge, and a home-screen card all route the user back to the untagged set.

Portfolio-CTA imports (where the user explicitly said "add photos to this requirement") are the one exception — those keep the existing tag UX because the tags are already known.

## Section A — Import flow changes

### A1. `ImportReviewView`

When `isPrefilledFromPortfolio == false`:

- Hide `tagSummaryBar` and the `ImportTagEditorSheet` presentation.
- Keep per-photo keep/discard and rating.
- Primary CTA stays `"Import N Photo(s)"`; tapping it runs the import with all-nil `baseMetadata`.

When `isPrefilledFromPortfolio == true`:

- No change — current tag summary + editor remain.

### A2. `ImportFlowView`

- Pass `isPrefilledFromPortfolio = (prefilledProcedure != nil)` down to `ImportReviewView`.
- No other changes.

### A3. `PhotoImportService`

No code change. The service already:

- Accepts `baseMetadata: PhotoMetadata` with optional fields.
- Calls `metadata.assignMetadata(perPhotoMetadata, to: record.id.uuidString)` for every imported photo.

When `baseMetadata` is all-nil, this creates a `PhotoMetadata` row with nil fields, which `getIncompleteAssetIds()` already classifies as incomplete. The untagged state is a free consequence of the existing data flow.

### A4. Post-import toast

- Message: `"N imported · Tap Library to tag"`.
- Tap action: `router.navigateToLibrary(filter: LibraryFilter(showUntaggedOnly: true))`.
- Requires extending the global toast handler to support an optional tap action (see C2).

### A5. Analytics

- Extend `AnalyticsService.logPhotoImported` with a `prefilled: Bool` parameter to distinguish portfolio-CTA imports from plain backfills.

## Section B — Library "Needs Tagging" + bulk-tag

### B1. Untagged definition

A photo is untagged iff its `PhotoMetadata` has nil `procedure` OR nil `stage` OR nil `angle`, OR it has no metadata row at all. `MetadataManager.getIncompleteAssetIds()` already computes this over `assetMetadata`; the filter branch additionally treats records without a metadata row as incomplete.

Add `MetadataManager.isIncomplete(assetId: String) -> Bool` for per-record checks inside `filteredRecords`.

Add a published-or-computed `incompleteAssetCount: Int` on `MetadataManager` for badge binding.

### B2. Chip bar above the grid

A new component, `NeedsTaggingChipBar`, rendered above the Library grid. Two chips:

- `All` — default, no filter.
- `Needs Tagging (N)` — sets `LibraryFilter.showUntaggedOnly = true`. N from `incompleteAssetCount`, omitted when 0.

Toggling between chips mutates `router.libraryFilter.showUntaggedOnly`. The chip bar is visible even when N = 0 (tapping it just shows an empty state).

### B3. `LibraryFilter` extension

Add `var showUntaggedOnly: Bool = false`. Update:

- `LibraryFilter.isEmpty` — ignore `showUntaggedOnly` (the chip bar is a separate surface; the filter sheet stays clean).
- `LibraryFilter.activeFilterCount` — unchanged.
- `LibraryFilter.reset()` — set back to false.

### B4. `LibraryViewModel.filteredRecords` branch

Applied before other filter branches:

```swift
if filter.showUntaggedOnly {
    result = result.filter { record in
        metadata.isIncomplete(assetId: record.id.uuidString)
    }
}
```

Composes with other filters (which in practice will return nothing extra, since untagged photos lack procedure/stage/angle to match).

### B5. `SelectionActionBar` gains a "Tag" action

- New icon: `tag.fill`, label "Tag".
- New callback parameter: `onTag: () -> Void`.
- Same premium gating as the rest of selection mode (`.batchOperations`), though the kill switch currently makes all features free.

### B6. `BulkTagSheet`

New sheet component (modeled on `ImportTagEditorSheet`) with **per-field touched semantics**.

State model:

```swift
enum FieldState<Value> {
    case unchanged       // don't write this field on apply
    case set(Value)      // write this value to all selected
    case cleared         // write nil to all selected
}
```

Sections:

- **Procedure** — pills; current display is the shared value if all agree, "(Mixed)" if not, empty if none have it. Tapping sets the field.
- **Tooth** — wheel picker with an "Unchanged" row that stays selected unless the user picks a specific tooth.
- **Stage** — pills, same rules as procedure.
- **Angle** — pills, same rules as procedure.

A "Clear" affordance per section is out of scope for v1; users can only overwrite or leave unchanged.

**Apply** button: `"Apply to N photos"`. On tap:

1. For each selected `assetId`, fetch (or create) `PhotoMetadata`.
2. For each field in `set(value)`, write that value.
3. Call `MetadataManager.assignMetadata(updated, to: assetId)`.
4. If procedure + toothNumber are both set on apply, emit a `ToothEntry` (matching capture/import behavior).
5. Exit selection mode; clear `selectedAssetIds`.
6. Toast: `"Tagged N photo(s)"`.

### B7. Tab bar badge

Wire `DPTabBar.badgeCounts[.library]` to `MetadataManager.shared.incompleteAssetCount`. `ContentView` is the assembly point.

### B8. Analytics

- `bulk_tag_applied` — parameters: `photo_count: Int`, `fields_changed: String` (comma-joined subset of `["procedure","tooth","stage","angle"]`).
- `untagged_filter_viewed` — fired when user taps `Needs Tagging` chip.
- `import_to_library_nudge_tapped` — fired when post-import toast is tapped.

## Section C — Nudges, edge cases, testing

### C1. Home-screen nudge card (`UntaggedPhotosCard`)

Shown when `incompleteAssetCount > 0`. Placement: below the existing home header, above portfolio summary cards.

- Headline: `"N photos need tagging"`.
- Subhead: `"Tag them so they count toward your portfolios"`.
- CTA: `"Tag now"` — navigates to Library with `showUntaggedOnly = true`.
- Dismiss (X).

**Dismissal lifetime**: persists for 2 session launches. Implementation: a `UserDefaults` counter `untaggedCardDismissedRemainingSessions: Int`. On dismiss, set to 2. On `SimFolioApp` launch, if > 0, decrement by 1 and save. The card is suppressed while the value is > 0. After the counter reaches 0 (i.e., on the launch that would make it -1), the card reappears if `incompleteAssetCount > 0`.

### C2. Toast tap support

The current global toast posts via `NotificationCenter.default` with `userInfo: ["message":…, "type":…]`. Extend with an optional key `onTap: @escaping () -> Void`. The toast view in `ContentView` (or wherever the toast is observed) wires a tap gesture that invokes the stored closure and dismisses the toast.

Backwards compat: toasts without an `onTap` stay non-interactive.

### C3. Edge cases

- **Photos deleted before tagging** — `MetadataManager.cleanupOrphanedData` handles it already.
- **Last untagged photo tagged while filter active** — grid shows empty state: `"All caught up · Tap All to see your library."` No auto-pivot; user stays in control.
- **Bulk-tag on photo with no existing metadata row** — `BulkTagSheet.apply` creates a fresh `PhotoMetadata` before writing fields.
- **Mixed values in selection** — `(Mixed)` display; user can overwrite to one value or leave the row unchanged.
- **Prefilled import** — existing portfolio-match indicator logic in `ImportReviewView` unchanged.

### C4. Files to create/modify

**Modify:**
- `SimFolio/Features/Import/ImportReviewView.swift` — hide tag summary + editor sheet when not prefilled.
- `SimFolio/Features/Import/ImportFlowView.swift` — pass `isPrefilledFromPortfolio` down.
- `SimFolio/Services/AnalyticsService.swift` — add `prefilled` to `logPhotoImported`; add `logBulkTagApplied`, `logUntaggedFilterViewed`, `logImportNudgeTapped`.
- `SimFolio/Core/Navigation.swift` — add `showUntaggedOnly: Bool` to `LibraryFilter`; update `reset()`.
- `SimFolio/Features/Library/LibraryView.swift` — insert chip bar above grid; wire filter; add "Tag" action to selection bar; present `BulkTagSheet`.
- `SimFolio/Services/MetadataManager.swift` — add `isIncomplete(assetId:)`; expose `incompleteAssetCount`.
- `SimFolio/App/ContentView.swift` — wire Library tab badge; wire toast tap support.
- `SimFolio/Features/Home/HomeView.swift` — integrate `UntaggedPhotosCard`.
- `SimFolio/SimFolioApp.swift` — decrement the nudge dismissal session counter on launch.

**Create:**
- `SimFolio/Features/Library/BulkTagSheet.swift`.
- `SimFolio/Features/Library/NeedsTaggingChipBar.swift`.
- `SimFolio/Features/Home/UntaggedPhotosCard.swift`.

**Tests:**
- `SimFolioTests/Features/BulkTagSheetTests.swift` — per-field touched semantics, apply logic, mixed-value handling, tooth-entry emission.
- `SimFolioTests/Features/LibraryFilterTests.swift` — `showUntaggedOnly` filtering including records without metadata rows.
- `SimFolioUITests/BulkTagFlowUITests.swift` — end-to-end: import untagged → tap toast → select in Library → apply tags → confirm filter count drops to 0 and card disappears.

### C5. Out of scope (v1)

- Smart tag suggestions from EXIF/date clustering.
- Per-photo tagging during import.
- OCR / image recognition for tag guesses.
- Undo for bulk-tag apply.
- Custom sort in the "Needs Tagging" view.
- Persistent (permanent) dismissal of the home card.

## Success criteria

- A user can import 50 photos and get to the Library in fewer taps than today (no tag pills to touch).
- The "Needs Tagging" chip is the single authoritative surface for untagged photos; its count matches `incompleteAssetCount`.
- Applying tags to a multi-selection in Library writes only the fields the user explicitly set; untouched fields keep each photo's existing per-photo value.
- The home nudge and tab badge disappear naturally as the user tags photos; the card's 2-session dismissal behaves as specified.
- The portfolio-CTA import path is behaviorally unchanged.
