// ImageProcessingService.swift
// CoreImage-based image processing for photo editing
//
// Provides:
// - Adjustment filters (brightness, contrast, saturation, etc.)
// - Transform operations (crop, rotate)
// - Efficient processing with CIContext caching

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Image Processing Service

/// Service for applying image adjustments and transforms using CoreImage
final class ImageProcessingService: ImageProcessing {

    // MARK: - Singleton

    static let shared = ImageProcessingService()

    // MARK: - Properties

    /// Shared CIContext for efficient filter processing
    private let context: CIContext

    /// Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.simfolio.imageprocessing", qos: .userInteractive)

    // MARK: - Initialization

    private init() {
        // Use Metal for hardware acceleration if available
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .highQualityDownsample: true
            ])
        } else {
            context = CIContext(options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .highQualityDownsample: true
            ])
        }
    }

    // MARK: - Main Processing Method

    /// Apply all edits to an image.
    ///
    /// `@MainActor` because markup compositing uses SwiftUI's `ImageRenderer`,
    /// which is main-actor-bound. Callers running on background queues should
    /// use `applyEditsAsync(to:editState:)` instead.
    /// - Parameters:
    ///   - image: The original UIImage.
    ///   - editState: The edit state containing adjustments, transforms, and markup.
    /// - Returns: The processed UIImage, or nil if processing failed.
    @MainActor
    func applyEdits(to image: UIImage, editState: EditState) -> UIImage? {
        guard let adjusted = applyAdjustmentsAndTransforms(to: image, editState: editState) else {
            return nil
        }
        return applyMarkup(to: adjusted, markupState: editState.markup)
    }

    /// Apply all edits to an image, async. Runs the CoreImage adjustments and
    /// transforms on a background queue, then hops to the main actor for the
    /// markup compositing step (which requires `ImageRenderer`).
    /// - Parameters:
    ///   - image: The original UIImage.
    ///   - editState: The edit state.
    /// - Returns: The processed UIImage, or nil if processing failed.
    func applyEditsAsync(to image: UIImage, editState: EditState) async -> UIImage? {
        let adjusted: UIImage? = await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                continuation.resume(returning: self?.applyAdjustmentsAndTransforms(to: image, editState: editState))
            }
        }
        guard let adjusted else { return nil }

        return await MainActor.run {
            applyMarkup(to: adjusted, markupState: editState.markup)
        }
    }

    // MARK: - Split Pipeline Helpers

    /// Runs the CoreImage adjustment + transform pipeline. Pure CoreImage work —
    /// safe to call from any queue.
    private func applyAdjustmentsAndTransforms(to image: UIImage, editState: EditState) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        var processed = ciImage
        processed = applyAdjustments(to: processed, adjustments: editState.adjustments)
        processed = applyTransform(to: processed, transform: editState.transform, originalSize: image.size)

        return renderToUIImage(processed, originalOrientation: image.imageOrientation)
    }

    /// Composites markup over an already-adjusted image. Main-actor-bound
    /// because `MarkupRenderingService` uses SwiftUI's `ImageRenderer`.
    @MainActor
    private func applyMarkup(to image: UIImage, markupState: MarkupState) -> UIImage? {
        guard markupState.hasMarkup else { return image }
        return MarkupRenderingService.shared.renderMarkup(onto: image, markupState: markupState) ?? image
    }

    // MARK: - Adjustment Processing

    /// Apply all adjustments to a CIImage
    private func applyAdjustments(to image: CIImage, adjustments: ImageAdjustments) -> CIImage {
        var result = image

        // Brightness
        if adjustments.brightness != 0 {
            result = applyBrightness(to: result, value: adjustments.brightness)
        }

        // Exposure
        if adjustments.exposure != 0 {
            result = applyExposure(to: result, value: adjustments.exposure)
        }

        // Highlights and Shadows
        if adjustments.highlights != 0 || adjustments.shadows != 0 {
            result = applyHighlightShadow(to: result, highlights: adjustments.highlights, shadows: adjustments.shadows)
        }

        // Contrast
        if adjustments.contrast != 1.0 {
            result = applyContrast(to: result, value: adjustments.contrast)
        }

        // Black Point
        if adjustments.blackPoint != 0 {
            result = applyBlackPoint(to: result, value: adjustments.blackPoint)
        }

        // Saturation
        if adjustments.saturation != 1.0 {
            result = applySaturation(to: result, value: adjustments.saturation)
        }

        // Brilliance (vibrance)
        if adjustments.brilliance != 0 {
            result = applyBrilliance(to: result, value: adjustments.brilliance)
        }

        // Sharpness
        if adjustments.sharpness != 0 {
            result = applySharpness(to: result, value: adjustments.sharpness)
        }

        // Definition (unsharp mask for local contrast)
        if adjustments.definition != 0 {
            result = applyDefinition(to: result, value: adjustments.definition)
        }

        return result
    }

    // MARK: - Individual Adjustment Filters

    private func applyBrightness(to image: CIImage, value: Double) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = Float(value)
        filter.contrast = 1.0
        filter.saturation = 1.0
        return filter.outputImage ?? image
    }

    private func applyExposure(to image: CIImage, value: Double) -> CIImage {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(value)
        return filter.outputImage ?? image
    }

    private func applyHighlightShadow(to image: CIImage, highlights: Double, shadows: Double) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        // CIHighlightShadowAdjust: highlightAmount 0-1 (reduce highlights), shadowAmount -1 to 1
        filter.highlightAmount = Float(1.0 - highlights) // Invert so positive = brighter highlights
        filter.shadowAmount = Float(shadows)
        return filter.outputImage ?? image
    }

    private func applyContrast(to image: CIImage, value: Double) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = 0
        filter.contrast = Float(value)
        filter.saturation = 1.0
        return filter.outputImage ?? image
    }

    private func applyBlackPoint(to image: CIImage, value: Double) -> CIImage {
        // Use tone curve to lift or lower the black point
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        // Lift blacks by moving point0 up
        filter.point0 = CGPoint(x: 0, y: value)
        filter.point1 = CGPoint(x: 0.25, y: 0.25)
        filter.point2 = CGPoint(x: 0.5, y: 0.5)
        filter.point3 = CGPoint(x: 0.75, y: 0.75)
        filter.point4 = CGPoint(x: 1, y: 1)
        return filter.outputImage ?? image
    }

    private func applySaturation(to image: CIImage, value: Double) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = 0
        filter.contrast = 1.0
        filter.saturation = Float(value)
        return filter.outputImage ?? image
    }

    private func applyBrilliance(to image: CIImage, value: Double) -> CIImage {
        // Brilliance is similar to vibrance - boost muted colors more than saturated ones
        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = Float(value)
        return filter.outputImage ?? image
    }

    private func applySharpness(to image: CIImage, value: Double) -> CIImage {
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = Float(value)
        return filter.outputImage ?? image
    }

    private func applyDefinition(to image: CIImage, value: Double) -> CIImage {
        // Definition uses unsharp mask for local contrast enhancement
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.radius = 2.5
        filter.intensity = Float(value)
        return filter.outputImage ?? image
    }

    // MARK: - Transform Processing

    /// Apply transform (rotation and crop) to a CIImage
    private func applyTransform(to image: CIImage, transform: ImageTransform, originalSize: CGSize) -> CIImage {
        var result = image

        // Apply 90-degree rotations first
        if transform.rotation90Count != 0 {
            result = apply90DegreeRotation(to: result, count: transform.rotation90Count)
        }

        // Apply fine rotation
        if transform.fineRotation != 0 {
            result = applyFineRotation(to: result, degrees: transform.fineRotation)
        }

        // Apply crop last
        if let cropRect = transform.cropRect {
            result = applyCrop(to: result, normalizedRect: cropRect)
        }

        return result
    }

    private func apply90DegreeRotation(to image: CIImage, count: Int) -> CIImage {
        var result = image
        let normalizedCount = count % 4

        for _ in 0..<normalizedCount {
            // Rotate 90 degrees clockwise
            let rotationTransform = CGAffineTransform(rotationAngle: -.pi / 2)

            // Calculate new bounds after rotation
            let rotatedBounds = result.extent.applying(rotationTransform)

            // Translate to keep image in positive coordinate space
            let translationTransform = CGAffineTransform(translationX: -rotatedBounds.origin.x, y: -rotatedBounds.origin.y)

            result = result.transformed(by: rotationTransform.concatenating(translationTransform))
        }

        return result
    }

    private func applyFineRotation(to image: CIImage, degrees: Double) -> CIImage {
        let radians = degrees * .pi / 180

        // Get center of image
        let extent = image.extent
        let centerX = extent.midX
        let centerY = extent.midY

        // Create transform: translate to origin, rotate, translate back
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerX, y: centerY)
        transform = transform.rotated(by: CGFloat(radians))
        transform = transform.translatedBy(x: -centerX, y: -centerY)

        let rotated = image.transformed(by: transform)

        // Crop to original bounds to remove rotation artifacts at edges
        // The rotation may extend beyond original bounds
        return rotated.cropped(to: extent)
    }

    private func applyCrop(to image: CIImage, normalizedRect: CGRect) -> CIImage {
        let extent = image.extent

        // Convert normalized rect (0-1) to actual pixel coordinates
        let cropRect = CGRect(
            x: extent.origin.x + normalizedRect.origin.x * extent.width,
            y: extent.origin.y + (1 - normalizedRect.origin.y - normalizedRect.height) * extent.height, // Flip Y
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )

        return image.cropped(to: cropRect)
    }

    // MARK: - Rendering

    /// Render CIImage to UIImage
    private func renderToUIImage(_ ciImage: CIImage, originalOrientation: UIImage.Orientation) -> UIImage? {
        let extent = ciImage.extent

        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    // MARK: - Preview Generation

    /// Generate a low-resolution preview for real-time editing feedback
    /// - Parameters:
    ///   - image: The original image
    ///   - editState: Current edit state
    ///   - maxDimension: Maximum dimension for preview (default 800)
    /// - Returns: Preview UIImage
    @MainActor
    func generatePreview(from image: UIImage, editState: EditState, maxDimension: CGFloat = 800) -> UIImage? {
        // Downscale for preview
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let previewSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        guard let resizedImage = resizeImage(image, to: previewSize) else {
            return nil
        }

        // Create edit state without markup for base preview (markup is rendered in canvas overlay)
        var previewEditState = editState
        previewEditState.markup = MarkupState()

        return applyEdits(to: resizedImage, editState: previewEditState)
    }

    /// Resize an image for preview
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    // MARK: - Quick Adjustments

    /// Apply only adjustments (no transforms) for real-time slider preview
    func applyAdjustmentsOnly(to image: UIImage, adjustments: ImageAdjustments) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let processed = applyAdjustments(to: ciImage, adjustments: adjustments)

        return renderToUIImage(processed, originalOrientation: image.imageOrientation)
    }

    // MARK: - Full Quality Export

    /// Apply edits at full quality for saving
    @MainActor
    func applyEditsFullQuality(to image: UIImage, editState: EditState) -> UIImage? {
        return applyEdits(to: image, editState: editState)
    }
}

// MARK: - UIImage Extension for Rotation

extension UIImage {
    /// Rotate the image by the specified degrees
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180

        // Calculate new size
        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        // Ensure size is positive
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move origin to center
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)

        // Rotate
        context.rotate(by: radians)

        // Draw image centered
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }

    /// Rotate the image by 90 degrees clockwise
    func rotated90Clockwise() -> UIImage? {
        return rotated(by: 90)
    }

    /// Rotate the image by 90 degrees counter-clockwise
    func rotated90CounterClockwise() -> UIImage? {
        return rotated(by: -90)
    }

    /// Crop the image to the specified normalized rect (0-1 coordinates)
    func cropped(to normalizedRect: CGRect) -> UIImage? {
        let cropRect = CGRect(
            x: normalizedRect.origin.x * size.width,
            y: normalizedRect.origin.y * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return nil }

        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
