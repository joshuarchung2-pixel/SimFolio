# Test Suite Rewrite & Logging System Design

**Date:** 2026-04-12
**Status:** Approved

## Problem

The existing test suite (~6,000 lines across 15 files) has drifted from the production code. 16 tests fail due to model evolution (added `feed` tab, changed properties, `Date()` in factories causing flaky equality). All 8 `EditHistory` tests crash instantly, causing repeated "SimFolio quit unexpectedly" dialogs from parallel simulator clones. UI tests aren't registered in the scheme and can't run at all. There is no structured logging — only `#if DEBUG print()` statements.

## Goals

1. Green test suite with isolated, deterministic tests
2. Structured logging system using `os.Logger` for the app and in-memory capture for tests
3. Protocol-based dependency injection for the 5 core services
4. Explicit test plan and scheme fixes to eliminate crash dialogs
5. Full UI test rewrite with stable accessibility-identifier-based queries

## Non-Goals

- Protocol extraction for hardware/third-party services (CameraService, SubscriptionManager, AuthenticationService, etc.)
- CI/CD pipeline setup
- Snapshot testing
- Code coverage gating

---

## 1. Logging System

### 1.1 App-Level Logging

**File:** `Core/Logging/AppLogger.swift`

Replace the existing `ErrorLogger` in `Core/Utilities/ErrorHandling.swift` with a structured `os.Logger`-based system.

**Subsystems and categories:**

| Subsystem | Categories | Usage |
|---|---|---|
| `com.simfolio.app` | `lifecycle`, `permissions`, `state` | App launch, permission requests, AppState changes |
| `com.simfolio.services` | `metadata`, `storage`, `notifications`, `auth` | Service operations, data persistence |
| `com.simfolio.editor` | `processing`, `persistence`, `history` | Image edits, edit state save/load |
| `com.simfolio.ui` | `navigation`, `capture`, `library`, `portfolio` | View lifecycle, user interactions |

**Interface:**

```swift
import os

enum AppLogger {
    static let app = Logger(subsystem: "com.simfolio.app", category: "lifecycle")
    static let permissions = Logger(subsystem: "com.simfolio.app", category: "permissions")
    static let metadata = Logger(subsystem: "com.simfolio.services", category: "metadata")
    static let storage = Logger(subsystem: "com.simfolio.services", category: "storage")
    static let editor = Logger(subsystem: "com.simfolio.editor", category: "processing")
    static let editPersistence = Logger(subsystem: "com.simfolio.editor", category: "persistence")
    static let navigation = Logger(subsystem: "com.simfolio.ui", category: "navigation")
    // ... one static per category
}
```

**Migration:** All existing `ErrorLogger.log()`, `debugLog()`, and bare `print()` calls in service files get replaced with the appropriate `AppLogger` category call. The `ErrorHandling.swift` utility functions (`tryOrNil`, `tryOrDefault`, `tryWithErrorHandler`) are updated to use `AppLogger` internally but keep their signatures.

### 1.2 Test-Level Logging

**File:** `SimFolioTests/Utilities/TestLogger.swift`

An in-memory log sink for test runs. Since `os.Logger` writes to the unified logging system and can't be intercepted directly, `AppLogger` gains an optional secondary sink:

```swift
enum AppLogger {
    /// When set, log entries are also forwarded here (test use only)
    static var testSink: TestLogSink?
    // ...
}
```

Each `AppLogger` static method checks `testSink` and forwards the entry if non-nil. In production, `testSink` is always nil — zero overhead.

**Behavior:**

- `TestLogSink` captures entries as `(timestamp: Date, level: OSLogType, subsystem: String, category: String, message: String)` tuples in an array
- Registers as an `XCTestObservation` observer
- On test failure: dumps all captured log entries since the last `setUp()` call to the test output
- Provides assertion helpers: `TestLogSink.assertNoErrors()`, `TestLogSink.assertContains(message:)`
- Resets captured entries in each test's `setUp()`
- Installed in a shared `XCTestCase` base class or via a test observer's `testBundleWillStart`

