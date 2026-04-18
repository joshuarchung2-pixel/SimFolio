// PhotoEditModels.swift
// Models for photo editing feature
//
// Contains:
// - ImageAdjustments: Stores all adjustment values (brightness, contrast, etc.)
// - ImageTransform: Stores transformation values (crop, rotation)
// - EditState: Complete state for photo editing
// - EditHistory: Undo/redo stack for edits

import SwiftUI
import CoreImage
import Combine

// MARK: - Image Adjustments

/// Stores all image adjustment slider values
/// Each value is normalized around 0 (default), with negative and positive ranges
/// Ranges are reduced by 50% from standard values for finer control
struct ImageAdjustments: Codable, Equatable {
    /// Brightness adjustment (-0.5 to 0.5, default 0)
    var brightness: Double = 0

    /// Exposure adjustment (-1.0 to 1.0, default 0)
    var exposure: Double = 0

    /// Highlights adjustment (-0.5 to 0.5, default 0)
    var highlights: Double = 0

    /// Shadows adjustment (-0.5 to 0.5, default 0)
    var shadows: Double = 0

    /// Contrast adjustment (0.75 to 1.25, default 1.0)
    var contrast: Double = 1.0

    /// Black point adjustment (0 to 0.25, default 0)
    var blackPoint: Double = 0

    /// Saturation adjustment (0.5 to 1.5, default 1.0)
    var saturation: Double = 1.0

    /// Brilliance adjustment (-0.5 to 0.5, default 0)
    var brilliance: Double = 0

    /// Sharpness adjustment (0 to 1.0, default 0)
    var sharpness: Double = 0

    /// Definition adjustment (0 to 1.0, default 0)
    var definition: Double = 0

    /// Whether any adjustment has been modified from default
    var hasChanges: Bool {
        brightness != 0 ||
        exposure != 0 ||
        highlights != 0 ||
        shadows != 0 ||
        contrast != 1.0 ||
        blackPoint != 0 ||
        saturation != 1.0 ||
        brilliance != 0 ||
        sharpness != 0 ||
        definition != 0
    }

    /// Reset all adjustments to defaults
    mutating func reset() {
        brightness = 0
        exposure = 0
        highlights = 0
        shadows = 0
        contrast = 1.0
        blackPoint = 0
        saturation = 1.0
        brilliance = 0
        sharpness = 0
        definition = 0
    }

    /// Default adjustments
    static let `default` = ImageAdjustments()
}

// MARK: - Image Transform

/// Stores image transformation values (crop and rotation)
struct ImageTransform: Codable, Equatable {
    /// Crop rectangle in normalized coordinates (0-1)
    /// nil means no crop (use full image)
    var cropRect: CGRect?

    /// Fine rotation angle in degrees (-45 to 45)
    var fineRotation: Double = 0

    /// 90-degree rotation count (0, 1, 2, or 3 = 0°, 90°, 180°, 270°)
    var rotation90Count: Int = 0

    /// Total rotation in degrees
    var totalRotationDegrees: Double {
        fineRotation + Double(rotation90Count * 90)
    }

    /// Total rotation in radians
    var totalRotationRadians: Double {
        totalRotationDegrees * .pi / 180
    }

    /// Whether any transform has been applied
    var hasChanges: Bool {
        cropRect != nil || fineRotation != 0 || rotation90Count != 0
    }

    /// Reset all transforms to defaults
    mutating func reset() {
        cropRect = nil
        fineRotation = 0
        rotation90Count = 0
    }

    /// Rotate 90 degrees clockwise
    mutating func rotate90Clockwise() {
        rotation90Count = (rotation90Count + 1) % 4
    }

    /// Rotate 90 degrees counter-clockwise
    mutating func rotate90CounterClockwise() {
        rotation90Count = (rotation90Count + 3) % 4
    }

    /// Default transform
    static let `default` = ImageTransform()
}

// MARK: - Edit State

/// Complete editing state for a photo
struct EditState: Codable, Equatable {
    /// Asset identifier for the photo being edited
    var assetId: String

    /// Adjustment values
    var adjustments: ImageAdjustments = ImageAdjustments()

    /// Transform values
    var transform: ImageTransform = ImageTransform()

    /// Markup/annotation state
    var markup: MarkupState = MarkupState()

    /// Whether any edits have been made
    var hasChanges: Bool {
        adjustments.hasChanges || transform.hasChanges || markup.hasMarkup
    }

    /// Reset all edits
    mutating func resetAll() {
        adjustments.reset()
        transform.reset()
        markup.clearAll()
    }

    /// Reset only adjustments
    mutating func resetAdjustments() {
        adjustments.reset()
    }

    /// Reset only transforms
    mutating func resetTransform() {
        transform.reset()
    }

    /// Reset only markup
    mutating func resetMarkup() {
        markup.clearAll()
    }
}

// MARK: - Edit History Entry

/// A single entry in the edit history for undo/redo
struct EditHistoryEntry: Codable, Equatable {
    let state: EditState
    let timestamp: Date

    init(state: EditState) {
        self.state = state
        self.timestamp = Date()
    }
}

// MARK: - Edit History

/// Manages undo/redo stack for edits
class EditHistory: ObservableObject {
    /// Maximum number of undo steps
    private let maxHistorySize = 50

    /// Stack of past states (for undo)
    @Published private(set) var undoStack: [EditHistoryEntry] = []

    /// Stack of future states (for redo)
    @Published private(set) var redoStack: [EditHistoryEntry] = []

