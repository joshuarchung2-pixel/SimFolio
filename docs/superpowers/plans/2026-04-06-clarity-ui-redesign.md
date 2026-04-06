# Clarity UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul SimFolio's visual design from the current dark blue gradient aesthetic to the "Clarity" direction — warm whites, deep teal accent, serif headings, border-based cards, reduced information density.

**Architecture:** The redesign flows outward from the design system. Update `DesignSystem.swift` + Asset Catalog colors first (all views using tokens update automatically), then update components, then navigation, then individual screens. Many screen tasks are independent and can run in parallel.

**Tech Stack:** SwiftUI, SF Pro + New York (system serif), Xcode Asset Catalog color sets

**Spec:** `docs/superpowers/specs/2026-04-06-clarity-ui-redesign-design.md`

---

## Phase 1: Foundation

These tasks must complete before any screen work begins. Task 1 and Task 2 can run in parallel.

### Task 1: Update Asset Catalog Colors

**Files:**
- Modify: `SimFolio/Assets.xcassets/Colors/Background.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/Surface.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/SurfaceSecondary.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/Divider.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/TextPrimary.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/TextSecondary.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/Colors/TextTertiary.colorset/Contents.json`
- Modify: `SimFolio/Assets.xcassets/AccentColor.colorset/Contents.json`

These are loaded via `Color("Background")` etc. in `DesignSystem.swift`. Updating these JSON files propagates the new palette everywhere automatically.

- [ ] **Step 1: Update Background.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/Background.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.973",
          "green" : "0.980",
          "red" : "0.980"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.090",
          "green" : "0.098",
          "red" : "0.102"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#FAFAF8` → RGB(0.980, 0.980, 0.973). Dark: `#1A1917` → RGB(0.102, 0.098, 0.090).

- [ ] **Step 2: Update Surface.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/Surface.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "1.000",
          "green" : "1.000",
          "red" : "1.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.125",
          "green" : "0.137",
          "red" : "0.141"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#FFFFFF`. Dark: `#242320` → RGB(0.141, 0.137, 0.125).

- [ ] **Step 3: Update SurfaceSecondary.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/SurfaceSecondary.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.894",
          "green" : "0.918",
          "red" : "0.929"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.176",
          "green" : "0.184",
          "red" : "0.188"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#EDE9E4` (warm tint of SurfaceSecondary). Dark: `#302F2D`.

- [ ] **Step 4: Update Divider.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/Divider.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.894",
          "green" : "0.918",
          "red" : "0.929"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.208",
          "green" : "0.220",
          "red" : "0.227"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#EDEAE4`. Dark: `#3A3835`.

- [ ] **Step 5: Update TextPrimary.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/TextPrimary.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.149",
          "green" : "0.165",
          "red" : "0.176"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.910",
          "green" : "0.929",
          "red" : "0.941"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#2D2A26`. Dark: `#F0EDE8`.

- [ ] **Step 6: Update TextSecondary.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/TextSecondary.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.471",
          "green" : "0.522",
          "red" : "0.545"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.549",
          "green" : "0.584",
          "red" : "0.608"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#8B8578`. Dark: `#9B958C`.

- [ ] **Step 7: Update TextTertiary.colorset**

Replace contents of `SimFolio/Assets.xcassets/Colors/TextTertiary.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.651",
          "green" : "0.686",
          "red" : "0.710"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.373",
          "green" : "0.400",
          "red" : "0.420"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#B5AFA6`. Dark: `#6B665F`.

- [ ] **Step 8: Update AccentColor.colorset**

Replace contents of `SimFolio/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.373",
          "green" : "0.478",
          "red" : "0.169"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`#2B7A5F` — deep teal, same in light and dark.

- [ ] **Step 9: Create AccentLight.colorset**

Create `SimFolio/Assets.xcassets/Colors/AccentLight.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.941",
          "green" : "0.961",
          "red" : "0.910"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.161",
          "green" : "0.188",
          "red" : "0.102"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Light: `#E8F5F0`. Dark: `#1A3029`.

- [ ] **Step 10: Build to verify color assets parse correctly**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 11: Commit**

```bash
git add SimFolio/Assets.xcassets/
git commit -m "style: update Asset Catalog colors to Clarity warm palette"
```

---

### Task 2: Update DesignSystem.swift

**Files:**
- Modify: `SimFolio/Core/DesignSystem.swift`

