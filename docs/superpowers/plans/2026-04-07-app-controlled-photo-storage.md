# App-Controlled Photo Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move photo storage from the iOS Photos library to the app's Documents directory so photos are app-owned, protected from accidental deletion, and invisible to the Photos app.

**Architecture:** Replace `PhotoLibraryManager` (PHAsset-based) with a new `PhotoStorageService` that manages JPEG files in `Documents/Photos/` and `Documents/Thumbnails/`. A `PhotoRecord` model replaces `PHAsset` as the photo identifier throughout the app. One-time migration copies existing Photos library photos to app storage.

**Tech Stack:** Swift, SwiftUI, FileManager, CoreGraphics (thumbnail generation), PHPhotoLibrary (migration + optional camera roll save only)

**Spec:** `docs/superpowers/specs/2026-04-07-app-controlled-photo-storage-design.md`

---

## Files Overview

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `SimFolio/Models/PhotoRecord.swift` | Photo identifier model (replaces PHAsset) |
| Create | `SimFolio/Services/PhotoStorageService.swift` | File-based photo storage (save/load/delete/thumbnails) |
| Create | `SimFolio/Services/PhotoMigrationService.swift` | One-time migration from Photos library to app storage |
| Modify | `SimFolio/Services/MetadataManager.swift` | Add PhotoRecord tracking, key remapping support |
| Modify | `SimFolio/Features/Capture/CaptureFlowView.swift` | Save to PhotoStorageService instead of PHPhotoLibrary |
| Modify | `SimFolio/Features/Profile/Settings/CaptureSettingsView.swift` | Add "Save to Camera Roll" toggle |
| Modify | `SimFolio/Features/Home/HomeView.swift` | Load thumbnails from PhotoStorageService |
| Modify | `SimFolio/Features/Library/LibraryView.swift` | Replace PHAsset data source with PhotoRecord |
| Modify | `SimFolio/Features/PhotoEditor/PhotoEditorView.swift` | Load/save via PhotoStorageService |
| Modify | `SimFolio/Features/Portfolios/PortfolioChecklistTab.swift` | Load thumbnails from PhotoStorageService |
| Modify | `SimFolio/Features/Portfolios/PortfolioDetailView.swift` | Replace PHAsset references |
| Modify | `SimFolio/Features/Portfolios/PortfolioPhotosTab.swift` | Replace PHAsset references |
| Modify | `SimFolio/Features/Portfolios/PortfolioExportSheet.swift` | Load from file URLs instead of PHAsset |
| Modify | `SimFolio/App/ContentView.swift` | Wire migration on launch, update data source |
| Modify | `SimFolio/Services/PhotoLibraryManager.swift` | Retain only for migration + camera roll save |
| Modify | `SimFolio/Features/PhotoEditor/PhotoEditPersistenceService.swift` | Key remapping support |
| Test | `SimFolioTests/PhotoStorageServiceTests.swift` | Unit tests for storage service |
| Test | `SimFolioTests/PhotoMigrationServiceTests.swift` | Unit tests for key remapping logic |

---

## Task 1: Create PhotoRecord Model

**Files:**
- Create: `SimFolio/Models/PhotoRecord.swift`

This is the lightweight model that replaces PHAsset as the photo identifier throughout the app. It's `Codable` for JSON persistence and `Identifiable` for SwiftUI lists.

- [ ] **Step 1: Create PhotoRecord model**

```swift
// PhotoRecord.swift
// SimFolio - Represents an app-owned photo stored in the Documents directory

import Foundation

struct PhotoRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdDate: Date
    var fileSize: Int64

    /// File URL for the full-resolution photo
    var photoURL: URL {
        PhotoStorageService.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// File URL for the thumbnail
    var thumbnailURL: URL {
        PhotoStorageService.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (note: `PhotoStorageService` reference will be forward-declared — the directories are static, so this may need to be adjusted in Task 2 to avoid circular reference. If it doesn't compile, make the URLs computed using `FileManager` directly instead of referencing `PhotoStorageService`.)

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Models/PhotoRecord.swift
git commit -m "feat: add PhotoRecord model for app-controlled photo storage"
```

---

## Task 2: Create PhotoStorageService

**Files:**
- Create: `SimFolio/Services/PhotoStorageService.swift`
- Create: `SimFolioTests/PhotoStorageServiceTests.swift`

The core service that manages JPEG files on disk. Handles save (with thumbnail generation), load, delete, and record persistence.

- [ ] **Step 1: Write failing tests**

