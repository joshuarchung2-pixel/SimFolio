import Foundation
import FirebaseFirestore

struct Comment: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let postId: String
    let userId: String
    let authorName: String
    let text: String
    let createdAt: Date
    var isHidden: Bool

    var displayDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
