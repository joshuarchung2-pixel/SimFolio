# SimFolio UI Redesign — "Clarity" Direction

**Date:** 2026-04-06
**Status:** Design approved
**Scope:** Comprehensive visual overhaul of all screens

## Overview

Full visual redesign of SimFolio from the current dark blue gradient aesthetic to "Clarity" — a warm, minimal direction with serif headings, muted colors, and border-based card styling. The goal is to make the app feel modern, elevated, and distinctive while reducing visual noise and information density.

## Design Principles

1. **Less is more** — show what matters, hide the rest. Prefer tap-to-reveal over showing everything at once.
2. **Warm over cool** — warm whites, warm grays, warm blacks. No cool blue tints.
3. **Borders over shadows** — subtle warm gray borders (`#E8E5DF`) instead of drop shadows for card elevation.
4. **Typography as hierarchy** — serif headings (New York) establish visual hierarchy without needing color or weight tricks.
5. **Color-only selection state** — selected pills/tags change only border color, background fill, and text color. Never content or dimensions (no checkmarks, no border weight changes).

## Color Palette

### Core

| Token | Light Mode | Usage |
|-------|-----------|-------|
| `background` | `#FAFAF8` (warm white) | Page backgrounds |
| `surface` | `#FFFFFF` | Cards, modals, sheets |
| `divider` | `#EDEAE4` | Borders, separators, card strokes |

### Text

| Token | Value | Usage |
|-------|-------|-------|
| `textPrimary` | `#2D2A26` (warm black) | Headings, primary labels |
| `textSecondary` | `#8B8578` (warm gray) | Subtitles, metadata |
| `textTertiary` | `#B5AFA6` (light warm gray) | Placeholders, disabled text |

### Accent

| Token | Value | Usage |
|-------|-------|-------|
| `accent` | `#2B7A5F` (deep teal) | Primary buttons, selected states, links, progress bars |
| `accentLight` | `#E8F5F0` | Teal-tinted backgrounds, selected pill fills |
| `accentDark` | `#1D5A45` | Pressed states |

### Status

| Token | Value | Usage |
|-------|-------|-------|
| `success` | `#2B7A5F` | Same as accent — complete states |
| `warning` | `#C49A5C` / bg `#FEF6EE` | Due soon |
| `error` | `#C47070` / bg `#FEF0F0` | Overdue, destructive actions |

### Procedure Colors (muted)

All procedure colors are desaturated to harmonize with the warm palette. Each has a light background tint and a border color:

| Procedure | Text | Background | Border |
|-----------|------|------------|--------|
| Class 1 | `#4A6FA5` | `#F0F4FE` | `#D8E2F8` |
| Class 2 | `#3D7A54` | `#EDF7F0` | `#D0EBDA` |
| Class 3 | `#7A5CA0` | `#F5F0FA` | `#E4D8F2` |
| Class 4 | `#A07840` | `#FEF6EE` | `#F8E4CC` |
| Class 5 | `#A05050` | `#FEF0F0` | `#F8D4D4` |
| Crown | `#A07840` | `#FEF6EE` | `#F8E4CC` |
| Bridge | `#2B7A5F` | `#E8F5F0` | `#D0E8DF` |
| Veneer | `#7A8A40` | `#F4F6EE` | `#E2E8CC` |
| Inlay | `#A07840` | `#FEF6EE` | `#F8E4CC` |
| Onlay | `#7A5CA0` | `#F5F0FA` | `#E4D8F2` |
| Root Canal | `#3D7A54` | `#EDF7F0` | `#D0EBDA` |
| Extraction | `#A05050` | `#FEF0F0` | `#F8D4D4` |

## Typography

### Headings — New York (system serif)

Apple's built-in serif font. Zero bundle cost, pairs naturally with SF Pro.

| Style | Font | Size | Weight |
|-------|------|------|--------|
| Large Title | New York | 34pt | Bold |
| Title | New York | 28pt | Bold |
| Title 2 | New York | 22pt | Semibold |
| Title 3 | New York | 20pt | Semibold |

In SwiftUI: `.font(.system(.title, design: .serif))`

### Body — SF Pro (system)

| Style | Size | Weight |
|-------|------|--------|
| Headline | 17pt | Semibold |
| Body | 17pt | Regular |
| Subheadline | 15pt | Regular |
| Footnote | 13pt | Regular |
| Caption | 12pt | Regular |
| Caption 2 | 10pt | Regular |

### Section Labels

