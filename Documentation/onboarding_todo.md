# Onboarding Screenshots TODO

This document provides guidance for creating/editing screenshots used in onboarding pages 1-5.

## Overview

The first five onboarding pages use illustrative visuals to showcase app features. Currently, these pages use mockup UI elements built with SwiftUI. This guide outlines specifications for future screenshot replacements or enhancements.

---

## Page 1: Welcome

**Current Visual:** App icon with decorative feature icons (camera, photo stack, folder)

**Screenshot Specifications:**
- **Dimensions:** 280pt x 320pt display area
- **Content:** App icon prominently displayed
- **Suggested Composition:**
  - App icon centered with subtle shadow
  - Optional: floating icons representing key features (camera, photos, folders)
  - Gradient background with primary color accents
- **Visual Style:** Clean, welcoming, brand-focused

**Notes:**
- Ensure app icon is high-resolution (at least 2x scale)
- Maintain consistent corner radius (18pt) with app icon

---

## Page 2: Smart Capture

**Current Visual:** Phone mockup showing camera viewfinder with tagging UI

**Screenshot Specifications:**
- **Dimensions:** 240pt x 280pt phone frame
- **Content:** Capture interface with tag pills visible
- **Suggested Composition:**
  - Camera viewfinder or actual dental photo as background
  - Tag pills showing: procedure type, stage, tooth number, angle
  - Clear visual hierarchy showing pre-capture tagging workflow
- **Visual Elements to Capture:**
  - Procedure tag (e.g., "Class 1")
  - Stage tag (e.g., "Prep")
  - Tooth number tag (e.g., "#14")
  - Angle tag (e.g., "Occlusal/Incisal")
  - Rating indicator (optional)

**Notes:**
- Use realistic dental procedure photo if possible
- Ensure tag pills are legible at small size
- Consider showing the capture button for context

---

## Page 3: Requirements Tracking

**Current Visual:** Progress card with circular progress indicator and checklist items

**Screenshot Specifications:**
- **Dimensions:** 280pt width card
- **Content:** Portfolio progress overview
- **Suggested Composition:**
  - Circular progress indicator (65% or similar)
  - Portfolio name and requirement count
  - Mix of completed and pending checklist items
- **Visual Elements to Capture:**
  - Progress percentage
  - "X of Y requirements" subtitle
  - Completed items with checkmarks and strikethrough
  - Pending items clearly visible
  - Due date indicator (if applicable)

**Notes:**
- Use realistic portfolio names (e.g., "Fall 2024 Portfolio")
- Show mix of procedure types in checklist
- Ensure good contrast between completed/pending states

---

## Page 4: Photo Editing

**Current Visual:** Phone mockup with crop grid overlay and adjustment sliders

**Screenshot Specifications:**
- **Dimensions:** 240pt x 280pt phone frame
- **Content:** Photo editing interface
- **Suggested Composition:**
  - Dental photo with crop grid overlay visible
  - Corner handles for crop adjustment
  - 1-2 adjustment sliders (brightness, contrast)
  - Clear indication of editing capabilities
- **Visual Elements to Capture:**
  - Crop grid (rule of thirds)
  - Corner drag handles
  - Adjustment slider with thumb position
  - Slider icons (sun for brightness, contrast icon)

**Notes:**
- Use actual dental photo for more realistic appearance
- Show crop grid at slightly adjusted position (not full frame)
- Slider values should be at non-default positions to show adjustment

---

## Page 5: Export Ready

**Current Visual:** Abstract illustration with folder, ZIP file, and upload indicator

**Screenshot Specifications:**
- **Dimensions:** 200pt x 200pt display area
- **Content:** Export/sharing concept visualization
- **Suggested Composition:**
  - Folder icon (representing organized photos)
  - ZIP file icon (representing export package)
  - Upload/share indicator
  - Success/completion visual cue
- **Visual Elements to Capture:**
  - File organization metaphor
  - Export format indicator (.ZIP)
  - Share/upload action indicator
  - Green/success color accents

**Notes:**
- Keep composition clean and simple
- Use app color palette (warning yellow for folder, primary blue for ZIP, success green for upload)
- Consider subtle shadow/depth for floating elements

---

## General Guidelines

### Image Format & Resolution
- **Format:** PNG with transparency (if applicable)
- **Resolution:** 3x scale for Retina displays
- **Color Space:** sRGB

### Visual Consistency
- Use `AppTheme` colors from the design system
- Maintain consistent corner radius (use `AppTheme.CornerRadius` values)
- Apply consistent shadow styles (use `.shadowMedium()` equivalent)

### Accessibility Considerations
- Ensure sufficient contrast ratios
- Avoid conveying information through color alone
- Text overlays should meet WCAG AA standards

### File Naming Convention
```
onboarding_page[N]_[description]@3x.png
```
Examples:
- `onboarding_page1_welcome@3x.png`
- `onboarding_page2_capture@3x.png`
- `onboarding_page3_progress@3x.png`
- `onboarding_page4_editing@3x.png`
- `onboarding_page5_export@3x.png`

### Asset Catalog Integration
Add screenshots to:
```
SimFolio/Assets.xcassets/Onboarding/
```

---

## Implementation Notes

When replacing mockup UI with actual screenshots:

1. Create image sets in Assets.xcassets for each screenshot
2. Update the corresponding page views to use `Image("assetName")` instead of SwiftUI mockup code
3. Apply appropriate `.resizable()` and `.aspectRatio(contentMode: .fit)` modifiers
4. Maintain frame constraints from `OnboardingLayout` constants
5. Test on multiple device sizes to ensure proper scaling

---

## Status

| Page | Current State | Screenshot Status |
|------|---------------|-------------------|
| 1. Welcome | SwiftUI mockup | TODO |
| 2. Smart Capture | SwiftUI mockup | TODO |
| 3. Requirements | SwiftUI mockup | TODO |
| 4. Photo Editing | SwiftUI mockup | TODO |
| 5. Export | SwiftUI mockup | TODO |
