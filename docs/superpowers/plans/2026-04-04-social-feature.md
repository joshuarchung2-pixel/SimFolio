# Social Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a school-scoped social feed where dental students can share simulation photos, comment, react, report, and block — with full App Store compliance.

**Architecture:** Firebase-backed social layer (Auth + Firestore + Storage) on top of the existing local-first app. New 5th "Feed" tab. Auth is optional and only gates social features. Existing app functionality is unaffected.

**Tech Stack:** SwiftUI, Firebase Auth (Sign in with Apple + email), Firestore, Firebase Storage, existing AppTheme design system.

**Source root:** `SimFolio/SimFolio/` (all paths below are relative to project root `/Users/joshuachung/Desktop/SimFolio/`)

**Spec:** `Documentation/SocialFeaturePlan.md`

---

## Dependency Graph

```
Task 1 (Models) ──┬──> Task 3 (AuthService) ──┬──> Task 5 (SignIn UI)
                   │                            ├──> Task 6 (Account Deletion)
                   │                            ├──> Task 7 (UserProfileService)
                   │                            └──> Task 8 (School Picker + Migration)
                   │
                   ├──> Task 2 (Security Rules)        [independent]
                   ├──> Task 14 (Analytics Events)     [independent]
                   ├──> Task 15 (Privacy/Compliance)   [independent]
                   │
                   ├──> Task 9 (PhotoSharingService) ──> Task 10 (Share UI + Capture Prompt)
                   │                                  ──> Task 11 (Feed Tab + SocialFeedView)
                   │                                  ──> Task 12 (PostDetailView)
                   │
                   ├──> Task 13 (SocialInteractionService) ──> Task 12 (PostDetailView)
                   │
                   └──> Task 4 (ModerationService + ContentFilter) ──> Task 12 (PostDetailView)
                                                                   ──> Task 16 (Report/Block UI)

Task 17 (Social Settings + Onboarding) ──> Task 3
Task 18 (Terms of Service) ──> independent
Task 19 (Integration + Wiring) ──> ALL previous tasks
```

## Parallelization Groups

- **Wave 1** (no deps): Tasks 1, 2, 14, 15, 18
- **Wave 2** (needs models): Tasks 3, 4, 9, 13
- **Wave 3** (needs services): Tasks 5, 6, 7, 8, 10, 11, 16, 17
- **Wave 4** (needs feed): Tasks 12
- **Wave 5** (final): Task 19

---

## Existing Patterns to Follow

### Service Pattern (stateful)
```swift
@MainActor
class ServiceName: ObservableObject {
    static let shared = ServiceName()
    @Published var someState: Type = defaultValue
    private init() { }
}
```

### Service Pattern (stateless)
```swift
enum ServiceName {
    static func doThing() { }
}
```

### Model Pattern
```swift
struct ModelName: Codable, Identifiable, Hashable {
    let id: String
    // properties...
}
```

### Design System
- Colors: `AppTheme.Colors.primary`, `.surface`, `.textPrimary`, `.textSecondary`
- Typography: `AppTheme.Typography.title`, `.body`, `.caption`
- Spacing: `AppTheme.Spacing.sm` (8), `.md` (16), `.lg` (24)
- Corner radius: `AppTheme.CornerRadius.small` (8), `.medium` (12), `.large` (16)
- Shadows: `.shadowSmall()`, `.shadowMedium()`
- Buttons: `DPButton(title:style:size:action:)` — styles: .primary, .secondary, .destructive
- Cards: `DPCard { content }`
- Tags: `DPTagPill(text:color:)`
- Procedure colors: `AppTheme.procedureColor(for: "Class 1")`

### Key Existing Files
- App entry: `SimFolio/SimFolioApp.swift` (Firebase init in AppDelegate, line ~236)
- Tab view: `SimFolio/App/ContentView.swift` (4 tabs at lines 192-248)
- Navigation: `SimFolio/Core/Navigation.swift` (MainTab enum lines 19-64, DPTabBar lines 68-154, NavigationRouter lines 276-521)
- Capture save: `SimFolio/Features/Capture/CaptureFlowView.swift` (savePhotos() at line ~1369)
- Library: `SimFolio/Features/Library/LibraryView.swift` (PhotoDetailView menu at line ~2305)
- Profile: `SimFolio/Features/Profile/ProfileView.swift` (SettingsSection pattern at line ~716)
- Onboarding: `SimFolio/Features/Onboarding/OnboardingView.swift` (school TextField at line ~899)
- Analytics: `SimFolio/Services/AnalyticsService.swift` (AnalyticsEvent enum at line ~23)

---

## Task 1: Data Models

**Files:**
- Create: `SimFolio/Models/SharedPost.swift`
- Create: `SimFolio/Models/Comment.swift`
- Create: `SimFolio/Models/DentalSchool.swift`
- Create: `SimFolio/Models/SocialReport.swift`

- [ ] **Step 1: Create SharedPost model**

```swift
// SimFolio/Models/SharedPost.swift
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
```

- [ ] **Step 2: Create Comment model**

```swift
// SimFolio/Models/Comment.swift
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
```

- [ ] **Step 3: Create DentalSchool model with curated list**