Update color constants, typography (Nexa → New York serif), and neuter shadow modifiers.

- [ ] **Step 1: Update primary and secondary colors**

In `SimFolio/Core/DesignSystem.swift`, change the primary/secondary color hex values:

```swift
// Before:
static let primary = Color(hex: "2563EB")
static let secondary = Color(hex: "64748B")

// After:
static let primary = Color(hex: "2B7A5F")
static let secondary = Color(hex: "8B8578")
```

- [ ] **Step 2: Update procedure colors to muted palette**

Replace the procedure color constants:

```swift
// Before:
static let class1 = Color(hex: "3B82F6")
static let class2 = Color(hex: "22C55E")
static let class3 = Color(hex: "F97316")
static let crown = Color(hex: "A855F7")

// After:
static let class1 = Color(hex: "6B8FC7")
static let class2 = Color(hex: "5BA678")
static let class3 = Color(hex: "C49A5C")
static let crown = Color(hex: "9678BD")
```

- [ ] **Step 3: Update status colors**

```swift
// Before:
static let success = Color(hex: "22C55E")
static let warning = Color(hex: "EAB308")
static let error = Color(hex: "EF4444")
static let info = Color(hex: "3B82F6")

// After:
static let success = Color(hex: "2B7A5F")
static let warning = Color(hex: "C49A5C")
static let error = Color(hex: "C47070")
static let info = Color(hex: "4A6FA5")
```

- [ ] **Step 4: Add accentLight and accentDark colors**

Add after the `divider` line in the Background Colors section:

```swift
/// Accent light tint - for selected pill backgrounds, status tints (adaptive via Asset Catalog)
static let accentLight = Color("AccentLight")

/// Accent dark - for pressed states
static let accentDark = Color(hex: "1D5A45")
```

- [ ] **Step 5: Add procedure background and border color helpers**

Add below the existing `procedureColor(for:)` method:

```swift
/// Get the background tint color for a procedure type
static func procedureBackgroundColor(for procedure: String) -> Color {
    switch procedure.lowercased() {
    case "class 1", "class1", "class i":
        return Color(hex: "F0F4FE")
    case "class 2", "class2", "class ii":
        return Color(hex: "EDF7F0")
    case "class 3", "class3", "class iii":
        return Color(hex: "F5F0FA")
    case "class 4", "class4", "class iv":
        return Color(hex: "FEF6EE")
    case "class 5", "class5", "class v":
        return Color(hex: "FEF0F0")
    case "crown", "crowns":
        return Color(hex: "FEF6EE")
    case "bridge":
        return Color(hex: "E8F5F0")
    case "veneer":
        return Color(hex: "F4F6EE")
    case "inlay":
        return Color(hex: "FEF6EE")
    case "onlay":
        return Color(hex: "F5F0FA")
    case "root canal":
        return Color(hex: "EDF7F0")
    case "extraction":
        return Color(hex: "FEF0F0")
    default:
        return Colors.surfaceSecondary
    }
}

/// Get the border color for a procedure type
static func procedureBorderColor(for procedure: String) -> Color {
    switch procedure.lowercased() {
    case "class 1", "class1", "class i":
        return Color(hex: "D8E2F8")
    case "class 2", "class2", "class ii":
        return Color(hex: "D0EBDA")
    case "class 3", "class3", "class iii":
        return Color(hex: "E4D8F2")
    case "class 4", "class4", "class iv":
        return Color(hex: "F8E4CC")
    case "class 5", "class5", "class v":
        return Color(hex: "F8D4D4")
    case "crown", "crowns":
        return Color(hex: "F8E4CC")
    case "bridge":
        return Color(hex: "D0E8DF")
    case "veneer":
        return Color(hex: "E2E8CC")
    case "inlay":
        return Color(hex: "F8E4CC")
    case "onlay":
        return Color(hex: "E4D8F2")
    case "root canal":
        return Color(hex: "D0EBDA")
    case "extraction":
        return Color(hex: "F8D4D4")
    default:
        return Colors.divider
    }
}
```

- [ ] **Step 6: Update procedure color switch to include all procedures**

Update the existing `procedureColor(for:)` method to handle all procedure types:

```swift
static func procedureColor(for procedure: String) -> Color {
    switch procedure.lowercased() {
    case "class 1", "class1", "class i":
        return Color(hex: "4A6FA5")
    case "class 2", "class2", "class ii":
        return Color(hex: "3D7A54")
    case "class 3", "class3", "class iii":
        return Color(hex: "7A5CA0")
    case "class 4", "class4", "class iv":
        return Color(hex: "A07840")
    case "class 5", "class5", "class v":
        return Color(hex: "A05050")
    case "crown", "crowns":
        return Color(hex: "A07840")
    case "bridge":
        return Color(hex: "2B7A5F")
    case "veneer":
        return Color(hex: "7A8A40")
    case "inlay":
        return Color(hex: "A07840")
    case "onlay":
        return Color(hex: "7A5CA0")
    case "root canal":
        return Color(hex: "3D7A54")
    case "extraction":
        return Color(hex: "A05050")
    default:
        return Colors.secondary
    }
}
```

- [ ] **Step 7: Update typography — Nexa to New York serif**

Replace the heading font definitions:

```swift
// Before:
static let largeTitle = Font.custom("Nexa-Bold", size: 34)
static let title = Font.custom("Nexa-Bold", size: 28)
static let title2 = Font.custom("Nexa-Bold", size: 22)
static let title3 = Font.custom("Nexa-Bold", size: 20)

// After:
static let largeTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
static let title = Font.system(.title, design: .serif).weight(.bold)
static let title2 = Font.system(.title2, design: .serif).weight(.semibold)
static let title3 = Font.system(.title3, design: .serif).weight(.semibold)
```

Also add the section label style:

```swift
/// Section label - 11pt uppercase for section headers
static let sectionLabel = Font.system(size: 11, weight: .semibold)
```

- [ ] **Step 8: Neuter shadow modifiers to no-ops**

The shadow view modifiers are called throughout the app. Rather than hunt down every call site, make them no-ops:

```swift
// Replace the shadow modifier implementations:
extension View {
    /// Shadow removed in Clarity redesign — borders provide elevation
    func shadowSmall() -> some View {
        self
    }

    /// Shadow removed in Clarity redesign — borders provide elevation
    func shadowMedium() -> some View {
        self
    }

    /// Shadow removed in Clarity redesign — borders provide elevation
    func shadowLarge() -> some View {
        self
    }

    /// Apply a custom shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        self
    }
}
```

- [ ] **Step 9: Update angle colors to match warm palette**

Update the `angleColor(for:)` method:

```swift
static func angleColor(for angle: String) -> Color {
    switch angle.lowercased() {
    case "occlusal", "incisal", "occlusal/incisal":
        return Color(hex: "4A6FA5")
    case "buccal", "facial", "buccal/facial":
        return Color(hex: "3D7A54")
    case "lingual", "palatal":
        return Color(hex: "A07840")
    case "mesial":
        return Color(hex: "7A5CA0")
    case "distal":
        return Color(hex: "A05050")
    case "facial straight":
        return Color(hex: "2B7A5F")
    case "facial retracted":
        return Color(hex: "7A5CA0")
    default:
        return Colors.secondary
    }
}
```

- [ ] **Step 10: Build**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 11: Commit**

```bash
git add SimFolio/Core/DesignSystem.swift
git commit -m "style: update DesignSystem to Clarity palette, serif typography, no shadows"
```

---

### Task 3: Update Core Components

**Files:**
- Modify: `SimFolio/Core/Components.swift`

Update DPCard, DPButton, DPTagPill, DPIconButton, DPProgressBar, DPToast, DPEmptyState, and DPSectionHeader to match Clarity spec. Remove DPProgressRing.

- [ ] **Step 1: Update DPCard — border instead of shadow**

In `DPCard.body`, replace the overlay and shadow modifier:

```swift
// Before:
var body: some View {
    content
        .padding(padding)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.quaternary, lineWidth: 0.5))
        .modifier(CardShadowModifier(style: shadowStyle))
}

// After:
var body: some View {
    content
        .padding(padding)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
}
```

- [ ] **Step 2: Update DPButton colors**

In `DPButton`, update `backgroundColor`, `foregroundColor`, and `borderColor` computed properties. The primary color token already changed in DesignSystem.swift, so these will automatically use teal. Update the corner radius:

```swift
// Before:
private var cornerRadius: CGFloat {
    switch size {
    case .small: return AppTheme.CornerRadius.small
    case .medium: return AppTheme.CornerRadius.small
    case .large: return AppTheme.CornerRadius.medium
    }
}

// After:
private var cornerRadius: CGFloat {
    return AppTheme.CornerRadius.medium // 10pt for all sizes
}
```