```swift
// PhotoStorageServiceTests.swift

import XCTest
@testable import SimFolio

final class PhotoStorageServiceTests: XCTestCase {
    var service: PhotoStorageService!

    override func setUp() {
        super.setUp()
        service = PhotoStorageService.shared
        // Clean up any test data
        for record in service.records {
            service.deletePhoto(id: record.id)
        }
    }

    func testSavePhotoCreatesRecord() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        XCTAssertNotNil(record)
        XCTAssertTrue(service.records.contains(where: { $0.id == record.id }))
        XCTAssertTrue(record.fileSize > 0)
    }

    func testLoadImageReturnsImage() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        let loaded = service.loadImage(id: record.id)
        XCTAssertNotNil(loaded)
    }

    func testLoadThumbnailReturnsImage() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        let thumbnail = service.loadThumbnail(id: record.id)
        XCTAssertNotNil(thumbnail)
    }

    func testDeletePhotoRemovesFiles() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        service.deletePhoto(id: record.id)

        XCTAssertNil(service.loadImage(id: record.id))
        XCTAssertNil(service.loadThumbnail(id: record.id))
        XCTAssertFalse(service.records.contains(where: { $0.id == record.id }))
    }

    func testRecordsPersistAcrossLoads() {
        let image = createTestImage()
        let record = service.savePhoto(image)

        // Force reload from UserDefaults
        service.reloadRecords()

        XCTAssertTrue(service.records.contains(where: { $0.id == record.id }))
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/PhotoStorageServiceTests 2>&1 | tail -20
```

Expected: FAIL — `PhotoStorageService` does not exist yet.

- [ ] **Step 3: Implement PhotoStorageService**

```swift
// PhotoStorageService.swift
// SimFolio - File-based photo storage service
//
// Manages photos in the app's Documents directory. Photos are stored as JPEG files
// identified by UUID. Thumbnails are generated on save for efficient grid display.

import UIKit
import Combine

@MainActor
class PhotoStorageService: ObservableObject {
    static let shared = PhotoStorageService()

    // MARK: - Directories

    static let photosDirectory: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let thumbnailsDirectory: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    // MARK: - State

    @Published var records: [PhotoRecord] = []

    private let userDefaultsKey = "photoRecords"
    private let thumbnailMaxDimension: CGFloat = 300
    private let thumbnailCompressionQuality: CGFloat = 0.7

    // MARK: - Init

    private init() {
        loadRecords()
    }

    // MARK: - Save

    /// Save an image to app storage and generate a thumbnail. Returns the new PhotoRecord.
    @discardableResult
    func savePhoto(_ image: UIImage, compressionQuality: CGFloat = 0.85) -> PhotoRecord {
        let id = UUID()
        let photoURL = Self.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        let thumbnailURL = Self.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        // Save full-res
        let data = image.jpegData(compressionQuality: compressionQuality) ?? Data()
        try? data.write(to: photoURL)

        // Generate and save thumbnail
        let thumbnail = generateThumbnail(from: image)
        let thumbData = thumbnail.jpegData(compressionQuality: thumbnailCompressionQuality) ?? Data()
        try? thumbData.write(to: thumbnailURL)

        let record = PhotoRecord(
            id: id,
            createdDate: Date(),
            fileSize: Int64(data.count)
        )

        records.insert(record, at: 0) // newest first
        saveRecords()

        return record
    }

    // MARK: - Load

    /// Load full-resolution image from disk
    func loadImage(id: UUID) -> UIImage? {
        let url = Self.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Load thumbnail image from disk
    func loadThumbnail(id: UUID) -> UIImage? {
        let url = Self.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    /// Delete a photo and its thumbnail from disk
    func deletePhoto(id: UUID) {
        let photoURL = Self.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        let thumbnailURL = Self.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        try? FileManager.default.removeItem(at: photoURL)
        try? FileManager.default.removeItem(at: thumbnailURL)

        records.removeAll { $0.id == id }
        saveRecords()
    }

    /// Delete multiple photos
    func deletePhotos(ids: [UUID]) {
        for id in ids {
            let photoURL = Self.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
            let thumbnailURL = Self.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
            try? FileManager.default.removeItem(at: photoURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        records.removeAll { ids.contains($0.id) }
        saveRecords()
    }

    // MARK: - Disk Usage

    /// Total bytes used by all stored photos and thumbnails
    func diskUsage() -> Int64 {
        records.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Persistence

    func reloadRecords() {
        loadRecords()
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([PhotoRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func saveRecords() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(from image: UIImage) -> UIImage {
        let size = image.size
        let scale: CGFloat
        if size.width > size.height {
            scale = thumbnailMaxDimension / size.width
        } else {
            scale = thumbnailMaxDimension / size.height
        }

        // Don't upscale
        guard scale < 1.0 else { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

- [ ] **Step 4: Fix PhotoRecord to not reference PhotoStorageService** (avoid circular dependency)

Update `PhotoRecord.swift` — remove the computed `photoURL`/`thumbnailURL` properties since they reference `PhotoStorageService`. Instead, consumers will call `PhotoStorageService.loadImage(id:)` and `loadThumbnail(id:)` directly.

```swift
struct PhotoRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdDate: Date
    var fileSize: Int64
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/PhotoStorageServiceTests 2>&1 | tail -20
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Services/PhotoStorageService.swift SimFolio/Models/PhotoRecord.swift SimFolioTests/PhotoStorageServiceTests.swift
git commit -m "feat: add PhotoStorageService for file-based photo storage"
```

---

## Task 3: Integrate PhotoStorageService with MetadataManager

**Files:**
- Modify: `SimFolio/Services/MetadataManager.swift`

MetadataManager already keys `assetMetadata` by `String`. Since `PhotoRecord.id` is a UUID, we just use `id.uuidString` as the key. The dictionary type doesn't change — only callers passing PHAsset.localIdentifier need updating (done in later tasks).

Add a helper for key remapping (used by migration) and a method to clean up orphaned metadata for deleted app-stored photos.

- [ ] **Step 1: Add key remapping and cleanup support to MetadataManager**

Add these methods to MetadataManager (after the existing `cleanupOrphanedData` method):

```swift
// MARK: - Key Remapping (for migration)

