// SocialInteractionService.swift
// SimFolio — manages comments and reactions on posts.
//
// Comments are stored at posts/{postId}/comments/{commentId}.
// Reactions are stored at posts/{postId}/reactions/{userId} with a single `type` field.
// All writes that mutate post-level counters run inside Firestore transactions.

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SocialInteractionService: ObservableObject {
    static let shared = SocialInteractionService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Comments

    /// Add a comment to a post. Validates text, writes to subcollection, increments commentCount.
    func addComment(postId: String, text: String) async throws -> Comment {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw InteractionError.notAuthenticated
        }

        // Validate text
        if let reason = ContentFilterService.filterReason(text) {
            throw InteractionError.contentFiltered(reason)
        }

        // Get author name from user doc
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let authorName = userDoc.data()?["displayName"] as? String ?? "Anonymous"

        let commentData: [String: Any] = [
            "postId": postId,
            "userId": userId,
            "authorName": authorName,
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
            "isHidden": false,
        ]

        let commentRef = db.collection("posts").document(postId).collection("comments").document()

        // Write comment and increment count atomically
        let postRef = db.collection("posts").document(postId)
        _ = try await db.runTransaction { transaction, errorPointer in
            transaction.setData(commentData, forDocument: commentRef)
            transaction.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            return nil
        }

        AnalyticsService.logEvent(.commentAdded)

        return Comment(
            id: commentRef.documentID,
            postId: postId,
            userId: userId,
            authorName: authorName,
            text: text,
            createdAt: Date(),
            isHidden: false
        )
    }

    /// Delete own comment. Decrements commentCount atomically.
    func deleteComment(postId: String, commentId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let commentRef = postRef.collection("comments").document(commentId)

        _ = try await db.runTransaction { transaction, errorPointer in
            transaction.deleteDocument(commentRef)
            transaction.updateData(["commentCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
            return nil
        }

        AnalyticsService.logEvent(.commentDeleted)
    }

    /// Get paginated comments for a post, ordered by createdAt ascending.
    func getComments(postId: String, limit: Int = 20, afterDocument: DocumentSnapshot? = nil) async throws -> ([Comment], DocumentSnapshot?) {
        var query = db.collection("posts").document(postId).collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)

        if let afterDoc = afterDocument {
            query = query.start(afterDocument: afterDoc)
        }

        let snapshot = try await query.getDocuments()
        let comments = snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
            .filter { !$0.isHidden }
        return (comments, snapshot.documents.last)
    }

    // MARK: - Reactions

    /// Toggle a reaction on a post. If same type exists, remove it. If different type, switch. If none, add.
    func toggleReaction(postId: String, type: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw InteractionError.notAuthenticated
        }

        let postRef = db.collection("posts").document(postId)
        let reactionRef = postRef.collection("reactions").document(userId)

        _ = try await db.runTransaction { transaction, errorPointer in
            let reactionDoc: DocumentSnapshot
            do {
                reactionDoc = try transaction.getDocument(reactionRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            if reactionDoc.exists {
                let existingType = reactionDoc.data()?["type"] as? String ?? ""

                if existingType == type {
                    // Same reaction — remove it
                    transaction.deleteDocument(reactionRef)
                    transaction.updateData([
                        "reactionCounts.\(existingType)": FieldValue.increment(Int64(-1))
                    ], forDocument: postRef)
                } else {
                    // Different reaction — switch
                    transaction.updateData(["type": type], forDocument: reactionRef)
                    transaction.updateData([
                        "reactionCounts.\(existingType)": FieldValue.increment(Int64(-1)),
                        "reactionCounts.\(type)": FieldValue.increment(Int64(1))
                    ], forDocument: postRef)
                }
            } else {
                // No reaction — add new
                transaction.setData(["type": type], forDocument: reactionRef)
                transaction.updateData([
                    "reactionCounts.\(type)": FieldValue.increment(Int64(1))
                ], forDocument: postRef)
            }

            return nil
        }

        AnalyticsService.logEvent(.reactionAdded, parameters: ["type": type])
    }

    /// Get the current user's reaction type for a post, or nil if none.
    func getUserReaction(postId: String) async throws -> String? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }

        let doc = try await db.collection("posts").document(postId)
            .collection("reactions").document(userId).getDocument()

        return doc.data()?["type"] as? String
    }

    // MARK: - Errors

    enum InteractionError: LocalizedError {
        case notAuthenticated
        case contentFiltered(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to interact with posts."
            case .contentFiltered(let reason):
                return reason
            }
        }
    }
}
