// MarkupModels.swift
// Data models for markup/annotation feature
//
// Contains:
// - MarkupColor: Color representation for markup elements
// - LineWidth: Line thickness options
// - FontSize: Text size options
// - FreeformLine: Freehand drawing paths
// - MeasurementLine: I-shaped measurement indicators
// - TextBox: Text annotations
// - MarkupElement: Unified element type
// - MarkupState: Complete markup state for a photo

import SwiftUI
import UIKit

// MARK: - Markup Color

/// Color representation for markup elements with Codable support
struct MarkupColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    /// Convert to SwiftUI Color
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Convert to UIColor
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Convert to CGColor
    var cgColor: CGColor {
        uiColor.cgColor
    }

    // MARK: - Preset Colors

    static let white = MarkupColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    static let black = MarkupColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    static let red = MarkupColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1.0) // #EF4444
    static let blue = MarkupColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1.0) // #3B82F6
    static let green = MarkupColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0) // #22C55E
    static let yellow = MarkupColor(red: 0.918, green: 0.702, blue: 0.031, alpha: 1.0) // #EAB308
    static let orange = MarkupColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 1.0) // #F97316
    static let purple = MarkupColor(red: 0.659, green: 0.333, blue: 0.969, alpha: 1.0) // #A855F7

    /// All preset colors for the color picker
    static let presets: [MarkupColor] = [
        .white, .black, .red, .blue, .green, .yellow, .orange, .purple
    ]

    /// Initialize from SwiftUI Color (approximate - uses UIColor conversion)
    init(from color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// MARK: - Line Width

/// Line thickness options for drawing and measurement lines
enum LineWidth: Int, Codable, CaseIterable, Identifiable {
    case thin = 1       // 2pt
    case medium = 2     // 4pt
    case thick = 3      // 6pt
    case extraThick = 4 // 8pt
    case bold = 5       // 10pt

    var id: Int { rawValue }

    /// Actual point width
    var pointWidth: CGFloat {
        switch self {
        case .thin: return 2
        case .medium: return 4
        case .thick: return 6
        case .extraThick: return 8
        case .bold: return 10
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .thin: return "Thin"
        case .medium: return "Medium"
        case .thick: return "Thick"
        case .extraThick: return "Extra Thick"
        case .bold: return "Bold"
        }
    }
}

// MARK: - Font Size

/// Font size options for text boxes
enum FontSize: Int, Codable, CaseIterable, Identifiable {
    case small = 12
    case medium = 16
    case large = 20
    case extraLarge = 24

    var id: Int { rawValue }

    /// Actual point size
    var pointSize: CGFloat {
        CGFloat(rawValue)
    }

    /// Display name
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

// MARK: - Codable CGPoint

/// Wrapper for CGPoint to enable Codable support
struct CodablePoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Codable CGSize

/// Wrapper for CGSize to enable Codable support
struct CodableSize: Codable, Equatable, Hashable {
    var width: Double
    var height: Double

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }

    init(_ size: CGSize) {
        self.width = Double(size.width)
        self.height = Double(size.height)
    }

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

// MARK: - Freeform Line

/// A freehand drawing path
struct FreeformLine: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var points: [CodablePoint]
    var color: MarkupColor
    var lineWidth: LineWidth
    var zIndex: Int

    /// Computed bounding rect in normalized coordinates
    var boundingRect: CGRect {
        guard !points.isEmpty else {
            return .zero
        }

        let xs = points.map { $0.x }
        let ys = points.map { $0.y }

        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0

        // Add padding for line width
        let padding = Double(lineWidth.pointWidth) / 1000 // Approximate padding in normalized space

        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: max(maxX - minX + padding * 2, 0.01),
            height: max(maxY - minY + padding * 2, 0.01)
        )
    }

    /// Center point of the bounding rect
    var center: CGPoint {
        let rect = boundingRect
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    init(id: UUID = UUID(), points: [CGPoint], color: MarkupColor, lineWidth: LineWidth, zIndex: Int = 0) {
        self.id = id
        self.points = points.map { CodablePoint($0) }
        self.color = color
        self.lineWidth = lineWidth
        self.zIndex = zIndex
    }
}

// MARK: - Measurement Line

/// An I-shaped line to indicate distance (visual only, no numbers)
struct MeasurementLine: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var startPoint: CodablePoint
    var endPoint: CodablePoint
    var color: MarkupColor
    var lineWidth: LineWidth
    var capLength: Double // Normalized length of the I-caps
    var zIndex: Int

    /// Computed bounding rect in normalized coordinates
    var boundingRect: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)

        // Add padding for caps and line width
        let padding = max(capLength, Double(lineWidth.pointWidth) / 1000)

        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: max(maxX - minX + padding * 2, 0.01),
            height: max(maxY - minY + padding * 2, 0.01)
        )
    }

    /// Center point of the line
    var center: CGPoint {
        CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    /// Angle of the line in radians
    var angle: Double {
        atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
    }

    /// Length of the line in normalized coordinates
    var length: Double {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        return sqrt(dx * dx + dy * dy)
    }

    init(
        id: UUID = UUID(),
        startPoint: CGPoint,
        endPoint: CGPoint,
        color: MarkupColor,
        lineWidth: LineWidth,
        capLength: Double = 0.03,
        zIndex: Int = 0
    ) {
        self.id = id
        self.startPoint = CodablePoint(startPoint)
        self.endPoint = CodablePoint(endPoint)
        self.color = color
        self.lineWidth = lineWidth
        self.capLength = capLength
        self.zIndex = zIndex
    }
}

