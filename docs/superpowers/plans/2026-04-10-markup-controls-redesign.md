# Markup Controls Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flatten the photo editor's markup sub-toolbar, add a smart empty state for Select mode, and relocate Undo from the sub-mode row to the editor top bar.

**Architecture:** Pure view-layer refactor across three SwiftUI files. No model, service, or persistence changes. Each flattening task removes tile backgrounds and drives selection state through `foregroundStyle` alone, matching the treatment already used by the Transform/Adjust/Markup mode picker. The signature of `MarkupControlsView` changes to add an `isMarkupEmpty` input and drop the `canUndo`/`onUndo` inputs. A small local `MarkupEmptyStateView` covers the Select-with-nothing-selected state with context-aware copy.

**Tech Stack:** SwiftUI, Swift, iOS 16+, `AppTheme` design tokens, Xcode 16, `xcodebuild` for verification.

**Spec:** `docs/superpowers/specs/2026-04-10-markup-controls-redesign-design.md`

---

## File Inventory

**Modified (3):**
- `SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift`
- `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift`
- `SimFolio/Features/PhotoEditor/PhotoEditorView.swift`

**Untouched:** `MarkupModels.swift`, `MarkupCanvasView.swift`, `MarkupElementViews.swift`, `MarkupRenderingService.swift`, `PhotoEditPersistenceService.swift`, `PhotoEditModels.swift`.

**Line numbers note:** All line numbers in task headers refer to the ORIGINAL file state at the start of this plan. As tasks modify files, line numbers will shift slightly. Always locate target code by the struct / property / function name (e.g. "the `ActionButton` struct"), not by absolute line number.

---

## Task 1: Update `PropertyEditorSection` typography

Switch section labels from the caption font/gray treatment to the app's established uppercase-tracked section label style.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift:280-293`

- [ ] **Step 1: Replace the `PropertyEditorSection` body**

Open `SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift`. Replace the entire `PropertyEditorSection` struct (currently at lines 280-293) with:

```swift
/// Section wrapper for property editors with label
struct PropertyEditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "8E8E93"))

            content()
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift
git commit -m "$(cat <<'EOF'
refactor: use sectionLabel typography in markup property sections

Switch the "Color" / "Line Width" / "Font Size" / "Fill Color"
labels to the app's existing uppercase-tracked sectionLabel style.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Flatten `LineWidthOptionView`

Remove the tile background. Selection is communicated by the line preview changing to teal and a subtle border staying around the selected option.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift:137-164`

- [ ] **Step 1: Replace the `LineWidthOptionView` body**

Replace the entire `LineWidthOptionView` struct (currently at lines 137-164) with:

```swift
/// Individual line width option
struct LineWidthOptionView: View {
    let width: LineWidth
    let isSelected: Bool

    private let optionSize: CGFloat = 44

    var body: some View {
        ZStack {
            // Line preview — teal when selected, white otherwise
            RoundedRectangle(cornerRadius: width.pointWidth / 2)
                .fill(isSelected ? AppTheme.Colors.primary : .white)
                .frame(width: optionSize - 16, height: width.pointWidth)

            // Selection border
            if isSelected {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(AppTheme.Colors.primary, lineWidth: 2)
                    .frame(width: optionSize, height: optionSize)
            }
        }
        .frame(width: optionSize, height: optionSize)
        .contentShape(Rectangle())
    }
}
```

Note: The `RoundedRectangle(...).fill(isSelected ? ... : Color.white.opacity(0.1))` background is gone. The `contentShape(Rectangle())` ensures the whole 44x44 area remains tappable after the background is removed.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift
git commit -m "$(cat <<'EOF'
refactor: flatten line width option view

Remove the tile background; selection is communicated by the line
preview filling in teal and a subtle border around the selected option.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Flatten `FontSizeOptionView`

Remove the tile background. Selection is communicated by the "Aa" glyph turning teal.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift:191-210`

- [ ] **Step 1: Replace the `FontSizeOptionView` body**

Replace the entire `FontSizeOptionView` struct (currently at lines 191-210) with:

```swift
/// Individual font size option
struct FontSizeOptionView: View {
    let size: FontSize
    let isSelected: Bool