```swift
// SimFolio/Models/DentalSchool.swift
import Foundation

struct DentalSchool: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let shortName: String
    let state: String

    var displayName: String { "\(name) (\(shortName))" }
}

extension DentalSchool {
    /// Curated list of ~70 accredited US dental schools
    static let allSchools: [DentalSchool] = [
        DentalSchool(id: "uab", name: "University of Alabama at Birmingham School of Dentistry", shortName: "UAB", state: "AL"),
        DentalSchool(id: "midwestern-az", name: "Midwestern University College of Dental Medicine - Arizona", shortName: "MWU-AZ", state: "AZ"),
        DentalSchool(id: "atsu", name: "A.T. Still University Arizona School of Dentistry & Oral Health", shortName: "ATSU-ASDOH", state: "AZ"),
        DentalSchool(id: "llu", name: "Loma Linda University School of Dentistry", shortName: "LLU", state: "CA"),
        DentalSchool(id: "ucsf", name: "University of California San Francisco School of Dentistry", shortName: "UCSF", state: "CA"),
        DentalSchool(id: "ucla", name: "UCLA School of Dentistry", shortName: "UCLA", state: "CA"),
        DentalSchool(id: "usc", name: "Herman Ostrow School of Dentistry of USC", shortName: "USC", state: "CA"),
        DentalSchool(id: "uop", name: "University of the Pacific Arthur A. Dugoni School of Dentistry", shortName: "UOP", state: "CA"),
        DentalSchool(id: "western", name: "Western University of Health Sciences College of Dental Medicine", shortName: "WesternU", state: "CA"),
        DentalSchool(id: "cu-dental", name: "University of Colorado School of Dental Medicine", shortName: "CU", state: "CO"),
        DentalSchool(id: "uconn", name: "University of Connecticut School of Dental Medicine", shortName: "UConn", state: "CT"),
        DentalSchool(id: "howard", name: "Howard University College of Dentistry", shortName: "Howard", state: "DC"),
        DentalSchool(id: "nova", name: "Nova Southeastern University College of Dental Medicine", shortName: "Nova", state: "FL"),
        DentalSchool(id: "uf", name: "University of Florida College of Dentistry", shortName: "UF", state: "FL"),
        DentalSchool(id: "lecom", name: "Lake Erie College of Osteopathic Medicine School of Dental Medicine", shortName: "LECOM", state: "FL"),
        DentalSchool(id: "dcu", name: "Dental College of Georgia at Augusta University", shortName: "DCG", state: "GA"),
        DentalSchool(id: "uic", name: "University of Illinois Chicago College of Dentistry", shortName: "UIC", state: "IL"),
        DentalSchool(id: "siu", name: "Southern Illinois University School of Dental Medicine", shortName: "SIU", state: "IL"),
        DentalSchool(id: "midwestern-il", name: "Midwestern University College of Dental Medicine - Illinois", shortName: "MWU-IL", state: "IL"),
        DentalSchool(id: "iu", name: "Indiana University School of Dentistry", shortName: "IU", state: "IN"),
        DentalSchool(id: "uiowa", name: "University of Iowa College of Dentistry & Dental Clinics", shortName: "Iowa", state: "IA"),
        DentalSchool(id: "uk", name: "University of Kentucky College of Dentistry", shortName: "UK", state: "KY"),
        DentalSchool(id: "uofl", name: "University of Louisville School of Dentistry", shortName: "UofL", state: "KY"),
        DentalSchool(id: "lsu", name: "Louisiana State University Health School of Dentistry", shortName: "LSU", state: "LA"),
        DentalSchool(id: "une", name: "University of New England College of Dental Medicine", shortName: "UNE", state: "ME"),
        DentalSchool(id: "umd", name: "University of Maryland School of Dentistry", shortName: "UMD", state: "MD"),
        DentalSchool(id: "bu", name: "Boston University Henry M. Goldman School of Dental Medicine", shortName: "BU", state: "MA"),
        DentalSchool(id: "harvard", name: "Harvard School of Dental Medicine", shortName: "Harvard", state: "MA"),
        DentalSchool(id: "tufts", name: "Tufts University School of Dental Medicine", shortName: "Tufts", state: "MA"),
        DentalSchool(id: "umich", name: "University of Michigan School of Dentistry", shortName: "UMich", state: "MI"),
        DentalSchool(id: "detroit", name: "University of Detroit Mercy School of Dentistry", shortName: "UDM", state: "MI"),
        DentalSchool(id: "umn", name: "University of Minnesota School of Dentistry", shortName: "UMN", state: "MN"),
        DentalSchool(id: "ummc", name: "University of Mississippi Medical Center School of Dentistry", shortName: "UMMC", state: "MS"),
        DentalSchool(id: "umkc", name: "University of Missouri-Kansas City School of Dentistry", shortName: "UMKC", state: "MO"),
        DentalSchool(id: "creighton", name: "Creighton University School of Dentistry", shortName: "Creighton", state: "NE"),
        DentalSchool(id: "unmc", name: "University of Nebraska Medical Center College of Dentistry", shortName: "UNMC", state: "NE"),
        DentalSchool(id: "unlv", name: "University of Nevada, Las Vegas School of Dental Medicine", shortName: "UNLV", state: "NV"),
        DentalSchool(id: "rutgers", name: "Rutgers School of Dental Medicine", shortName: "Rutgers", state: "NJ"),
        DentalSchool(id: "columbia", name: "Columbia University College of Dental Medicine", shortName: "Columbia", state: "NY"),
        DentalSchool(id: "nyu", name: "New York University College of Dentistry", shortName: "NYU", state: "NY"),
        DentalSchool(id: "stony", name: "Stony Brook University School of Dental Medicine", shortName: "Stony Brook", state: "NY"),
        DentalSchool(id: "touro", name: "Touro College of Dental Medicine", shortName: "Touro", state: "NY"),
        DentalSchool(id: "buffalo", name: "University at Buffalo School of Dental Medicine", shortName: "UB", state: "NY"),
        DentalSchool(id: "unc", name: "University of North Carolina at Chapel Hill Adams School of Dentistry", shortName: "UNC", state: "NC"),
        DentalSchool(id: "ecu", name: "East Carolina University School of Dental Medicine", shortName: "ECU", state: "NC"),
        DentalSchool(id: "case", name: "Case Western Reserve University School of Dental Medicine", shortName: "CWRU", state: "OH"),
        DentalSchool(id: "osu", name: "The Ohio State University College of Dentistry", shortName: "OSU", state: "OH"),
        DentalSchool(id: "ou", name: "University of Oklahoma College of Dentistry", shortName: "OU", state: "OK"),
        DentalSchool(id: "ohsu", name: "Oregon Health & Science University School of Dentistry", shortName: "OHSU", state: "OR"),
        DentalSchool(id: "kornberg", name: "Temple University Maurice H. Kornberg School of Dentistry", shortName: "Temple", state: "PA"),
        DentalSchool(id: "upenn", name: "University of Pennsylvania School of Dental Medicine", shortName: "Penn", state: "PA"),
        DentalSchool(id: "pitt", name: "University of Pittsburgh School of Dental Medicine", shortName: "Pitt", state: "PA"),
        DentalSchool(id: "musc", name: "Medical University of South Carolina James B. Edwards College of Dental Medicine", shortName: "MUSC", state: "SC"),
        DentalSchool(id: "meharry", name: "Meharry Medical College School of Dentistry", shortName: "Meharry", state: "TN"),
        DentalSchool(id: "uthsc", name: "University of Tennessee Health Science Center College of Dentistry", shortName: "UTHSC", state: "TN"),
        DentalSchool(id: "tamu", name: "Texas A&M University College of Dentistry", shortName: "TAMU", state: "TX"),
        DentalSchool(id: "utsa", name: "UT Health San Antonio School of Dentistry", shortName: "UTHSA", state: "TX"),
        DentalSchool(id: "uth", name: "UTHealth Houston School of Dentistry", shortName: "UTH", state: "TX"),
        DentalSchool(id: "utah", name: "Roseman University of Health Sciences College of Dental Medicine", shortName: "Roseman", state: "UT"),
        DentalSchool(id: "vcu", name: "Virginia Commonwealth University School of Dentistry", shortName: "VCU", state: "VA"),
        DentalSchool(id: "liberty", name: "Liberty University College of Dental Medicine", shortName: "Liberty", state: "VA"),
        DentalSchool(id: "uw", name: "University of Washington School of Dentistry", shortName: "UW", state: "WA"),
        DentalSchool(id: "wvu", name: "West Virginia University School of Dentistry", shortName: "WVU", state: "WV"),
        DentalSchool(id: "marquette", name: "Marquette University School of Dentistry", shortName: "Marquette", state: "WI"),
    ]

    static let otherSchool = DentalSchool(id: "other", name: "Other - Request my school", shortName: "Other", state: "")

    /// Find school by ID
    static func school(withId id: String) -> DentalSchool? {
        allSchools.first { $0.id == id }
    }

    /// Search schools by name or abbreviation
    static func search(_ query: String) -> [DentalSchool] {
        guard !query.isEmpty else { return allSchools }
        let lowered = query.lowercased()
        return allSchools.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.shortName.lowercased().contains(lowered) ||
            $0.state.lowercased().contains(lowered)
        }
    }
}
```

