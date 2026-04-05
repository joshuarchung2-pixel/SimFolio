import Foundation
import FirebaseFirestore

struct SharedPost: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let userId: String
    let authorName: String
    let authorSchool: String
    let imageURL: String
    let thumbnailURL: String
    let caption: String?
    let procedure: String
    let stage: String?
    let angle: String?
    let toothNumber: Int?
    let createdAt: Date
    var reactionCounts: [String: Int]
    var commentCount: Int
    let isSimulation: Bool
    var reportCount: Int
    var isHidden: Bool

    var displayDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var totalReactions: Int {
        reactionCounts.values.reduce(0, +)
    }
}