// MARK: - Text Box

/// A text annotation with customizable styling
struct TextBox: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var position: CodablePoint // Center position in normalized coordinates
    var text: String
    var fontSize: FontSize
    var fontColor: MarkupColor
    var fillColor: MarkupColor? // Optional background fill
    var rotation: Double // Degrees
    var size: CodableSize // Size in normalized coordinates
    var zIndex: Int

    /// Computed bounding rect in normalized coordinates
    var boundingRect: CGRect {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        // For simplicity, return axis-aligned bounding box
        // A more accurate version would account for rotation
        return CGRect(
            x: position.x - halfWidth,
            y: position.y - halfHeight,
            width: size.width,
            height: size.height
        )
    }

    /// Center point (same as position)
    var center: CGPoint {
        position.cgPoint
    }

    init(
        id: UUID = UUID(),
        position: CGPoint,
        text: String,
        fontSize: FontSize = .medium,
        fontColor: MarkupColor = .white,
        fillColor: MarkupColor? = nil,
        rotation: Double = 0,
        size: CGSize = CGSize(width: 0.2, height: 0.05),
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = CodablePoint(position)
        self.text = text
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.fillColor = fillColor
        self.rotation = rotation
        self.size = CodableSize(size)
        self.zIndex = zIndex
    }
}

// MARK: - Markup Element

/// Unified enum for all markup element types
enum MarkupElement: Codable, Identifiable, Equatable, Hashable {
    case freeformLine(FreeformLine)
    case measurementLine(MeasurementLine)
    case textBox(TextBox)

    var id: UUID {
        switch self {
        case .freeformLine(let line): return line.id
        case .measurementLine(let line): return line.id
        case .textBox(let box): return box.id
        }
    }

    var zIndex: Int {
        switch self {
        case .freeformLine(let line): return line.zIndex
        case .measurementLine(let line): return line.zIndex
        case .textBox(let box): return box.zIndex
        }
    }

    var boundingRect: CGRect {
        switch self {
        case .freeformLine(let line): return line.boundingRect
        case .measurementLine(let line): return line.boundingRect
        case .textBox(let box): return box.boundingRect
        }
    }

    var center: CGPoint {
        switch self {
        case .freeformLine(let line): return line.center
        case .measurementLine(let line): return line.center
        case .textBox(let box): return box.center
        }
    }

    var color: MarkupColor {
        switch self {
        case .freeformLine(let line): return line.color
        case .measurementLine(let line): return line.color
        case .textBox(let box): return box.fontColor
        }
    }

    /// Update zIndex in place
    mutating func setZIndex(_ newZIndex: Int) {
        switch self {
        case .freeformLine(var line):
            line.zIndex = newZIndex
            self = .freeformLine(line)
        case .measurementLine(var line):
            line.zIndex = newZIndex
            self = .measurementLine(line)
        case .textBox(var box):
            box.zIndex = newZIndex
            self = .textBox(box)
        }
    }

