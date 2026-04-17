// PhotoStorageService.swift
// SimFolio - File-based photo storage service
//
// Manages photos in the app's Documents directory. Photos are stored as JPEG files
// identified by UUID. Thumbnails are generated on save for efficient grid display.

import UIKit
import Combine

@MainActor
class PhotoStorageService: ObservableObject, PhotoStoring {
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

    // MARK: - URL Helpers

    private func photoURL(for id: UUID) -> URL {
        Self.photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    private func thumbnailURL(for id: UUID) -> URL {
        Self.thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    // MARK: - Save

    /// Save an image to app storage and generate a thumbnail. Returns the new PhotoRecord.
    @discardableResult
    func savePhoto(_ image: UIImage, compressionQuality: CGFloat = 0.85) -> PhotoRecord {
        savePhoto(image, createdDate: Date(), compressionQuality: compressionQuality)
    }

    /// Save an image with an explicit createdDate (used when importing existing photos whose
    /// original capture date must be preserved — e.g. from PHAsset.creationDate).
    @discardableResult
    func savePhoto(_ image: UIImage, createdDate: Date, compressionQuality: CGFloat = 0.85) -> PhotoRecord {
        let id = UUID()

        let data = image.jpegData(compressionQuality: compressionQuality) ?? Data()
        try? data.write(to: photoURL(for: id))

        let thumbnail = generateThumbnail(from: image)
        let thumbData = thumbnail.jpegData(compressionQuality: thumbnailCompressionQuality) ?? Data()
        try? thumbData.write(to: thumbnailURL(for: id))

        let record = PhotoRecord(
            id: id,
            createdDate: createdDate,
            fileSize: Int64(data.count)
        )

        records.insert(record, at: 0)
        sortRecordsByCreatedDate()
        saveRecords()

        return record
    }

    private func sortRecordsByCreatedDate() {
        records.sort { $0.createdDate > $1.createdDate }
    }

    // MARK: - Load

    /// Load full-resolution image from disk (unedited original bytes)
    func loadImage(id: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL(for: id)) else { return nil }
        return UIImage(data: data)
    }

    /// Load thumbnail image from disk (unedited original bytes)
    func loadThumbnail(id: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: thumbnailURL(for: id)) else { return nil }
        return UIImage(data: data)
    }

    /// Load full-resolution image with any persisted edits applied.
    /// Use this for display. The editor should continue to use `loadImage`
    /// so it operates on the unedited original.
    func loadEditedImage(id: UUID) -> UIImage? {
        guard let raw = loadImage(id: id) else { return nil }
        return PhotoEditPersistenceService.shared.applyStoredEdits(
            to: raw,
            assetId: id.uuidString
        )
    }

    /// Load thumbnail with any persisted edits applied.
    /// Use this for display in grids and lists.
    func loadEditedThumbnail(id: UUID) -> UIImage? {
        guard let raw = loadThumbnail(id: id) else { return nil }
        return PhotoEditPersistenceService.shared.applyStoredEditsForPreview(
            to: raw,
            assetId: id.uuidString
        )
    }

    // MARK: - Delete

    /// Delete a photo and its thumbnail from disk
    func deletePhoto(id: UUID) {
        try? FileManager.default.removeItem(at: photoURL(for: id))
        try? FileManager.default.removeItem(at: thumbnailURL(for: id))

        records.removeAll { $0.id == id }
        saveRecords()
    }

    /// Delete multiple photos
    func deletePhotos(ids: [UUID]) {
        for id in ids {
            try? FileManager.default.removeItem(at: photoURL(for: id))
            try? FileManager.default.removeItem(at: thumbnailURL(for: id))
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
