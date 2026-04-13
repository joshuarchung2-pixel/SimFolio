// ModerationService.swift
// SimFolio
//
// Handles user reporting of posts/comments and user blocking via Firestore.

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ModerationService: ObservableObject {
    static let shared = ModerationService()

    @Published var blockedUserIds: [String] = []

    private lazy var db = Firestore.firestore()

    private init() {}

    // MARK: - Reporting

    func reportPost(postId: String, reason: SocialReport.ReportReason, details: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let report = [
            "reporterId": userId,
            "targetType": SocialReport.ReportTargetType.post.rawValue,
            "targetId": postId,
            "reason": reason.rawValue,
            "details": details as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "status": SocialReport.ReportStatus.pending.rawValue
        ] as [String: Any]

        try await db.collection("reports").addDocument(data: report)

        // Increment report count on the post and auto-hide if >= 3
        let postRef = db.collection("posts").document(postId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let postDoc: DocumentSnapshot
            do {
                postDoc = try transaction.getDocument(postRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentCount = postDoc.data()?["reportCount"] as? Int ?? 0
            let newCount = currentCount + 1

            var updates: [String: Any] = ["reportCount": newCount]
            if newCount >= 3 {
                updates["isHidden"] = true
            }

            transaction.updateData(updates, forDocument: postRef)
            return nil
        }

        AnalyticsService.logEvent(.postReported, parameters: ["reason": reason.rawValue])
    }

    func reportComment(postId: String, commentId: String, reason: SocialReport.ReportReason, details: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let report = [
            "reporterId": userId,
            "targetType": SocialReport.ReportTargetType.comment.rawValue,
            "targetId": commentId,
            "reason": reason.rawValue,
            "details": details as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "status": SocialReport.ReportStatus.pending.rawValue
        ] as [String: Any]

        try await db.collection("reports").addDocument(data: report)
        AnalyticsService.logEvent(.commentReported, parameters: ["reason": reason.rawValue])
    }

    // MARK: - Blocking

    func blockUser(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(currentUserId)
        try await userRef.updateData([
            "blockedUserIds": FieldValue.arrayUnion([userId])
        ])

        blockedUserIds.append(userId)
        AnalyticsService.logEvent(.userBlocked)
    }

    func unblockUser(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(currentUserId)
        try await userRef.updateData([
            "blockedUserIds": FieldValue.arrayRemove([userId])
        ])

        blockedUserIds.removeAll { $0 == userId }
        AnalyticsService.logEvent(.userUnblocked)
    }

    func loadBlockedUsers() async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let doc = try await db.collection("users").document(currentUserId).getDocument()
        blockedUserIds = doc.data()?["blockedUserIds"] as? [String] ?? []
    }

    func isUserBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }
}
