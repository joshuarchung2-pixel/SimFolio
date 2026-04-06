import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()

    @Published var userProfile: FirestoreUserProfile?
    @Published var isLoading = false

    private let db = Firestore.firestore()

    struct FirestoreUserProfile: Codable {
        let userId: String
        var displayName: String
        var school: String
        var schoolId: String
        var graduationYear: Int?
        var profileImageURL: String?
        let createdAt: Date
        var socialOptIn: Bool
        var blockedUserIds: [String]
        var isActive: Bool
        var tosAcceptedAt: Date?
        var commentSetting: String // "everyone" or "none"
    }

    private init() {}

    // MARK: - Profile Management

    /// Create a new user profile in Firestore from onboarding data
    func createProfile(displayName: String, school: String, schoolId: String, graduationYear: Int?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let profile = FirestoreUserProfile(
            userId: userId,
            displayName: displayName,
            school: school,
            schoolId: schoolId,
            graduationYear: graduationYear,
            profileImageURL: nil,
            createdAt: Date(),
            socialOptIn: false,
            blockedUserIds: [],
            isActive: true,
            tosAcceptedAt: nil,
            commentSetting: "everyone"
        )

        try await db.collection("users").document(userId).setData(try Firestore.Encoder().encode(profile))
        self.userProfile = profile
    }

    /// Fetch user profile from Firestore
    func fetchProfile() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        let doc = try await db.collection("users").document(userId).getDocument()
        if doc.exists {
            userProfile = try doc.data(as: FirestoreUserProfile.self)
        }
    }

    /// Update specific fields on the user profile
    func updateProfile(_ updates: [String: Any]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(userId).updateData(updates)
        try await fetchProfile()
    }

    /// Link existing UserDefaults onboarding data to Firestore on first sign-in
    func linkOnboardingData() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let doc = try await db.collection("users").document(userId).getDocument()
        if doc.exists {
            userProfile = try doc.data(as: FirestoreUserProfile.self)
            return
        }

        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "userName") ?? ""
        let school = defaults.string(forKey: "userSchool") ?? ""
        let schoolId = defaults.string(forKey: "userSchoolId") ?? ""
        let year = defaults.integer(forKey: "userGraduationYear")

        try await createProfile(
            displayName: name,
            school: school,
            schoolId: schoolId,
            graduationYear: year > 0 ? year : nil
        )
    }

    // MARK: - Social Settings

    /// Set social opt-in status
    func setSocialOptIn(_ enabled: Bool) async throws {
        try await updateProfile([
            "socialOptIn": enabled,
            "tosAcceptedAt": enabled ? FieldValue.serverTimestamp() : NSNull()
        ])

        if enabled {
            AnalyticsService.logEvent(.socialOptIn)
            AnalyticsService.setUserProperty("true", for: .socialEnabled)
        } else {
            AnalyticsService.logEvent(.socialOptOut)
            AnalyticsService.setUserProperty("false", for: .socialEnabled)
        }
    }

    /// Update comment setting
    func setCommentSetting(_ setting: String) async throws {
        try await updateProfile(["commentSetting": setting])
    }

    /// Clear local profile state (on sign out)
    func clearProfile() {
        userProfile = nil
    }
}
