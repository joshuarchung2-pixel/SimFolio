# Markup Controls Redesign

**Date:** 2026-04-10
**Status:** Approved for implementation planning
**Scope:** Photo editor markup sub-toolbar — visual polish and empty state

## Problem

The markup sub-toolbar inside the photo editor has two issues:

1. **Visual mismatch.** It uses a heavy tile aesthetic (`Color.white.opacity(0.1)` backgrounds on every button, drop shadows on the property panel, `systemGray6` fill) that doesn't match the rest of the photo editor chrome. The mode picker one row above is flat and clean; the markup sub-toolbar below it looks like a different era.
2. **Empty Select mode.** When Select is the active sub-mode and nothing is selected, the property panel is literally empty — a gray box with no content, no hint, no next action.

The effect is that the markup UI looks dated and is hard to use. Users hit an empty panel in Select mode with no guidance on what to do.

## Non-goals

- Changing the dark editor chrome (it's a photo-editor convention and the right call for a photo editor).
- Touching Transform or Adjust modes — they already look fine.
- Changing the markup canvas itself (drawing/selection/handles).
- Changing the set of color/line-width/font-size options or the text input sheet.
- Changing persistence, models, or services.

This is a pure view-layer polish pass scoped to the markup sub-toolbar and the one top-bar change that makes the layout work.

## Design direction

**Flat** treatment, consistent with the existing Transform/Adjust/Markup mode picker in `PhotoEditorView.swift:244`. Button state is communicated by color, not by background tiles. The property panel becomes a borderless region separated from the sub-mode row by a hairline divider, not a floating shadowed box.

The dark chrome stays. The existing teal accent (`AppTheme.Colors.primary`) becomes the single selection indicator everywhere.

### Visual tokens

| Element | Treatment |
|---|---|
| Selected button | `AppTheme.Colors.primary` (teal) icon + label |
| Unselected button | `#C7C7CC` icon + label |
| Disabled button | `#3A3A3C` icon + label |
| Button backgrounds | Removed entirely — no `RoundedRectangle` fills |
| Section labels ("Color", "Line Width", etc.) | `AppTheme.Typography.sectionLabel` (11pt SF Pro semibold) with `.tracking(0.8)` and `.textCase(.uppercase)`, color `#8E8E93` |
| Property panel container | Transparent, hairline top divider (`Color.white.opacity(0.08)`) |
| Panel shadow / clip / fill | Removed |
| Color swatch selection ring | Keep — 3pt `AppTheme.Colors.primary` stroke |
| Swatch / button tap target sizes | Unchanged — already meet HIG minimums |

## Component changes

### Top bar (`PhotoEditorView.swift:124`)

When `editorMode == .markup`, the top bar gains an Undo button between Cancel and the title:

```
[ Cancel ]  [ ↶ ]        Edit Photo        [ Done ]
```

- Icon only (`arrow.uturn.backward`), no label, same white tint as Cancel.
- Disabled when `!viewModel.history.canUndo`, dimmed via `.opacity(0.4)`.
- Hidden in Transform and Adjust modes — those keep the current three-item layout.
- Existing undo state and action wiring (`viewModel.history.canUndo`, `viewModel.undo()`) are already in place; they just get invoked from a new location.

### Sub-mode row (`MarkupControlsView.swift:67`)

The Undo tile goes away. The row becomes four evenly-spaced items:

```
  Select    Draw    Measure    Text
```

Each item is a `SubModeButton` with `.frame(maxWidth: .infinity)` so they divide the row evenly. No tile backgrounds. Icon + caption, teal when selected, `#C7C7CC` otherwise.

### Property panel (`MarkupControlsView.swift:44`)

The current `ZStack { ScrollView ... if hasSelection { actionButtons } }` with `systemGray6` background, `clipShape`, and shadow is replaced by a flat `VStack`:

```
VStack {
  // Hairline top divider
  Divider (1px, white 8%)

  // Inline action row — only when an element is selected
  if hasSelection {
    [ Delete (red) | Front | Back ]
  }

  // Property editors for the active sub-mode
  ScrollView { propertyEditors }

  // OR: empty state when subMode == .select && !hasSelection
  MarkupEmptyStateView(isMarkupEmpty: ...)
}
```

No container fill, no clip, no shadow. The panel visually flows from the sub-mode row above it via the hairline divider.

### Inline action row (new, shown when `hasSelection`)

Replaces the current floating pill overlay. Sits at the top of the property panel, above "Color":

- `[Delete | Front | Back]` evenly spaced.
- Flat icons + captions.
- Delete is red (`AppTheme.Colors.error`), Front/Back are `#C7C7CC`.
- No tile backgrounds.
- Uses the existing `onDelete`, `onBringToFront`, `onSendToBack` callbacks unchanged.

The 60pt bottom padding on `propertyEditors` that was making room for the overlay goes away.

### Empty state (new — `MarkupEmptyStateView`)

Rendered inside the property panel when `subMode == .select && !hasSelection`. Smart / context-aware:

| Condition | Icon | Title | Hint |
|---|---|---|---|
| `isMarkupEmpty == true` | `scribble.variable` | "No marks yet" | "Switch to Draw, Measure, or Text to annotate your photo." |
| `isMarkupEmpty == false` | `hand.point.up` | "Nothing selected" | "Tap a mark on the photo to edit its color or size." |

Centered in the panel, vertical stack, 8pt spacing. Title uses `AppTheme.Typography.sectionLabel`. Icon is 22pt, `#48484A`. Hint is caption-sized, `#8E8E93`, max width ~240pt, line-limited to 2.

Implemented as a small view in the same file as `MarkupControlsView` (<30 lines, doesn't warrant its own file).

### Property editor internals (`MarkupPropertyEditors.swift`)

- `PropertyEditorSection` — label font changes from `AppTheme.Typography.caption` gray to `AppTheme.Typography.sectionLabel` gray. Same structure.
- `LineWidthOptionView` — background `RoundedRectangle.fill(Color.white.opacity(0.1))` removed. Selection is communicated by the line preview changing from `.white` to `AppTheme.Colors.primary`. The selection border `.stroke(...)` stays.
- `FontSizeOptionView` — same treatment: background removed, selection communicated by foreground color (teal when selected, `#C7C7CC` otherwise). Selection border stays.
- `ColorSwatchView`, `FillColorPickerView`, `NoneColorOptionView` — unchanged. The swatches are already flat and the teal selection ring is already correct.

### `SubModeButton` and `ActionButton`

Both lose their `.background(RoundedRectangle…)` modifiers. `SubModeButton` becomes:

```
VStack { icon; label }
  .foregroundStyle(isSelected ? .primary : #C7C7CC)
  .frame(maxWidth: .infinity, minHeight: 50)
```

`ActionButton` loses its `backgroundColor` computed property and its usage. `foregroundColor` stays but becomes the sole state indicator.

## Wiring & data flow

`MarkupControlsView` signature changes:

**Added:**
- `isMarkupEmpty: Bool` — drives the smart empty state. Source: `!viewModel.editState.markup.hasMarkup` passed in from `PhotoEditorView` (reuses the existing computed property on `MarkupState`).

**Removed:**
- `canUndo: Bool`
- `onUndo: (() -> Void)?`

These move up to `PhotoEditorView.topBar`, which already has access to `viewModel.history.canUndo` and `viewModel.undo()`.

No model changes. No persistence changes. No new services. No new state. This is entirely a view-layer refactor.

## Files affected

Three files:

1. **`SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift`**
   - Remove tile backgrounds from `SubModeButton` and `ActionButton`.
   - Restructure body: drop `ZStack`, use flat `VStack` with hairline divider.
   - Remove Undo button from `subModePicker`; make row four evenly-spaced items.
   - Move inline action row to the top of the panel (shown when `hasSelection`).
   - Add `MarkupEmptyStateView` struct and render it when appropriate.
   - Add `isMarkupEmpty: Bool` parameter; remove `canUndo` and `onUndo`.

2. **`SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift`**
   - `PropertyEditorSection` label font → `AppTheme.Typography.sectionLabel`.
   - `LineWidthOptionView` — remove background fill, drive selection via preview color.
   - `FontSizeOptionView` — remove background fill, drive selection via foreground color.

3. **`SimFolio/Features/PhotoEditor/PhotoEditorView.swift`**
   - `topBar` — add conditional Undo button between Cancel and title when `editorMode == .markup`.
   - `markupControlsView` (the internal var that builds `MarkupControlsView`) — pass `isMarkupEmpty: !viewModel.editState.markup.hasMarkup`, drop `canUndo` and `onUndo` parameters.

Untouched:
- `MarkupModels.swift`
- `MarkupCanvasView.swift`
- `MarkupElementViews.swift`
- `MarkupRenderingService.swift`
- `PhotoEditPersistenceService.swift`
- `PhotoEditModels.swift`

## Testing

**Unit tests:** None added. This is pure view-layer work with no logic changes worth covering in `SimFolioTests`.

**UI tests:** Run `SimFolioUITests/PhotoEditorUITests.swift` unchanged. If any test asserts on button tile backgrounds (unlikely — UI tests typically query by accessibility identifier), update those assertions. The accessibility identifiers for `SubModeButton`, `ActionButton`, Undo, and the property editors are preserved.

**Manual verification** on simulator (iPhone 17):

1. Open photo editor, switch to Markup mode.
2. **Empty markup state.** Immediately tap Select. Panel should show `scribble.variable` icon, "No marks yet" title, "Switch to Draw, Measure, or Text..." hint.
3. **Populated but nothing selected.** Draw a freeform line. Switch back to Select, don't tap the line. Panel should show `hand.point.up` icon, "Nothing selected" title, "Tap a mark on the photo to edit its color or size." hint.
4. **Element selected.** Tap the line. Panel should show `[Delete | Front | Back]` at the top, then Color section, then Line Width section.
5. **Undo in top bar.** Verify Undo button appears in top bar only when `editorMode == .markup`. Disabled on fresh load. Enabled after drawing. Works.
6. **All four sub-modes.** Each should render its property editors flat, legible, with New York serif uppercase section labels.
7. **Transform and Adjust modes.** Confirm they're unchanged — no Undo in top bar, no layout regressions.

## Build verification

Standard build command:

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Then the UI test suite:

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SimFolioUITests/PhotoEditorUITests 2>&1 | tail -40
```