Also update the destructive background color:

```swift
// In backgroundColor:
case .destructive:
    return Color(hex: "C44040")
```

- [ ] **Step 3: Update DPTagPill — color-only selection, no checkmarks**

Replace the `DPTagPill.body`:

```swift
var body: some View {
    HStack(spacing: AppTheme.Spacing.xs) {
        Text(text)
            .font(font)
            .foregroundStyle(isSelected ? color : AppTheme.Colors.textSecondary)

        if showRemoveButton {
            Button(action: {
                onRemove?()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: removeIconSize, weight: .semibold))
                    .foregroundStyle(isSelected ? color : AppTheme.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, verticalPadding)
    .background(isSelected ? color.opacity(0.12) : AppTheme.Colors.surface)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full))
    .overlay(
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
            .strokeBorder(isSelected ? color : AppTheme.Colors.divider, lineWidth: 1)
    )
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.easeInOut(duration: 0.15), value: isPressed)
    .onTapGesture {
        if let onTap = onTap {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(tagAccessibilityLabel)
    .accessibilityHint(tagAccessibilityHint)
    .accessibilityAddTraits(onTap != nil ? .isButton : [])
    .accessibilityAddTraits(isSelected ? .isSelected : [])
}
```

Key changes: unselected text is `textSecondary` not the color, background uses `surface` when unselected, border is always 1px (divider when unselected, color when selected), no border weight change.

- [ ] **Step 4: Update DPIconButton — remove shadow**

In `DPIconButton.body`, remove the shadow modifier:

```swift
// Before:
.clipShape(Circle())
.modifier(CardShadowModifier(style: shadowStyle))

// After:
.clipShape(Circle())
```

- [ ] **Step 5: Update DPProgressBar defaults**

Update the default parameter values and auto-coloring:

```swift
// In the init, change defaults:
init(
    progress: Double,
    height: CGFloat = 3,  // was 8
    backgroundColor: Color = AppTheme.Colors.divider,  // was surfaceSecondary
    foregroundColor: Color? = nil,
    cornerRadius: CGFloat? = nil,
    showPercentageLabel: Bool = false,
    animate: Bool = true
)
```

Update the auto-coloring computed property `effectiveForegroundColor`:

```swift
// Find the effectiveForegroundColor property and update the ranges:
private var effectiveForegroundColor: Color {
    if let foregroundColor = foregroundColor {
        return foregroundColor
    }
    // Auto-color based on progress
    switch progress {
    case 0..<0.25:
        return Color(hex: "C47070") // muted red
    case 0.25..<0.50:
        return Color(hex: "C49A5C") // muted amber
    case 0.50..<0.75:
        return Color(hex: "C49A5C") // muted amber
    default:
        return AppTheme.Colors.primary // teal
    }
}
```

- [ ] **Step 6: Remove DPProgressRing entirely**

Find and delete the entire `DPProgressRing` struct and its related code in `Components.swift`. Search for `// MARK: - DPProgressRing` and delete everything until the next `// MARK:` section.

- [ ] **Step 7: Update DPToast styling**

Find the DPToast body and update:
- Remove shadow, add border
- Update type colors to match new status colors (these should already match from DesignSystem changes, but verify the left accent bar color logic)

- [ ] **Step 8: Update DPEmptyState**

Find the DPEmptyState and update:
- Icon should be in a 64pt rounded square with `accentLight` background
- Title should use serif: `.font(.system(.title3, design: .serif).weight(.semibold))`
- Message should use `textSecondary`

- [ ] **Step 9: Update DPSectionHeader**

Find DPSectionHeader and update:
- Title: use `AppTheme.Typography.sectionLabel` (11pt semibold), `textSecondary`, uppercase, letter-spaced
- "See All" action: `accent` color, no chevron icon

