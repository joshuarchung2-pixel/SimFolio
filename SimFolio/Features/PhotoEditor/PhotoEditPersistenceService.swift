// PhotoEditPersistenceService.swift
// Persistence service for photo edit states
//
// Stores edit states in UserDefaults so edits persist across app launches.
// When a photo is edited, the edit state is saved and can be retrieved
// when the user returns to edit the same photo.

import Foundation
import Photos
import UIKit

// MARK: - Photo Edit Persistence Service

/// Service for persisting photo edit states
final class PhotoEditPersistenceService {

    // MARK: - Singleton

    static let shared = PhotoEditPersistenceService()

    // MARK: - Constants

    private let userDefaultsKey = "photoEditStates"
    private let maxStoredEdits = 100

    // MARK: - Properties

    /// In-memory cache of edit states
    private var editStatesCache: [String: EditState] = [:]

    /// Serial queue for thread-safe cache access
    private let cacheQueue = DispatchQueue(label: "com.simfolio.editStateCacheQueue")

    // MARK: - Initialization

    private init() {
        loadEditStates()
    }

    // MARK: - Public Methods

    /// Save an edit state for a photo
    /// - Parameters:
    ///   - editState: The edit state to save
    ///   - assetId: The asset identifier
    func saveEditState(_ editState: EditState, for assetId: String) {
        cacheQueue.sync {
            // Only save if there are actual changes
            if editState.hasChanges {
                editStatesCache[assetId] = editState
            } else {
                // Remove edit state if reset to defaults
                editStatesCache.removeValue(forKey: assetId)
            }
        }

        // Persist to UserDefaults
        persistEditStates()
    }

    /// Get the edit state for a photo
    /// - Parameter assetId: The asset identifier
    /// - Returns: The saved edit state, or nil if none exists
    func getEditState(for assetId: String) -> EditState? {
        return cacheQueue.sync { editStatesCache[assetId] }
    }

    /// Check if a photo has saved edits
    /// - Parameter assetId: The asset identifier
    /// - Returns: True if the photo has saved edits
    func hasEditState(for assetId: String) -> Bool {
        return cacheQueue.sync { editStatesCache[assetId] != nil }
    }

    /// Delete the edit state for a photo
    /// - Parameter assetId: The asset identifier
    func deleteEditState(for assetId: String) {
        editStatesCache.removeValue(forKey: assetId)
        persistEditStates()
    }

    /// Delete all edit states
    func deleteAllEditStates() {
        editStatesCache.removeAll()
        persistEditStates()
    }

    /// Get the number of stored edit states
    var editStateCount: Int {
        return editStatesCache.count
    }

    /// Clean up edit states for deleted photos
    /// - Parameter existingAssetIds: Set of asset IDs that still exist
    func cleanupOrphanedEditStates(existingAssetIds: Set<String>) {
        let orphanedIds = Set(editStatesCache.keys).subtracting(existingAssetIds)

        for id in orphanedIds {
            editStatesCache.removeValue(forKey: id)
        }

        if !orphanedIds.isEmpty {
            persistEditStates()
        }
    }

    // MARK: - Private Methods

    /// Load edit states from UserDefaults
    private func loadEditStates() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: EditState].self, from: data) else {
            return
        }

        editStatesCache = decoded
    }

    /// Persist edit states to UserDefaults
    private func persistEditStates() {
        // Limit the number of stored edits
        if editStatesCache.count > maxStoredEdits {
            // Remove oldest entries (this is a simple approach; could be improved with timestamps)
            let keysToRemove = Array(editStatesCache.keys.prefix(editStatesCache.count - maxStoredEdits))
            for key in keysToRemove {
                editStatesCache.removeValue(forKey: key)
            }
        }

        guard let encoded = try? JSONEncoder().encode(editStatesCache) else {
            print("Failed to encode edit states")
            return
        }

        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }
}

// MARK: - Photo Library Extension

