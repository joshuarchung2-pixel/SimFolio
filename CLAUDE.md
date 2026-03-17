# SimFolio

A dental simulation portfolio management iOS app for dental students to capture, organize, and track their procedural photography.

## Project Overview

SimFolio helps dental students manage their clinical photography portfolios by:
- Capturing standardized dental procedure photos
- Organizing photos by procedure type, stage, and angle
- Tracking portfolio completion progress
- Managing deadlines and requirements
- Exporting portfolios for submission

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum iOS**: iOS 16.0+
- **Architecture**: Feature-based modular structure with shared Core components

## Design System

The app uses a centralized design system in `Core/DesignSystem.swift`:

- **Colors**: Access via `AppTheme.Colors.primary`, `.secondary`, `.background`, etc.
- **Typography**: Nexa font for headings (`AppTheme.Typography.title`), system font for body
- **Spacing**: 4pt grid system (`AppTheme.Spacing.sm`, `.md`, `.lg`)
- **Corner Radius**: `AppTheme.CornerRadius.small`, `.medium`, `.large`
- **Shadows**: `.shadowSmall()`, `.shadowMedium()`, `.shadowLarge()` view modifiers
- **Procedure Colors**: `AppTheme.procedureColor(for: "Class 1")` returns consistent colors

Shorthand aliases available: `Theme`, `ThemeColors`, `ThemeTypography`, `ThemeSpacing`

## Key Models

### Portfolio
Represents a collection of photo requirements with optional due date:
- `requirements: [PortfolioRequirement]` - Required procedure/stage/angle combinations
- `dueDate: Date?` - Optional deadline
- `isDueSoon`, `isOverdue` - Computed deadline status

### PhotoMetadata
Tags attached to photos in the library:
- `procedure: String` - e.g., "Class 1", "Crown"
- `stage: String` - e.g., "Preparation", "Restoration"
- `angle: String` - e.g., "Occlusal", "Buccal/Facial"
- `toothNumber: Int`
- `rating: Int` (1-5 stars)

### Photo Editing Models

#### EditState
Complete editing state for a photo:
- `assetId: String` - Asset identifier
- `adjustments: ImageAdjustments` - All adjustment values
- `transform: ImageTransform` - Crop and rotation values
- `hasChanges: Bool` - Whether any edits have been made

#### ImageAdjustments
Image adjustment slider values (reduced ranges for finer control):
- `brightness: Double` (-0.5 to 0.5, default 0)
- `exposure: Double` (-1.0 to 1.0, default 0)
- `highlights: Double` (-0.5 to 0.5, default 0)
- `shadows: Double` (-0.5 to 0.5, default 0)
- `contrast: Double` (0.75 to 1.25, default 1.0)
- `blackPoint: Double` (0 to 0.25, default 0)
- `saturation: Double` (0.5 to 1.5, default 1.0)
- `brilliance: Double` (-0.5 to 0.5, default 0)
- `sharpness: Double` (0 to 1.0, default 0)
- `definition: Double` (0 to 1.0, default 0)

#### ImageTransform
Image transformation values:
- `cropRect: CGRect?` - Normalized crop rectangle (0-1)
- `fineRotation: Double` - Fine rotation in degrees (-45 to 45)
- `rotation90Count: Int` - 90-degree rotation count (0-3)

## Photo Editing Feature

The app includes a comprehensive photo editing feature accessible from the photo detail view.

### Accessing the Editor
- Dedicated edit button in the photo detail view top bar
- Also available via the "Edit Photo" option in the more menu

### Editor Modes

#### Transform Mode
- **Crop**: Interactive crop overlay with aspect ratio presets (Freeform, Original, Square, 4:3, 3:4, 16:9, 9:16)
- **Fine Rotation**: Slider-based straightening (-45° to +45°) while in crop mode
- **90° Rotation**: Separate buttons for clockwise/counter-clockwise 90° rotation

#### Adjust Mode
10 adjustment sliders:
1. Brightness - Overall lightness
2. Exposure - Simulates camera exposure
3. Highlights - Bright area adjustment
4. Shadows - Dark area adjustment
5. Contrast - Tonal range
6. Black Point - Deepens blacks
7. Saturation - Color intensity
8. Brilliance - Vibrance/smart saturation
9. Sharpness - Edge enhancement
10. Definition - Local contrast

### Key Services

#### ImageProcessingService
CoreImage-based processing with Metal acceleration:
- `applyEdits(to:editState:)` - Apply all edits to an image
- `generatePreview(from:editState:maxDimension:)` - Generate real-time preview
- `applyAdjustmentsOnly(to:adjustments:)` - Quick adjustment preview

