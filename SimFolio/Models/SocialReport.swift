// SocialReport.swift
// SimFolio
//
// Model representing a user-submitted report for a post or comment.

import Foundation

struct SocialReport: Identifiable, Codable {
    let id: String
    let reporterId: String
    let targetType: ReportTargetType
    let targetId: String
    let reason: ReportReason
    let details: String?
    let createdAt: Date
    var status: ReportStatus

    enum ReportTargetType: String, Codable {
        case post
        case comment
    }

    enum ReportReason: String, Codable, CaseIterable {
        case inappropriate = "inappropriate"
        case spam = "spam"
        case harassment = "harassment"
        case misinformation = "misinformation"
        case other = "other"

        var displayName: String {
            switch self {
            case .inappropriate: return "Inappropriate Content"
            case .spam: return "Spam"
            case .harassment: return "Harassment"
            case .misinformation: return "Misinformation"
            case .other: return "Other"
            }
        }
    }

    enum ReportStatus: String, Codable {
        case pending
        case reviewed
        case resolved
        case dismissed
    }
}
