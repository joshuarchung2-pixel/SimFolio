# Post-Migration Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix capture settings bugs, add divider borders to Library pills, and allow editing portfolio requirements after creation.

**Architecture:** Three independent changes. Tasks 1-2 are styling/bug fixes in single files. Task 3 expands `EditPortfolioSheet` to include requirement management using the existing `RequirementPreviewRow` and `RequirementEditorSheet` components.

**Tech Stack:** Swift, SwiftUI

**Spec:** `docs/superpowers/specs/2026-04-07-post-migration-polish-design.md`

**Build command (no simulator):**
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

---

## Files Overview

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `SimFolio/Features/Profile/Settings/CaptureSettingsView.swift` | Remove old toggle, fix picker labels |
| Modify | `SimFolio/Features/Library/LibraryView.swift` | Add 1px divider border to CompactAccessCard |
| Modify | `SimFolio/Features/Portfolios/CreatePortfolioSheet.swift` | Expand EditPortfolioSheet with requirement editing |

---

## Task 1: Fix Capture Settings

**Files:**
- Modify: `SimFolio/Features/Profile/Settings/CaptureSettingsView.swift`

Two bugs: redundant Picker labels and a leftover toggle.

- [ ] **Step 1: Remove the old "Auto-Save to Photos" toggle**

Delete the `@AppStorage("autoSaveToLibrary")` property (line 29):

```swift
// DELETE THIS LINE:
@AppStorage("autoSaveToLibrary") private var autoSaveToLibrary = true
```

Delete the "Auto-Save Toggle" from `savingSection` (lines 152-159). The section should start directly with the Image Quality picker. Remove the entire Toggle block:

```swift
// DELETE THIS BLOCK from savingSection:
// Auto-Save Toggle
Toggle(isOn: $autoSaveToLibrary) {
    SettingLabel(
        icon: "square.and.arrow.down.fill",
        title: "Auto-Save to Photos",
        subtitle: "Save captures to photo library"
    )
}
.tint(AppTheme.Colors.primary)
```

- [ ] **Step 2: Fix Picker label doubling**

Add `.labelsHidden()` to the Flash picker (after `.pickerStyle(.menu)`):

```swift
Picker("Flash", selection: $defaultFlashMode) {
    ForEach(flashOptions, id: \.self) { option in
        Text(option).tag(option)
    }
}
.pickerStyle(.menu)
.tint(AppTheme.Colors.primary)
.labelsHidden()
```

Add `.labelsHidden()` to the Quality picker (after `.pickerStyle(.menu)`):

```swift
Picker("Quality", selection: $imageQuality) {
    ForEach(qualityOptions, id: \.self) { option in
        Text(option).tag(option)
    }
}
.pickerStyle(.menu)
.tint(AppTheme.Colors.primary)
.labelsHidden()
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/Profile/Settings/CaptureSettingsView.swift
git commit -m "fix: remove redundant auto-save toggle, fix picker label doubling"
```

---

## Task 2: Add Library Pill Borders

**Files:**
- Modify: `SimFolio/Features/Library/LibraryView.swift`

Add 1px `AppTheme.Colors.divider` border to `CompactAccessCard` to match card styling in Home and Profile.

- [ ] **Step 1: Add border overlay to CompactAccessCard**

Find `CompactAccessCard` (~line 890). Add an `.overlay()` after `.cornerRadius()`:

```swift
.background(AppTheme.Colors.surface)
.cornerRadius(AppTheme.CornerRadius.medium)
.overlay(
    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
        .stroke(AppTheme.Colors.divider, lineWidth: 1)
)
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Library/LibraryView.swift
git commit -m "fix: add divider border to Library quick access pills"
```

---

## Task 3: Portfolio Requirement Editing

**Files:**
- Modify: `SimFolio/Features/Portfolios/CreatePortfolioSheet.swift` (EditPortfolioSheet section, ~line 270)

Expand `EditPortfolioSheet` to allow editing, removing, and adding requirements. Reuse the existing `RequirementPreviewRow` (~line 456) and `RequirementEditorSheet` (~line 546) components.

- [ ] **Step 1: Add requirements state to EditPortfolioSheet**

Add these state properties after the existing `dueDate` state (~line 283):

```swift
@State private var requirements: [PortfolioRequirement] = []
@State private var showRequirementEditor = false
@State private var editingRequirementIndex: Int? = nil
@State private var requirementToDeleteIndex: Int? = nil
@State private var showDeleteRequirementAlert = false
@State private var matchingPhotoCount: Int = 0
```