- [ ] **Step 10: Build**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20`

Expected: `BUILD SUCCEEDED`. If DPProgressRing removal causes build errors, note which files reference it — those will be fixed in Task 5.

- [ ] **Step 11: Commit**

```bash
git add SimFolio/Core/Components.swift
git commit -m "style: update components to Clarity — borders, color-only pills, remove ProgressRing"
```

---

## Phase 2: Infrastructure

These depend on Phase 1. Task 4, 5, and 6 can run in parallel.

### Task 4: Replace Custom Tab Bar with Standard TabView

**Files:**
- Modify: `SimFolio/App/ContentView.swift`
- Modify: `SimFolio/Core/Navigation.swift`

- [ ] **Step 1: Update ContentView to use standard TabView**

Replace the `mainAppContent` and `tabContent` sections in `ContentView.swift`. The current approach uses a ZStack with `DPTabBar` overlaid. Replace with a standard `TabView`:

```swift
@ViewBuilder
private var mainAppContent: some View {
    ZStack {
        TabView(selection: $router.selectedTab) {
            NavigationView {
                HomeView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Home", systemImage: router.selectedTab == .home ? "house.fill" : "house")
            }
            .tag(MainTab.home)

            CaptureFlowView(cameraService: cameraService)
                .tabItem {
                    Label("Capture", systemImage: router.selectedTab == .capture ? "camera.fill" : "camera")
                }
                .tag(MainTab.capture)

            NavigationView {
                LibraryView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Library", systemImage: router.selectedTab == .library ? "photo.on.rectangle.fill" : "photo.on.rectangle")
            }
            .tag(MainTab.library)

            NavigationView {
                SocialFeedView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Feed", systemImage: router.selectedTab == .feed ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.and.text.bubble.right")
            }
            .tag(MainTab.feed)

            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Profile", systemImage: router.selectedTab == .profile ? "person.fill" : "person")
            }
            .tag(MainTab.profile)
        }
        .tint(AppTheme.Colors.primary)
        .onChange(of: router.selectedTab) { newTab in
            if previousTab == .capture && newTab != .capture {
                cameraService.stopSession()
            }
            if newTab == .capture && previousTab != .capture {
                cameraService.startSession()
            }
            switch newTab {
            case .home:
                AnalyticsService.logScreenView("Home", screenClass: "HomeView")
            case .capture:
                AnalyticsService.logScreenView("Capture", screenClass: "CaptureFlowView")
                AnalyticsService.logEvent(.cameraOpened)
            case .library:
                AnalyticsService.logScreenView("Library", screenClass: "LibraryView")
                AnalyticsService.logEvent(.libraryOpened)
            case .feed:
                AnalyticsService.logScreenView("Social Feed", screenClass: "SocialFeedView")
            case .profile:
                AnalyticsService.logScreenView("Profile", screenClass: "ProfileView")
            }
            previousTab = newTab
        }

        // App tour overlay
        if showAppTour {
            AppTourView(
                isPresented: $showAppTour,
                selectedTab: $router.selectedTab
            )
            .transition(.opacity)
            .zIndex(999)
        }
    }
}
```

Remove the old `tabContent` computed property and the `isTabBarVisible` conditional that wrapped `DPTabBar`.

- [ ] **Step 2: Remove `isTabBarVisible` usage in ContentView**

Remove the `isTabBarVisible` computed property and the animation tied to it. The standard TabView handles its own visibility.

- [ ] **Step 3: Build**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20`

