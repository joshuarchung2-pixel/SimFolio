# App-Controlled Photo Storage

## Problem

Photos are stored in the iOS Photos library (PHAsset in a "SimFolio" album). Users can accidentally delete them from the Photos app, and the app has no way to back them up or recover them. The "Back Up Your Portfolio" messaging promises safety but doesn't deliver on it yet.

## Solution

Move photo storage from the iOS Photos library to the app's Documents directory. Photos become app-owned files identified by UUID, invisible to the Photos app, and protected from accidental deletion. An optional "Save to Camera Roll" toggle preserves the ability to share photos outside SimFolio.

## New Components

### PhotoRecord

Lightweight model replacing PHAsset as the photo identifier.

```swift
struct PhotoRecord: Codable, Identifiable {
    let id: UUID              // Also the filename stem ({id}.jpg)
    let createdDate: Date
    var fileSize: Int64
}
```

Stored as a JSON array in MetadataManager (same persistence pattern as portfolios).

### PhotoStorageService

Singleton managing files in `Documents/Photos/` (full-res) and `Documents/Thumbnails/` (thumbnails).

**Public API:**

```swift
@MainActor
class PhotoStorageService: ObservableObject {
    static let shared = PhotoStorageService()

    @Published var records: [PhotoRecord]  // Sorted by createdDate descending

    // CRUD
    func savePhoto(_ image: UIImage) -> PhotoRecord
    func loadImage(id: UUID) -> UIImage?
    func loadThumbnail(id: UUID) -> UIImage?
    func deletePhoto(id: UUID)
    func deletePhotos(ids: [UUID])

    // Bulk
    func allRecords() -> [PhotoRecord]
    func diskUsage() -> Int64  // Total bytes
}
```

**File layout:**
```
Documents/
  Photos/
    {uuid}.jpg          # Full-res JPEG (quality matching current photoQuality setting)
  Thumbnails/
    {uuid}.jpg          # 300px thumbnail JPEG
```

**Thumbnail generation:** On save, generate a 300px-max-dimension JPEG thumbnail at 0.7 compression quality. This replaces `PHImageManager` thumbnail requests. Full-res JPEGs use the user's `imageQuality` setting (from Capture Settings).

**Persistence:** `records` array saved to UserDefaults as JSON (key: `"photoRecords"`), loaded at init. Same pattern as `MetadataManager.portfolios`.

### PhotoMigrationService

One-time migration for existing users whose photos are in the Photos library.

```swift
class PhotoMigrationService {
    static func needsMigration() -> Bool
    static func migrate(progress: (Int, Int) -> Void) async -> [String: UUID]  // oldAssetId → newUUID
}
```

**Migration steps:**
1. Fetch all PHAssets from the "SimFolio" album
2. For each asset: request full-res image, save to `Documents/Photos/{newUUID}.jpg`, generate thumbnail
3. Build `[oldAssetId: newUUID]` mapping
4. Return mapping so caller can remap MetadataManager and PhotoEditPersistenceService keys
5. Set `UserDefaults "photoMigrationComplete" = true`

**Progress reporting:** The caller (ContentView) shows a progress view during migration. Could be many photos, so this must be async with progress updates.

**Photos library cleanup:** Do NOT delete photos from the Photos library after migration. The user may still want them there. Just stop referencing them.

## Changes to Existing Code

### CaptureFlowView / CameraService

**Current:** After capture, saves to PHPhotoLibrary → gets PHAsset → stores localIdentifier.

**New:** After capture, calls `PhotoStorageService.savePhoto(image)` → gets `PhotoRecord`. If "Save to Camera Roll" toggle is on, also saves copy to PHPhotoLibrary (fire-and-forget, no reference stored).

### MetadataManager

**Current:** `assetMetadata: [String: PhotoMetadata]` keyed by `PHAsset.localIdentifier`.

**New:** Same dictionary, keyed by `PhotoRecord.id.uuidString`. No model changes to PhotoMetadata itself.

Add: `@Published var photoRecords: [PhotoRecord]` (or delegate to PhotoStorageService).

Migration remaps all keys from old asset IDs to new UUIDs.

### PhotoLibraryManager

**Current:** Manages PHFetchResult, creates "SimFolio" album, fetches assets.

**New:** Retained only for migration (reading existing photos) and the "Save to Camera Roll" feature. No longer the primary photo source. Most of its functionality is replaced by PhotoStorageService.

### LibraryView

**Current:** Displays `PhotoLibraryManager.assets` (PHAsset array) in a grid using `PHImageManager` for thumbnails.

**New:** Displays `PhotoStorageService.records` in a grid. Thumbnails loaded from disk via `PhotoStorageService.loadThumbnail(id:)`. The grid layout, filtering, and selection logic remain unchanged — only the data source and image loading change.

### Photo Detail Views

**Current:** Load full-res via `PHImageManager.requestImage(for: asset)`.

**New:** Load full-res via `PhotoStorageService.loadImage(id:)`. Returns `UIImage?` synchronously from disk.

### PhotoEditPersistenceService

**Current:** Edit states keyed by PHAsset.localIdentifier.

**New:** Same keys, now UUID strings. Migration remaps keys. No API changes.

### Export

**Current:** Loads images from PHAsset for export.

**New:** Loads images from `PhotoStorageService.loadImage(id:)` or directly from file URLs (`Documents/Photos/{uuid}.jpg`).

### ContentView (Migration Wiring)

On app launch, before showing the main UI:
1. Check `PhotoMigrationService.needsMigration()`
2. If yes, show a migration progress view (replacing the launch screen)
3. Run migration, get key mapping
4. Remap `MetadataManager.assetMetadata` keys
5. Remap `PhotoEditPersistenceService` keys
6. Proceed to normal app flow

### Capture Settings

Add toggle: **"Save to Camera Roll"** (default: off).
- `@AppStorage("saveToPhotoLibrary") var saveToPhotoLibrary = false`
- When enabled, after saving to app storage, also save a copy to PHPhotoLibrary
- This is a convenience copy — the app sandbox is always the source of truth

## What Stays the Same

- `PhotoMetadata` model (procedure, stage, angle, tooth number, rating)
- `Portfolio` model and all portfolio/requirement logic
- `ImageAdjustments`, `ImageTransform`, `EditState` models
- `ImageProcessingService` (CoreImage-based editing)
- All UI layouts — views receive images from a different source but render identically
- Design system, navigation, tab structure
- Analytics, auth, social feed, onboarding
- UserDefaults as the persistence layer for non-photo data

## Permissions Impact

**Camera permission:** Still required (capture).

**Photo Library permission:** Changes from required to optional.
- Required only if "Save to Camera Roll" is enabled or during migration
- New users who don't enable the toggle never need photo library permission
- Onboarding camera permission page stays; photo library permission page becomes conditional

## Edge Cases

- **Disk full:** `savePhoto` should throw/return nil if write fails. Show toast.
- **Corrupted file:** `loadImage` returns nil → show placeholder in UI.
- **Migration interrupted:** Track per-asset migration progress. Resume where left off on next launch.
- **iCloud backup:** Documents directory is backed up by iCloud by default. Large photo libraries could affect iCloud storage. Consider using `Documents/` (backed up) vs `Library/Application Support/` (not backed up by default). Decision: use `Documents/` — backup is a feature, not a bug, given the "Back Up Your Portfolio" framing.
- **App deletion:** If the user deletes the app, photos are gone. This is expected for app-only storage. The "Back Up Your Portfolio" account creation provides the cloud safety net (future Firestore sync).
