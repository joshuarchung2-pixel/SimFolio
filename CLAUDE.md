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

- **Colors**: Warm palette with `#FAFAF8` background and `#2B7A5F` teal accent. Access via `AppTheme.Colors.primary` (teal), `.secondary`, `.background`, `.surface`, `.textPrimary`, `.textSecondary`, `.textTertiary`, `.divider`, `.accentLight`, `.accentDark`
- **Typography**: New York serif for headings (`AppTheme.Typography.title`, `.title2`, `.title3`, `.largeTitle`), SF Pro system font for body. Section labels use `AppTheme.Typography.sectionLabel` with `.tracking(0.8)` and `.textCase(.uppercase)`
- **Spacing**: 4pt grid system (`AppTheme.Spacing.sm`, `.md`, `.lg`)
- **Corner Radius**: `AppTheme.CornerRadius.small`, `.medium`, `.large`
- **Procedure Colors**: `AppTheme.procedureColor(for: "Class 1")` returns consistent text colors; `procedureBackgroundColor(for:)` and `procedureBorderColor(for:)` for card backgrounds and borders
- **Cards**: Use 1px `divider` borders for elevation instead of shadows
- **Tag pills**: Color-only selection state (no checkmarks, no border weight change)
- **Navigation**: Standard iOS `TabView` (not a custom tab bar component)

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

## Building & Testing

Build and test using `xcodebuild` via Bash. The primary scheme is `SimFolio`.

### Dev loop: build once, re-test fast (DEFAULT)

A full `xcodebuild test` invocation spends 90%+ of its time on rebuild + sign + install + simulator boot, NOT on the tests themselves (the SimFolioTests suite runs in <1s). For iterative work, build once and reuse the bundle:

**Step 1 — build the test bundle once (slow, ~2-3 min):**
```bash
xcodebuild build-for-testing -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

**Step 2 — run tests against the prebuilt bundle (fast, ~10-30s):**
```bash
./scripts/run-tests.sh
```

The wrapper boots the simulator if needed, runs `test-without-building`, then classifies the run by parsing the xcresult bundle instead of trusting xcodebuild's exit code. That absorbs the simulator preflight flake (see below) — exit 0 iff 0 tests actually failed.

Override via env vars: `SIM_NAME="iPhone 16" ./scripts/run-tests.sh`, `ONLY_TESTING="SimFolioTests/PhotoEditorTests" ./scripts/run-tests.sh`.

Re-run step 2 as often as you like. Re-run step 1 only when source files change.

If you need the raw xcodebuild command (e.g. debugging the wrapper itself):
```bash
xcodebuild test-without-building -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40
```

### One-shot test runs (slow but self-contained)

Use these only when you don't want to manage the build cache:

```bash
# Unit tests
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40

# UI tests (requires SimFolioUITests target in the Xcode project — not currently wired)
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioUITests 2>&1 | tail -40
```

### Build only (no tests)
```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

### Clean build
```bash
xcodebuild clean -project SimFolio.xcodeproj -scheme SimFolio
```

### Simulator preflight flake ("TEST EXECUTE FAILED" with 0 real failures)

`xcodebuild test` exits non-zero when the simulator's app-launch preflight trips, even when every test in the run actually passed. Two layers of mitigation are in place:

1. **`./scripts/run-tests.sh`** — the default dev-loop runner. It classifies the run from the xcresult bundle, so a preflight flake with 0 real failures exits 0 and is silent. Prefer this over raw `xcodebuild test-without-building`.
2. **Keep the simulator booted between runs.** The wrapper auto-boots `iPhone 17` if it isn't warm; don't shut it down between runs. Cold boots are when the preflight race is worst.

If the simulator gets genuinely stuck (boots fail, tests hang indefinitely, not just a preflight flake), nuke and retry:

```bash
xcrun simctl shutdown all; killall Simulator 2>/dev/null; xcrun simctl erase all
```

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