Fix any compilation errors. Common issues: references to `isTabBarVisible`, `router.showTabBar()`, `router.hideTabBar()` in other files. These calls can remain in NavigationRouter (they're no-ops now since the standard TabView ignores them) or be removed from call sites.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/App/ContentView.swift SimFolio/Core/Navigation.swift
git commit -m "style: replace custom DPTabBar with standard iOS TabView"
```

---

### Task 5: Replace DPProgressRing Usages

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioDetailView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioListView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioChecklistTab.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioExportSheet.swift`

- [ ] **Step 1: Find all DPProgressRing usages**

Run grep to locate every occurrence:

```bash
grep -rn "DPProgressRing" SimFolio/Features/ SimFolio/Core/
```

- [ ] **Step 2: Replace each DPProgressRing with DPProgressBar**

For each occurrence, replace `DPProgressRing(progress: X, ...)` with `DPProgressBar(progress: X)`. The new 3pt-height bar is the default. Remove any label style parameters (like `.percentage`, `.fraction`) since the bar doesn't need them — show the percentage as separate text nearby if needed.

Example pattern:

```swift
// Before:
DPProgressRing(progress: completion, size: 60, labelStyle: .percentage)

// After:
VStack(alignment: .leading, spacing: 4) {
    DPProgressBar(progress: completion)
    Text("\(Int(completion * 100))%")
        .font(AppTheme.Typography.caption)
        .foregroundStyle(AppTheme.Colors.textSecondary)
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20`

Expected: `BUILD SUCCEEDED` — no more DPProgressRing references.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/
git commit -m "style: replace all DPProgressRing with DPProgressBar"
```

---

### Task 6: Update StateViews and Other Shared Components

**Files:**
- Modify: `SimFolio/Core/Components/StateViews/EmptyStateView.swift`
- Modify: `SimFolio/Core/Components/StateViews/ErrorView.swift`
- Modify: `SimFolio/Core/Components/StateViews/LoadingView.swift`
- Modify: `SimFolio/Core/Components/StateViews/PermissionDeniedView.swift`
- Modify: `SimFolio/Core/Components/StateViews/SkeletonView.swift`

- [ ] **Step 1: Read each file and update to Clarity style**

For each StateView file:
- Replace any hardcoded colors with `AppTheme.Colors` tokens
- Replace any shadow modifiers (they're already no-ops but check for inline `.shadow()` calls)
- Ensure empty state icons use the new pattern: icon in a rounded square with `accentLight` background
- Ensure titles use serif font: `.font(.system(.title3, design: .serif).weight(.semibold))`
- Replace any references to `.primary` color that aren't `AppTheme.Colors.primary` (like SwiftUI's `Color.primary`)

- [ ] **Step 2: Build**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Core/Components/
git commit -m "style: update StateViews to Clarity palette and serif headings"
```

---

## Phase 3: Screen Updates

These depend on Phase 1-2. **All tasks in this phase can run in parallel** — they touch independent files.

### Task 7: Redesign HomeView

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift` (1665 lines)

This is the biggest screen change. The current HomeView has a hero slideshow, gradient overlays, stats card, and portfolio navigator.

- [ ] **Step 1: Read the full HomeView.swift to understand structure**

Read the file and identify:
- Hero slideshow section
- Stats card section
- Portfolio navigator section
- Any gradient overlays or dark theme styling

- [ ] **Step 2: Remove hero slideshow and gradient overlays**

Delete the hero photo slideshow section (auto-rotating carousel with timer, gradient overlay, page indicators). This is likely a large chunk of code.

- [ ] **Step 3: Replace with new Clarity layout**

Implement the new top-to-bottom hierarchy:

1. **Header**: "SimFolio" section label + "Good morning" serif title
2. **Stats row**: Two side-by-side stat cards (photo count in white card, completion % in teal-tinted card)
3. **Recent section**: Section label "Recent" with "See all" link + horizontal scroll of photo thumbnails (60pt)
4. **Portfolios section**: Section label "Portfolios" + vertical list of portfolio cards with name, due date, percentage, thin progress bar

Use `ScrollView` for the main content. Apply warm white background.

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("SIMFOLIO")
                    .font(AppTheme.Typography.sectionLabel)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .tracking(0.8)

                Text(greeting)
                    .font(AppTheme.Typography.title)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Stats row
            statsRow
                .padding(.horizontal, AppTheme.Spacing.md)

            // Recent captures
            if !recentPhotos.isEmpty {
                recentSection
            }

            // Portfolios
            portfolioSection
                .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xxl)
    }
    .background(AppTheme.Colors.background)
    .navigationBarHidden(true)
}
```

- [ ] **Step 4: Implement statsRow**

```swift
private var statsRow: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
        // Photo count
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Text("\(totalPhotoCount)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Photos")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )

        // Completion
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Text("\(completionPercentage)%")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primary)
            Text("Complete")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.accentLight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 5: Implement portfolioSection**

```swift
private var portfolioSection: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
        Text("PORTFOLIOS")
            .font(AppTheme.Typography.sectionLabel)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .tracking(0.8)

        ForEach(portfolios) { portfolio in
            portfolioCard(portfolio)
        }
    }
}

