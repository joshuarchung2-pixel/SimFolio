// PhotoLibraryManager.swift
// Photo library access and operations
//
// Will contain:
//
// PhotoLibraryManager (ObservableObject, singleton):
//
// Published State:
// - assets: [PHAsset] - All photos in the Dental Portfolio album
//
// Album Management:
// - createAlbumIfNeeded(): Create "Dental Portfolio" album if not exists
// - fetchAssets(): Refresh asset list from Photos library
//
// Save Operations:
// - save(image:procedure:otherTags:completion:): Legacy save with TagManager
// - saveWithMetadata(image:metadata:completion:): Save with PhotoMetadata
//
// Read Operations:
// - requestThumbnail(for:completion:): Load 200x200 thumbnail
// - requestImage(for:completion:): Load full resolution image
//
// Delete Operations:
// - deleteAssets(identifiers:completion:): Delete specified photos
// - deletePhotosWithIncompleteTags(completion:): Cleanup incomplete photos
//
// Private:
// - albumName: String = "Dental Portfolio"
//
// Migration notes:
// - Extract PhotoLibraryManager from gem1 lines 6363-6479
// - Consider removing legacy save() method (uses TagManager)
// - Add batch operations for better performance
// - Consider adding PHPhotoLibraryChangeObserver for live updates

import Photos
import UIKit

// MARK: - PhotoLibraryManager

/// Central manager for Photos library access
/// Singleton accessible via PhotoLibraryManager.shared
class PhotoLibraryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PhotoLibraryManager()

    // MARK: - Published State

    /// All photos in the Dental Portfolio album
    @Published var assets: [PHAsset] = []

    // MARK: - Private Properties

    private let albumName = "Dental Portfolio"
    private var album: PHAssetCollection?

    // MARK: - Initialization

    private init() {
        // Find or create album on init
        findOrCreateAlbum()
    }

    // MARK: - Album Management

    /// Find existing album or create new one
    private func findOrCreateAlbum() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existingAlbum = collections.firstObject {
            album = existingAlbum
        }
        // TODO: Create album if it doesn't exist
    }

    /// Fetch all assets from the album
    func fetchAssets() {
        guard let album = album else {
            assets = []
            return
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)

        var fetchedAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }

        DispatchQueue.main.async {
            self.assets = fetchedAssets
        }
    }

    // MARK: - Thumbnail Loading

    /// Request a thumbnail for an asset
    /// - Parameters:
    ///   - asset: The PHAsset to load
    ///   - size: Target size for the thumbnail
    ///   - completion: Callback with the loaded image
    func requestThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Request full resolution image for an asset
    /// - Parameters:
    ///   - asset: The PHAsset to load
    ///   - completion: Callback with the loaded image
    func requestImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