- [ ] **Step 4: Create SocialReport model**

```swift
// SimFolio/Models/SocialReport.swift
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
```

- [ ] **Step 5: Commit models**

```bash
git add SimFolio/Models/SharedPost.swift SimFolio/Models/Comment.swift SimFolio/Models/DentalSchool.swift SimFolio/Models/SocialReport.swift
git commit -m "feat(social): add data models for SharedPost, Comment, DentalSchool, SocialReport"
```

---

## Task 2: Firebase Security Rules

**Files:**
- Create: `Config/firestore.rules`
- Create: `Config/storage.rules`

- [ ] **Step 1: Write Firestore security rules**

```
// Config/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: is the request from an authenticated user?
    function isAuth() {
      return request.auth != null;
    }

    // Helper: is the requesting user the document owner?
    function isOwner(userId) {
      return isAuth() && request.auth.uid == userId;
    }

    // Helper: get user doc
    function getUserDoc() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid));
    }

    // Helper: is user blocked by target user?
    function isBlockedBy(targetUserId) {
      let targetUser = get(/databases/$(database)/documents/users/$(targetUserId));
      return request.auth.uid in targetUser.data.blockedUserIds;
    }

    // Users collection
    match /users/{userId} {
      allow read: if isAuth();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if isOwner(userId);
    }

    // School requests collection
    match /schoolRequests/{requestId} {
      allow create: if isAuth();
      allow read: if false; // Admin only
    }

    // Posts collection
    match /posts/{postId} {
      allow read: if isAuth()
        && resource.data.isSimulation == true;
      allow create: if isAuth()
        && request.resource.data.userId == request.auth.uid
        && request.resource.data.isSimulation == true;
      allow update: if isOwner(resource.data.userId);
      allow delete: if isOwner(resource.data.userId);

      // Comments subcollection
      match /comments/{commentId} {
        allow read: if isAuth();
        allow create: if isAuth()
          && request.resource.data.userId == request.auth.uid;
        allow delete: if isAuth()
          && resource.data.userId == request.auth.uid;
      }

      // Reactions subcollection
      match /reactions/{reactionUserId} {
        allow read: if isAuth();
        allow write: if isAuth()
          && reactionUserId == request.auth.uid;
      }
    }

    // Reports collection
    match /reports/{reportId} {
      allow create: if isAuth()
        && request.resource.data.reporterId == request.auth.uid;
      allow read: if false; // Admin only via Firebase Console
    }
  }
}
```

- [ ] **Step 2: Write Storage security rules**