#### PhotoEditPersistenceService
Persists edit states to UserDefaults:
- `saveEditState(_:for:)` - Save edit state for an asset
- `getEditState(for:)` - Retrieve saved edit state
- `hasEditState(for:)` - Check if edits exist
- `deleteEditState(for:)` - Remove edit state
- `getEditSummary(for:)` - Human-readable edit summary

## Testing

### UI Testing Launch Arguments
The app supports launch arguments for UI testing:
- `--uitesting` - Disables animations for faster tests
- `--reset-onboarding` - Resets onboarding state
- `--skip-onboarding` - Skips onboarding flow
- `--reset-all-data` - Clears all app data
- `--with-sample-data` - Adds sample portfolios and metadata

### Test Structure
- `SimFolioTests/` - Unit tests (models, services, accessibility, photo editor)
- `SimFolioUITests/` - UI tests (onboarding, capture, library, portfolio, profile, photo editor flows)

## XcodeBuildMCP Tools

This project uses XcodeBuildMCP for Xcode build automation:

### Building
Use `mcp__xcodebuildmcp__build_sim_name_proj` to build the project for a simulator.

### Testing
Use `mcp__xcodebuildmcp__test_sim_name_proj` to run tests on a simulator.

### Cleaning
Use `mcp__xcodebuildmcp__clean` to clean the build folder.

### Logs
Use `mcp__xcodebuildmcp__capture_logs` to capture device/simulator logs.

## Code Style Guidelines

- Follow Swift API Design Guidelines
- Use `AppTheme` tokens instead of hardcoded colors/fonts/spacing
- Prefer computed properties over methods for simple derivations
- Use `@StateObject` for owned observable objects, `@EnvironmentObject` for injected ones
- Keep views small and extract reusable components to `Core/Components/`
- Use meaningful accessibility labels (see `Core/Accessibility/`)

## Common Tasks

### Adding a new procedure type
1. Add color constant in `AppTheme.Colors`
2. Update `AppTheme.procedureColor(for:)` switch case
3. Update `ProcedureConfig` if needed

### Adding a new feature
1. Create folder under `Features/`
2. Add main view and any sub-views
3. Register navigation if needed in `Navigation.swift`
4. Add tab in `ContentView.swift` if it's a main tab

## Analytics and Crash Reporting

The app uses Firebase Analytics and Crashlytics for usage analytics and crash reporting.

### Setup Requirements (One-time)
Before the app can send analytics:
1. Create a Firebase project at https://console.firebase.google.com/
2. Register iOS app with bundle ID `com.joshuachung.simfolio`
3. Download `GoogleService-Info.plist` and add to `SimFolio/` folder
4. Enable Crashlytics in Firebase Console

**Note**: `GoogleService-Info.plist` is git-ignored and must be downloaded from the Firebase Console for each development environment.

### AnalyticsService
Centralized analytics service in `Services/AnalyticsService.swift`:

**Predefined Events** (use `AnalyticsEvent` enum):
- `onboardingStarted`, `onboardingCompleted`, `onboardingSkipped`
- `portfolioCreated`, `portfolioDeleted`, `portfolioExported`, `portfolioViewed`
- `photoCaptured`, `photoTagged`, `photoEdited`, `photoDeleted`, `photoFavorited`
- `requirementFulfilled`, `requirementAdded`
- `cameraOpened`, `libraryOpened`, `filterApplied`, `searchPerformed`
- `paywallViewed`, `subscriptionStarted`, `subscriptionCancelled`

**User Properties** (use `AnalyticsUserProperty` enum):
- `userType`, `schoolName`, `graduationYear`
- `portfolioCount`, `photoCount`, `isPremium`

**Usage Examples**:
```swift
// Log event
AnalyticsService.logEvent(.portfolioCreated, parameters: ["name": "Fall 2024"])

// Convenience method
AnalyticsService.logPortfolioCreated(name: "Fall 2024", requirementCount: 5, hasDueDate: true)

// Set user property
AnalyticsService.setUserProperty("UCSF", for: .schoolName)

// Track screen
AnalyticsService.logScreenView("Portfolio Detail", screenClass: "PortfolioDetailView")

// SwiftUI view modifier
MyView().trackScreen("Home")

// Log error to Crashlytics
AnalyticsService.logError(error, context: "photo_export")

// Add breadcrumb for crash debugging
AnalyticsService.addBreadcrumb("User tapped export button")
```

**Opt-out Support**:
```swift
// Disable analytics (respects user privacy preference)
AnalyticsService.setAnalyticsEnabled(false)

// Check status
if AnalyticsService.analyticsEnabled { ... }
```

### dSYM Upload (Crashlytics)
A build phase script automatically uploads dSYM files for Release builds. Debug builds skip the upload for faster iteration.

### Adding New Analytics Events
1. Add event to `AnalyticsEvent` enum in `AnalyticsService.swift`
2. Optionally add convenience method for common parameter combinations
3. Call `AnalyticsService.logEvent()` at appropriate location
