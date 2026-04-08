// PhotoMigrationService.swift
// SimFolio - One-time migration from Photos library to app storage

import UIKit
import Photos

class PhotoMigrationService {

    static let migrationCompleteKey = "photoMigrationComplete"

    // MARK: - Migration Check

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

    // MARK: - Migration

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
                // Save to app storage (MainActor required)
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
