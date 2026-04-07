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