```
// Config/storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only upload to their own path
    match /users/{userId}/photos/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024  // 5MB limit
        && request.resource.contentType.matches('image/.*');
    }

    match /users/{userId}/thumbnails/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid == userId
        && request.resource.size < 1 * 1024 * 1024  // 1MB limit
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

- [ ] **Step 3: Commit security rules**

```bash
git add Config/firestore.rules Config/storage.rules
git commit -m "feat(social): add Firestore and Storage security rules"
```

---

## Task 3: AuthenticationService

**Files:**
- Create: `SimFolio/Services/AuthenticationService.swift`

- [ ] **Step 1: Create AuthenticationService**

Singleton, @MainActor, ObservableObject. Wraps Firebase Auth with Sign in with Apple and email/password.

Key interface:
```swift
@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    enum AuthState { case loading, signedOut, signedIn }

    @Published var currentUser: FirebaseAuth.User?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    // Sign in with Apple
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws

    // Email/password
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws

    // Sign out
    func signOut() throws

    // Account deletion (full compliance flow)
    func deleteAccount() async throws
    // - Revokes Sign in with Apple token
    // - Deletes all Firestore data (user doc, posts, comments, reactions)
    // - Deletes all Storage files
    // - Warns about active subscriptions
    // - Calls Auth.auth().currentUser?.delete()

    // Password reset
    func sendPasswordReset(email: String) async throws
}
```

Must listen to `Auth.auth().addStateDidChangeListener` in init.

For Sign in with Apple token revocation on delete: store the Apple authorization code at sign-in time, then use it to call Apple's token revocation endpoint via `Auth.auth().revokeToken(withAuthorizationCode:)`.

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Services/AuthenticationService.swift
git commit -m "feat(social): add AuthenticationService with Sign in with Apple and account deletion"
```

---

## Task 4: ModerationService + ContentFilterService

**Files:**
- Create: `SimFolio/Services/ModerationService.swift`
- Create: `SimFolio/Services/ContentFilterService.swift`

- [ ] **Step 1: Create ContentFilterService**

Stateless text filter. Basic profanity/slur word list. Returns whether text passes or fails.

```swift
enum ContentFilterService {
    static func isTextClean(_ text: String) -> Bool
    static func filterReason(_ text: String) -> String?  // nil if clean
}
```

Include a reasonable profanity word list as a private static array. Filter should be case-insensitive and check word boundaries (not substrings).

- [ ] **Step 2: Create ModerationService**

```swift
@MainActor
class ModerationService: ObservableObject {
    static let shared = ModerationService()

    func reportPost(postId: String, reason: SocialReport.ReportReason, details: String?) async throws
    func reportComment(postId: String, commentId: String, reason: SocialReport.ReportReason, details: String?) async throws
    func blockUser(userId: String) async throws  // adds to current user's blockedUserIds
    func unblockUser(userId: String) async throws
    func getBlockedUserIds() -> [String]  // from cached user doc
    func isUserBlocked(_ userId: String) -> Bool

    // Auto-hide: when reporting, if post.reportCount >= 3, set isHidden = true
    // Use Firestore transaction for atomic reportCount increment
}
```

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Services/ModerationService.swift SimFolio/Services/ContentFilterService.swift
git commit -m "feat(social): add ModerationService and ContentFilterService"
```

---

## Task 5: Sign In UI

**Files:**
- Create: `SimFolio/Features/Auth/SignInView.swift`
- Create: `SimFolio/Features/Auth/SignInWithAppleButton.swift`

- [ ] **Step 1: Create SignInWithAppleButton**

SwiftUI wrapper around ASAuthorizationAppleIDButton using UIViewRepresentable. Handle the authorization flow and pass the credential to AuthenticationService.

- [ ] **Step 2: Create SignInView**

Full sign-in screen with:
- App branding at top (SimFolio logo/name)
- "Sign in to share with classmates" messaging
- Sign in with Apple button (prominent, primary action)
- Divider with "or"
- Email/password fields with sign in / sign up toggle
- "Forgot password?" link
- "Skip" / dismiss button (social features optional)
- Error display for auth failures
- Use AppTheme tokens throughout

Present as a sheet from NavigationRouter. Add `.signIn` case to `SheetType` enum in Navigation.swift.

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Auth/SignInView.swift SimFolio/Features/Auth/SignInWithAppleButton.swift
git commit -m "feat(social): add sign-in UI with Sign in with Apple and email/password"
```

---

## Task 6: Account Deletion Flow

**Files:**
- Modify: `SimFolio/Features/Profile/ProfileView.swift`
- Modify: `SimFolio/Features/Profile/Settings/DataManagementView.swift`

- [ ] **Step 1: Add account deletion UI to DataManagementView**

Add a new section at the bottom of DataManagementView (or ProfileView settings) for authenticated users:

- "ACCOUNT" SettingsSection with:
  - "Delete Account" SettingsRow (destructive style, red)
  - On tap: show confirmation alert with multi-step flow:
    1. If active subscription: warn about billing, show "Manage Subscription" link
    2. Confirm deletion with "Delete Account" / "Cancel"
    3. Show progress indicator during deletion
    4. Show "Account deleted" confirmation
    5. Dismiss and return to unauthenticated state

Only show this section when `AuthenticationService.shared.authState == .signedIn`.

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Features/Profile/ProfileView.swift SimFolio/Features/Profile/Settings/DataManagementView.swift
git commit -m "feat(social): add account deletion flow with subscription handling"
```

---

## Task 7: UserProfileService

**Files:**
- Create: `SimFolio/Services/UserProfileService.swift`

- [ ] **Step 1: Create UserProfileService**

Manages the Firestore user document. Syncs between UserDefaults (offline cache) and Firestore (source of truth for social).

```swift
@MainActor
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()

    @Published var userProfile: FirestoreUserProfile?
    @Published var isLoading = false

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
    }

    func createProfile(from onboardingProfile: UserOnboardingProfile, schoolId: String) async throws
    func fetchProfile() async throws
    func updateProfile(_ updates: [String: Any]) async throws
    func linkOnboardingData()  // reads UserDefaults, writes to Firestore on first sign-in
    func setSocialOptIn(_ enabled: Bool) async throws
}
```

On `AuthenticationService.authState` change to `.signedIn`, auto-fetch or create profile.

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Services/UserProfileService.swift
git commit -m "feat(social): add UserProfileService for Firestore user profiles"
```

---

