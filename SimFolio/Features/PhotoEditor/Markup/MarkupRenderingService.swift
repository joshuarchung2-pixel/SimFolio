// MarkupRenderingService.swift
// Service for rendering markup annotations onto images
//
// Renders markup elements to UIImage for:
// - Preview display with composited markup
// - Export with markup baked into the image

import UIKit
import CoreGraphics

// MARK: - Markup Rendering Service

/// Service for rendering markup annotations onto images
final class MarkupRenderingService {

    // MARK: - Singleton

    static let shared = MarkupRenderingService()

    // Reference canvas size for scaling line widths
    // Line widths are designed to look good at this approximate screen size
    private let referenceCanvasWidth: CGFloat = 400

    private init() {}

    // MARK: - Scale Factor

    /// Calculate scale factor for line widths and font sizes
    /// This ensures markup looks proportionally the same on large images as on screen
    private func scaleFactor(for imageSize: CGSize) -> CGFloat {
        let smallerDimension = min(imageSize.width, imageSize.height)
        return smallerDimension / referenceCanvasWidth
    }

    // MARK: - Public Methods

    /// Render markup onto an image
    /// - Parameters:
    ///   - image: The base image
    ///   - markupState: The markup state containing all elements
    /// - Returns: The image with markup rendered on top
    func renderMarkup(onto image: UIImage, markupState: MarkupState) -> UIImage? {
        guard markupState.hasMarkup else {
            return image
        }

        let imageSize = image.size

        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            // Draw the base image
            image.draw(at: .zero)

            // Draw each element sorted by zIndex
            for element in markupState.sortedElements {
                renderElement(element, in: context.cgContext, imageSize: imageSize)
            }
        }
    }

    /// Render markup for preview (lower quality but faster)
    /// - Parameters:
    ///   - image: The base image
    ///   - markupState: The markup state
    ///   - maxDimension: Maximum dimension for preview
    /// - Returns: Preview image with markup
    func renderMarkupPreview(onto image: UIImage, markupState: MarkupState, maxDimension: CGFloat = 800) -> UIImage? {
        guard markupState.hasMarkup else {
            return image
        }

        // Scale down for preview
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let previewSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: previewSize)

        return renderer.image { context in
            // Draw scaled base image
            image.draw(in: CGRect(origin: .zero, size: previewSize))

            // Draw each element
            for element in markupState.sortedElements {
                renderElement(element, in: context.cgContext, imageSize: previewSize)
            }
        }
    }

    // MARK: - Private Rendering Methods

    private func renderElement(_ element: MarkupElement, in context: CGContext, imageSize: CGSize) {
        let scale = scaleFactor(for: imageSize)
        switch element {
        case .freeformLine(let line):
            renderFreeformLine(line, in: context, imageSize: imageSize, scale: scale)
        case .measurementLine(let line):
            renderMeasurementLine(line, in: context, imageSize: imageSize, scale: scale)
        case .textBox(let box):
            renderTextBox(box, in: context, imageSize: imageSize, scale: scale)
        }
    }

    // MARK: - Freeform Line Rendering

    private func renderFreeformLine(_ line: FreeformLine, in context: CGContext, imageSize: CGSize, scale: CGFloat) {
        guard line.points.count > 0 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        // Scale line width proportionally to image size
        let scaledLineWidth = line.lineWidth.pointWidth * scale

        context.setStrokeColor(line.color.cgColor)
        context.setLineWidth(scaledLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Convert normalized points to actual coordinates
        let scaledPoints = line.points.map { point in
            CGPoint(
                x: CGFloat(point.x) * imageSize.width,
                y: CGFloat(point.y) * imageSize.height
            )
        }

        if scaledPoints.count == 1 {
            // Single point - draw a small circle
            let point = scaledPoints[0]
            context.addEllipse(in: CGRect(
                x: point.x - scaledLineWidth / 2,
                y: point.y - scaledLineWidth / 2,
                width: scaledLineWidth,
                height: scaledLineWidth
            ))
            context.setFillColor(line.color.cgColor)
            context.fillPath()
        } else {
            // Draw smooth path
            context.move(to: scaledPoints[0])

            if scaledPoints.count == 2 {
                context.addLine(to: scaledPoints[1])
            } else {
                for i in 1..<scaledPoints.count {
                    let current = scaledPoints[i]
                    let previous = scaledPoints[i - 1]
                    let midPoint = CGPoint(
                        x: (previous.x + current.x) / 2,
                        y: (previous.y + current.y) / 2
                    )

                    if i == 1 {
                        context.addLine(to: midPoint)
                    } else {
                        context.addQuadCurve(to: midPoint, control: previous)
                    }

                    if i == scaledPoints.count - 1 {
                        context.addLine(to: current)
                    }
                }
            }

            context.strokePath()
        }
    }

    // MARK: - Measurement Line Rendering

    private func renderMeasurementLine(_ line: MeasurementLine, in context: CGContext, imageSize: CGSize, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Scale line width proportionally to image size
        let scaledLineWidth = line.lineWidth.pointWidth * scale

        context.setStrokeColor(line.color.cgColor)
        context.setLineWidth(scaledLineWidth)
        context.setLineCap(.square)
        context.setLineJoin(.miter)

        // Convert normalized points to actual coordinates
        let start = CGPoint(
            x: CGFloat(line.startPoint.x) * imageSize.width,
            y: CGFloat(line.startPoint.y) * imageSize.height
        )
        let end = CGPoint(
            x: CGFloat(line.endPoint.x) * imageSize.width,
            y: CGFloat(line.endPoint.y) * imageSize.height
        )

        // Main line
        context.move(to: start)
        context.addLine(to: end)

        // Calculate perpendicular direction for caps
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0 else {
            context.strokePath()
            return
        }

        let perpX = -dy / length
        let perpY = dx / length

        // Cap size (use average dimension for scaling)
        let capSize = CGFloat(line.capLength) * min(imageSize.width, imageSize.height)

        // Start cap
        context.move(to: CGPoint(x: start.x + perpX * capSize, y: start.y + perpY * capSize))
        context.addLine(to: CGPoint(x: start.x - perpX * capSize, y: start.y - perpY * capSize))

        // End cap
        context.move(to: CGPoint(x: end.x + perpX * capSize, y: end.y + perpY * capSize))
        context.addLine(to: CGPoint(x: end.x - perpX * capSize, y: end.y - perpY * capSize))

        context.strokePath()
    }

    // MARK: - Text Box Rendering

    private func renderTextBox(_ box: TextBox, in context: CGContext, imageSize: CGSize, scale: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }

        // Calculate position and size in actual coordinates
        let position = CGPoint(
            x: CGFloat(box.position.x) * imageSize.width,
            y: CGFloat(box.position.y) * imageSize.height
        )

        let size = CGSize(
            width: CGFloat(box.size.width) * imageSize.width,
            height: CGFloat(box.size.height) * imageSize.height
        )

        // Apply rotation transform
        context.translateBy(x: position.x, y: position.y)
        context.rotate(by: CGFloat(box.rotation) * .pi / 180)
        context.translateBy(x: -position.x, y: -position.y)

        // Calculate bounding rect
        let rect = CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        // Scale corner radius and padding proportionally
        let scaledCornerRadius = 4 * scale
        let scaledPadding = 4 * scale

        // Draw fill if present
        if let fillColor = box.fillColor {
            context.setFillColor(fillColor.cgColor)
            let fillPath = UIBezierPath(roundedRect: rect, cornerRadius: scaledCornerRadius)
            context.addPath(fillPath.cgPath)
            context.fillPath()
        }

        // Draw text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Scale font size proportionally to image size
        let scaledFontSize = box.fontSize.pointSize * scale
        let font = UIFont.systemFont(ofSize: scaledFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: box.fontColor.uiColor,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = rect.insetBy(dx: scaledPadding, dy: scaledPadding)
        (box.text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