extension PhotoEditPersistenceService {

    /// Apply saved edits to a newly loaded image
    /// - Parameters:
    ///   - image: The original image
    ///   - assetId: The asset identifier
    /// - Returns: The edited image if edits exist, otherwise the original
    func applyStoredEdits(to image: UIImage, assetId: String) -> UIImage {
        guard let editState = getEditState(for: assetId) else {
            return image
        }

        return ImageProcessingService.shared.applyEdits(to: image, editState: editState) ?? image
    }

    /// Get a preview with stored edits applied
    /// - Parameters:
    ///   - image: The original image
    ///   - assetId: The asset identifier
    /// - Returns: The edited preview if edits exist, otherwise the original
    func applyStoredEditsForPreview(to image: UIImage, assetId: String) -> UIImage {
        guard let editState = getEditState(for: assetId) else {
            return image
        }

        return ImageProcessingService.shared.generatePreview(
            from: image,
            editState: editState,
            maxDimension: 400
        ) ?? image
    }
}

// MARK: - Edit State Summary

extension PhotoEditPersistenceService {

    /// Get a summary of edits applied to a photo
    /// - Parameter assetId: The asset identifier
    /// - Returns: A human-readable summary of the edits
    func getEditSummary(for assetId: String) -> String? {
        guard let editState = getEditState(for: assetId) else {
            return nil
        }

        var parts: [String] = []

        // Transform summary
        if editState.transform.hasChanges {
            var transformParts: [String] = []

            if editState.transform.cropRect != nil {
                transformParts.append("Cropped")
            }

            if editState.transform.rotation90Count != 0 {
                transformParts.append("Rotated \(editState.transform.rotation90Count * 90)°")
            }

            if editState.transform.fineRotation != 0 {
                transformParts.append(String(format: "Straightened %.1f°", editState.transform.fineRotation))
            }

            if !transformParts.isEmpty {
                parts.append(transformParts.joined(separator: ", "))
            }
        }

        // Adjustment summary
        if editState.adjustments.hasChanges {
            var adjustmentCount = 0
            if editState.adjustments.brightness != 0 { adjustmentCount += 1 }
            if editState.adjustments.exposure != 0 { adjustmentCount += 1 }
            if editState.adjustments.highlights != 0 { adjustmentCount += 1 }
            if editState.adjustments.shadows != 0 { adjustmentCount += 1 }
            if editState.adjustments.contrast != 1.0 { adjustmentCount += 1 }
            if editState.adjustments.blackPoint != 0 { adjustmentCount += 1 }
            if editState.adjustments.saturation != 1.0 { adjustmentCount += 1 }
            if editState.adjustments.brilliance != 0 { adjustmentCount += 1 }
            if editState.adjustments.sharpness != 0 { adjustmentCount += 1 }
            if editState.adjustments.definition != 0 { adjustmentCount += 1 }

            if adjustmentCount > 0 {
                parts.append("\(adjustmentCount) adjustment\(adjustmentCount == 1 ? "" : "s")")
            }
        }

        // Markup summary
        if editState.markup.hasMarkup {
            var markupParts: [String] = []
            var lineCount = 0
            var measurementCount = 0
            var textCount = 0

            for element in editState.markup.elements {
                switch element {
                case .freeformLine:
                    lineCount += 1
                case .measurementLine:
                    measurementCount += 1
                case .textBox:
                    textCount += 1
                }
            }

            if lineCount > 0 {
                markupParts.append("\(lineCount) drawing\(lineCount == 1 ? "" : "s")")
            }
            if measurementCount > 0 {
                markupParts.append("\(measurementCount) measurement\(measurementCount == 1 ? "" : "s")")
            }
            if textCount > 0 {
                markupParts.append("\(textCount) text\(textCount == 1 ? "" : "s")")
            }

            if !markupParts.isEmpty {
                parts.append("Markup: " + markupParts.joined(separator: ", "))
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