private func portfolioCard(_ portfolio: Portfolio) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(portfolio.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let dueDate = portfolio.dueDate {
                    Text("Due \(dueDate.formatted(.dateTime.month().day()))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            Spacer()
            Text("\(portfolio.completionPercentage)%")
                .font(AppTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        DPProgressBar(progress: Double(portfolio.completionPercentage) / 100.0)
    }
    .padding(AppTheme.Spacing.md)
    .background(AppTheme.Colors.surface)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    .overlay(
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
    )
}
```

- [ ] **Step 6: Clean up — remove unused state variables, timers, and methods**

Delete: slideshow timer, slideshow state, gradient overlay code, stats card view, any `LinearGradient` calls, any dark-blue specific styling.

- [ ] **Step 7: Build and fix errors**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20`

Fix any compilation errors from property name mismatches or removed variables.

- [ ] **Step 8: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift
git commit -m "style: redesign HomeView — remove slideshow, add Clarity layout"
```

---

### Task 8: Redesign ProfileView

**Files:**
- Modify: `SimFolio/Features/Profile/ProfileView.swift` (962 lines)

- [ ] **Step 1: Read ProfileView.swift fully**

- [ ] **Step 2: Replace header — inline avatar + name**

Replace centered avatar stack with:

```swift
HStack(spacing: AppTheme.Spacing.md) {
    // Avatar
    Text(initials)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(AppTheme.Colors.primary)
        .frame(width: 52, height: 52)
        .background(AppTheme.Colors.accentLight)
        .clipShape(Circle())

    // Name + school
    VStack(alignment: .leading, spacing: 2) {
        Text(userName)
            .font(.system(.title3, design: .serif).weight(.bold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
        Text(schoolInfo)
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
}
.padding(.horizontal, AppTheme.Spacing.md)
```

- [ ] **Step 3: Replace stats grid with horizontal row**

```swift
HStack(spacing: 0) {
    statItem(value: "\(photoCount)", label: "Photos")
    Divider().frame(height: 32)
    statItem(value: "\(portfolioCount)", label: "Portfolios")
    Divider().frame(height: 32)
    statItem(value: "\(completionPercentage)%", label: "Complete",
             valueColor: AppTheme.Colors.primary)
}
.padding(.vertical, AppTheme.Spacing.md)
```

Remove the average rating stat.

- [ ] **Step 4: Replace settings sections with iOS grouped list style**

Use standard grouped list with white cards and divider borders. Structure: Settings group (Portfolios, Capture Settings, Notifications, Data Management) + About group (About, Sign Out in red).

- [ ] **Step 5: Build and fix**

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Profile/ProfileView.swift
git commit -m "style: redesign ProfileView — inline header, horizontal stats, grouped lists"
```

---

### Task 9: Redesign Social Feed

**Files:**
- Modify: `SimFolio/Features/Social/SocialFeedView.swift` (293 lines)
- Modify: `SimFolio/Features/Social/Components/FeedPostCard.swift` (115 lines)

- [ ] **Step 1: Read both files**

- [ ] **Step 2: Update SocialFeedView**

- Add serif "Feed" heading at top
- Update sign-in wall and opt-in prompt to use Clarity empty state pattern (icon in tinted square, serif title)
- Update new posts banner: `accentLight` background, `accent` text, 10pt radius
- Update filter chips: filled teal for selected, white bordered for unselected
- Left-justify caption text (not centered)

- [ ] **Step 3: Update FeedPostCard**

- White card with 1px divider border
- Avatar circle colored by procedure
- Procedure badge as top-right label (muted procedure background/text color)
- Caption left-justified, `textSecondary`
- Reactions: heart + comment count only, no fire emoji
- Remove any shadow styling

- [ ] **Step 4: Build and fix**

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Social/
git commit -m "style: redesign SocialFeedView and FeedPostCard to Clarity"
```

---

### Task 10: Update CreatePortfolioSheet (Add Requirement)

**Files:**
- Modify: `SimFolio/Features/Portfolios/CreatePortfolioSheet.swift` (1213 lines)

- [ ] **Step 1: Read the full file**

Focus on: procedure chip rendering, stage pill rendering (the broken vertical text wrapping), angle chip rendering, the stepper for photos per angle, Cancel/Add buttons.

- [ ] **Step 2: Fix stage pill layout**

The current stage pills use fixed widths that cause vertical text wrapping. Change to flex-wrap layout:

- Stage pills should use `LazyVGrid` or `FlowLayout` with `.flexible()` sizing, or wrap in a horizontal `FlowLayout`
- Remove any fixed-width constraints on stage items
- Use rectangular corners (8pt radius) for stage pills, pill-shaped for procedures and angles

- [ ] **Step 3: Update selection styling**

All chips/pills — procedures, stages, angles — must use color-only selection:
- No checkmarks appended
- Border stays 1px always
- Selected: `accentLight` background, `accent` border and text
- Unselected: `surface` background, `divider` border, `textSecondary` text
- For procedure-colored pills: selected uses procedure background/border/text, unselected uses neutral

- [ ] **Step 4: Update Cancel/Add buttons**

- Cancel: tertiary style (plain text, `textSecondary` color)
- Add: primary teal button
- Title: serif font, centered

- [ ] **Step 5: Update section labels to uppercase style**

All section headers (Procedure, Stages, Angles, Photos Per Angle) should use the new section label style: 11pt semibold, uppercase, letter-spaced, `textSecondary`.

- [ ] **Step 6: Build and fix**

- [ ] **Step 7: Commit**

```bash
git add SimFolio/Features/Portfolios/CreatePortfolioSheet.swift
git commit -m "style: redesign Add Requirement modal — fix pills, Clarity styling"
```

---

### Task 11: Update Remaining Screens

**Files:**
- Modify: `SimFolio/Features/Portfolios/PortfolioDetailView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioListView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioChecklistTab.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioPhotosTab.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioExportSheet.swift`
- Modify: `SimFolio/Features/Library/LibraryView.swift`
- Modify: `SimFolio/Features/Capture/CaptureFlowView.swift`
- Modify: `SimFolio/Features/Onboarding/OnboardingView.swift`

These screens follow the same principles. Most of the heavy lifting was done in Phase 1 (tokens auto-propagate). This task focuses on removing any hardcoded dark-theme colors, gradients, or inline shadows.

- [ ] **Step 1: Scan each file for hardcoded styling**

Grep for patterns that need updating:

```bash
grep -n "LinearGradient\|Color(hex\|\.shadow(\|Color\.blue\|Color\.black\.opacity\|#[0-9A-Fa-f]\{6\}" SimFolio/Features/Portfolios/*.swift SimFolio/Features/Library/*.swift SimFolio/Features/Capture/CaptureFlowView.swift SimFolio/Features/Onboarding/OnboardingView.swift
```

- [ ] **Step 2: Update each file**

For each file:
- Replace `LinearGradient` with flat `AppTheme.Colors.background` or `AppTheme.Colors.surface`
- Replace hardcoded `Color(hex: ...)` with `AppTheme.Colors` tokens where appropriate
- Replace inline `.shadow(...)` calls with removal (borders handle elevation)
- Ensure navigation titles use serif: `.font(.system(.title2, design: .serif))`
- Update filter/chip UIs to match the Clarity pill selection behavior

- [ ] **Step 3: Build full project**

Run: `xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20`

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/
git commit -m "style: apply Clarity styling to remaining screens"
```

---

## Phase 4: Verification

### Task 12: Final Build and Cleanup

**Files:**
- Possibly modify: any files with remaining build errors

- [ ] **Step 1: Clean build**

```bash
xcodebuild clean -project SimFolio.xcodeproj -scheme SimFolio
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

- [ ] **Step 2: Run unit tests**

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40
```

Fix any test failures caused by the redesign (likely tests that reference removed components like DPProgressRing or check specific colors).

- [ ] **Step 3: Remove Nexa font files if bundled**

Check if Nexa font files exist in the project:

```bash
find SimFolio -name "Nexa*" -o -name "nexa*"
```

If found, remove them and clean up any Info.plist font registration entries.

- [ ] **Step 4: Update CLAUDE.md**

Update the Design System section in CLAUDE.md to reflect the new Clarity palette, serif typography, and component changes. Remove references to Nexa, shadows, and DPProgressRing.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: cleanup — remove Nexa font, update docs, fix tests"
```

---

## Parallelization Guide

```
Phase 1 (sequential start):
  Task 1 (Asset Catalog) ──┐
  Task 2 (DesignSystem)  ──┼── must complete before Phase 2
  Task 3 (Components)    ──┘

Phase 2 (parallel):
  Task 4 (TabView)       ─┐
  Task 5 (ProgressRing)  ─┼── can run in parallel, must complete before Phase 3
  Task 6 (StateViews)    ─┘

Phase 3 (parallel):
  Task 7  (HomeView)             ─┐
  Task 8  (ProfileView)          ─┤
  Task 9  (Social Feed)          ─┼── all independent, can run in parallel
  Task 10 (CreatePortfolioSheet) ─┤
  Task 11 (Remaining Screens)    ─┘

Phase 4:
  Task 12 (Verification) ── after all above complete
```

**Maximum parallelism:** 5 subagents during Phase 3.
