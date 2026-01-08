// ImageCache.swift
// Dental Portfolio - Image Caching System
//
// Provides efficient image caching for PHAssets with automatic
// memory management and prefetching support.
//
// Features:
// - In-memory cache with configurable limits
// - PHAsset image loading with size optimization
// - Request cancellation for off-screen items
// - Prefetching for smooth scrolling
// - Thread-safe actor-based implementation

import SwiftUI
import Photos

// MARK: - Image Cache

/// Actor-based image cache for thread-safe caching operations
actor ImageCache {
    /// Shared singleton instance
    static let shared = ImageCache()

    // MARK: - Properties

    private var cache = NSCache<NSString, UIImage>()
    private var requestIDs: [String: PHImageRequestID] = [:]

    private let imageManager = PHCachingImageManager()

    // MARK: - Initialization

    init() {
        // Configure cache limits
        cache.countLimit = 200 // Max 200 images
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB

        // Configure image manager
        imageManager.allowsCachingHighQualityImages = true
    }

    // MARK: - Cache Operations

    /// Retrieve cached image for key
    /// - Parameter key: Cache key
    /// - Returns: Cached image if available
    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Store image in cache
    /// - Parameters:
    ///   - image: Image to cache
    ///   - key: Cache key
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Remove image from cache
    /// - Parameter key: Cache key
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        requestIDs.removeAll()
    }

    // MARK: - PHAsset Loading

    /// Load image for PHAsset with caching
    /// - Parameters:
    ///   - asset: Photo asset to load
    ///   - targetSize: Desired image size
    ///   - contentMode: Content mode for resizing
    ///   - deliveryMode: Delivery mode (opportunistic, fast, high quality)
    /// - Returns: Loaded image or nil
    func loadImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    ) async -> UIImage? {
        let cacheKey = "\(asset.localIdentifier)-\(Int(targetSize.width))x\(Int(targetSize.height))"

        // Check cache first
        if let cached = image(forKey: cacheKey) {
            return cached
        }

        // Load from Photos
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { [weak self] image, info in
                Task {
                    if let image = image {
                        await self?.setImage(image, forKey: cacheKey)
                    }

                    // Only return final image (not degraded)
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        continuation.resume(returning: image)
                    }
                }
            }

            Task {
                await self.setRequestID(requestID, forKey: cacheKey)
            }
        }
    }

    /// Load high quality image for full screen display
    /// - Parameter asset: Photo asset to load
    /// - Returns: Full resolution image
    func loadFullSizeImage(for asset: PHAsset) async -> UIImage? {
        let targetSize = CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
        )

        return await loadImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat
        )
    }

    /// Cancel pending image request
    /// - Parameter key: Cache key for the request
    func cancelRequest(forKey key: String) {
        if let requestID = requestIDs[key] {
            imageManager.cancelImageRequest(requestID)
            requestIDs.removeValue(forKey: key)
        }
    }

    private func setRequestID(_ id: PHImageRequestID, forKey key: String) {
        requestIDs[key] = id
    }

    // MARK: - Prefetching

    /// Start caching images for assets
    /// - Parameters:
    ///   - assets: Assets to prefetch
    ///   - targetSize: Target size for cached images
    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    /// Stop caching images for assets
    /// - Parameters:
    ///   - assets: Assets to stop caching
    ///   - targetSize: Target size used for caching
    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    /// Stop all image caching
    func stopAllCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    // MARK: - Cache Statistics

    /// Get current cache count
    var cacheCount: Int {
        // NSCache doesn't expose count, so we track approximately
        cache.countLimit
    }
}

// MARK: - Cached Async Image View

/// SwiftUI view that loads and caches PHAsset images
struct CachedAsyncImage: View {
    let asset: PHAsset
    let targetSize: CGSize
    var contentMode: ContentMode = .fill
    var placeholder: AnyView = AnyView(
        AppTheme.Colors.surfaceSecondary
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(AppTheme.Colors.textTertiary)
            )
    )

    @State private var image: UIImage?
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.textSecondary))
                    )
            } else {
                placeholder
            }
        }
        .task(id: asset.localIdentifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        image = await ImageCache.shared.loadImage(
            for: asset,
            targetSize: targetSize
        )
        isLoading = false
    }
}

// MARK: - Cached Thumbnail View

/// Optimized thumbnail view for grid displays
struct CachedThumbnailView: View {
    let asset: PHAsset
    let size: CGFloat

    @State private var image: UIImage?
    @State private var hasLoaded: Bool = false

    private var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: size * scale, height: size * scale)
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AppTheme.Colors.surfaceSecondary
                    .overlay(
                        Group {
                            if !hasLoaded {
                                shimmerOverlay
                            }
                        }
                    )
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
        .onDisappear {
            cancelLoading()
        }
    }

    private var shimmerOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .rotationEffect(.degrees(30))
    }

    private func loadThumbnail() async {
        image = await ImageCache.shared.loadImage(
            for: asset,
            targetSize: targetSize,
            deliveryMode: .fastFormat
        )
        hasLoaded = true
    }

    private func cancelLoading() {
        let cacheKey = "\(asset.localIdentifier)-\(Int(targetSize.width))x\(Int(targetSize.height))"
        Task {
            await ImageCache.shared.cancelRequest(forKey: cacheKey)
        }
    }
}

// MARK: - Image Prefetcher

/// Coordinates image prefetching for smooth scrolling
class ImagePrefetcher {
    private let cache = ImageCache.shared
    private var prefetchedAssets: Set<String> = []

    /// Prefetch images for upcoming assets
    /// - Parameters:
    ///   - assets: Assets to prefetch
    ///   - targetSize: Target size for prefetched images
    func prefetch(assets: [PHAsset], targetSize: CGSize) {
        let newAssets = assets.filter { !prefetchedAssets.contains($0.localIdentifier) }

        guard !newAssets.isEmpty else { return }

        Task {
            await cache.startCaching(assets: newAssets, targetSize: targetSize)
        }

        newAssets.forEach { prefetchedAssets.insert($0.localIdentifier) }
    }

    /// Cancel prefetch for assets no longer needed
    /// - Parameters:
    ///   - assets: Assets to cancel
    ///   - targetSize: Target size used for prefetching
    func cancelPrefetch(assets: [PHAsset], targetSize: CGSize) {
        Task {
            await cache.stopCaching(assets: assets, targetSize: targetSize)
        }

        assets.forEach { prefetchedAssets.remove($0.localIdentifier) }
    }

    /// Clear all prefetch state
    func reset() {
        Task {
            await cache.stopAllCaching()
        }
        prefetchedAssets.removeAll()
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ImageCache_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Image Cache Preview")
                .font(AppTheme.Typography.title3)

            // Note: Cannot preview actual PHAsset loading without Photos permission
            Rectangle()
                .fill(AppTheme.Colors.surfaceSecondary)
                .frame(width: 200, height: 200)
                .overlay(
                    ProgressView()
                )
                .cornerRadius(AppTheme.CornerRadius.md)
        }
        .padding()
    }
}
#endif