## Task 8: School Picker + Migration

**Files:**
- Create: `SimFolio/Features/Auth/SchoolPickerView.swift`
- Create: `SimFolio/Features/Auth/SchoolMigrationSheet.swift`
- Modify: `SimFolio/Features/Onboarding/OnboardingView.swift` (replace school TextField ~line 899)

- [ ] **Step 1: Create SchoolPickerView**

Reusable searchable school selector:
- Search bar at top
- Scrollable list of `DentalSchool.search(query)` results
- Each row: school name, short name, state
- "Other - Request my school" at bottom
- Selection callback: `onSelect: (DentalSchool) -> Void`
- If "Other" selected, show a TextField for school name + submit to Firestore `schoolRequests` collection
- Use AppTheme tokens

- [ ] **Step 2: Create SchoolMigrationSheet**

One-time sheet for existing users:
- Title: "Select Your School"
- Subtitle: "We've updated our school list to help you connect with classmates"
- Embedded SchoolPickerView
- Pre-populate search with existing `UserDefaults.string(forKey: "userSchool")`
- Cannot dismiss without selecting (no X button, `.interactiveDismissDisabled(true)`)
- On selection: update UserDefaults `userSchool` with standardized name, save `userSchoolId` with school ID
- Set `UserDefaults.bool(forKey: "hasCompletedSchoolMigration")` = true

- [ ] **Step 3: Update OnboardingView**

In `OnboardingPersonalizationPageView` (~line 899), replace the school TextField with SchoolPickerView. Keep the same validation: `!userProfile.dentalSchoolAffiliation.isEmpty`. Set `dentalSchoolAffiliation` to the selected school's `name` property.

- [ ] **Step 4: Add migration trigger to ContentView**

In ContentView, after `isAppReady` becomes true, check:
```swift
if !UserDefaults.standard.bool(forKey: "hasCompletedSchoolMigration")
   && UserDefaults.standard.string(forKey: "userSchool") != nil {
    showSchoolMigration = true
}
```

Present SchoolMigrationSheet as `.fullScreenCover`.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Auth/SchoolPickerView.swift SimFolio/Features/Auth/SchoolMigrationSheet.swift SimFolio/Features/Onboarding/OnboardingView.swift SimFolio/App/ContentView.swift
git commit -m "feat(social): add curated school picker, replace free-text, add migration sheet"
```

---

## Task 9: PhotoSharingService

**Files:**
- Create: `SimFolio/Services/PhotoSharingService.swift`

- [ ] **Step 1: Create PhotoSharingService**

```swift
@MainActor
class PhotoSharingService: ObservableObject {
    static let shared = PhotoSharingService()

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0

    // Share a photo to the feed
    func sharePhoto(image: UIImage, metadata: PhotoMetadata, caption: String?) async throws -> SharedPost
    // 1. Validate with ContentFilterService (caption text)
    // 2. Compress to max 2048px, JPEG 0.8
    // 3. Generate thumbnail at 400px
    // 4. Strip EXIF metadata (create clean UIImage -> JPEG data)
    // 5. Upload full image to Storage: users/{uid}/photos/{postId}.jpg
    // 6. Upload thumbnail to Storage: users/{uid}/thumbnails/{postId}.jpg
    // 7. Create Firestore doc in posts collection
    // 8. Return created SharedPost

    func deletePost(_ post: SharedPost) async throws
    // Delete Storage files + Firestore doc

    func getSchoolFeed(school: String, limit: Int, afterDocument: DocumentSnapshot?) async throws -> ([SharedPost], DocumentSnapshot?)
    // Paginated query: posts where authorSchool == school, isHidden == false, ordered by createdAt desc

    func getUserPosts(userId: String) async throws -> [SharedPost]

    func getLatestPostTimestamp(school: String) async throws -> Date?
    // For the new-post indicator: query latest 1 post, return createdAt

    func isPhotoShared(assetId: String) -> Bool
    // Check local cache of shared asset IDs
}
```

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Services/PhotoSharingService.swift
git commit -m "feat(social): add PhotoSharingService with upload, feed queries, thumbnail generation"
```

---

## Task 10: Share UI + Post-Capture Prompt

**Files:**
- Create: `SimFolio/Features/Social/SharePhotoSheet.swift`
- Modify: `SimFolio/Features/Capture/CaptureFlowView.swift` (after savePhotos ~line 1404)
- Modify: `SimFolio/Features/Library/LibraryView.swift` (PhotoDetailView menu ~line 2305)

- [ ] **Step 1: Create SharePhotoSheet**

Sheet presented when user wants to share a photo:
- Photo preview thumbnail
- Simulation confirmation checkbox: "I confirm this is simulation work (not a real patient)"
- Caption TextField (optional, max 280 chars)
- Caption character counter
- "Share to Class Feed" DPButton (.primary) — disabled until checkbox checked
- "Cancel" DPButton (.secondary)
- Loading state during upload
- Success confirmation with checkmark animation
- Error handling with retry option
- Validates caption with ContentFilterService before submission

- [ ] **Step 2: Add post-capture share prompt**

In CaptureFlowView, after `savePhotos()` completes (after the DispatchGroup notify block ~line 1404):
- Add `@State private var showSharePrompt = false`
- Add `@State private var sharePromptDismissedThisSession = false`
- Add `@State private var savedPhotoForSharing: UIImage?`
- After successful save, if user is authenticated, social is opted in, and `!sharePromptDismissedThisSession`:
  - Set `savedPhotoForSharing` to the first saved photo
  - Set `showSharePrompt = true`
- Present SharePhotoSheet as `.sheet`
- If user dismisses without sharing, set `sharePromptDismissedThisSession = true`

- [ ] **Step 3: Add "Share to Feed" to PhotoDetailView menu**

