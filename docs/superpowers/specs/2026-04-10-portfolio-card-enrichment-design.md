# Portfolio Card Enrichment — Home

**Date:** 2026-04-10
**Status:** Approved, ready for implementation plan
**Scope:** `SimFolio/Features/Home/HomeView.swift` (`PortfolioRowCard`), `SimFolio/Services/MetadataManager.swift`

## Problem

The `PortfolioRowCard` on the home page currently shows only the portfolio name, due date, completion percentage, and a progress bar. It gives no sense of what is inside the portfolio — which procedures it covers, how many photos have been captured, or what the work actually looks like. Users have to tap into the detail view to see anything concrete.

## Goal

Enrich the card with a compact thumbnail strip and a denser caption line, so a student can glance at the home screen and see (a) how many procedures a portfolio spans, (b) how many photos are in vs. required, and (c) a visual preview of the procedures themselves — without tapping in.

## Non-goals

- No change to `PortfolioDetailView` or the portfolio list screen
- No new filtering, sorting, or interaction on the card (it remains a tap-to-navigate row)
- No "next action" hints or missing-angle summaries (deferred — considered under Route C during brainstorming)
- No changes to the Recent captures strip above the Portfolios section

## Layout

```
┌─────────────────────────────────────────────┐
│ Fall 2024 Restorative                 42%  │
│ Due Apr 24 · 12/30 photos · 5 procedures    │
│                                             │
│ [◼︎] [◼︎] [◼︎] [◼︎]  +2                       │
│                                             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━      │
└─────────────────────────────────────────────┘
```

Rows, top to bottom:

1. **Title row** — unchanged. Portfolio name left (`AppTheme.Typography.headline`, `textPrimary`), completion `%` right (`AppTheme.Typography.footnote.weight(.semibold)`, `textSecondary`).
2. **Caption row** — new merged caption. Dot-separated, `AppTheme.Typography.caption`, `textSecondary` for segments, `textTertiary` for dots. Segment order and graceful degradation:
   - With due date + photos + procedures: `Due Apr 24 · 12/30 photos · 5 procedures`
   - No due date: `12/30 photos · 5 procedures`
   - Single procedure: `Due Apr 24 · 12/30 photos · 1 procedure` (singular)
   - Zero requirements: caption row hides entirely (nothing to show — `0/0 photos` is noise)
3. **Thumbnail strip** — new. Up to 4 square thumbs, 44pt × 44pt, 8pt corner radius, 2pt border using `AppTheme.procedureBorderColor(for:)` keyed to the thumb's procedure so each reads as its procedure. 8pt gap between thumbs. If the portfolio's requirements span more than 4 distinct procedures, render the 4 most-recent and append a `+N` pill after the last thumb (44pt height, width fits content with 12pt horizontal padding, fully rounded capsule, `AppTheme.Colors.surface` background with 1pt `divider` border, label format `+N` in `AppTheme.Typography.caption.weight(.medium)`, `textSecondary`). Hidden entirely when the portfolio has zero matching photos (see Empty State).
4. **Progress bar** — unchanged (`DPProgressBar`).

Vertical padding, background, border, and corner radius all unchanged. Estimated card height: ~130pt with a full strip, ~90pt when the strip is hidden (vs. current ~80pt).

## Data flow

### New helper on `MetadataManager`

```swift
/// One representative photo per distinct procedure in the portfolio's requirements.
/// Returns all procedures that have at least one matching photo, ordered by the
/// representative's capture date (newest procedure first). Caller applies any
/// display limit and computes overflow.
func getProcedureRepresentatives(
    for portfolio: Portfolio
) -> [(assetId: String, procedure: String)]
```

**Matching semantics:** procedure-only. A photo tagged `Class 1 / Preparation / Occlusal` counts as a Class 1 representative even if the portfolio's Class 1 requirement specifies a different stage or angle. This is intentional: the strip visualizes the procedures the portfolio *covers*, not strict fulfillment — the `%` and `12/30 photos` already convey fulfillment. A stricter match would hide photos a student legitimately captured for the same procedure category and feel misleading.

**Algorithm:**

1. Build `requiredProcedures: Set<String>` from `portfolio.requirements.map(\.procedure)`.
2. Build a lookup `photoDates: [String: Date]` from `PhotoStorageService.shared.records` (keyed by UUID string → `createdDate`).
3. Walk `assetMetadata`. For each entry whose `procedure` is in `requiredProcedures`, consider the corresponding `photoDates[assetId]`. If no date is found (metadata without a matching record), skip.
4. Group by procedure. For each procedure, keep the entry with the newest `createdDate`. **Tie-break:** if two entries for the same procedure share `createdDate`, keep the one with the lexicographically smaller `assetId` (stable, independent of dictionary iteration order).
5. Sort the grouped winners by `createdDate` descending. **Tie-break:** same as above — lexicographically smaller `assetId` wins.
6. Return all `(assetId, procedure)` tuples.