    var body: some View {
        Text("Aa")
            .font(.system(size: size.pointSize * 0.8))
            .foregroundStyle(isSelected ? AppTheme.Colors.primary : Color(hex: "C7C7CC"))
            .frame(width: 50, height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
    }
}
```

Note: The background `RoundedRectangle(...).fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.1))` is gone. The selection overlay border stays.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupPropertyEditors.swift
git commit -m "$(cat <<'EOF'
refactor: flatten font size option view

Remove the tile background; selection is communicated by the "Aa"
glyph turning teal and the existing selection border.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Flatten `SubModeButton`

Remove the tile background. Drive selection via `foregroundStyle` only. Remove the fixed 60pt width so the button can stretch evenly when embedded in an `HStack` with `maxWidth: .infinity` frames.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift:264-286`

- [ ] **Step 1: Replace the `SubModeButton` body**

Open `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift`. Replace the entire `SubModeButton` struct (currently at lines 264-286) with:

```swift
// MARK: - Sub-Mode Button

/// Button for selecting a sub-mode
struct SubModeButton: View {
    let mode: MarkupSubMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18))
                Text(mode.rawValue)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(isSelected ? AppTheme.Colors.primary : Color(hex: "C7C7CC"))
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
    }
}
```

Changes:
- Removed the `.background(RoundedRectangle(...).fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.1)))`.
- Changed `foregroundStyle(isSelected ? .white : .gray)` to `foregroundStyle(isSelected ? AppTheme.Colors.primary : Color(hex: "C7C7CC"))`.
- Changed `.frame(width: 60, height: 50)` to `.frame(maxWidth: .infinity, minHeight: 50)` so buttons stretch evenly in the HStack.
- Added `.contentShape(Rectangle())` to keep the full area tappable.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift
git commit -m "$(cat <<'EOF'
refactor: flatten markup sub-mode button

Remove the tile background; selection is communicated by teal tint
alone. Make the button stretch evenly so the row can be split across
Select/Draw/Measure/Text with equal widths.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Flatten `ActionButton`

Remove the tile background and the `backgroundColor` computed property. Selection state is communicated by icon color alone (Delete red, Front/Back gray).

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift:288-341`

- [ ] **Step 1: Replace the `ActionButton` struct**

Replace the entire `ActionButton` struct (currently at lines 288-341) with:

```swift
// MARK: - Action Button

/// Styled action button for markup actions
struct ActionButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return AppTheme.Colors.primary
        case .secondary:
            return Color(hex: "C7C7CC")
        case .destructive:
            return AppTheme.Colors.error
        }
    }
}
```

Changes:
- Removed the `.background(RoundedRectangle(...).fill(backgroundColor))`.
- Removed the `backgroundColor` computed property entirely.
- Changed `.foregroundColor` for `.secondary` from `.white` to `Color(hex: "C7C7CC")` and for `.destructive` from `.white` to `AppTheme.Colors.error`. `.primary` becomes `AppTheme.Colors.primary` (was `.white`).
- Changed `.frame(width: 60, height: 44)` to `.frame(maxWidth: .infinity, minHeight: 44)` so buttons stretch evenly in the inline action row.
- Added `.contentShape(Rectangle())`.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift
git commit -m "$(cat <<'EOF'
refactor: flatten markup action button

Remove tile background; Delete is red, Front/Back are gray via
foreground color alone. Stretch buttons evenly for an inline row.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Add `MarkupEmptyStateView`

Introduce the smart/context-aware empty state view. It has no callers yet — it'll be wired up in Task 8.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift` (append new struct)

- [ ] **Step 1: Add the struct at the bottom of the file**

Open `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift` and add the following struct at the very bottom of the file (after `TextInputSheetView`, which currently ends around line 389):