Uppercase, letter-spaced, small:
- Font: SF Pro, 11pt, Semibold
- Color: `textSecondary`
- Letter spacing: 0.8pt
- Transform: uppercase

## Components

### DPCard

- Background: `surface` (`#FFFFFF`)
- Border: 1px solid `divider` (`#E8E5DF`)
- Corner radius: 12pt
- Padding: 16pt
- Shadow: none (removed entirely)
- The subtle 0.5pt quaternary border overlay is removed — replaced by the explicit 1px divider border.

### DPButton

| Variant | Background | Text | Border |
|---------|-----------|------|--------|
| Primary | `accent` | white | none |
| Secondary | `surface` | `accent` | 1.5px `accent` |
| Tertiary | transparent | `accent` | none |
| Destructive | `#C44040` | white | none |

- Corner radius: 10pt
- Heights remain: small 32pt, medium 44pt, large 52pt
- Press animation: scale 0.97 (unchanged)

### DPTagPill

- Unselected: background `surface`, border 1px `divider`, text `textSecondary`
- Selected: background `accentLight`, border 1px `accent`, text `accent`
- Border weight does NOT change between states (always 1px)
- No checkmark appended on selection
- Procedure-colored pills use the muted procedure background/border/text from the table above
- Corner radius: fully rounded (unchanged)

### DPProgressBar

- Track: `divider` (`#EDEAE4`), 3pt height
- Fill: `accent` by default
- Auto-coloring updated: <25% `#C47070`, 25-50% `#C49A5C`, 50-75% `#C49A5C`, >75% `#2B7A5F`
- Progress rings are replaced by progress bars throughout the app

### DPToast

- Background: `surface`
- Border: 1px `divider`
- Left accent bar: 3pt, colored by type
- Shadow: none (border provides elevation)
- Type colors: success `#2B7A5F`, warning `#C49A5C`, error `#C47070`, info `#4A6FA5`

### DPEmptyState

- Icon: 56pt, displayed in a 64pt rounded square with `accentLight` background
- Title: serif (New York), 18pt semibold
- Message: 14pt, `textSecondary`, left-aligned or centered depending on context
- Action button: primary style

### DPSectionHeader

- Title label: 11pt, uppercase, letter-spaced, `textSecondary` (the new section label style)
- "See All" action: 12pt, `accent` color, no chevron

### Status Indicators

Inline badge style:
- Background: status-appropriate tint
- Text: status-appropriate color
- 6pt colored dot prefix
- Border radius: 8pt
- Padding: 8px 14px

## Navigation

### Tab Bar

Replace the custom `DPTabBar` with a standard iOS `TabView` tab bar:
- Use `.tint(Color.accent)` for the selected color
- Unselected color: `textTertiary`
- No glow effects, no custom shadows, no FAB-style center button
- The Capture tab uses the same style as other tabs (camera icon, no special treatment)
- 5 tabs remain: Home, Capture, Library, Feed, Profile

## Screen-by-Screen Changes

### Home Screen

**Remove:**
- Dark blue gradient background
- Hero photo slideshow (420pt auto-rotating carousel)
- Progress ring widget
- Dotted-line separators in portfolio stats
- Sticky stats card

**Replace with:**
- Warm white `background`
- Simple greeting: "SimFolio" caption label + "Good morning" serif title
- Two stat boxes side by side: photo count (white card) + completion % (teal-tinted card)
- "Recent" section: horizontal row of recent photo thumbnails (60pt rounded squares) with "See all" link
- "Portfolios" section: vertical list of portfolio cards, each showing name, due date, percentage, and thin progress bar

**Information hierarchy (top to bottom):** greeting → stats → recents → portfolios

### Add Requirement Modal

**Remove:**
- Dark blue background
- Neon-bright procedure color chips
- Fixed-width stage pills that cause vertical text wrapping
- Checkmarks in selected pills
- Blue outlined Cancel/Add buttons

**Replace with:**
- Warm white `background`
- Cancel: plain text button (tertiary style), left-aligned
- Add: primary teal button, right-aligned
- "Add Requirement" title: serif, centered
- Section labels: uppercase, letter-spaced, `textSecondary`
- Procedure chips: muted colors from procedure palette, pill-shaped, flex-wrap layout
- Stage pills: rectangular (8pt radius), flex-wrap layout — text wraps to new line, never vertically within a pill
- Angle chips: pill-shaped, same as procedures
- All selection states: color-only (background fill + border color + text color change, no checkmarks, no border weight change)
- Photos per angle stepper: clean card with `-`/`+` buttons

