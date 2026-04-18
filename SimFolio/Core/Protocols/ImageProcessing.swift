import UIKit

protocol ImageProcessing {
    @MainActor
    func applyEdits(to image: UIImage, editState: EditState) -> UIImage?

    @MainActor
    func generatePreview(from image: UIImage, editState: EditState, maxDimension: CGFloat) -> UIImage?

    func applyAdjustmentsOnly(to image: UIImage, adjustments: ImageAdjustments) -> UIImage?
}