```swift
// MARK: - Markup Empty State View

/// Context-aware empty state for Select sub-mode when nothing is selected.
/// Shows different copy depending on whether the photo has any markup elements.
struct MarkupEmptyStateView: View {
    let isMarkupEmpty: Bool

    private var iconName: String {
        isMarkupEmpty ? "scribble.variable" : "hand.point.up"
    }

    private var title: String {
        isMarkupEmpty ? "No marks yet" : "Nothing selected"
    }

    private var hint: String {
        isMarkupEmpty
            ? "Switch to Draw, Measure, or Text to annotate your photo."
            : "Tap a mark on the photo to edit its color or size."
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "48484A"))
                .accessibilityHidden(true)

            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "8E8E93"))

            Text(hint)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. The struct is unused at this point — that's fine, no warning because it's a top-level public type.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift
git commit -m "$(cat <<'EOF'
feat: add MarkupEmptyStateView for select mode

Context-aware empty state shown when Select is the active sub-mode
and nothing is selected. Different copy depending on whether the
photo already has any markup elements.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `isMarkupEmpty` parameter to `MarkupControlsView` and wire the call site

Add the new parameter with a default of `false` so we don't break the call site in a single edit. In the same task, pass the real value from `PhotoEditorView`. `canUndo`/`onUndo` still exist and are still passed — those are removed in Task 10.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift:14-36`
- Modify: `SimFolio/Features/PhotoEditor/PhotoEditorView.swift:361-399`

- [ ] **Step 1: Add the new parameter to the struct declaration**

In `MarkupControlsView.swift`, locate the property block at the top of `MarkupControlsView` (currently lines 14-36). Add `let isMarkupEmpty: Bool` immediately after `let selectedElementType: MarkupElementType?`. The relevant block should look like this afterward:

```swift
struct MarkupControlsView: View {
    @Binding var subMode: MarkupSubMode
    @Binding var selectedColor: MarkupColor
    @Binding var selectedLineWidth: LineWidth
    @Binding var selectedFontSize: FontSize
    @Binding var selectedFillColor: MarkupColor?

    let hasSelection: Bool
    let selectedElementType: MarkupElementType?
    let isMarkupEmpty: Bool

    // Undo state
    var canUndo: Bool = false

    // Action callbacks
    var onUndo: (() -> Void)?
    var onDelete: (() -> Void)?
    var onBringToFront: (() -> Void)?
    var onSendToBack: (() -> Void)?
    var onColorChanged: ((MarkupColor) -> Void)?
    var onLineWidthChanged: ((LineWidth) -> Void)?
    var onFontSizeChanged: ((FontSize) -> Void)?
    var onFillColorChanged: ((MarkupColor?) -> Void)?
    var onClearAll: (() -> Void)?
```

(Only the `let isMarkupEmpty: Bool` line is new. Everything else is unchanged.)

- [ ] **Step 2: Pass `isMarkupEmpty` from the call site**

In `PhotoEditorView.swift`, locate `markupControlsView` (currently lines 361-399). Add one line after `selectedElementType:`:

```swift
private var markupControlsView: some View {
    MarkupControlsView(
        subMode: $viewModel.markupSubMode,
        selectedColor: $viewModel.selectedMarkupColor,
        selectedLineWidth: $viewModel.selectedLineWidth,
        selectedFontSize: $viewModel.selectedFontSize,
        selectedFillColor: $viewModel.selectedFillColor,
        hasSelection: viewModel.editState.markup.selectedElementId != nil,
        selectedElementType: viewModel.selectedMarkupElementType,
        isMarkupEmpty: !viewModel.editState.markup.hasMarkup,
        canUndo: viewModel.history.canUndo,
        onUndo: {
            viewModel.undo()
        },
        onDelete: {
            viewModel.deleteSelectedMarkupElement()
        },
        onBringToFront: {
            viewModel.bringSelectedMarkupToFront()
        },
        onSendToBack: {
            viewModel.sendSelectedMarkupToBack()
        },
        onColorChanged: { color in
            viewModel.updateSelectedMarkupColor(color)
        },
        onLineWidthChanged: { width in
            viewModel.updateSelectedMarkupLineWidth(width)
        },
        onFontSizeChanged: { size in
            viewModel.updateSelectedMarkupFontSize(size)
        },
        onFillColorChanged: { color in
            viewModel.updateSelectedMarkupFillColor(color)
        },
        onClearAll: {
            viewModel.clearAllMarkup()
        }
    )
}
```