In LibraryView.swift PhotoDetailView, add a new menu item after the existing "Share" button (~line 2305):
```swift
Button {
    showFeedShareSheet = true
} label: {
    Label("Share to Class Feed", systemImage: "person.2")
}
```
Only show when `AuthenticationService.shared.authState == .signedIn && UserProfileService.shared.userProfile?.socialOptIn == true`.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/Social/SharePhotoSheet.swift SimFolio/Features/Capture/CaptureFlowView.swift SimFolio/Features/Library/LibraryView.swift
git commit -m "feat(social): add share sheet, post-capture prompt, and library share integration"
```

---

## Task 11: Feed Tab + SocialFeedView

**Files:**
- Create: `SimFolio/Features/Social/SocialFeedView.swift`
- Create: `SimFolio/Features/Social/Components/FeedPostCard.swift`
- Modify: `SimFolio/Core/Navigation.swift` (add `.feed` to MainTab)
- Modify: `SimFolio/App/ContentView.swift` (add 5th tab)

- [ ] **Step 1: Add `.feed` tab to MainTab enum**

In Navigation.swift, add `case feed` to MainTab enum (between `library` and `profile`, or after `library`). Give it:
- title: "Feed"
- icon: "bubble.left.and.text.bubble.right" (or "person.2")
- selectedIcon: "bubble.left.and.text.bubble.right.fill" (or "person.2.fill")
- rawValue: update numbering
- accessibilityHint: "View your class feed"

Update DPTabBar to render 5 tabs.

- [ ] **Step 2: Create FeedPostCard**

Reusable card component for the feed:
- Thumbnail image (AsyncImage with placeholder)
- Author name + school badge (DPTagPill)
- Procedure color tag (AppTheme.procedureColor)
- Caption (if present, max 2 lines)
- Timestamp (relative: "2h ago" using SharedPost.displayDate)
- Reaction summary (top 3 reactions with counts)
- Comment count icon
- Tap action callback
- Use DPCard, AppTheme tokens
- Skeleton loading state

- [ ] **Step 3: Create SocialFeedView**

Main feed view:
- If not authenticated: show sign-in prompt with DPButton to present SignInView
- If authenticated but not opted in: show opt-in prompt (leads to SocialOnboardingSheet)
- If opted in: show feed
  - Pull-to-refresh (`.refreshable`)
  - LazyVStack of FeedPostCard items
  - Infinite scroll: load next page when last item appears (`.onAppear` on last card)
  - Filter chips at top: "All" + procedure types (horizontal ScrollView of DPTagPill)
  - Empty state: use EmptyStateView pattern — "No posts yet. Be the first to share!"
  - "New posts" banner: lightweight Firestore listener on latest timestamp, show banner if newer than last loaded
  - Tap card -> navigate to PostDetailView (via NavigationLink or sheet)
- Filter out posts from blocked users (ModerationService.isUserBlocked)

- [ ] **Step 4: Add Feed tab to ContentView**

In ContentView tab content section (~line 192), add:
```swift
case .feed:
    NavigationView {
        SocialFeedView()
    }
    .navigationViewStyle(.stack)
```

Add `.feed` to the tab rendering.

- [ ] **Step 5: Commit**

```bash
git add SimFolio/Features/Social/SocialFeedView.swift SimFolio/Features/Social/Components/FeedPostCard.swift SimFolio/Core/Navigation.swift SimFolio/App/ContentView.swift
git commit -m "feat(social): add Feed tab with SocialFeedView and FeedPostCard"
```

---

## Task 12: PostDetailView

**Files:**
- Create: `SimFolio/Features/Social/PostDetailView.swift`
- Create: `SimFolio/Features/Social/Components/ReactionBar.swift`
- Create: `SimFolio/Features/Social/Components/ReactionPicker.swift`
- Create: `SimFolio/Features/Social/Components/CommentListView.swift`
- Create: `SimFolio/Features/Social/Components/CommentInputBar.swift`

- [ ] **Step 1: Create ReactionBar**

Horizontal bar showing aggregated reaction counts:
- Shows each reaction emoji + count for reactions with count > 0
- Tap a reaction to toggle it (calls SocialInteractionService)
- Highlighted state if current user has reacted with that emoji
- Compact mode (for feed cards) vs expanded mode (for detail view)

- [ ] **Step 2: Create ReactionPicker**

Full reaction picker:
- 5 reactions in a row: fire, clap, hundred, tooth, star
- Each shows emoji + label below
- Tap to toggle
- Long-press to see who reacted (future, for now just toggle)

- [ ] **Step 3: Create CommentListView**

Paginated comment list:
- LazyVStack of comment rows
- Each row: author name, comment text, relative timestamp
- Swipe to delete own comments
- "Report" context menu on others' comments
- Load more on scroll
- Empty state: "No comments yet"
- Filter out comments where isHidden == true

- [ ] **Step 4: Create CommentInputBar**

Bottom text input:
- TextField with "Add a comment..." placeholder
- Send button (arrow.up.circle.fill)
- Keyboard-aware (moves up with keyboard)
- Validates text with ContentFilterService before submission
- Disabled state when not authenticated or posting

- [ ] **Step 5: Create PostDetailView**

Full-screen post detail:
- Full-resolution photo with pinch-to-zoom (similar to existing PhotoDetailView)
- Author info header (name, school, timestamp)
- Procedure/stage/angle/tooth tags (DPTagPill row)
- Caption (if present)
- ReactionPicker
- Divider
- CommentListView
- CommentInputBar (pinned to bottom)
- Overflow menu with: "Report Post", "Block User" (only on others' posts), "Delete Post" (only on own posts)
- Navigation back button

- [ ] **Step 6: Commit**

```bash
git add SimFolio/Features/Social/PostDetailView.swift SimFolio/Features/Social/Components/ReactionBar.swift SimFolio/Features/Social/Components/ReactionPicker.swift SimFolio/Features/Social/Components/CommentListView.swift SimFolio/Features/Social/Components/CommentInputBar.swift
git commit -m "feat(social): add PostDetailView with reactions, comments, and moderation actions"
```

---

## Task 13: SocialInteractionService

**Files:**
- Create: `SimFolio/Services/SocialInteractionService.swift`

- [ ] **Step 1: Create SocialInteractionService**

```swift
@MainActor
class SocialInteractionService: ObservableObject {
    static let shared = SocialInteractionService()