---

## 2. Protocol Extraction

### 2.1 Protocols

Five protocols, each in its own file under `Core/Protocols/`:

**`MetadataManaging`** — Portfolio CRUD, asset metadata CRUD, procedure/stage queries, portfolio stats:

- `var portfolios: [Portfolio] { get }`
- `var procedureConfigs: [ProcedureConfig] { get }`
- `var stageConfigs: [StageConfig] { get }`
- `var assetMetadata: [String: PhotoMetadata] { get }`
- `func addPortfolio(_ portfolio: Portfolio)`
- `func updatePortfolio(_ portfolio: Portfolio)`
- `func deletePortfolio(_ portfolioId: String)`
- `func getPortfolio(by id: String) -> Portfolio?`
- `func assignMetadata(_ metadata: PhotoMetadata, to assetId: String)`
- `func getMetadata(for assetId: String) -> PhotoMetadata?`
- `func deleteMetadata(for assetId: String)`
- `func getPortfolioStats(_ portfolio: Portfolio) -> (fulfilled: Int, total: Int)`
- `func getPortfolioCompletionPercentage(_ portfolio: Portfolio) -> Double`
- `func getMatchingPhotoCount(procedure: String, stage: String, angle: String) -> Int`
- `func getEnabledProcedureNames() -> [String]`
- `func getEnabledStageNames() -> [String]`
- `func getRating(for assetId: String) -> Int?`
- `func setRating(_ rating: Int?, for assetId: String)`
- `func photoCount(for procedure: String) -> Int`

**`PhotoStoring`** — Photo save/load/delete:

- `var records: [PhotoRecord] { get }`
- `func savePhoto(_ image: UIImage, compressionQuality: CGFloat) -> PhotoRecord`
- `func loadImage(id: UUID) -> UIImage?`
- `func loadThumbnail(id: UUID) -> UIImage?`
- `func loadEditedImage(id: UUID) -> UIImage?`
- `func loadEditedThumbnail(id: UUID) -> UIImage?`
- `func deletePhoto(id: UUID)`
- `func deletePhotos(ids: [UUID])`

**`EditStatePersisting`** — Edit state CRUD:

- `func saveEditState(_ editState: EditState, for assetId: String)`
- `func getEditState(for assetId: String) -> EditState?`
- `func hasEditState(for assetId: String) -> Bool`
- `func deleteEditState(for assetId: String)`
- `func getEditSummary(for assetId: String) -> String?`

**`ImageProcessing`** — Image edit application:

- `func applyEdits(to image: UIImage, editState: EditState) -> UIImage?`
- `func generatePreview(from image: UIImage, editState: EditState, maxDimension: CGFloat) -> UIImage?`
- `func applyAdjustmentsOnly(to image: UIImage, adjustments: ImageAdjustments) -> UIImage?`

**`NavigationRouting`** — Tab/sheet/alert state:

- `var selectedTab: MainTab { get set }`
- `var isTabBarVisible: Bool { get }`
- `var activeSheet: SheetType? { get }`
- `var captureFlowActive: Bool { get }`
- `var libraryFilter: LibraryFilter { get set }`
- `func navigateToHome()`
- `func navigateToCapture(procedure: String?, stage: String?, angle: String?, toothNumber: Int?, forPortfolioId: String?)`
- `func navigateToLibrary(filter: LibraryFilter?)`
- `func navigateToPortfolio(id: String)`
- `func presentSheet(_ sheet: SheetType)`
- `func dismissSheet()`
- `func showTabBar()`
- `func hideTabBar()`
- `func resetCaptureState()`
- `func resetAll()`

### 2.2 Conformance

Each existing service class adds `: MetadataManaging` (etc.) to its declaration. No method signatures change — the protocols are extracted from the existing public API.

### 2.3 Injection Pattern

Production code continues using `.shared` singletons. No changes to app bootstrap. The protocols exist so that tests can inject mocks — production views can adopt protocol-typed dependencies incrementally, but that's not required for this work.

