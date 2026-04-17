// PhotoImportService.swift
// SimFolio - Orchestrates importing candidates from the Photos library into app storage
//
// Responsibilities:
// - Iterate ImportCandidates, skipping any whose PHAsset identifier is already imported
// - Persist each photo via PhotoStoring.savePhoto(_:createdDate:) preserving original date
// - Record metadata via MetadataManaging.assignMetadata
// - Mark imported IDs to dedupe re-imports
// - Report progress and honor cancellation between items

import UIKit

// MARK: - PhotoImporting

protocol PhotoImporting {
    func importCandidates(
        _ candidates: [ImportCandidate],
        metadata: PhotoMetadata,
        onProgress: @escaping (ImportProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) async -> ImportResult
}

// MARK: - PhotoImportService

final class PhotoImportService: PhotoImporting {

    // MARK: Shared instance (uses production singletons)

    @MainActor
    static let shared = PhotoImportService(
        photoStorage: PhotoStorageService.shared,
        metadata: MetadataManager.shared
    )

    // MARK: Dependencies

    private let photoStorage: PhotoStoring
    private let metadata: MetadataManaging

    init(photoStorage: PhotoStoring, metadata: MetadataManaging) {
        self.photoStorage = photoStorage
        self.metadata = metadata
    }

    // MARK: Import

    /// Imports the given candidates into app storage and attaches the provided metadata
    /// (rating is overridden per-candidate by `ImportCandidate.rating`).
    ///
    /// - Skipped: candidates whose `pHAssetId` is already in the imported set.
    /// - Failed: candidates with a load error OR nil image.
    /// - Imported: everything else; the photo is saved, metadata assigned, and the PHAsset
    ///   identifier marked as imported.
    ///
    /// Progress is reported after each processed candidate (success, skip, or fail).
    /// Cancellation is polled before each candidate; already-saved work is kept.
    func importCandidates(
        _ candidates: [ImportCandidate],
        metadata baseMetadata: PhotoMetadata,
        onProgress: @escaping (ImportProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) async -> ImportResult {
        var progress = ImportProgress(completed: 0, total: candidates.count, skipped: 0, failed: 0)
        var importedCount = 0

        for candidate in candidates {
            if isCancelled() {
                break
            }

            // Dedupe by PHAsset identifier (empty/missing IDs are not deduped).
            if let assetId = candidate.pHAssetId, !assetId.isEmpty,
               await metadataHasImported(assetId: assetId) {
                progress.skipped += 1
                progress.completed += 1
                onProgress(progress)
                continue
            }

            // Treat missing image or load error as a failure; keep batch going.
            guard candidate.loadError == nil, let image = candidate.image else {
                progress.failed += 1
                progress.completed += 1
                onProgress(progress)
                continue
            }

            let createdDate = candidate.originalCapturedDate ?? Date()

            // savePhoto is @MainActor on the live service, so hop to the main actor.
            let record = await MainActor.run { () -> PhotoRecord in
                photoStorage.savePhoto(image, createdDate: createdDate, compressionQuality: 0.85)
            }

            var perPhotoMetadata = baseMetadata
            perPhotoMetadata.rating = candidate.rating > 0 ? candidate.rating : baseMetadata.rating
            await MainActor.run {
                metadata.assignMetadata(perPhotoMetadata, to: record.id.uuidString)
                if let entry = perPhotoMetadata.toothEntry, let mm = metadata as? MetadataManager {
                    mm.addToothEntry(entry)
                }
                if let assetId = candidate.pHAssetId, !assetId.isEmpty {
                    metadata.markImported(assetId: assetId)
                }
            }

            importedCount += 1
            progress.completed += 1
            onProgress(progress)
        }

        return ImportResult(
            imported: importedCount,
            skipped: progress.skipped,
            failed: progress.failed
        )
    }

    // MARK: - Helpers

    private func metadataHasImported(assetId: String) async -> Bool {
        await MainActor.run { metadata.hasImported(assetId: assetId) }
    }
}