### Profile Screen

**Remove:**
- Dark gradient background
- Centered avatar stack with gradient circle
- 2x2 stats card grid
- Average rating stat

**Replace with:**
- Warm white `background`
- Inline header: avatar (52pt circle, `accentLight` background, teal initials) + name/school text, side by side
- Stats as horizontal row with dividers: Photos | Portfolios | Complete %
- Thin divider line below stats
- "Settings" section label + iOS-native grouped list (white background, divider borders, chevron disclosure indicators)
- Separate grouped list for About + Sign Out (destructive red text)

### Social Feed

**Remove:**
- Dark blue background
- Dark translucent post cards with drop shadows
- Solid blue "new posts" banner
- Fire emoji reaction
- Centered caption text

**Replace with:**
- Warm white `background`
- "Feed" serif heading at top
- New posts banner: `accentLight` background, `accent` text, 10pt radius
- Filter chips: filled teal for selected, bordered white for unselected (same no-resize behavior)
- Post cards: white background, 1px `divider` border, 12pt radius
  - Header: avatar (34pt, colored by procedure) + name/timestamp + procedure badge (top-right, muted procedure color)
  - Caption: left-justified, `textSecondary`, 13pt
  - Image placeholder: `divider` colored, 8pt radius
  - Reactions: heart + comment count only, `textTertiary` icons with `textSecondary` numbers
- Sign-in wall and opt-in prompt: same empty state pattern (icon in tinted square, serif title, description, primary CTA)

### Other Screens (same principles applied)

These screens weren't specifically mocked but follow the same Clarity rules:

**Library:**
- White background, border-based cards
- Grid thumbnails with rounded corners
- Filter/sort controls use the same chip/pill styling
- Procedure grouping headers use the section label style

**Portfolio Detail:**
- Replace tab-based navigation (Overview | Checklist | Photos) with a single scrollable view — simpler, less cognitive overhead
- Progress bar instead of progress ring
- Requirement list as clean bordered cards
- Due date badge uses status indicator styling

**Photo Editor:**
- No visual changes needed — the editor overlay is already functionally styled and doesn't use the dark blue theme

**Capture Flow:**
- Tag picker uses the same pill selection rules (color-only state changes)
- White background for pre-capture settings

**Onboarding:**
- Apply warm palette and serif headings
- Primary CTA buttons in teal

## Dark Mode

All existing adaptive color assets in the Asset Catalog will need updating:

| Token | Light | Dark |
|-------|-------|------|
| `background` | `#FAFAF8` | `#1A1917` |
| `surface` | `#FFFFFF` | `#242320` |
| `divider` | `#EDEAE4` | `#3A3835` |
| `textPrimary` | `#2D2A26` | `#F0EDE8` |
| `textSecondary` | `#8B8578` | `#9B958C` |
| `textTertiary` | `#B5AFA6` | `#6B665F` |

Accent colors remain the same in both modes except `accentLight`, which adapts:

| Token | Light | Dark |
|-------|-------|------|
| `accent` | `#2B7A5F` | `#2B7A5F` |
| `accentLight` | `#E8F5F0` | `#1A3029` |
| `accentDark` | `#1D5A45` | `#1D5A45` |

Procedure colors remain the same in both modes (they're already muted enough to work on dark backgrounds).

## What Gets Removed

- `Nexa Bold` custom font and all references — replaced by New York system serif
- Custom `DPTabBar` — replaced by standard iOS `TabView`
- All shadow view modifiers (`.shadowSmall()`, `.shadowMedium()`, `.shadowLarge()`) — borders replace shadows
- `DPProgressRing` component — progress bars used everywhere instead
- Hero photo slideshow in HomeView
- Glow effect on tab bar selected state
- Tab bar badge styling (if keeping badges, use standard iOS badge)
- Fire emoji reaction in social feed

## What Gets Added

- New York serif font usage (system, no bundling needed)
- Section label style (uppercase, letter-spaced, 11pt)
- Updated Asset Catalog colors for all core tokens
- Dark mode variants for the warm palette

## Migration Notes

- The design system file (`Core/DesignSystem.swift`) is the primary file to update — all color, typography, and component tokens flow from there
- Views that hardcode colors or fonts (instead of using `AppTheme` tokens) will need individual updates
- The custom tab bar in `Core/Navigation.swift` gets replaced with standard `TabView`
- Progress ring references throughout the app get swapped to progress bars
