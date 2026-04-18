// PhotoLibraryManager.swift
// SimFolio - Photo library access and operations
//
// Will contain:
//
// PhotoLibraryManager (ObservableObject, singleton):
//
// Published State:
// - assets: [PHAsset] - All photos in the SimFolio album
//
// Album Management:
// - createAlbumIfNeeded(): Create "SimFolio" album if not exists
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
// - albumName: String = "SimFolio"
//
// Migration notes:
// - Extract PhotoLibraryManager from gem1 lines 6363-6479
// - Consider removing legacy save() method (uses TagManager)
// - Add batch operations for better performance
// - Consider adding PHPhotoLibraryChangeObserver for live updates

import Photos
import UIKit
import Combine

// MARK: - PhotoLibraryManager

/// Central manager for Photos library access
/// Singleton accessible via PhotoLibraryManager.shared
class PhotoLibraryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PhotoLibraryManager()

    // MARK: - Published State

    /// All photos in the SimFolio album
    @Published var assets: [PHAsset] = []

    // MARK: - Private Properties

    private let albumName = "SimFolio"
    private var album: PHAssetCollection?

    // MARK: - Initialization

    private init() {
        // Don't access photo library on init - wait for explicit permission
        // Album will be created/found when needed (e.g., when saving a photo)
    }

    /// Initialize the photo library manager after permission is granted
    /// Call this after the user grants photo library permission
    func initializeIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            findOrCreateAlbum()
        }
    }

    // MARK: - Album Management

    /// Find existing album or create new one
    private func findOrCreateAlbum() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existingAlbum = collections.firstObject {
            album = existingAlbum
        } else {
            // Create album if it doesn't exist
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            } completionHandler: { success, error in
                if success {
                    // Re-fetch to get the newly created album
                    DispatchQueue.main.async {
                        let newFetchOptions = PHFetchOptions()
                        newFetchOptions.predicate = NSPredicate(format: "title = %@", self.albumName)
                        let newCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: newFetchOptions)
                        self.album = newCollections.firstObject
                    }
                } else if let error = error {
                    #if DEBUG
                    print("Error creating album: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    /// Fetch all assets from the album (or all photos if no album)
    /// Only fetches if photo library permission is granted
    func fetchAssets() {
        // Check permission before accessing photo library
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            // Not authorized - don't access photo library
            return
        }

        // Initialize album if needed (now that we have permission)
        if album == nil {
            findOrCreateAlbum()
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var fetchedAssets: [PHAsset] = []

        if let album = album {
            // Fetch from SimFolio album
            let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
            fetchResult.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
        } else {
            // Fall back to fetching all photos that have metadata in MetadataManager
            // This ensures we show photos even if the album doesn't exist yet
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            allPhotos.enumerateObjects { asset, _, _ in
                // Only include photos that have SimFolio metadata
                if MetadataManager.shared.assetMetadata[asset.localIdentifier] != nil {
                    fetchedAssets.append(asset)
                }
            }
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
    @discardableResult
    func requestThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return PHImageManager.default().requestImage(
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

    // MARK: - Edited Image Loading

    /// Request a thumbnail with any saved edits applied
    /// - Parameters:
    ///   - asset: The PHAsset to load
    ///   - size: Target size for the thumbnail
    ///   - completion: Callback with the edited image
    func requestEditedThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        // Check if there are saved edits first
        let hasEdits = PhotoEditPersistenceService.shared.hasEditState(for: asset.localIdentifier)

        if hasEdits {
            // Need to load a larger image to apply edits, then scale down
            let editSize = CGSize(width: size.width * 2, height: size.height * 2)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: editSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    guard let image = image else {
                        completion(nil)
                        return
                    }
                    // Apply stored edits
                    let editedImage = PhotoEditPersistenceService.shared.applyStoredEditsForPreview(
                        to: image,
                        assetId: asset.localIdentifier
                    )
                    completion(editedImage)
                }
            }
        } else {
            // No edits, use fast thumbnail loading
            requestThumbnail(for: asset, size: size, completion: completion)
        }
    }

    /// Request full resolution image with any saved edits applied
    /// - Parameters:
    ///   - asset: The PHAsset to load
    ///   - completion: Callback with the edited image
    func requestEditedImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        requestImage(for: asset) { image in
            guard let image = image else {
                completion(nil)
                return
            }
            // Apply stored edits if any
            let editedImage = PhotoEditPersistenceService.shared.applyStoredEdits(
                to: image,
                assetId: asset.localIdentifier
            )
            completion(editedImage)
        }
    }

    /// Request full resolution image with any saved edits applied asynchronously
    /// - Parameters:
    ///   - asset: The PHAsset to load
    ///   - completion: Callback with the edited image
    func requestEditedImageAsync(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        requestImage(for: asset) { image in
            guard let image = image else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Check if edits exist
            guard let editState = PhotoEditPersistenceService.shared.getEditState(for: asset.localIdentifier) else {
                // No edits, return original
                DispatchQueue.main.async {
                    completion(image)
                }
                return
            }

            // Apply edits: adjustments/transforms off main, markup on main.
            Task {
                let editedImage = await ImageProcessingService.shared.applyEditsAsync(to: image, editState: editState)
                await MainActor.run {
                    completion(editedImage ?? image)
                }
            }
        }
    }

    // MARK: - Save Operations

    /// Save an image with metadata to the Photos library
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - metadata: PhotoMetadata to associate with the image
    ///   - completion: Callback with the saved asset's local identifier (or nil on failure)
    func saveWithMetadata(image: UIImage, metadata: PhotoMetadata, completion: @escaping (String?) -> Void) {
        // Ensure we have an album first, then save
        ensureAlbumExists { [weak self] albumReady in
            self?.performSave(image: image, metadata: metadata, completion: completion)
        }
    }

    /// Ensure the SimFolio album exists before saving
    private func ensureAlbumExists(completion: @escaping (Bool) -> Void) {
        if album != nil {
            completion(true)
            return
        }

        // Try to find or create the album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existingAlbum = collections.firstObject {
            album = existingAlbum
            completion(true)
            return
        }

        // Create the album
        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    // Re-fetch to get the newly created album
                    let newFetchOptions = PHFetchOptions()
                    newFetchOptions.predicate = NSPredicate(format: "title = %@", self.albumName)
                    let newCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: newFetchOptions)
                    self.album = newCollections.firstObject
                }
                completion(success)
            }
        }
    }

    /// Actually perform the save operation
    private func performSave(image: UIImage, metadata: PhotoMetadata, completion: @escaping (String?) -> Void) {
        var assetIdentifier: String?
        var assetPlaceholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges {
            // Create the asset
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetPlaceholder = request.placeholderForCreatedAsset
            assetIdentifier = assetPlaceholder?.localIdentifier

            // Add to album if available
            if let album = self.album, let placeholder = assetPlaceholder {
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets([placeholder] as NSArray)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success, let identifier = assetIdentifier {
                    #if DEBUG
                    print("✅ Photo saved successfully with ID: \(identifier)")
                    #endif

                    // Store metadata in MetadataManager (use assignMetadata to persist to UserDefaults)
                    MetadataManager.shared.assignMetadata(metadata, to: identifier)

                    // Add tooth entry if available
                    if let entry = metadata.toothEntry {
                        MetadataManager.shared.addToothEntry(entry)
                    }

                    // Refresh assets
                    self.fetchAssets()

                    completion(identifier)
                } else {
                    #if DEBUG
                    print("❌ Failed to save photo: \(error?.localizedDescription ?? "Unknown error")")
                    #endif
                    completion(nil)
                }
            }
        }
    }

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

    /// Create album if it doesn't exist
    func createAlbumIfNeeded(completion: @escaping (Bool) -> Void) {
        // Check if album already exists
        if album != nil {
            completion(true)
            return
        }

        // Create new album
        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    // Fetch the newly created album
                    self.findOrCreateAlbum()
                }
                completion(success)
            }
        }
    }
}