---

## 3. Unit Test Rewrite

### 3.1 File Structure

```
SimFolioTests/
├── Models/
│   ├── PhotoMetadataTests.swift
│   ├── PortfolioTests.swift
│   ├── PortfolioRequirementTests.swift
│   ├── ProcedureConfigTests.swift
│   ├── ToothEntryTests.swift
│   ├── LibraryFilterTests.swift
│   └── PhotoEditModelTests.swift
├── Services/
│   ├── MetadataManagerTests.swift
│   ├── PhotoStorageServiceTests.swift
│   ├── PhotoEditPersistenceTests.swift
│   ├── ImageProcessingServiceTests.swift
│   └── NavigationRouterTests.swift
├── Accessibility/
│   └── AccessibilityTests.swift
├── Utilities/
│   ├── TestData.swift
│   ├── TestLogger.swift
│   └── MockServices.swift
└── PortfolioCardCaptionTests.swift
```

### 3.2 TestData Factory Rewrite

All `Date` parameters use a fixed reference date:

```swift
static let referenceDate = ISO8601DateFormatter().date(from: "2025-01-15T12:00:00Z")!
```

No factory method uses `Date()`. Tests that need relative dates compute them from `referenceDate`.

### 3.3 Mock Strategy

Each mock conforms to its protocol, stores state in plain arrays/dictionaries, and tracks calls:

```swift
class MockMetadataManager: MetadataManaging {
    var portfolios: [Portfolio] = []
    var procedureConfigs: [ProcedureConfig] = []
    var stageConfigs: [StageConfig] = []
    var assetMetadata: [String: PhotoMetadata] = [:]

    // Call tracking
    var addPortfolioCalls: [Portfolio] = []
    var assignMetadataCalls: [(PhotoMetadata, String)] = []

    func addPortfolio(_ portfolio: Portfolio) {
        addPortfolioCalls.append(portfolio)
        portfolios.append(portfolio)
    }
    // ... etc
}
```

No UserDefaults, no disk, no singletons.

### 3.4 Specific Fixes for Current Failures

| Failure | Fix |
|---|---|
| `EditHistoryTests` (8 crashes) | Construct on `@MainActor`, use deterministic EditState values |
| `MainTabTests` (2) | Update to 5 tabs, add `feed` case assertions |
| `PhotoMetadataTests.testEquality` | Use `referenceDate` in factory, not `Date()` |
| `PortfolioTests.testPortfolioHashable` | Add custom `hash(into:)` and `==` using `id` only |
| `PortfolioRequirementTests.testRequirementHashable` | Same — custom Hashable on `id` |
| `ToothEntryTests.testToothEntryIdentifiable` | Verify against current model properties |
| `AccessibilityTests` date labels (2) | Match current relative date formatting |

### 3.5 Custom Hashable Conformances

`Portfolio` and `PortfolioRequirement` get explicit `Hashable`/`Equatable` using `id` only, since identity semantics (same id = same entity) are the correct behavior for these domain objects.

---

## 4. UI Test Rewrite

### 4.1 File Structure

```
SimFolioUITests/
├── Utilities/
│   ├── UITestApp.swift
│   └── UITestHelpers.swift
├── OnboardingUITests.swift
├── LibraryUITests.swift
├── CaptureFlowUITests.swift
├── PortfolioUITests.swift
├── PhotoEditorUITests.swift
└── ProfileUITests.swift
```

### 4.2 Launch Configuration

```swift
enum UITestApp {
    static func launch(
        skipOnboarding: Bool = true,
        withSampleData: Bool = true,
        resetAll: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        if resetAll { app.launchArguments.append("--reset-all-data") }
        if skipOnboarding { app.launchArguments.append("--skip-onboarding") }
        if withSampleData { app.launchArguments.append("--with-sample-data") }
        app.launch()
        return app
    }
}
```

### 4.3 Accessibility Identifiers

Production views gain `accessibilityIdentifier` modifiers where missing. UI tests query by identifier, not label text or element index. Examples:

- `"tab-home"`, `"tab-capture"`, `"tab-library"`, `"tab-feed"`, `"tab-profile"`
- `"library-filter-button"`, `"library-search-field"`
- `"portfolio-create-button"`, `"portfolio-card-{id}"`
- `"editor-adjust-tab"`, `"editor-crop-tab"`, `"editor-save-button"`

### 4.4 Wait Helpers

```swift
extension XCUIElement {
    func waitForExistence(timeout: TimeInterval = 5) -> Bool {
        waitForExistence(timeout: timeout)
    }
}

func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) {
    XCTAssertTrue(element.waitForExistence(timeout: timeout),
                  "Element \(element) did not appear within \(timeout)s")
}
```

### 4.5 Coverage Scope

Each UI test file covers:
- **Golden path:** The main happy-path flow
- **1-2 edge cases:** Empty states, cancel/back navigation
- **No hardware tests:** No camera capture, no photo library permission flows

---

## 5. Test Infrastructure

### 5.1 Test Plan

**File:** `SimFolio.xctestplan` (project root)

```json
{
  "configurations": [{
    "name": "Default",
    "options": {
      "language": "en",
      "region": "US",
      "environmentVariableEntries": [
        { "key": "SIMFOLIO_TESTING", "value": "1" }
      ]
    }
  }],
  "testTargets": [
    { "target": { "name": "SimFolioTests" }, "parallelizable": false },
    { "target": { "name": "SimFolioUITests" }, "parallelizable": false }
  ]
}
```

### 5.2 Scheme Fix

Update `SimFolio.xcscheme` TestAction:
- Reference `SimFolio.xctestplan` instead of `shouldAutocreateTestPlan = YES`
- Add `SimFolioUITests` as a testable reference
- Set `parallelizable = NO` on both targets

### 5.3 Test-Aware App Bootstrap

In `SimFolioApp.swift`, when `ProcessInfo.processInfo.environment["SIMFOLIO_TESTING"] == "1"`:
- Skip `FirebaseApp.configure()`
- Skip notification permission prompts
- `UIView.setAnimationsEnabled(false)`

---

## Summary of Files to Create

| File | Purpose |
|---|---|
| `Core/Logging/AppLogger.swift` | os.Logger subsystems |
| `Core/Protocols/MetadataManaging.swift` | Protocol |
| `Core/Protocols/PhotoStoring.swift` | Protocol |
| `Core/Protocols/EditStatePersisting.swift` | Protocol |
| `Core/Protocols/ImageProcessing.swift` | Protocol |
| `Core/Protocols/NavigationRouting.swift` | Protocol |
| `SimFolio.xctestplan` | Test plan |
| `SimFolioTests/Utilities/TestLogger.swift` | Test log capture |
| `SimFolioUITests/Utilities/UITestApp.swift` | UI test launch helper |
| `SimFolioUITests/Utilities/UITestHelpers.swift` | Element wait helpers |

## Summary of Files to Modify

| File | Change |
|---|---|
| `Core/Utilities/ErrorHandling.swift` | Replace print-based logging with AppLogger calls |
| `Services/MetadataManager.swift` | Add `: MetadataManaging` conformance |
| `Services/PhotoStorageService.swift` | Add `: PhotoStoring` conformance |
| `Features/PhotoEditor/PhotoEditPersistenceService.swift` | Add `: EditStatePersisting` conformance |
| `Features/PhotoEditor/ImageProcessingService.swift` | Add `: ImageProcessing` conformance |
| `Core/Navigation.swift` | Add `: NavigationRouting` conformance |
| `Models/Portfolio.swift` | Custom Hashable/Equatable on `id` |
| `Models/PortfolioRequirement.swift` (or Portfolio.swift) | Custom Hashable/Equatable on `id` |
| `SimFolio.xcscheme` | Add UI tests, reference test plan |
| `App/SimFolioApp.swift` | Test-aware bootstrap |
| Various views | Add `accessibilityIdentifier` modifiers |
| All existing test files | Full rewrite |
