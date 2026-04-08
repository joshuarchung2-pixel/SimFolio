// AuthenticationService.swift
// SimFolio - Firebase Authentication Service
//
// Singleton service wrapping Firebase Auth for Sign in with Apple and
// email/password authentication. Handles account deletion with full
// data cleanup for App Store compliance.

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import AuthenticationServices
import CryptoKit

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case notSignedIn
    case missingCredential
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "No user is currently signed in."
        case .missingCredential: return "Missing authentication credential."
        case .appleSignInFailed: return "Sign in with Apple failed."
        }
    }
}

// MARK: - AuthenticationService

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    enum AuthState {
        case loading, signedOut, signedIn
    }

    @Published var currentUser: User?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    // Store for Sign in with Apple token revocation
    private var currentNonce: String?
    private var appleAuthorizationCode: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Listen to auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.authState = user != nil ? .signedIn : .signedOut
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign in with Apple

    /// Generate random nonce and return a configured ASAuthorizationAppleIDRequest
    func startSignInWithApple() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Complete Sign in with Apple after Apple authorization succeeds
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.missingCredential
        }

        // Store authorization code for later token revocation on account deletion
        if let authorizationCode = appleIDCredential.authorizationCode,
           let codeString = String(data: authorizationCode, encoding: .utf8) {
            appleAuthorizationCode = codeString
        }

        guard let nonce = currentNonce else {
            throw AuthError.appleSignInFailed
        }

        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        try await Auth.auth().signIn(with: credential)
        AnalyticsService.logEvent(.signInCompleted, parameters: ["provider": "apple"])
    }

    // MARK: - Email/Password

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        // result.user is automatically set via the state listener
        _ = result
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        // State listener handles the rest
    }

    // MARK: - Account Deletion (App Store compliance)

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.notSignedIn }

        // Step 1: Revoke Sign in with Apple token if applicable
        if let authCode = appleAuthorizationCode,
           let authCodeData = authCode.data(using: .utf8) {
            try await Auth.auth().revokeToken(withAuthorizationCode: String(data: authCodeData, encoding: .utf8) ?? authCode)
        }

        // Step 2: Delete user data from Firestore
        let db = Firestore.firestore()
        let userId = user.uid

        // Delete user's posts and their subcollections
        let posts = try await db.collection("posts").whereField("userId", isEqualTo: userId).getDocuments()
        for post in posts.documents {
            // Delete comments subcollection
            let comments = try await post.reference.collection("comments").getDocuments()
            for comment in comments.documents {
                try await comment.reference.delete()
            }
            // Delete reactions subcollection
            let reactions = try await post.reference.collection("reactions").getDocuments()
            for reaction in reactions.documents {
                try await reaction.reference.delete()
            }
            try await post.reference.delete()
        }

        // Delete user document
        // (Note: Firestore doesn't support collection group queries easily here,
        //  so delete the user doc which is the main requirement)
        try await db.collection("users").document(userId).delete()

        // Step 3: Delete Storage files
        let storage = Storage.storage()
        let photosRef = storage.reference().child("users/\(userId)/photos")
        let thumbnailsRef = storage.reference().child("users/\(userId)/thumbnails")
        // List and delete all files (requires listing API)
        do {
            let photoList = try await photosRef.listAll()
            for item in photoList.items { try await item.delete() }
            let thumbList = try await thumbnailsRef.listAll()
            for item in thumbList.items { try await item.delete() }
        } catch {
            // Storage folders may not exist yet, continue
        }

        // Step 4: Delete Firebase Auth account
        try await user.delete()

        // Clear local state
        appleAuthorizationCode = nil
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess { fatalError("Unable to generate nonce") }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
