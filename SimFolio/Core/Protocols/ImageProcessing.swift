import UIKit

protocol ImageProcessing {
    func applyEdits(to image: UIImage, editState: EditState) -> UIImage?
    func generatePreview(from image: UIImage, editState: EditState, maxDimension: CGFloat) -> UIImage?
    func applyAdjustmentsOnly(to image: UIImage, adjustments: ImageAdjustments) -> UIImage?
}
