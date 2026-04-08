import Foundation
import FirebaseFirestore

struct SocialReport: Codable, Identifiable {
    @DocumentID var id: String?
    let reporterId: String
    let targetType: ReportTargetType
    let targetId: String
    let reason: ReportReason
    let details: String?
    let createdAt: Date
    var status: ReportStatus

    enum ReportTargetType: String, Codable {
        case post, comment, user
    }

    enum ReportReason: String, Codable, CaseIterable {
        case inappropriate = "Inappropriate content"
        case realPatient = "Real patient photo"
        case ageInappropriate = "Age-inappropriate content"
        case harassment = "Harassment"
        case spam = "Spam"
        case other = "Other"
    }

    enum ReportStatus: String, Codable {
        case pending, reviewed, resolved
    }
}
