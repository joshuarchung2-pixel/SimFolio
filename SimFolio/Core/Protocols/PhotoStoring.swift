import UIKit

protocol PhotoStoring: AnyObject {
    var records: [PhotoRecord] { get }

    func savePhoto(_ image: UIImage, compressionQuality: CGFloat) -> PhotoRecord
    func loadImage(id: UUID) -> UIImage?
    func loadThumbnail(id: UUID) -> UIImage?
    func loadEditedImage(id: UUID) -> UIImage?
    func loadEditedThumbnail(id: UUID) -> UIImage?
    func deletePhoto(id: UUID)
    func deletePhotos(ids: [UUID])
}