/// Remap assetMetadata keys from old identifiers to new ones
func remapMetadataKeys(_ mapping: [String: UUID]) {
    var newMetadata: [String: PhotoMetadata] = [:]
    for (oldKey, metadata) in assetMetadata {
        if let newId = mapping[oldKey] {
            newMetadata[newId.uuidString] = metadata
        } else {
            // Keep unmapped entries (shouldn't happen, but safe)
            newMetadata[oldKey] = metadata
        }
    }
    assetMetadata = newMetadata
    saveAssetMetadata()
}

/// Clean up metadata entries that have no corresponding PhotoRecord
func cleanupOrphanedAppStorageData() {
    let validIds = Set(PhotoStorageService.shared.records.map { $0.id.uuidString })
    let orphanedKeys = assetMetadata.keys.filter { !validIds.contains($0) }
    for key in orphanedKeys {
        assetMetadata.removeValue(forKey: key)
    }
    if !orphanedKeys.isEmpty {
        saveAssetMetadata()
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Services/MetadataManager.swift
git commit -m "feat: add key remapping and app storage cleanup to MetadataManager"
```

---

## Task 4: Update Capture Path

**Files:**
- Modify: `SimFolio/Features/Capture/CaptureFlowView.swift`
- Modify: `SimFolio/Features/Profile/Settings/CaptureSettingsView.swift`

Change the capture flow to save photos to `PhotoStorageService` instead of `PHPhotoLibrary`. Add the "Save to Camera Roll" toggle.

- [ ] **Step 1: Add "Save to Camera Roll" toggle to CaptureSettingsView**

In `CaptureSettingsView.swift`, add the AppStorage property alongside the other saving settings (~line 28):

```swift
@AppStorage("saveToCameraRoll") private var saveToCameraRoll = false
```

Add a toggle in the saving section (after the `imageQuality` picker, before the section closing brace):

```swift
Divider().padding(.leading, AppTheme.Spacing.md)

Toggle(isOn: $saveToCameraRoll) {
    VStack(alignment: .leading, spacing: 2) {
        Text("Save to Camera Roll")
            .font(AppTheme.Typography.body)
            .foregroundStyle(AppTheme.Colors.textPrimary)
        Text("Also save a copy to the Photos app")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
}
.tint(AppTheme.Colors.primary)
.padding(.horizontal, AppTheme.Spacing.md)
.padding(.vertical, 10)
```

- [ ] **Step 2: Update CaptureFlowView.savePhotos()**

In `CaptureFlowView.swift`, find the `savePhotos()` function in `CaptureReviewView` (~line 1369). Replace the save logic.

Add this AppStorage at the top of `CaptureReviewView` (alongside other state properties):

```swift
@AppStorage("saveToCameraRoll") private var saveToCameraRoll = false
```

Replace the save loop body. Current code calls `PhotoLibraryManager.shared.saveWithMetadata(image:metadata:)`. New code:

```swift
func savePhotos() {
    let baseMetadata = PhotoMetadata(
        procedure: captureState.selectedProcedure,
        toothNumber: captureState.selectedToothNumber,
        toothDate: captureState.selectedToothDate,
        stage: captureState.selectedStage,
        angle: captureState.selectedAngle,
        rating: nil
    )

    for photo in photosToSave {
        var photoMetadata = baseMetadata
        photoMetadata.rating = photo.rating > 0 ? photo.rating : nil

        // Save to app storage
        let record = PhotoStorageService.shared.savePhoto(photo.image)

        // Store metadata keyed by new UUID
        MetadataManager.shared.assignMetadata(photoMetadata, to: record.id.uuidString)

        // Add tooth entry
        if let entry = photoMetadata.toothEntry {
            MetadataManager.shared.addToothEntry(entry)
        }

        // Optionally save to camera roll
        if saveToCameraRoll {
            PhotoLibraryManager.shared.saveImageToCameraRoll(photo.image)
        }

        // Analytics
        AnalyticsService.logPhotoCaptured(
            procedure: photoMetadata.procedure,
            stage: photoMetadata.stage,
            toothNumber: photoMetadata.toothNumber
        )
    }

    captureState.reset()
    router.selectedTab = .home
}
```

- [ ] **Step 3: Add `saveImageToCameraRoll` helper to PhotoLibraryManager**

This is a fire-and-forget method that just saves to the Photos library without tracking the asset. Add to `PhotoLibraryManager.swift`:

```swift
/// Save image to camera roll without tracking (fire-and-forget)
func saveImageToCameraRoll(_ image: UIImage) {
    PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
    } completionHandler: { success, error in
        if let error = error {
            print("Failed to save to camera roll: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Capture/CaptureFlowView.swift SimFolio/Features/Profile/Settings/CaptureSettingsView.swift SimFolio/Services/PhotoLibraryManager.swift
git commit -m "feat: capture path saves to app storage, add camera roll toggle"
```

---

## Task 5: Update HomeView

**Files:**
- Modify: `SimFolio/Features/Home/HomeView.swift`

HomeView displays recent photo thumbnails in a horizontal scroll via `RecentThumbnailView`. Update to use `PhotoStorageService` instead of `PHAsset`.

- [ ] **Step 1: Update HomeView data source**

Replace `PhotoLibraryManager.shared` references with `PhotoStorageService.shared` for the recent photos section.

Where HomeView currently accesses `library.assets` for recent photos, switch to `PhotoStorageService.shared.records`.

Update `RecentThumbnailView` (~line 257-286) to accept a `PhotoRecord` instead of `PHAsset`:

```swift
struct RecentThumbnailView: View {
    let record: PhotoRecord
    @State private var image: UIImage?

    var body: some View {
        // Same layout, just different image loading
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.surfaceSecondary)
            }
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}
```

Update callers of `RecentThumbnailView` to pass `PhotoRecord` instead of `PHAsset`. Update the count references: `library.assets.count` → `PhotoStorageService.shared.records.count`.

Keep `@ObservedObject var library = PhotoLibraryManager.shared` if it's used for photo count in ProfileView, but update the HomeView's recent photos to iterate over `PhotoStorageService.shared.records.prefix(10)`.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Home/HomeView.swift
git commit -m "feat: HomeView loads thumbnails from app storage"
```

---

## Task 6: Update LibraryView Grid and Filtering

**Files:**
- Modify: `SimFolio/Features/Library/LibraryView.swift`

This is the largest change. LibraryView (3,931 lines) uses `PHAsset` throughout. The approach: replace the data source from `PhotoLibraryManager.assets` ([PHAsset]) to `PhotoStorageService.records` ([PhotoRecord]), and update all components that display photos.

**Key changes:**
1. Data source: `PhotoStorageService.shared.records` instead of `library.assets`
2. Filtering: Filter on `PhotoRecord.id.uuidString` against `MetadataManager.assetMetadata`
3. `PhotoGridCell`: Accept `PhotoRecord` instead of `PHAsset`, load thumbnail from disk
4. `LibraryPhotoThumbnail`: Same change
5. Selection tracking: `Set<UUID>` instead of `Set<String>` (PHAsset.localIdentifier)
6. Photo count: `PhotoStorageService.shared.records.count`

- [ ] **Step 1: Add PhotoStorageService as observed object**

At the top of `LibraryView`, add:

```swift
@ObservedObject var photoStorage = PhotoStorageService.shared
```

- [ ] **Step 2: Replace data source**

Wherever `library.assets` is used as the photo data source, replace with `photoStorage.records`. The `filteredAssets` computed property should become `filteredRecords`, filtering `PhotoRecord` objects against metadata.

Replace the `filteredAssets` pattern:

```swift
var filteredRecords: [PhotoRecord] {
    var result = photoStorage.records

    // Apply procedure filter
    if let procedure = selectedProcedure {
        result = result.filter { record in
            metadataManager.assetMetadata[record.id.uuidString]?.procedure == procedure
        }
    }

    // Apply stage filter
    if let stage = selectedStage {
        result = result.filter { record in
            metadataManager.assetMetadata[record.id.uuidString]?.stage == stage
        }
    }

    // Apply search
    if !searchText.isEmpty {
        result = result.filter { record in
            guard let metadata = metadataManager.assetMetadata[record.id.uuidString] else { return false }
            let search = searchText.lowercased()
            return (metadata.procedure?.lowercased().contains(search) ?? false) ||
                   (metadata.stage?.lowercased().contains(search) ?? false) ||
                   (metadata.angle?.lowercased().contains(search) ?? false)
        }
    }

    return result
}
```

- [ ] **Step 3: Update PhotoGridCell**

Change `PhotoGridCell` to accept `PhotoRecord` instead of `PHAsset`:

```swift
struct PhotoGridCell: View {
    let record: PhotoRecord
    let metadata: PhotoMetadata?
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    @ObservedObject var metadataManager: MetadataManager

    @State private var image: UIImage?

    // ... same layout code, just change thumbnail loading ...

    private func loadThumbnail() {
        guard image == nil else { return }
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }

    private func loadThumbnailForce() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}
```

Update all callers of `PhotoGridCell` to pass `PhotoRecord` instead of `PHAsset`.

- [ ] **Step 4: Update LibraryPhotoThumbnail**

Same pattern — accept `PhotoRecord` instead of `PHAsset`:

```swift
struct LibraryPhotoThumbnail: View {
    let record: PhotoRecord
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?

    // ... same layout ...

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}
```

- [ ] **Step 5: Update selection tracking**

Change selection sets from `Set<String>` (PHAsset.localIdentifier) to `Set<UUID>` (PhotoRecord.id). Update all selection-related code:
- `selectedAssets` → `selectedPhotoIds: Set<UUID>`
- Selection toggles: `selectedPhotoIds.insert(record.id)` / `.remove(record.id)`

- [ ] **Step 6: Update delete functionality**

Replace PHAsset deletion with `PhotoStorageService.deletePhotos(ids:)`:

```swift
func deleteSelectedPhotos() {
    let idsToDelete = Array(selectedPhotoIds)

    // Remove metadata
    for id in idsToDelete {
        metadataManager.assetMetadata.removeValue(forKey: id.uuidString)
    }
    metadataManager.saveAssetMetadata()

    // Remove edit states
    for id in idsToDelete {
        PhotoEditPersistenceService.shared.deleteEditState(for: id.uuidString)
    }

    // Delete files
    PhotoStorageService.shared.deletePhotos(ids: idsToDelete)

    selectedPhotoIds.removeAll()
}
```

- [ ] **Step 7: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. There may be many compiler errors on first pass — work through them systematically. Every `PHAsset` reference in this file should be replaced with `PhotoRecord` or removed.

- [ ] **Step 8: Commit**

```bash
git add SimFolio/Features/Library/LibraryView.swift
git commit -m "feat: LibraryView uses PhotoStorageService instead of PHAsset"
```

---

## Task 7: Update Photo Detail and Photo Editor

**Files:**
- Modify: `SimFolio/Features/Library/LibraryView.swift` (PhotoDetailView, PhotoDetailSheet are in this file)
- Modify: `SimFolio/Features/PhotoEditor/PhotoEditorView.swift`

- [ ] **Step 1: Update PhotoDetailSheet**

`PhotoDetailSheet` currently takes a `photoId: String` (PHAsset.localIdentifier) and `allAssets: [PHAsset]`. Change to work with UUID:

```swift
struct PhotoDetailSheet: View {
    let photoId: UUID
    let allRecords: [PhotoRecord]
    var onDismiss: () -> Void = {}
    var onPhotoTagged: ((String) -> Void)?
    @State private var isPresented = true

    var body: some View {
        if let record = allRecords.first(where: { $0.id == photoId }) {
            PhotoDetailView(
                record: record,
                allRecords: allRecords,
                isPresented: $isPresented
            )
        }
    }
}
```

- [ ] **Step 2: Update PhotoDetailView**

Change `PhotoDetailView` to accept `PhotoRecord` instead of `PHAsset`. Update image loading:

```swift
// Replace: PhotoLibraryManager.shared.requestEditedImage(for: currentAsset) { ... }
// With:
func loadFullImage() {
    guard let baseImage = PhotoStorageService.shared.loadImage(id: currentRecord.id) else { return }
    // Apply edits if any
    let editedImage = PhotoEditPersistenceService.shared.applyStoredEdits(
        to: baseImage,
        assetId: currentRecord.id.uuidString
    )
    self.image = editedImage
}
```

Replace `currentAsset: PHAsset` with `currentRecord: PhotoRecord`. Replace `allAssets: [PHAsset]` with `allRecords: [PhotoRecord]`. Replace navigation by `localIdentifier` with navigation by `UUID`.

- [ ] **Step 3: Update PhotoEditorView**

`PhotoEditorView` loads a full-res image for editing. Change it to accept a `UUID` (or `PhotoRecord`) and load via `PhotoStorageService`:

```swift
// Replace PHAsset-based image loading with:
func loadImage() {
    guard let image = PhotoStorageService.shared.loadImage(id: photoId) else { return }
    self.originalImage = image
}
```

The editor saves edits via `PhotoEditPersistenceService` keyed by asset ID string — change the key to `photoId.uuidString`.

If the editor has a "Save copy" feature that writes back to PHPhotoLibrary, update it to write back to `PhotoStorageService` (overwrite the original file or save as new).

- [ ] **Step 4: Update callers in ContentView**

In `ContentView.sheetContent(for:)`, the `.photoDetail` case passes `photoLibrary.assets`. Update:

```swift
case .photoDetail(let id):
    if let uuid = UUID(uuidString: id) {
        PhotoDetailSheet(
            photoId: uuid,
            allRecords: PhotoStorageService.shared.records,
            onDismiss: { router.dismissSheet() },
            onPhotoTagged: { _ in router.dismissSheet() }
        )
    }
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Library/LibraryView.swift SimFolio/Features/PhotoEditor/PhotoEditorView.swift SimFolio/App/ContentView.swift
git commit -m "feat: photo detail and editor use PhotoStorageService"
```

---

## Task 8: Update Portfolio Views

**Files:**
- Modify: `SimFolio/Features/Portfolios/PortfolioChecklistTab.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioDetailView.swift`
- Modify: `SimFolio/Features/Portfolios/PortfolioPhotosTab.swift`

These views display thumbnails for portfolio requirements and photos. They reference PHAsset for thumbnail loading.

- [ ] **Step 1: Update PortfolioChecklistTab**

Find all `PHAsset` references. Where it loads thumbnails for matched requirements, change to:

```swift
// Replace: PhotoLibraryManager.shared.requestThumbnail(for: asset, ...) { image in ... }
// With:
if let uuid = UUID(uuidString: assetId) {
    image = PhotoStorageService.shared.loadThumbnail(id: uuid)
}
```

Replace `PHAsset` parameters with `String` (UUID string from metadata key) or `UUID`.

- [ ] **Step 2: Update PortfolioDetailView**

Same pattern — replace PHAsset thumbnail loading with PhotoStorageService. Update any navigation that passes PHAsset to photo detail.

- [ ] **Step 3: Update PortfolioPhotosTab**

Same pattern — replace PHAsset data source and thumbnail loading.

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Portfolios/PortfolioChecklistTab.swift SimFolio/Features/Portfolios/PortfolioDetailView.swift SimFolio/Features/Portfolios/PortfolioPhotosTab.swift
git commit -m "feat: portfolio views use PhotoStorageService"
```

---

## Task 9: Update Export

**Files:**
- Modify: `SimFolio/Features/Portfolios/PortfolioExportSheet.swift`

Export currently loads images via `PHImageManager`. Change to load from file URLs.

- [ ] **Step 1: Replace image loading**

Replace the `loadImage(from asset: PHAsset)` method (~line 571):

```swift
func loadImage(for assetId: String) throws -> UIImage {
    guard let uuid = UUID(uuidString: assetId),
          let image = PhotoStorageService.shared.loadImage(id: uuid) else {
        throw ExportError.failedToLoadImage
    }

    // Apply saved edits
    let editedImage = PhotoEditPersistenceService.shared.applyStoredEdits(
        to: image,
        assetId: assetId
    )
    return editedImage
}
```

- [ ] **Step 2: Update exportAsZip to use asset IDs instead of PHAssets**

Replace the `matchingAssets: [PHAsset]` references with asset ID strings from metadata. Instead of iterating over `PHAsset` objects, iterate over matching metadata keys:

```swift
// Get matching asset IDs from metadata
let matchingAssetIds: [String] = portfolio.requirements.flatMap { req in
    metadataManager.assetMetadata.compactMap { (key, metadata) in
        if metadata.procedure == req.procedure &&
           metadata.stage == req.stage &&
           metadata.angle == req.angle {
            return key
        }
        return nil
    }
}
```

Update the export loop to call `loadImage(for: assetId)` instead of `loadImage(from: asset)`.

For `asset.creationDate` in date-based organization, look up `PhotoStorageService.shared.records.first(where: { $0.id.uuidString == assetId })?.createdDate`.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/Portfolios/PortfolioExportSheet.swift
git commit -m "feat: export loads photos from app storage"
```

---

## Task 10: Create PhotoMigrationService

**Files:**
- Create: `SimFolio/Services/PhotoMigrationService.swift`
- Create: `SimFolioTests/PhotoMigrationServiceTests.swift`

One-time migration: copies photos from the "SimFolio" album in the Photos library to app storage, builds a key mapping for MetadataManager and PhotoEditPersistenceService.

- [ ] **Step 1: Write tests for key remapping logic**

```swift
// PhotoMigrationServiceTests.swift

import XCTest
@testable import SimFolio

final class PhotoMigrationServiceTests: XCTestCase {

    func testBuildKeyMappingCreatesCorrectMapping() {
        // Given old asset IDs and new UUIDs
        let oldIds = ["old-asset-1", "old-asset-2", "old-asset-3"]
        let newIds = [UUID(), UUID(), UUID()]

        let mapping = PhotoMigrationService.buildKeyMapping(
            oldAssetIds: oldIds,
            newPhotoIds: newIds
        )

        XCTAssertEqual(mapping.count, 3)
        XCTAssertEqual(mapping["old-asset-1"], newIds[0])
        XCTAssertEqual(mapping["old-asset-2"], newIds[1])
        XCTAssertEqual(mapping["old-asset-3"], newIds[2])
    }

    func testRemapEditStateKeys() {
        let oldKey = "old-asset-1"
        let newId = UUID()
        let mapping: [String: UUID] = [oldKey: newId]

        var editStates: [String: EditState] = [:]
        let editState = EditState(assetId: oldKey)
        editStates[oldKey] = editState

        let remapped = PhotoMigrationService.remapEditStateKeys(editStates, mapping: mapping)

        XCTAssertNil(remapped[oldKey])
        XCTAssertNotNil(remapped[newId.uuidString])
    }
}
```

- [ ] **Step 2: Implement PhotoMigrationService**

```swift
// PhotoMigrationService.swift
// SimFolio - One-time migration from Photos library to app storage

import UIKit
import Photos

class PhotoMigrationService {

    static let migrationCompleteKey = "photoMigrationComplete"

    /// Check if migration is needed
    static func needsMigration() -> Bool {
        !UserDefaults.standard.bool(forKey: migrationCompleteKey)
            && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            && hasPhotosInLibrary()
    }

    /// Check if there are any photos to migrate
    private static func hasPhotosInLibrary() -> Bool {
        let manager = PhotoLibraryManager.shared
        return !manager.assets.isEmpty
    }

    /// Run the migration. Reports progress as (completed, total).
    /// Returns the key mapping from old asset IDs to new UUIDs.
    static func migrate(progress: @escaping (Int, Int) -> Void) async -> [String: UUID] {
        let assets = PhotoLibraryManager.shared.assets
        let total = assets.count
        var mapping: [String: UUID] = [:]

        for (index, asset) in assets.enumerated() {
            // Load full-res image from PHAsset
            let image = await loadImageFromAsset(asset)

            if let image = image {
                // Save to app storage
                let record = await MainActor.run {
                    PhotoStorageService.shared.savePhoto(image)
                }

                mapping[asset.localIdentifier] = record.id
            }

            await MainActor.run {
                progress(index + 1, total)
            }
        }

        // Mark migration complete
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)

        return mapping
    }

    /// Load full-res image from PHAsset (async wrapper)
    private static func loadImageFromAsset(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // PHImageManager may call completion twice (low + high quality)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // MARK: - Key Mapping Helpers

    /// Build a mapping from old asset IDs to new UUIDs
    static func buildKeyMapping(oldAssetIds: [String], newPhotoIds: [UUID]) -> [String: UUID] {
        var mapping: [String: UUID] = [:]
        for (index, oldId) in oldAssetIds.enumerated() where index < newPhotoIds.count {
            mapping[oldId] = newPhotoIds[index]
        }
        return mapping
    }

    /// Remap edit state dictionary keys using the migration mapping
    static func remapEditStateKeys(_ editStates: [String: EditState], mapping: [String: UUID]) -> [String: EditState] {
        var remapped: [String: EditState] = [:]
        for (oldKey, state) in editStates {
            if let newId = mapping[oldKey] {
                remapped[newId.uuidString] = state
            } else {
                remapped[oldKey] = state
            }
        }
        return remapped
    }

    /// Apply key remapping to PhotoEditPersistenceService
    static func remapEditStates(using mapping: [String: UUID]) {
        let service = PhotoEditPersistenceService.shared
        for (oldKey, newId) in mapping {
            if let editState = service.getEditState(for: oldKey) {
                service.saveEditState(editState, for: newId.uuidString)
                service.deleteEditState(for: oldKey)
            }
        }
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests/PhotoMigrationServiceTests 2>&1 | tail -20
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Services/PhotoMigrationService.swift SimFolioTests/PhotoMigrationServiceTests.swift
git commit -m "feat: add PhotoMigrationService for Photos library to app storage migration"
```

---

## Task 11: Wire Migration into ContentView

**Files:**
- Modify: `SimFolio/App/ContentView.swift`

Show a migration progress view on first launch after update. Run migration, remap keys, then proceed to normal app flow.

- [ ] **Step 1: Add migration state**

Add to ContentView's state properties:

```swift
@State private var isMigrating: Bool = false
@State private var migrationProgress: (Int, Int) = (0, 0)
```

- [ ] **Step 2: Add migration check to initializeApp()**

In the `initializeApp()` function, after `loadAppData()` and before the `MainActor.run` block that sets `isAppReady`, add:

```swift
// Check if photo migration is needed
if PhotoMigrationService.needsMigration() {
    await MainActor.run {
        isMigrating = true
    }

    let mapping = await PhotoMigrationService.migrate { completed, total in
        Task { @MainActor in
            migrationProgress = (completed, total)
        }
    }

    // Remap metadata keys
    await MainActor.run {
        MetadataManager.shared.remapMetadataKeys(mapping)
        PhotoMigrationService.remapEditStates(using: mapping)
        isMigrating = false
    }
}
```

- [ ] **Step 3: Add migration progress view**

In the body, update the `launchScreen` or add a new view:

```swift
if isAppReady {
    mainAppContent
} else if isMigrating {
    migrationProgressView
} else {
    launchScreen
}
```

Add the migration view:

```swift
private var migrationProgressView: some View {
    ZStack {
        AppTheme.Colors.background.ignoresSafeArea()

        VStack(spacing: AppTheme.Spacing.lg) {
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("Updating Photo Storage")
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Moving your photos to secure app storage...")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if migrationProgress.1 > 0 {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView(value: Double(migrationProgress.0), total: Double(migrationProgress.1))
                        .tint(AppTheme.Colors.primary)

                    Text("\(migrationProgress.0) of \(migrationProgress.1) photos")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
            }
        }
    }
}
```

- [ ] **Step 4: Update ContentView data source**

Replace `@ObservedObject private var photoLibrary = PhotoLibraryManager.shared` with:

```swift
@ObservedObject private var photoStorage = PhotoStorageService.shared
```

Keep `PhotoLibraryManager` import for migration support, but remove it from the main observation chain. Update `ProfileView` photo count to use `PhotoStorageService.shared.records.count` instead of `library.assets.count`.

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add SimFolio/App/ContentView.swift
git commit -m "feat: wire photo migration into app launch with progress UI"
```

---

## Task 12: Cleanup and Final Verification

**Files:**
- Modify: `SimFolio/Services/PhotoLibraryManager.swift` (strip down to migration + camera roll only)
- Modify: `SimFolio/Features/Profile/ProfileView.swift` (update photo count source)
- Potentially modify: Performance files (`EfficientPhotoLibrary.swift`, `ImageCache.swift`, `LazyLoadingHelpers.swift`) if they have PHAsset-specific code that's no longer used

- [ ] **Step 1: Strip PhotoLibraryManager**

Remove methods that are no longer used (thumbnail loading, edited image loading, album management for saves). Keep:
- `fetchAssets()` — still needed for migration
- `assets` property — still needed for migration
- `saveImageToCameraRoll()` — needed for the camera roll toggle
- Album finding — needed for migration fetch

Remove or deprecate:
- `saveWithMetadata()` — replaced by PhotoStorageService
- `requestThumbnail()` — replaced by PhotoStorageService
- `requestImage()` — replaced by PhotoStorageService
- `requestEditedImage()` / `requestEditedThumbnail()` — replaced

- [ ] **Step 2: Update ProfileView photo count**

In `ProfileView.swift`, change `photoCount` from `library.assets.count` to `PhotoStorageService.shared.records.count`. Add `@ObservedObject var photoStorage = PhotoStorageService.shared` if needed.

- [ ] **Step 3: Check remaining PHAsset references**

Search for any remaining `PHAsset` references outside of PhotoLibraryManager and migration code:

```bash
grep -r "PHAsset\|PhotoLibraryManager" SimFolio/ --include="*.swift" | grep -v "PhotoLibraryManager.swift" | grep -v "PhotoMigrationService.swift" | grep -v "Tests/"
```

Fix any remaining references.

- [ ] **Step 4: Run full build**

```bash
xcodebuild -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED with no warnings related to photo storage.

- [ ] **Step 5: Run unit tests**

```bash
xcodebuild test -project SimFolio.xcodeproj -scheme SimFolio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SimFolioTests 2>&1 | tail -40
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: strip PhotoLibraryManager to migration-only, clean up PHAsset references"
```

---

## Execution Order

```
Task 1  → Task 2  → Task 3  → Task 4
(model)   (service)  (metadata)  (capture)

Task 5  → Task 6  → Task 7  → Task 8  → Task 9
(home)    (library)  (detail)   (portfolio) (export)

Task 10 → Task 11 → Task 12
(migration) (wiring)  (cleanup)
```

All tasks are sequential — each builds on the previous. Tasks 5-9 are the core view-layer swap and should be done in order since they share the same data source change.

## Verification Checklist

After all tasks complete:

1. **New user flow:** Reset all data (`--reset-all-data`), capture a photo → verify it appears in Library (from app storage, not Photos library) → verify it does NOT appear in the Photos app
2. **"Save to Camera Roll" toggle:** Enable toggle, capture photo → verify it appears in BOTH app storage and Photos app
3. **Existing user migration:** Set up a test with photos in the Photos library → simulate first launch → verify migration progress shows → verify all photos appear in Library after migration → verify metadata is preserved
4. **Photo detail:** Tap a photo → verify full-res loads → verify edits display correctly
5. **Photo editor:** Edit a photo → verify edits save and display on return
6. **Export:** Export a portfolio → verify images load correctly from app storage
7. **Deletion:** Delete a photo from Library → verify it's removed from app storage
8. **Portfolio views:** Verify portfolio requirement thumbnails still display