    // Comments
    func addComment(postId: String, text: String) async throws -> Comment
    // Validates text with ContentFilterService
    // Writes to posts/{postId}/comments subcollection
    // Increments posts/{postId}.commentCount atomically

    func deleteComment(postId: String, commentId: String) async throws
    // Only own comments (enforced by rules + client check)
    // Decrements commentCount atomically

    func getComments(postId: String, limit: Int, afterDocument: DocumentSnapshot?) async throws -> ([Comment], DocumentSnapshot?)
    // Paginated, ordered by createdAt asc, filter isHidden == false

    // Reactions
    func toggleReaction(postId: String, type: String) async throws
    // Check if reaction doc exists at posts/{postId}/reactions/{currentUserId}
    // If exists with same type: delete (un-react), decrement reactionCounts[type]
    // If exists with different type: update type, adjust counts
    // If not exists: create, increment reactionCounts[type]
    // Use Firestore transaction for atomic count updates

    func getUserReaction(postId: String) async throws -> String?
    // Returns the reaction type for current user, or nil
}
```

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Services/SocialInteractionService.swift
git commit -m "feat(social): add SocialInteractionService for comments and reactions"
```

---

## Task 14: Analytics Events Update

**Files:**
- Modify: `SimFolio/Services/AnalyticsService.swift`

- [ ] **Step 1: Add social analytics events**

Add to `AnalyticsEvent` enum (after existing cases):
```swift
// Social
case socialOptIn
case socialOptOut
case photoShared
case photoUnshared
case feedViewed
case postViewed
case commentAdded
case commentDeleted
case reactionAdded
case reactionRemoved
case userReported
case postReported
case commentReported
case userBlocked
case userUnblocked
case signInStarted
case signInCompleted
case signInFailed
case accountDeleted
```

Add to `AnalyticsUserProperty` enum:
```swift
case socialEnabled
case sharedPhotoCount
case socialCommentCount
```

Add convenience methods:
```swift
static func logPhotoShared(procedure: String, hasCaption: Bool)
static func logPostViewed(postId: String, procedure: String)
```

- [ ] **Step 2: Commit**

```bash
git add SimFolio/Services/AnalyticsService.swift
git commit -m "feat(social): add social analytics events and user properties"
```

---

## Task 15: Privacy & Compliance Updates

**Files:**
- Modify: `SimFolio/PrivacyInfo.xcprivacy`
- Modify: `Documentation/PRIVACY_POLICY.md`
- Modify: `Documentation/privacy-policy.html`

- [ ] **Step 1: Update PrivacyInfo.xcprivacy**

Add collected data type entries for:
- `NSPrivacyCollectedDataTypeUserID` — linked to identity, purpose: App Functionality
- `NSPrivacyCollectedDataTypeEmailAddress` — linked to identity, purpose: App Functionality
- `NSPrivacyCollectedDataTypeName` — linked to identity, purpose: App Functionality
- `NSPrivacyCollectedDataTypePhotosorVideos` — linked to identity, purpose: App Functionality
- `NSPrivacyCollectedDataTypeOtherUserContent` — linked to identity, purpose: App Functionality

Read the existing plist structure first and add entries in the same format.

- [ ] **Step 2: Update PRIVACY_POLICY.md**

Add sections covering:
- Firebase Authentication (user accounts, email, Apple ID)
- Firebase Firestore (user profiles, posts, comments, reactions, reports, block lists)
- Firebase Storage (uploaded photos and thumbnails)
- Data shared with classmates (display name, school, photos, comments, reactions)
- Social data retention and deletion policy
- Account deletion process and timeline (24-48 hours)
- Note: if AI-based image moderation added, disclose it

- [ ] **Step 3: Update privacy-policy.html**

Mirror all changes from PRIVACY_POLICY.md into the HTML version.

- [ ] **Step 4: Commit**

```bash
git add SimFolio/PrivacyInfo.xcprivacy Documentation/PRIVACY_POLICY.md Documentation/privacy-policy.html
git commit -m "feat(social): update privacy manifest and policy for social features"
```

---

## Task 16: Report + Block UI

**Files:**
- Create: `SimFolio/Features/Social/ReportSheet.swift`
- Create: `SimFolio/Features/Social/BlockConfirmationView.swift`

- [ ] **Step 1: Create ReportSheet**

Sheet for reporting posts/comments/users:
- Title: "Report [Post/Comment/User]"
- List of `SocialReport.ReportReason.allCases` as selectable rows
- Optional details TextField for "Other" reason
- "Submit Report" DPButton (.destructive)
- "Cancel" button
- Success confirmation: "Thank you. We'll review this within 24 hours."
- Auto-dismiss after success

- [ ] **Step 2: Create BlockConfirmationView**

Confirmation alert/sheet for blocking:
- "Block [Username]?"
- Explanation: "They won't be able to see your posts, and you won't see theirs."
- "Block" DPButton (.destructive)
- "Cancel" DPButton (.secondary)
- On confirm: call ModerationService.blockUser, dismiss, show toast

- [ ] **Step 3: Commit**

```bash
git add SimFolio/Features/Social/ReportSheet.swift SimFolio/Features/Social/BlockConfirmationView.swift
git commit -m "feat(social): add report and block UI sheets"
```

---

## Task 17: Social Settings + Onboarding

**Files:**
- Create: `SimFolio/Features/Social/SocialOnboardingSheet.swift`
- Create: `SimFolio/Features/Social/SocialSettingsView.swift`
- Modify: `SimFolio/Features/Profile/ProfileView.swift` (add Social section + Contact Support)

