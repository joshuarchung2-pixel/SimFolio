import Foundation
import Combine
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class PhotoSharingService: ObservableObject {
    static let shared = PhotoSharingService()

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0

    private lazy var db = Firestore.firestore()
    private lazy var storage = Storage.storage()

    /// Local cache of shared asset local identifiers
    private var sharedAssetIds: Set<String> = []

    private init() {}

    // MARK: - Sharing

    /// Share a photo to the class feed
    func sharePhoto(image: UIImage, metadata: PhotoMetadata, caption: String?, assetId: String? = nil) async throws -> SharedPost {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SharingError.notAuthenticated
        }

        // Validate caption if present
        if let caption = caption, !caption.isEmpty {
            if let reason = ContentFilterService.filterReason(caption) {
                throw SharingError.contentFiltered(reason)
            }
        }

        isUploading = true
        uploadProgress = 0
        defer { isUploading = false }

        // Get user profile info for denormalization
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let authorName = userDoc.data()?["displayName"] as? String ?? "Anonymous"
        let authorSchool = userDoc.data()?["school"] as? String ?? ""

        let postId = UUID().uuidString

        // Compress full image (max 2048px, JPEG 0.8)
        let fullImageData = compressImage(image, maxDimension: 2048, quality: 0.8)

        // Generate thumbnail (400px)
        let thumbnailData = compressImage(image, maxDimension: 400, quality: 0.7)

        guard let fullData = fullImageData, let thumbData = thumbnailData else {
            throw SharingError.compressionFailed
        }

        uploadProgress = 0.1

        // Upload full image
        let photoRef = storage.reference().child("users/\(userId)/photos/\(postId).jpg")
        let photoMetadata = StorageMetadata()
        photoMetadata.contentType = "image/jpeg"
        _ = try await photoRef.putDataAsync(fullData, metadata: photoMetadata)
        let imageURL = try await photoRef.downloadURL().absoluteString

        uploadProgress = 0.5

        // Upload thumbnail
        let thumbRef = storage.reference().child("users/\(userId)/thumbnails/\(postId).jpg")
        let thumbMetadata = StorageMetadata()
        thumbMetadata.contentType = "image/jpeg"
        _ = try await thumbRef.putDataAsync(thumbData, metadata: thumbMetadata)
        let thumbnailURL = try await thumbRef.downloadURL().absoluteString

        uploadProgress = 0.8

        // Create Firestore document
        let postData: [String: Any] = [
            "userId": userId,
            "authorName": authorName,
            "authorSchool": authorSchool,
            "imageURL": imageURL,
            "thumbnailURL": thumbnailURL,
            "caption": caption as Any,
            "procedure": metadata.procedure ?? "",
            "stage": metadata.stage as Any,
            "angle": metadata.angle as Any,
            "toothNumber": metadata.toothNumber as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "reactionCounts": [String: Int](),
            "commentCount": 0,
            "isSimulation": true,
            "reportCount": 0,
            "isHidden": false,
        ]

        try await db.collection("posts").document(postId).setData(postData)

        // Track locally
        if let assetId = assetId {
            sharedAssetIds.insert(assetId)
        }

        uploadProgress = 1.0

        AnalyticsService.logPhotoShared(procedure: metadata.procedure ?? "", hasCaption: caption != nil)

        // Return the created post
        return SharedPost(
            id: postId,
            userId: userId,
            authorName: authorName,
            authorSchool: authorSchool,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: caption,
            procedure: metadata.procedure ?? "",
            stage: metadata.stage,
            angle: metadata.angle,
            toothNumber: metadata.toothNumber,
            createdAt: Date(),
            reactionCounts: [:],
            commentCount: 0,
            isSimulation: true,
            reportCount: 0,
            isHidden: false
        )
    }

    /// Delete a post and its associated Storage files
    func deletePost(_ post: SharedPost) async throws {
        guard let postId = post.id else { return }
        let userId = post.userId

        // Delete Storage files
        do {
            try await storage.reference().child("users/\(userId)/photos/\(postId).jpg").delete()
            try await storage.reference().child("users/\(userId)/thumbnails/\(postId).jpg").delete()
        } catch {
            // Files may not exist, continue with Firestore deletion
        }

        // Delete subcollections first
        let postRef = db.collection("posts").document(postId)
        let comments = try await postRef.collection("comments").getDocuments()
        for doc in comments.documents {
            try await doc.reference.delete()
        }
        let reactions = try await postRef.collection("reactions").getDocuments()
        for doc in reactions.documents {
            try await doc.reference.delete()
        }

        // Delete post document
        try await postRef.delete()
    }

    // MARK: - Feed Queries

    /// Get paginated school feed
    func getSchoolFeed(school: String, limit: Int = 20, afterDocument: DocumentSnapshot? = nil) async throws -> ([SharedPost], DocumentSnapshot?) {
        var query = db.collection("posts")
            .whereField("authorSchool", isEqualTo: school)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let afterDoc = afterDocument {
            query = query.start(afterDocument: afterDoc)
        }

        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents.compactMap { doc -> SharedPost? in
            try? doc.data(as: SharedPost.self)
        }

        let lastDoc = snapshot.documents.last
        return (posts, lastDoc)
    }

    /// Get a user's own posts
    func getUserPosts(userId: String) async throws -> [SharedPost] {
        let snapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: SharedPost.self) }
    }

    /// Get latest post timestamp for new-post indicator
    func getLatestPostTimestamp(school: String) async throws -> Date? {
        let snapshot = try await db.collection("posts")
            .whereField("authorSchool", isEqualTo: school)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let timestamp = doc.data()["createdAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Check if a local photo has been shared
    func isPhotoShared(assetId: String) -> Bool {
        sharedAssetIds.contains(assetId)
    }

    // MARK: - Image Processing

    /// Compress and resize an image, stripping EXIF metadata
    private func compressImage(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let scale: CGFloat

        if size.width > size.height {
            scale = min(1.0, maxDimension / size.width)
        } else {
            scale = min(1.0, maxDimension / size.height)
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Redraw to strip EXIF metadata
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage?.jpegData(compressionQuality: quality)
    }

    // MARK: - Errors

    enum SharingError: LocalizedError {
        case notAuthenticated
        case contentFiltered(String)
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to share photos."
            case .contentFiltered(let reason):
                return reason
            case .compressionFailed:
                return "Failed to process image for upload."
            }
        }
    }
}