- [ ] **Step 2: Update hasChanges to detect requirement changes**

Add a requirement check to the `hasChanges` computed property. After the existing due date check (before `return false`):

```swift
if requirements != portfolio.requirements {
    return true
}
```

- [ ] **Step 3: Update isValid to require at least one requirement**

Update the `isValid` computed property:

```swift
var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !requirements.isEmpty
}
```

- [ ] **Step 4: Replace requirementsInfo with editable requirements section**

Replace the `requirementsInfo` computed property (~line 412-432) with:

```swift
var requirementsSection: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
        Text("Requirements")
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.Colors.textPrimary)

        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(Array(requirements.enumerated()), id: \.element.id) { index, requirement in
                RequirementPreviewRow(
                    requirement: requirement,
                    onEdit: {
                        editingRequirementIndex = index
                        showRequirementEditor = true
                    },
                    onDelete: {
                        prepareDeleteRequirement(at: index)
                    }
                )
            }

            // Add Requirement button
            Button(action: {
                editingRequirementIndex = nil
                showRequirementEditor = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text("Add Requirement")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    .padding(.horizontal, AppTheme.Spacing.md)
}
```

- [ ] **Step 5: Update body to use requirementsSection and add sheets/alerts**

In the body, replace `requirementsInfo` with `requirementsSection`:

```swift
VStack(spacing: AppTheme.Spacing.lg) {
    nameSection
    dueDateSection
    requirementsSection
    Spacer(minLength: 100)
}
```

Add the requirement editor sheet and delete confirmation alert after `.onAppear`:

```swift
.onAppear {
    loadPortfolio()
}
.sheet(isPresented: $showRequirementEditor) {
    RequirementEditorSheet(
        isPresented: $showRequirementEditor,
        existingRequirement: editingRequirementIndex != nil ? requirements[editingRequirementIndex!] : nil,
        onSave: { requirement in
            if let index = editingRequirementIndex {
                requirements[index] = requirement
            } else {
                requirements.append(requirement)
            }
            editingRequirementIndex = nil
        }
    )
}
.alert("Remove Requirement?", isPresented: $showDeleteRequirementAlert) {
    Button("Cancel", role: .cancel) {
        requirementToDeleteIndex = nil
    }
    Button("Remove", role: .destructive) {
        if let index = requirementToDeleteIndex {
            requirements.remove(at: index)
            requirementToDeleteIndex = nil
        }
    }
} message: {
    if matchingPhotoCount > 0 {
        Text("This requirement has \(matchingPhotoCount) matching photo\(matchingPhotoCount == 1 ? "" : "s"). The photos will remain in your library but will no longer count toward this portfolio.")
    } else {
        Text("This requirement will be removed from the portfolio.")
    }
}
```

- [ ] **Step 6: Add helper methods**

Add `prepareDeleteRequirement` and update `loadPortfolio` and `saveChanges`:

```swift
func prepareDeleteRequirement(at index: Int) {
    requirementToDeleteIndex = index
    let requirement = requirements[index]

    // Count matching photos
    matchingPhotoCount = metadataManager.assetMetadata.values.filter { metadata in
        metadata.procedure == requirement.procedure
            && requirement.stages.contains(metadata.stage ?? "")
            && requirement.angles.contains(metadata.angle ?? "")
    }.count

    showDeleteRequirementAlert = true
}
```

Update `loadPortfolio()` to also load requirements:

```swift
func loadPortfolio() {
    name = portfolio.name
    hasDueDate = portfolio.dueDate != nil
    dueDate = portfolio.dueDate ?? Date()
    requirements = portfolio.requirements
}
```

Update `saveChanges()` to include requirements:

```swift
func saveChanges() {
    let updatedPortfolio = Portfolio(
        id: portfolio.id,
        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
        createdDate: portfolio.createdDate,
        dueDate: hasDueDate ? dueDate : nil,
        requirements: requirements
    )

    metadataManager.updatePortfolio(updatedPortfolio)
    isPresented = false
}
```

- [ ] **Step 7: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add SimFolio/Features/Portfolios/CreatePortfolioSheet.swift
git commit -m "feat: allow editing portfolio requirements after creation"
```

---

## Execution Order

Tasks 1, 2, and 3 are fully independent and can be executed in any order or in parallel.

```
Task 1 (capture settings)  ─┐
Task 2 (library borders)   ─┼─ all independent
Task 3 (requirement editing)─┘
```
