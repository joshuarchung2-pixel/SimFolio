// EfficientPhotoLibrary.swift
// Dental Portfolio - Efficient Photo Library Management
//
// Provides optimized photo library fetching with pagination,
// caching, and change observation for smooth performance.
//
// Features:
// - Paginated asset fetching
// - Smart caching with PHCachingImageManager
// - Library change observation
// - Filtering by metadata
// - Background loading support

import Photos
import Combine
import SwiftUI

// MARK: - Efficient Photo Library Manager

/// Manages photo library access with efficient pagination and caching
class EfficientPhotoLibraryManager: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = EfficientPhotoLibraryManager()

    // MARK: - Published Properties

    /// Loaded photo assets
    @Published var assets: [PHAsset] = []

    /// Whether currently loading
    @Published var isLoading: Bool = false

    /// Whether more content is available
    @Published var hasMoreContent: Bool = true

    /// Total count of available assets
    @Published var totalAssetCount: Int = 0

    /// Current error if any
    @Published var error: Error?

    // MARK: - Private Properties

    private var fetchResult: PHFetchResult<PHAsset>?
    private var currentPage: Int = 0
    private let pageSize: Int = 50

    private let imageManager = PHCachingImageManager()
    private var cachedAssets: [PHAsset] = []
    private let cachingTargetSize = CGSize(width: 200, height: 200)

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLibraryChangeObserver()
    }

    // MARK: - Fetching

    /// Fetch initial batch of assets
    @MainActor
    func fetchInitialAssets() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 0
        assets = []

        // Check authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            isLoading = false
            return
        }

        // Configure fetch options
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 0 // Fetch all, but we'll paginate access

        // Fetch all assets
        fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        totalAssetCount = fetchResult?.count ?? 0

        // Load first page
        await loadNextPage()

        isLoading = false
    }

    /// Load next page of assets
    @MainActor
    func loadNextPage() async {
        guard let fetchResult = fetchResult else { return }
        guard hasMoreContent else { return }
        guard !isLoading || currentPage == 0 else { return }

        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, fetchResult.count)

        guard startIndex < fetchResult.count else {
            hasMoreContent = false
            return
        }

        // Get assets for this page
        let indexSet = IndexSet(startIndex..<endIndex)
        var pageAssets: [PHAsset] = []

        fetchResult.enumerateObjects(at: indexSet, options: []) { asset, _, _ in
            pageAssets.append(asset)
        }

        // Append to main array
        assets.append(contentsOf: pageAssets)

        // Update caching
        updateCachedAssets()

        // Update pagination state
        currentPage += 1
        hasMoreContent = endIndex < fetchResult.count
    }

    /// Refresh the library
    @MainActor
    func refresh() async {
        await fetchInitialAssets()
    }

    // MARK: - Caching

    private func updateCachedAssets() {
        // Stop caching old assets
        if !cachedAssets.isEmpty {
            imageManager.stopCachingImages(
                for: cachedAssets,
                targetSize: cachingTargetSize,
                contentMode: .aspectFill,
                options: nil
            )
        }

        // Cache visible + buffer assets
        let cacheRange = max(0, assets.count - 100)..<assets.count
        cachedAssets = Array(assets[cacheRange])

        imageManager.startCachingImages(
            for: cachedAssets,
            targetSize: cachingTargetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    // MARK: - Filtering

    /// Get filtered assets based on criteria
    /// - Parameters:
    ///   - procedure: Filter by procedure type
    ///   - stage: Filter by stage
    ///   - angle: Filter by angle
    ///   - startDate: Filter by start date
    ///   - endDate: Filter by end date
    ///   - minRating: Filter by minimum rating
    /// - Returns: Filtered array of assets
    func filteredAssets(
        procedure: String? = nil,
        stage: String? = nil,
        angle: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        minRating: Int? = nil
    ) -> [PHAsset] {
        let metadata = MetadataManager.shared

        return assets.filter { asset in
            guard let meta = metadata.photoMetadata[asset.localIdentifier] else {
                // If no metadata, only include if no filters are set
                return procedure == nil && stage == nil && angle == nil && minRating == nil
            }

            if let procedure = procedure, meta.procedure != procedure {
                return false
            }

            if let stage = stage, meta.stage != stage {
                return false
            }

            if let angle = angle, meta.angle != angle {
                return false
            }

            if let minRating = minRating, (meta.rating ?? 0) < minRating {
                return false
            }

            if let startDate = startDate, let creation = asset.creationDate, creation < startDate {
                return false
            }

            if let endDate = endDate, let creation = asset.creationDate, creation > endDate {
                return false
            }

            return true
        }
    }

    /// Search assets by text query
    /// - Parameter query: Search query
    /// - Returns: Matching assets
    func searchAssets(query: String) -> [PHAsset] {
        guard !query.isEmpty else { return assets }

        let lowercasedQuery = query.lowercased()
        let metadata = MetadataManager.shared

        return assets.filter { asset in
            guard let meta = metadata.photoMetadata[asset.localIdentifier] else {
                return false
            }

            // Search in procedure, stage, angle, notes, tags
            if let procedure = meta.procedure, procedure.lowercased().contains(lowercasedQuery) {
                return true
            }

            if let stage = meta.stage, stage.lowercased().contains(lowercasedQuery) {
                return true
            }

            if let angle = meta.angle, angle.lowercased().contains(lowercasedQuery) {
                return true
            }

            if let notes = meta.notes, notes.lowercased().contains(lowercasedQuery) {
                return true
            }

            if meta.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }

            return false
        }
    }

    // MARK: - Asset Access

    /// Get asset by identifier
    /// - Parameter identifier: Local identifier
    /// - Returns: Asset if found
    func asset(withIdentifier identifier: String) -> PHAsset? {
        assets.first { $0.localIdentifier == identifier }
    }

    /// Get assets by identifiers
    /// - Parameter identifiers: Array of local identifiers
    /// - Returns: Array of matching assets
    func assets(withIdentifiers identifiers: [String]) -> [PHAsset] {
        let identifierSet = Set(identifiers)
        return assets.filter { identifierSet.contains($0.localIdentifier) }
    }

    // MARK: - Library Change Observer

    private func setupLibraryChangeObserver() {
        PHPhotoLibrary.shared().register(self)
    }

    // MARK: - Cleanup

    /// Clean up cached assets and reset state
    func cleanup() {
        imageManager.stopCachingImagesForAllAssets()
        cachedAssets = []
    }

    /// Reset manager state
    func reset() {
        cleanup()
        assets = []
        fetchResult = nil
        currentPage = 0
        hasMoreContent = true
        totalAssetCount = 0
        error = nil
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        cleanup()
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension EfficientPhotoLibraryManager: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = fetchResult,
              let changes = changeInstance.changeDetails(for: fetchResult) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.fetchResult = changes.fetchResultAfterChanges
            self?.totalAssetCount = changes.fetchResultAfterChanges.count

            // Handle changes
            if changes.hasIncrementalChanges {
                // Handle insertions
                if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                    var newAssets: [PHAsset] = []
                    changes.fetchResultAfterChanges.enumerateObjects(at: inserted, options: []) { asset, _, _ in
                        newAssets.append(asset)
                    }
                    self?.assets.insert(contentsOf: newAssets, at: 0)
                }

                // Handle deletions
                if let removed = changes.removedIndexes, !removed.isEmpty {
                    let removedIdentifiers = Set(removed.map { changes.fetchResultBeforeChanges.object(at: $0).localIdentifier })
                    self?.assets.removeAll { removedIdentifiers.contains($0.localIdentifier) }
                }

                // Handle modifications
                if let changed = changes.changedIndexes, !changed.isEmpty {
                    // Assets were modified - update UI if needed
                    NotificationCenter.default.post(
                        name: .photoLibraryAssetsChanged,
                        object: nil,
                        userInfo: ["changedIndexes": changed]
                    )
                }
            } else {
                // Full reload needed
                Task { @MainActor in
                    await self?.fetchInitialAssets()
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when photo library assets change
    static let photoLibraryAssetsChanged = Notification.Name("photoLibraryAssetsChanged")
}

// MARK: - Asset Fetch Request Builder

/// Builder for configuring asset fetch requests
struct AssetFetchRequest {
    var mediaType: PHAssetMediaType = .image
    var sortDescriptors: [NSSortDescriptor] = [
        NSSortDescriptor(key: "creationDate", ascending: false)
    ]
    var fetchLimit: Int = 0
    var predicate: NSPredicate?

    /// Build fetch options from request
    func buildOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = sortDescriptors
        options.fetchLimit = fetchLimit
        options.predicate = predicate
        return options
    }

    /// Fetch assets matching request
    func fetch() -> PHFetchResult<PHAsset> {
        let options = buildOptions()
        return PHAsset.fetchAssets(with: mediaType, options: options)
    }

    // MARK: - Predefined Requests

    /// Request for all images sorted by date
    static var allImages: AssetFetchRequest {
        AssetFetchRequest(mediaType: .image)
    }

    /// Request for favorite images
    static var favorites: AssetFetchRequest {
        var request = AssetFetchRequest(mediaType: .image)
        request.predicate = NSPredicate(format: "isFavorite == YES")
        return request
    }

    /// Request for recent images (last 30 days)
    static var recent: AssetFetchRequest {
        var request = AssetFetchRequest(mediaType: .image)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        request.predicate = NSPredicate(format: "creationDate >= %@", thirtyDaysAgo as NSDate)
        return request
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EfficientPhotoLibrary_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Efficient Photo Library")
                .font(AppTheme.Typography.title2)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Total Assets: \(EfficientPhotoLibraryManager.shared.totalAssetCount)")
                Text("Loaded: \(EfficientPhotoLibraryManager.shared.assets.count)")
                Text("Has More: \(EfficientPhotoLibraryManager.shared.hasMoreContent ? "Yes" : "No")")
            }
            .font(AppTheme.Typography.body)

            HStack(spacing: AppTheme.Spacing.sm) {
                DPButton("Refresh", size: .small) {
                    Task {
                        await EfficientPhotoLibraryManager.shared.refresh()
                    }
                }

                DPButton("Load More", style: .secondary, size: .small) {
                    Task {
                        await EfficientPhotoLibraryManager.shared.loadNextPage()
                    }
                }
            }
        }
        .padding()
    }
}
#endif