    /// Update color in place
    mutating func setColor(_ newColor: MarkupColor) {
        switch self {
        case .freeformLine(var line):
            line.color = newColor
            self = .freeformLine(line)
        case .measurementLine(var line):
            line.color = newColor
            self = .measurementLine(line)
        case .textBox(var box):
            box.fontColor = newColor
            self = .textBox(box)
        }
    }
}

// MARK: - Markup Sub-Mode

/// Sub-modes within Markup mode
enum MarkupSubMode: String, CaseIterable, Identifiable {
    case select = "Select"
    case freeform = "Draw"
    case measurement = "Measure"
    case text = "Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select: return "hand.point.up"
        case .freeform: return "scribble.variable"
        case .measurement: return "ruler"
        case .text: return "textformat"
        }
    }
}

// MARK: - Handle Type

/// Types of selection handles for resizing/repositioning/rotating elements
enum HandleType: String, CaseIterable {
    // Corner handles for text boxes and freeform lines
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    // Endpoint handles for measurement lines
    case startPoint
    case endPoint

    // Rotation handle
    case rotation
}

// MARK: - Markup State

/// Complete markup state for a photo
struct MarkupState: Codable, Equatable {
    var elements: [MarkupElement] = []
    var selectedElementId: UUID?
    private var nextZIndex: Int = 0

    /// Whether any markup has been added
    var hasMarkup: Bool {
        !elements.isEmpty
    }

    /// Elements sorted by zIndex for proper layering
    var sortedElements: [MarkupElement] {
        elements.sorted { $0.zIndex < $1.zIndex }
    }

    /// Get the currently selected element
    var selectedElement: MarkupElement? {
        guard let selectedId = selectedElementId else { return nil }
        return elements.first { $0.id == selectedId }
    }

    // MARK: - Element Operations

    /// Add a new element with proper zIndex
    mutating func addElement(_ element: MarkupElement) {
        var newElement = element
        newElement.setZIndex(nextZIndex)
        nextZIndex += 1
        elements.append(newElement)
    }

    /// Remove an element by ID
    mutating func removeElement(id: UUID) {
        elements.removeAll { $0.id == id }
        if selectedElementId == id {
            selectedElementId = nil
        }
    }

