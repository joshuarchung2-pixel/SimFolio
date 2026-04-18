// MarkupRenderingService.swift
// Service for rendering markup annotations onto images
//
// Renders markup elements to UIImage for:
// - Preview display with composited markup
// - Export with markup baked into the image
//
// Unified with the editor canvas: the same SwiftUI `MarkupElementView` used for
// the live preview is also what gets baked into the image via `ImageRenderer`.
// This makes editor, detail view, thumbnails, and exports pixel-identical by
// construction — drift between rendering surfaces is impossible.

import SwiftUI
import UIKit

// MARK: - Markup Rendering Service

/// Service for rendering markup annotations onto images.
///
/// `@MainActor` because SwiftUI's `ImageRenderer` is main-actor-bound. Callers
/// on background threads must hop to the main actor before invoking.
@MainActor
final class MarkupRenderingService {

    // MARK: - Singleton

    static let shared = MarkupRenderingService()

    /// Reference canvas size for scaling line widths / font sizes. Line widths and
    /// font sizes look good at this approximate screen size; we scale them up
    /// proportionally for larger images so markup stays visually consistent.
    private let referenceCanvasWidth: CGFloat = 400

    private init() {}

    // MARK: - Public Methods

    /// Render markup onto an image.
    /// - Parameters:
    ///   - image: The base image.
    ///   - markupState: The markup state containing all elements.
    /// - Returns: The image with markup rendered on top, or the original image
    ///            if there is no markup to render.
    func renderMarkup(onto image: UIImage, markupState: MarkupState) -> UIImage? {
        guard markupState.hasMarkup else { return image }

        let imageSize = image.size
        let pixelScale = pixelScale(for: imageSize)

        let layer = BakedMarkupLayer(
            markupState: markupState,
            canvasSize: imageSize,
            pixelScale: pixelScale
        )

        let renderer = ImageRenderer(content: layer)
        renderer.scale = 1.0
        renderer.isOpaque = false

        guard let overlay = renderer.uiImage else { return image }

        // Composite base image + overlay into a single bitmap at imageSize.
        let compositor = UIGraphicsImageRenderer(size: imageSize)
        return compositor.image { _ in
            image.draw(in: CGRect(origin: .zero, size: imageSize))
            overlay.draw(in: CGRect(origin: .zero, size: imageSize))
        }
    }

    /// Render markup for preview. Downscales the base image first for speed,
    /// then runs the same `renderMarkup` pipeline on the smaller image so there
    /// is only one rendering path.
    /// - Parameters:
    ///   - image: The base image.
    ///   - markupState: The markup state.
    ///   - maxDimension: Maximum dimension for the preview (default 800).
    /// - Returns: Preview image with markup composited.
    func renderMarkupPreview(onto image: UIImage, markupState: MarkupState, maxDimension: CGFloat = 800) -> UIImage? {
        guard markupState.hasMarkup else { return image }

        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        guard scale < 1.0 else {
            return renderMarkup(onto: image, markupState: markupState)
        }

        let previewSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let downscaled = UIGraphicsImageRenderer(size: previewSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: previewSize))
        }

        return renderMarkup(onto: downscaled, markupState: markupState)
    }

    // MARK: - Private Helpers

    /// Scale factor for stroke widths / font sizes / padding so markup stays
    /// visually consistent across image sizes.
    private func pixelScale(for imageSize: CGSize) -> CGFloat {
        let smaller = min(imageSize.width, imageSize.height)
        return smaller / referenceCanvasWidth
    }
}