(Only the `isMarkupEmpty: !viewModel.editState.markup.hasMarkup,` line is new. Everything else is unchanged.)

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. `isMarkupEmpty` is unused inside `MarkupControlsView` at this point — that's fine.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift SimFolio/Features/PhotoEditor/PhotoEditorView.swift
git commit -m "$(cat <<'EOF'
feat: add isMarkupEmpty input to MarkupControlsView

Adds a new input that reflects whether the photo has any markup
elements. Wired up at the call site using the existing hasMarkup
computed property. Consumed by the body restructure in a follow-up.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Restructure `MarkupControlsView` body and sub-mode picker

Replace the `ZStack`-with-overlay structure with a flat `VStack`. Move action buttons from a floating pill overlay to an inline row at the top of the property panel. Drop the Undo button from `subModePicker`. Add the empty state view for Select mode. The Undo button will reappear in the top bar in Task 9 — between Tasks 8 and 9 there is no visible undo button in markup mode (this is a brief transient state; Task 9 fixes it).

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift:38-100`

- [ ] **Step 1: Replace the `body` property**

Replace the `var body: some View { ... }` block (currently lines 38-63) with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            subModePicker
                .padding(.top, AppTheme.Spacing.xs)
                .padding(.bottom, AppTheme.Spacing.sm)

            // Hairline divider separating sub-mode row from panel
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            if subMode == .select && !hasSelection {
                MarkupEmptyStateView(isMarkupEmpty: isMarkupEmpty)
            } else {
                VStack(spacing: 0) {
                    // Inline action row — shown whenever an element is selected
                    if hasSelection {
                        actionButtons
                            .padding(.top, AppTheme.Spacing.sm)
                            .padding(.bottom, AppTheme.Spacing.xs)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        propertyEditors
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
```

Gone:
- The outer `ZStack(alignment: .bottom)`.
- `.background(Color(uiColor: .systemGray6))`.
- `.clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))`.
- `.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: -2)`.
- The `hasSelection ? 60 : AppTheme.Spacing.sm` bottom padding hack for the overlay.
- The floating `actionButtons` as an overlay (it's now inline at the top of the panel block).

- [ ] **Step 2: Replace the `subModePicker` private var**

Replace the `subModePicker` block (currently lines 67-100) with:

```swift
    // MARK: - Sub-Mode Picker

    private var subModePicker: some View {
        HStack(spacing: 0) {
            ForEach(MarkupSubMode.allCases) { mode in
                SubModeButton(
                    mode: mode,
                    isSelected: subMode == mode
                ) {
                    subMode = mode
                }
            }
        }
    }
```

Gone:
- The Undo button at the leading edge.
- The `Spacer()` that separated Undo from the sub-mode buttons.
- The `HStack(spacing: AppTheme.Spacing.sm)`.

`SubModeButton` was updated in Task 4 to use `.frame(maxWidth: .infinity)`, so all four items evenly divide the row width.

- [ ] **Step 3: Remove the overlay padding and container styling from `actionButtons`**

Locate the `actionButtons` private var (currently lines 215-250). Replace it with:

```swift
    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 0) {
            // Delete button
            ActionButton(
                title: "Delete",
                icon: "trash",
                style: .destructive
            ) {
                onDelete?()
            }

            // Bring to front
            ActionButton(
                title: "Front",
                icon: "square.3.layers.3d.top.filled",
                style: .secondary
            ) {
                onBringToFront?()
            }

            // Send to back
            ActionButton(
                title: "Back",
                icon: "square.3.layers.3d.bottom.filled",
                style: .secondary
            ) {
                onSendToBack?()
            }
        }
    }
```

Gone:
- `.padding(.horizontal, AppTheme.Spacing.md)`, `.padding(.vertical, AppTheme.Spacing.xs)`, and `.background(RoundedRectangle(...).fill(Color(uiColor: .systemGray5)))` — all part of the old floating pill.

`ActionButton` was updated in Task 5 to use `.frame(maxWidth: .infinity)`, so Delete/Front/Back evenly divide the row width.

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Warning: `canUndo` and `onUndo` are now unused in the struct body — that's expected; they are removed in Task 10.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift
git commit -m "$(cat <<'EOF'
refactor: flatten markup controls layout

Replace ZStack overlay + shadowed container with a flat VStack that
uses a hairline divider. Move action buttons from a floating pill
overlay to an inline row at the top of the panel. Drop the Undo tile
from the sub-mode row so Select/Draw/Measure/Text can share the
width evenly. Wire MarkupEmptyStateView for Select mode.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add Undo button to `PhotoEditorView.topBar` in markup mode

Add a conditional Undo button between Cancel and the title, shown only when `editorMode == .markup`.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/PhotoEditorView.swift:124-154`

- [ ] **Step 1: Replace the `topBar` property**

Locate `topBar` in `PhotoEditorView.swift` (currently lines 124-154) and replace it with:

```swift
    private var topBar: some View {
        HStack {
            // Cancel button
            Button(action: { handleCancel() }) {
                Text("Cancel")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white)
            }
            .padding(.leading, AppTheme.Spacing.md)

            // Undo button — markup mode only
            if editorMode == .markup {
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(viewModel.history.canUndo ? 1.0 : 0.4)
                }
                .disabled(!viewModel.history.canUndo)
                .padding(.leading, AppTheme.Spacing.md)
                .accessibilityLabel("Undo")
            }

            Spacer()

            // Title
            Text("Edit Photo")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)

            Spacer()

            // Save button
            Button(action: { saveEdits() }) {
                Text("Done")
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(viewModel.editState.hasChanges ? AppTheme.Colors.primary : .gray)
            }
            .disabled(!viewModel.editState.hasChanges || isSaving)
            .padding(.trailing, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(Color.black.opacity(0.8))
    }