    /// Update an existing element
    mutating func updateElement(_ element: MarkupElement) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        }
    }

    /// Bring an element to the front
    mutating func bringToFront(id: UUID) {
        guard var element = elements.first(where: { $0.id == id }) else { return }
        element.setZIndex(nextZIndex)
        nextZIndex += 1
        updateElement(element)
    }

    /// Send an element to the back
    mutating func sendToBack(id: UUID) {
        guard var element = elements.first(where: { $0.id == id }) else { return }

        // Find the minimum zIndex and go one below
        let minZIndex = elements.map { $0.zIndex }.min() ?? 0
        element.setZIndex(minZIndex - 1)
        updateElement(element)
    }

    /// Select an element by ID
    mutating func select(id: UUID?) {
        selectedElementId = id
    }

    /// Deselect the current element
    mutating func deselect() {
        selectedElementId = nil
    }

    /// Clear all markup
    mutating func clearAll() {
        elements.removeAll()
        selectedElementId = nil
        nextZIndex = 0
    }

    /// Move the selected element by a delta in normalized coordinates
    mutating func moveSelectedElement(by delta: CGSize) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        var element = elements[index]

        switch element {
        case .freeformLine(var line):
            line.points = line.points.map { point in
                CodablePoint(x: point.x + Double(delta.width), y: point.y + Double(delta.height))
            }
            element = .freeformLine(line)

        case .measurementLine(var line):
            line.startPoint = CodablePoint(
                x: line.startPoint.x + Double(delta.width),
                y: line.startPoint.y + Double(delta.height)
            )
            line.endPoint = CodablePoint(
                x: line.endPoint.x + Double(delta.width),
                y: line.endPoint.y + Double(delta.height)
            )
            element = .measurementLine(line)

        case .textBox(var box):
            box.position = CodablePoint(
                x: box.position.x + Double(delta.width),
                y: box.position.y + Double(delta.height)
            )
            element = .textBox(box)
        }

        elements[index] = element
    }

    /// Rotate the selected element by degrees around its center
    mutating func rotateSelectedElement(by degrees: Double) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        let radians = degrees * .pi / 180

        switch elements[index] {
        case .textBox(var box):
            box.rotation += degrees
            elements[index] = .textBox(box)

        case .freeformLine(var line):
            let center = line.center
            line.points = line.points.map { point in
                rotatePoint(point.cgPoint, around: center, by: radians)
            }.map { CodablePoint($0) }
            elements[index] = .freeformLine(line)

        case .measurementLine(var line):
            let center = line.center
            let newStart = rotatePoint(line.startPoint.cgPoint, around: center, by: radians)
            let newEnd = rotatePoint(line.endPoint.cgPoint, around: center, by: radians)
            line.startPoint = CodablePoint(newStart)
            line.endPoint = CodablePoint(newEnd)
            elements[index] = .measurementLine(line)
        }
    }

    /// Helper to rotate a point around a center by radians
    private func rotatePoint(_ point: CGPoint, around center: CGPoint, by radians: Double) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cos = Darwin.cos(radians)
        let sin = Darwin.sin(radians)
        return CGPoint(
            x: center.x + CGFloat(cos) * dx - CGFloat(sin) * dy,
            y: center.y + CGFloat(sin) * dx + CGFloat(cos) * dy
        )
    }

    /// Scale the selected element from its center
    mutating func scaleSelectedElement(by scale: CGFloat) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        switch elements[index] {
        case .textBox(var box):
            box.size = CodableSize(
                width: box.size.width * Double(scale),
                height: box.size.height * Double(scale)
            )
            elements[index] = .textBox(box)

        case .freeformLine(var line):
            let center = line.center
            line.points = line.points.map { point in
                scalePoint(point.cgPoint, from: center, by: scale)
            }.map { CodablePoint($0) }
            elements[index] = .freeformLine(line)

        case .measurementLine(var line):
            let center = line.center
            let newStart = scalePoint(line.startPoint.cgPoint, from: center, by: scale)
            let newEnd = scalePoint(line.endPoint.cgPoint, from: center, by: scale)
            line.startPoint = CodablePoint(newStart)
            line.endPoint = CodablePoint(newEnd)
            elements[index] = .measurementLine(line)
        }
    }

    /// Helper to scale a point from a center by a factor
    private func scalePoint(_ point: CGPoint, from center: CGPoint, by scale: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * scale,
            y: center.y + dy * scale
        )
    }

    /// Update the color of the selected element
    mutating func updateSelectedElementColor(_ color: MarkupColor) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        var element = elements[index]
        element.setColor(color)
        elements[index] = element
    }

    /// Update text box properties
    mutating func updateTextBox(id: UUID, text: String? = nil, fontSize: FontSize? = nil, fillColor: MarkupColor?? = nil) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }

        if case .textBox(var box) = elements[index] {
            if let newText = text {
                box.text = newText
            }
            if let newSize = fontSize {
                box.fontSize = newSize
            }
            if let newFill = fillColor {
                box.fillColor = newFill
            }
            elements[index] = .textBox(box)
        }
    }

    /// Update line width for the selected element
    mutating func updateSelectedLineWidth(_ width: LineWidth) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        switch elements[index] {
        case .freeformLine(var line):
            line.lineWidth = width
            elements[index] = .freeformLine(line)
        case .measurementLine(var line):
            line.lineWidth = width
            elements[index] = .measurementLine(line)
        case .textBox:
            break // Text boxes don't have line width
        }
    }

    /// Resize the selected element by dragging a corner handle
    mutating func resizeSelectedElement(handleType: HandleType, by delta: CGSize) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        switch elements[index] {
        case .textBox(var box):
            // Resize text box by adjusting size and position based on handle
            let deltaW = Double(delta.width)
            let deltaH = Double(delta.height)

            switch handleType {
            case .topLeft:
                // Move top-left corner: adjust position and size
                box.position = CodablePoint(
                    x: box.position.x + deltaW / 2,
                    y: box.position.y + deltaH / 2
                )
                box.size = CodableSize(
                    width: max(0.02, box.size.width - deltaW),
                    height: max(0.02, box.size.height - deltaH)
                )
            case .topRight:
                box.position = CodablePoint(
                    x: box.position.x + deltaW / 2,
                    y: box.position.y + deltaH / 2
                )
                box.size = CodableSize(
                    width: max(0.02, box.size.width + deltaW),
                    height: max(0.02, box.size.height - deltaH)
                )
            case .bottomLeft:
                box.position = CodablePoint(
                    x: box.position.x + deltaW / 2,
                    y: box.position.y + deltaH / 2
                )
                box.size = CodableSize(
                    width: max(0.02, box.size.width - deltaW),
                    height: max(0.02, box.size.height + deltaH)
                )
            case .bottomRight:
                box.position = CodablePoint(
                    x: box.position.x + deltaW / 2,
                    y: box.position.y + deltaH / 2
                )
                box.size = CodableSize(
                    width: max(0.02, box.size.width + deltaW),
                    height: max(0.02, box.size.height + deltaH)
                )
            case .startPoint, .endPoint, .rotation:
                break // Not applicable for text boxes
            }
            elements[index] = .textBox(box)

        case .freeformLine(var line):
            // Scale freeform line from the opposite corner
            let bounds = line.boundingRect
            var anchorPoint: CGPoint
            var scaleX: CGFloat = 1.0
            var scaleY: CGFloat = 1.0

            switch handleType {
            case .topLeft:
                anchorPoint = CGPoint(x: bounds.maxX, y: bounds.maxY)
                scaleX = max(0.1, (bounds.width - CGFloat(delta.width)) / bounds.width)
                scaleY = max(0.1, (bounds.height - CGFloat(delta.height)) / bounds.height)
            case .topRight:
                anchorPoint = CGPoint(x: bounds.minX, y: bounds.maxY)
                scaleX = max(0.1, (bounds.width + CGFloat(delta.width)) / bounds.width)
                scaleY = max(0.1, (bounds.height - CGFloat(delta.height)) / bounds.height)
            case .bottomLeft:
                anchorPoint = CGPoint(x: bounds.maxX, y: bounds.minY)
                scaleX = max(0.1, (bounds.width - CGFloat(delta.width)) / bounds.width)
                scaleY = max(0.1, (bounds.height + CGFloat(delta.height)) / bounds.height)
            case .bottomRight:
                anchorPoint = CGPoint(x: bounds.minX, y: bounds.minY)
                scaleX = max(0.1, (bounds.width + CGFloat(delta.width)) / bounds.width)
                scaleY = max(0.1, (bounds.height + CGFloat(delta.height)) / bounds.height)
            case .startPoint, .endPoint, .rotation:
                return // Not applicable
            }

            line.points = line.points.map { point in
                let newX = anchorPoint.x + (point.x - anchorPoint.x) * Double(scaleX)
                let newY = anchorPoint.y + (point.y - anchorPoint.y) * Double(scaleY)
                return CodablePoint(x: newX, y: newY)
            }
            elements[index] = .freeformLine(line)

        case .measurementLine:
            break // Use moveEndpoint for measurement lines
        }
    }

    /// Move an endpoint of the selected measurement line
    mutating func moveEndpoint(handleType: HandleType, by delta: CGSize) {
        guard let selectedId = selectedElementId,
              let index = elements.firstIndex(where: { $0.id == selectedId }) else { return }

        if case .measurementLine(var line) = elements[index] {
            switch handleType {
            case .startPoint:
                line.startPoint = CodablePoint(
                    x: line.startPoint.x + Double(delta.width),
                    y: line.startPoint.y + Double(delta.height)
                )
            case .endPoint:
                line.endPoint = CodablePoint(
                    x: line.endPoint.x + Double(delta.width),
                    y: line.endPoint.y + Double(delta.height)
                )
            default:
                return // Corner handles not used for measurement lines
            }
            elements[index] = .measurementLine(line)
        }
    }
}

// MARK: - Default Markup State

extension MarkupState {
    static let `default` = MarkupState()
}