- [ ] **Step 1: Create SocialOnboardingSheet**

First-time social opt-in flow (presented when user first opens Feed tab or taps Share):
1. Welcome page: "Share your work with classmates"
2. Guidelines: "Simulation photos only. No real patient photos."
3. Terms of Service acceptance checkbox
4. "Get Started" button (requires ToS checkbox)
5. On accept: set `socialOptIn = true` in UserProfileService, store `tosAcceptedAt`
6. If not authenticated, present SignInView first

- [ ] **Step 2: Create SocialSettingsView**

Settings sub-screen:
- **Social Feed toggle** — master opt-in/opt-out
- **Visibility** — "My School Only" (read-only for Tier 1, show as info)
- **Who can comment** — "Everyone" or "No one" picker
- **Blocked Users** — list with unblock option
- Use existing SettingsSection/SettingsRow pattern from ProfileView

- [ ] **Step 3: Add Social section and Contact Support to ProfileView**

In ProfileView settings sections (after Subscription section ~line 472), add:
```swift
SettingsSection(title: "SOCIAL") {
    SettingsRow(
        icon: "person.2",
        title: "Social Feed Settings",
        action: { showSocialSettings = true }
    )
}
```

In the About section, add:
```swift
SettingsRow(
    icon: "envelope",
    title: "Contact Support",
    subtitle: "joshuarchung2@gmail.com",
    action: { /* open mailto link */ }
)
```

- [ ] **Step 4: Commit**

```bash
git add SimFolio/Features/Social/SocialOnboardingSheet.swift SimFolio/Features/Social/SocialSettingsView.swift SimFolio/Features/Profile/ProfileView.swift
git commit -m "feat(social): add social onboarding, settings, and contact support"
```

---

## Task 18: Terms of Service

**Files:**
- Create: `Documentation/SocialTermsOfService.md`

- [ ] **Step 1: Write Terms of Service**

Must include:
- Zero-tolerance for real patient photos
- Prohibited content list (objectionable, harmful, illegal, harassment, spam)
- Consequences (account suspension/termination)
- Content ownership: users retain ownership, grant SimFolio a non-exclusive license to display
- Content removal: SimFolio may remove content that violates ToS
- Indemnification clause
- Statement that this agreement is between the developer and end user, not Apple
- Privacy policy reference
- Contact information

- [ ] **Step 2: Commit**

```bash
git add Documentation/SocialTermsOfService.md
git commit -m "feat(social): add Terms of Service for social features"
```

---

## Task 19: Integration + Wiring

**Files:**
- Modify: `SimFolio/SimFolioApp.swift` (initialize new services)
- Modify: `SimFolio/App/ContentView.swift` (wire everything together)
- Modify: `SimFolio/Core/Navigation.swift` (add social navigation routes to SheetType)

- [ ] **Step 1: Update SimFolioApp.swift**

In AppDelegate or app init:
- `AuthenticationService.shared` is accessed (triggers init and auth state listener)
- Ensure Firestore and Storage are initialized (already done via FirebaseApp.configure())

- [ ] **Step 2: Update Navigation.swift SheetType**

Add cases to SheetType enum:
```swift
case signIn
case sharePhoto(image: UIImage, metadata: PhotoMetadata)
case socialOnboarding
case reportPost(postId: String)
case reportComment(postId: String, commentId: String)
case blockUser(userId: String, userName: String)
case socialSettings
```

- [ ] **Step 3: Wire ContentView**

- Add `@StateObject private var authService = AuthenticationService.shared`
- Add `@StateObject private var userProfileService = UserProfileService.shared`
- Pass as environment objects to child views that need them
- Handle sheet presentations for new SheetType cases
- Handle school migration sheet trigger

- [ ] **Step 4: Final integration test**

Build the project. Verify:
- App launches without crashes
- All 5 tabs render
- Feed tab shows sign-in prompt when not authenticated
- Existing tabs and features still work
- No compiler errors

- [ ] **Step 5: Commit**

```bash
git add SimFolio/SimFolioApp.swift SimFolio/App/ContentView.swift SimFolio/Core/Navigation.swift
git commit -m "feat(social): wire social services and navigation into app"
```

---

## Manual Steps (Cannot Be Automated)

These steps require human action in external systems:

### Firebase Console
1. **Enable Authentication** providers: Sign in with Apple + Email/Password
2. **Configure Sign in with Apple** in Apple Developer portal (add Service ID, configure domains)
3. **Deploy Firestore security rules** from `Config/firestore.rules`
4. **Deploy Storage security rules** from `Config/storage.rules`
5. **Create Firestore indexes** for feed queries:
   - Collection: `posts`, Fields: `authorSchool` ASC, `isHidden` ASC, `createdAt` DESC
   - Collection: `posts`, Fields: `userId` ASC, `createdAt` DESC
6. **Set up report alerts** — configure email notifications for new documents in `reports` collection

### Apple Developer Portal
7. **Add Sign in with Apple capability** to the app's provisioning profile
8. **Configure Sign in with Apple Service ID** with correct redirect URLs

### Xcode Project
9. **Add Sign in with Apple capability** in Xcode Signing & Capabilities
10. **Update Xcode project** to include new files in the build target

### App Store Connect (before submission)
11. **Update age rating questionnaire** — answer "Yes" to "User Generated Content"
12. **Update App Store privacy labels** to declare: User ID, Email, Name, Photos/Videos, Other User Content (all linked to identity, App Functionality, not tracking)
13. **Create demo account** with pre-seeded social feed data for App Review
14. **Add demo credentials** and testing instructions to App Review Notes
15. **Upload updated privacy policy** URL if hosted externally

### Content
16. **Seed demo school feed** — create 5-10 sample posts with comments and reactions for the demo account's school
17. **Review Terms of Service** with legal counsel if possible