```

Only the `if editorMode == .markup { ... }` block is new. Everything else is unchanged.

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/PhotoEditor/PhotoEditorView.swift
git commit -m "$(cat <<'EOF'
feat: add undo button to photo editor top bar in markup mode

The undo control moves from the markup sub-mode row into the top bar
between Cancel and the title, shown only when Markup is the active
editor mode. Opacity reflects canUndo state.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Remove `canUndo` and `onUndo` from `MarkupControlsView`

Now that nothing uses them inside `MarkupControlsView`, drop the parameters from the struct and from the call site.

**Files:**
- Modify: `SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift:14-36`
- Modify: `SimFolio/Features/PhotoEditor/PhotoEditorView.swift:361-399`

- [ ] **Step 1: Remove the properties from the struct**

In `MarkupControlsView.swift`, locate the property block at the top of `MarkupControlsView`. Delete these three lines:

```swift
    // Undo state
    var canUndo: Bool = false

    // Action callbacks
    var onUndo: (() -> Void)?
```

And change the remaining `// Action callbacks` comment to just one block. The block should look like this afterward:

```swift
struct MarkupControlsView: View {
    @Binding var subMode: MarkupSubMode
    @Binding var selectedColor: MarkupColor
    @Binding var selectedLineWidth: LineWidth
    @Binding var selectedFontSize: FontSize
    @Binding var selectedFillColor: MarkupColor?

    let hasSelection: Bool
    let selectedElementType: MarkupElementType?
    let isMarkupEmpty: Bool

    // Action callbacks
    var onDelete: (() -> Void)?
    var onBringToFront: (() -> Void)?
    var onSendToBack: (() -> Void)?
    var onColorChanged: ((MarkupColor) -> Void)?
    var onLineWidthChanged: ((LineWidth) -> Void)?
    var onFontSizeChanged: ((FontSize) -> Void)?
    var onFillColorChanged: ((MarkupColor?) -> Void)?
    var onClearAll: (() -> Void)?
```

- [ ] **Step 2: Drop the arguments from the call site**

In `PhotoEditorView.swift`, locate `markupControlsView`. Delete the `canUndo:` line and the `onUndo:` closure. The call site should look like this afterward:

```swift
    private var markupControlsView: some View {
        MarkupControlsView(
            subMode: $viewModel.markupSubMode,
            selectedColor: $viewModel.selectedMarkupColor,
            selectedLineWidth: $viewModel.selectedLineWidth,
            selectedFontSize: $viewModel.selectedFontSize,
            selectedFillColor: $viewModel.selectedFillColor,
            hasSelection: viewModel.editState.markup.selectedElementId != nil,
            selectedElementType: viewModel.selectedMarkupElementType,
            isMarkupEmpty: !viewModel.editState.markup.hasMarkup,
            onDelete: {
                viewModel.deleteSelectedMarkupElement()
            },
            onBringToFront: {
                viewModel.bringSelectedMarkupToFront()
            },
            onSendToBack: {
                viewModel.sendSelectedMarkupToBack()
            },
            onColorChanged: { color in
                viewModel.updateSelectedMarkupColor(color)
            },
            onLineWidthChanged: { width in
                viewModel.updateSelectedMarkupLineWidth(width)
            },
            onFontSizeChanged: { size in
                viewModel.updateSelectedMarkupFontSize(size)
            },
            onFillColorChanged: { color in
                viewModel.updateSelectedMarkupFillColor(color)
            },
            onClearAll: {
                viewModel.clearAllMarkup()
            }
        )
    }
```

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. No more unused-property warnings on `canUndo`/`onUndo`.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/PhotoEditor/Markup/MarkupControlsView.swift SimFolio/Features/PhotoEditor/PhotoEditorView.swift
git commit -m "$(cat <<'EOF'
refactor: drop canUndo/onUndo from MarkupControlsView

Undo now lives in the top bar, so MarkupControlsView no longer needs
to know about undo state or callbacks.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Run UI test suite and manual verification

Sanity-check the existing UI tests, then manually verify each behavioral path from the spec in the simulator.

**Files:** None modified.

- [ ] **Step 1: Run the photo editor UI test suite**

Run:
```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioUITests/PhotoEditorUITests 2>&1 | tail -40
```

Expected: all tests pass. If any test fails because it was asserting on the old tile backgrounds (unlikely — UI tests usually query by accessibility identifier), note the failure and either update the assertion or flag it to the user.

- [ ] **Step 2: Launch the app in the simulator and verify the golden paths**

Run:
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -launch-arguments '--with-sample-data' build 2>&1 | tail -10
open -a Simulator
```

Then through the simulator UI:

1. **Open photo editor.** Navigate to a photo and open the editor. Confirm Transform, Adjust, and Markup modes all still appear in the mode picker.

2. **Transform and Adjust unchanged.** Tap Transform, confirm no regressions. Tap Adjust, confirm no regressions and no Undo button in the top bar.

3. **Markup mode — empty markup state.** Tap Markup, then tap Select. Verify:
   - Property panel shows `scribble.variable` icon, "NO MARKS YET" title (uppercase tracked), and "Switch to Draw, Measure, or Text to annotate your photo." hint.
   - Undo button appears in top bar, disabled (opacity 0.4).

4. **Markup mode — populated but nothing selected.** Switch to Draw, draw a freeform line on the photo. Switch back to Select, do not tap the line. Verify:
   - Property panel shows `hand.point.up` icon, "NOTHING SELECTED" title, and "Tap a mark on the photo to edit its color or size." hint.
   - Undo button is now enabled (full opacity).

5. **Markup mode — element selected.** Tap the freeform line. Verify:
   - Inline action row [Delete | Front | Back] appears at the top of the property panel, flat, evenly spaced, Delete in red.
   - Below that: Color section and Line Width section using New York-adjacent uppercase tracked section labels.
   - No floating pill at the bottom.

6. **Markup mode — sub-mode row.** Verify Select/Draw/Measure/Text are evenly spaced across the row, no Undo tile at the leading edge, selected mode is teal, unselected are light gray.

7. **Undo actually works.** With a line drawn and selected, tap the top-bar Undo button. The line should disappear, the panel should return to the "No marks yet" empty state, and Undo should become disabled.

8. **Switch modes.** Tap Transform or Adjust. Verify the Undo button disappears from the top bar. Return to Markup. Verify Undo reappears.

- [ ] **Step 3: Commit any UI test updates (if made) or skip if none**

If Step 1 required updating any UI test assertions:

```bash
git add SimFolioUITests/PhotoEditorUITests.swift
git commit -m "$(cat <<'EOF'
test: update photo editor UI test assertions for flat markup toolbar

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Otherwise skip this step.

---

## Done criteria

All 11 tasks complete, each ending in `BUILD SUCCEEDED`. The photo editor UI test suite passes. Manual verification of all 8 paths in Task 11 Step 2 passes.