    /// Whether undo is available
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether redo is available
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Record a new state (clears redo stack)
    func record(_ state: EditState) {
        undoStack.append(EditHistoryEntry(state: state))

        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Clear redo stack when new edit is made
        redoStack.removeAll()
    }

    /// Undo to previous state
    /// - Parameter currentState: The current state before undo
    /// - Returns: The previous state, or nil if no undo available
    func undo(currentState: EditState) -> EditState? {
        guard let previous = undoStack.popLast() else { return nil }

        // Save current state to redo stack
        redoStack.append(EditHistoryEntry(state: currentState))

        return previous.state
    }

    /// Redo to next state
    /// - Parameter currentState: The current state before redo
    /// - Returns: The next state, or nil if no redo available
    func redo(currentState: EditState) -> EditState? {
        guard let next = redoStack.popLast() else { return nil }

        // Save current state to undo stack
        undoStack.append(EditHistoryEntry(state: currentState))

        return next.state
    }

    /// Clear all history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // Explicit `nonisolated deinit` avoids the compiler emitting
    // `swift_task_deinitOnExecutorMainActorBackDeploy` for this class's
    // deallocating deinit. That shim has a heap-corruption bug (double-free of
    // its TaskLocal scope) that SIGABRTs when short-lived instances are
    // destroyed back-to-back — reproduces reliably in EditHistoryTests on the
    // iOS 26.2 simulator. Bumping the deployment target does not help; the
    // compiler emits the shim regardless.
    nonisolated deinit {}
}

// MARK: - Editor Mode

/// The current editing mode
enum EditorMode: String, CaseIterable, Identifiable {
    case transform = "Transform"
    case adjust = "Adjust"
    case markup = "Markup"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .transform: return "crop.rotate"
        case .adjust: return "slider.horizontal.3"
        case .markup: return "pencil.tip.crop.circle"
        }
    }
}

// MARK: - Transform Sub-Mode

/// Sub-modes within Transform mode
enum TransformSubMode: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case rotate = "Rotate"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .crop: return "crop"
        case .rotate: return "rotate.right"
        }
    }
}

// MARK: - Adjustment Type

/// Types of adjustments available
enum AdjustmentType: String, CaseIterable, Identifiable {
    case brightness = "Brightness"
    case exposure = "Exposure"
    case highlights = "Highlights"
    case shadows = "Shadows"
    case contrast = "Contrast"
    case blackPoint = "Black Point"
    case saturation = "Saturation"
    case brilliance = "Brilliance"
    case sharpness = "Sharpness"
    case definition = "Definition"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brightness: return "sun.max"
        case .exposure: return "plusminus.circle"
        case .highlights: return "sun.max.fill"
        case .shadows: return "moon.fill"
        case .contrast: return "circle.lefthalf.filled"
        case .blackPoint: return "circle.fill"
        case .saturation: return "drop.fill"
        case .brilliance: return "sparkles"
        case .sharpness: return "triangle"
        case .definition: return "square.dashed"
        }
    }

    /// Whether this adjustment requires premium subscription
    var isPremium: Bool {
        switch self {
        case .brightness, .contrast: return false
        default: return true
        }
    }

    /// Default value for this adjustment type
    var defaultValue: Double {
        switch self {
        case .contrast, .saturation: return 1.0
        default: return 0
        }
    }

    /// Minimum slider value
    var minValue: Double {
        switch self {
        case .brightness, .highlights, .shadows, .brilliance: return -0.5
        case .exposure: return -1.0
        case .contrast: return 0.75
        case .blackPoint, .sharpness, .definition: return 0
        case .saturation: return 0.5
        }
    }

    /// Maximum slider value
    var maxValue: Double {
        switch self {
        case .brightness, .highlights, .shadows, .brilliance: return 0.5
        case .exposure: return 1.0
        case .contrast: return 1.25
        case .blackPoint: return 0.25
        case .saturation: return 1.5
        case .sharpness, .definition: return 1.0
        }
    }

    /// Get the current value from adjustments
    func getValue(from adjustments: ImageAdjustments) -> Double {
        switch self {
        case .brightness: return adjustments.brightness
        case .exposure: return adjustments.exposure
        case .highlights: return adjustments.highlights
        case .shadows: return adjustments.shadows
        case .contrast: return adjustments.contrast
        case .blackPoint: return adjustments.blackPoint
        case .saturation: return adjustments.saturation
        case .brilliance: return adjustments.brilliance
        case .sharpness: return adjustments.sharpness
        case .definition: return adjustments.definition
        }
    }

    /// Set the value in adjustments
    func setValue(_ value: Double, in adjustments: inout ImageAdjustments) {
        switch self {
        case .brightness: adjustments.brightness = value
        case .exposure: adjustments.exposure = value
        case .highlights: adjustments.highlights = value
        case .shadows: adjustments.shadows = value
        case .contrast: adjustments.contrast = value
        case .blackPoint: adjustments.blackPoint = value
        case .saturation: adjustments.saturation = value
        case .brilliance: adjustments.brilliance = value
        case .sharpness: adjustments.sharpness = value
        case .definition: adjustments.definition = value
        }
    }
}

// MARK: - Aspect Ratio Presets

/// Preset aspect ratios for cropping
enum AspectRatioPreset: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case original = "Original"
    case square = "Square"
    case ratio4x3 = "4:3"
    case ratio3x4 = "3:4"
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"

    var id: String { rawValue }

    /// The aspect ratio value (width / height), or nil for freeform
    func ratio(originalAspect: CGFloat) -> CGFloat? {
        switch self {
        case .freeform: return nil
        case .original: return originalAspect
        case .square: return 1.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio3x4: return 3.0 / 4.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        }
    }
}