**Complexity:** O(M + R + P log P) where M = asset metadata entries, R = photo records, P = distinct procedures with at least one matching photo. M and R are both expected to be small for typical student portfolios (hundreds, not tens of thousands), so we do not cache.

### Supporting derived values in `PortfolioRowCard`

Computed as properties on the card, recomputed per render:

- `allRepresentatives: [(assetId, procedure)]` via the new helper (all procedures with photos)
- `visibleRepresentatives: [(assetId, procedure)]` = `allRepresentatives.prefix(4)`
- `overflowCount: Int` = `max(0, allRepresentatives.count - 4)` (drives the `+N` pill — only counts procedures that have photos but didn't fit)
- `distinctProcedureCount: Int` = `Set(portfolio.requirements.map(\.procedure)).count` (used only for the caption row's `5 procedures` label — this is the total count from requirements, whether or not they have photos yet)
- Existing `stats` and `completionPercentage` (unchanged)

Reactivity is automatic: `PortfolioRowCard` already holds `@ObservedObject var metadataManager = MetadataManager.shared`, so tagging or deleting a photo republishes and the card refreshes.

### Thumbnail loading

A new subview, private to `HomeView.swift`:

```swift
private struct PortfolioThumbStrip: View {
    let visibleRepresentatives: [(assetId: String, procedure: String)]  // already capped at 4
    let overflowCount: Int
    // body: HStack of ProcedureThumbView + optional "+N" pill
}

private struct ProcedureThumbView: View {
    let assetId: String
    let procedure: String
    @State private var image: UIImage?
    // body: 44pt square, procedure-colored border, loads thumbnail on appear
}
```

Each `ProcedureThumbView` calls `PhotoStorageService.shared.loadThumbnail(id:)` in `.onAppear`, mirroring the existing `RecentThumbnailView` pattern (HomeView.swift:257). `assetId` is converted to `UUID` for the call. A failed load falls back to a solid `AppTheme.procedureBackgroundColor(for: procedure)` square (no spinner, no placeholder icon) — acceptable because the procedure-colored border still identifies the tile.

## Empty state

A portfolio with zero matching photos renders **without** the thumbnail strip row. The card collapses to title row + caption row + progress bar (~90pt tall). The caption becomes, e.g., `Due Apr 24 · 0/30 photos · 5 procedures`. Rationale: dashed placeholders would add visual noise for the least valuable portfolios; hiding keeps the home page clean and nudges the user toward the "New Portfolio" affordance or the capture tab.

## Error handling

- **Thumbnail load failure:** fall back to a solid procedure-color square (no error UI).
- **Missing `PhotoRecord` for a metadata entry:** entry is skipped in step 3 of the algorithm. Do not crash, do not log.
- **Empty `assetMetadata`:** `getProcedureRepresentatives` returns `[]`; card hides the strip (handled by Empty State).
- **Portfolio with zero requirements:** `distinctProcedureCount` is 0, strip hides, caption degrades to due date only (or nothing).

## Testing

### Unit tests (`SimFolioTests`)

Add tests for `MetadataManager.getProcedureRepresentatives`:

1. Zero matching photos → returns `[]`.
2. One photo per procedure, 3 procedures → returns all 3, ordered by date desc.
3. Multiple photos for same procedure → returns only the newest one for that procedure.
4. 6 procedures with photos → returns all 6 sorted by date desc (caller slices to 4 + computes overflow `2`).
5. Metadata entry with no matching `PhotoRecord` → excluded from results.
6. Procedure required by portfolio but no photos captured → procedure not in results (does not contribute to overflow).
7. Same-date tie → lexicographically smaller `assetId` wins, both within a procedure group and between groups.

### Visual / manual checks

- Portfolio with 1, 2, 4, and 6+ procedures — strip renders with correct count and `+N` pill.
- Portfolio with 0 captured photos — strip hidden, card height reduced.
- Tagging a new photo updates the strip without needing to leave the home screen.
- Dark mode: borders and placeholders remain legible.
- VoiceOver: the card's accessibility label still reads as a single element; thumbnails are not individually focusable.

## Out of scope / future work

- Animated thumbnail transitions when new photos arrive
- Per-thumbnail tap to jump to that photo (currently the whole card taps to portfolio detail)
- "Missing angles" hint (Route C)
- Persisted thumbnail cache for instant render
