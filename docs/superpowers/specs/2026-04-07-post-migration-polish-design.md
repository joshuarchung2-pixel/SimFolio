# Post-Migration Polish Design Spec

**Goal:** Fix capture settings bugs, add 1px divider borders to Library pills, and allow editing portfolio requirements after creation.

**Scope:** 3 independent changes — a bug fix, a styling fix, and a feature addition.

---

## 1. Capture Settings Fixes

**Problem:** Two issues in `CaptureSettingsView.swift`:
- SwiftUI `Picker` labels ("Flash", "Quality") double up with the adjacent `SettingLabel` titles, showing "Default Flash Flash" and "Image Quality Quality"
- The old "Auto-Save to Photos" toggle (`autoSaveToLibrary`) is redundant now that photos always save to app storage. The newer "Save to Camera Roll" toggle handles the optional Photos copy.

**Fix:**
- Add `.labelsHidden()` to both Picker views to suppress the redundant label text
- Remove the "Auto-Save to Photos" toggle and its `@AppStorage("autoSaveToLibrary")` property entirely
- The "Save to Camera Roll" toggle (defaults `false`) remains as the only Photos-related setting

**Files:** `SimFolio/Features/Profile/Settings/CaptureSettingsView.swift`

---

## 2. Library Pill Borders

**Problem:** The Library quick access pills (`CompactAccessCard`) use plain `.background(AppTheme.Colors.surface)` without the 1px divider border that cards use in Home and Profile. Per the design system (CLAUDE.md: "Cards: Use 1px `divider` borders for elevation instead of shadows"), cards should use a 1px `AppTheme.Colors.divider` border.

**Fix:** Add a `.overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium).stroke(AppTheme.Colors.divider, lineWidth: 1))` to `CompactAccessCard` in `LibraryView.swift`.

Also add the same border to the procedure list rows if they use the same plain surface pattern without a border.

**Files:** `SimFolio/Features/Library/LibraryView.swift`

---

## 3. Portfolio Requirement Editing

**Problem:** Portfolio requirements are locked after creation. Users must delete and recreate a portfolio to change requirements. The user wants to edit, remove, and add requirements on existing portfolios.

### Changes to EditPortfolioSheet

Expand `EditPortfolioSheet` (in `CreatePortfolioSheet.swift`) to include a requirements section below the existing name/due date fields:

**Requirements List:**
- Display each existing requirement as a row showing: procedure name, stage count, angle count, total photos required
- Tap a requirement row → open `RequirementEditorSheet` pre-filled with that requirement's values (the `existingRequirement` parameter already supports this)
- Swipe-to-delete on a requirement row → if the requirement has matching photos in `MetadataManager.assetMetadata`, show a confirmation alert: **"Remove Requirement? This requirement has X matching photos. The photos will remain in your library but will no longer count toward this portfolio."** If no matching photos, delete without confirmation.

**Add Requirement Button:**
- At the bottom of the requirements list, show an "Add Requirement" button (styled like the existing one in `CreatePortfolioSheet`)
- Tapping opens `RequirementEditorSheet` with `existingRequirement: nil`
- On save, append the new requirement to the portfolio's requirements array

**Validation:**
- Portfolio must have at least 1 requirement (disable save if 0)
- Duplicate procedure check: if adding/editing a requirement results in a duplicate procedure, show a warning

**Saving:**
- Build updated `Portfolio` with modified requirements array
- Call `metadataManager.updatePortfolio(updatedPortfolio)` (already exists)

**Remove the "Requirements cannot be edited" info card** — it's no longer true.

### Data Model

No model changes needed. `Portfolio.requirements` is already `var` (mutable), and `PortfolioRequirement` properties are all `var`. `RequirementEditorSheet` already accepts `existingRequirement: PortfolioRequirement?` for edit mode.

### Matching Photo Count

To determine if a requirement has matching photos (for the delete warning), count entries in `MetadataManager.assetMetadata` where `metadata.procedure == requirement.procedure` AND the metadata's stage is in `requirement.stages` AND the metadata's angle is in `requirement.angles`.

### Files

- `SimFolio/Features/Portfolios/CreatePortfolioSheet.swift` (EditPortfolioSheet lives here)
