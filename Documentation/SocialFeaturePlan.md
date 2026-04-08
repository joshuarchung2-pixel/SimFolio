# SimFolio Social Feature Implementation Plan (Tier 1)

**Goal:** Simulation-only social feed where dental students can opt-in to share photos with classmates, and comment/react to each other's work.

**Scope:** Simulation lab photos only (mannequins/typodonts). No real patient photos in the social feed.

---

## Phase 0: Firebase Infrastructure

Set up the backend services needed for all subsequent phases.

### 0.1 Add Firebase SDKs
- Add `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage` to SPM dependencies in `project.pbxproj`
- Update conditional imports in `SimFolioApp.swift` to include new modules
- Initialize Firestore and Storage in `AppDelegate.didFinishLaunchingWithOptions`

### 0.2 Firebase Console Setup
- Enable **Authentication** with Sign in with Apple (required by App Store) and Email/Password
- Create **Firestore** database in production mode with security rules
- Create **Cloud Storage** bucket with access rules
- Set up Firestore indexes for feed queries (by school, by date, etc.)

### 0.3 Firestore Security Rules
Write rules that enforce:
- Users can only write to their own documents
- Users can only read posts from their school group
- Blocked users cannot read each other's content
- Reported content is flagged but still readable until moderated

### 0.4 Storage Security Rules
- Users can only upload to their own path (`users/{userId}/photos/`)
- All users in the same school can read shared photos
- Max file size limit (e.g., 5MB per photo)

**Files to create:**
- `Config/firestore.rules`
- `Config/storage.rules`

**Files to modify:**
- `SimFolio.xcodeproj/project.pbxproj` (add SPM dependencies)
- `SimFolioApp.swift` (initialize new Firebase services)

---

## Phase 1: User Authentication & Accounts

### 1.1 AuthenticationService
Create a new service to manage Firebase Auth state.

```
Services/AuthenticationService.swift
```

- `@Published var currentUser: FirebaseAuth.User?`
- `@Published var authState: AuthState` (`.signedOut`, `.signedIn`, `.loading`)
- Sign in with Apple flow
- Email/password sign up and sign in
- Sign out
- Account deletion (required by App Store)
- Listen to `Auth.auth().addStateDidChangeListener`

### 1.2 User Profile in Firestore
Migrate user profile from UserDefaults to Firestore (while keeping UserDefaults as local cache for offline).

**Firestore `users` collection schema:**
```
users/{userId}
  ├── displayName: String
  ├── school: String
  ├── graduationYear: Int
  ├── profileImageURL: String?
  ├── createdAt: Timestamp
  ├── socialOptIn: Bool (default false)
  ├── blockedUserIds: [String]
  └── isActive: Bool
```

### 1.3 Auth UI
- Add sign-in screen (presented when user tries to access social features)
- Add Sign in with Apple button (use `AuthenticationServices` framework)
- Add email/password option as fallback
- Gate social features behind authentication — the rest of the app works without an account

### 1.4 Account Deletion Flow (App Store Guideline 5.1.1(v))
- Add "Delete Account" option in Profile > Settings
- **Step 1 — Subscription check**: If user has an active RevenueCat subscription, warn that billing continues through Apple and present a link to subscription management (`showManageSubscription()` or link to `https://apps.apple.com/account/subscriptions`)
- **Step 2 — Confirmation**: Show confirmation dialog explaining what will be deleted and that this is irreversible. Display estimated timeline: "Your account and all associated data will be permanently deleted within 24-48 hours."
- **Step 3 — Delete data**: Delete all Firestore documents (user doc, posts, comments, reactions), all Storage files (photos, thumbnails), and any reports filed by the user
- **Step 4 — Revoke Sign in with Apple token**: If user signed in with Apple, call the Sign in with Apple REST API to revoke the user's refresh token. This is a **hard rejection requirement**.
- **Step 5 — Delete Firebase Auth account**: Call `Auth.auth().currentUser?.delete()`
- **Step 6 — Confirm completion**: Show confirmation alert that deletion is complete
- **Step 7 — Fall back to local-only mode**: Clear auth state, return to unauthenticated app experience

### 1.5 Standardize School Selection
**Decision: Replace free-text school input with curated picker.**

#### Curated School List
- Hardcoded list of ~70 accredited US dental schools
- Searchable/scrollable picker UI
- "Other — request your school" option that submits a request (store in Firestore `schoolRequests` collection)
- "Other" users can use the app normally but cannot access social features until their school is added

#### Existing User Migration
- On next app launch after update, show a one-time sheet: "Select your school from the list"
- Pre-populate search with their current free-text value for convenience
- Required step — cannot dismiss without selecting

#### Onboarding Update
- Replace the free-text `dentalSchoolAffiliation` field in onboarding with the curated picker
- Store the standardized school name in both UserDefaults and Firestore

### 1.6 Link Onboarding Data
When a user signs in for the first time:
- Read existing UserDefaults profile (name, school, graduation year)
- Write to Firestore user document
- Keep UserDefaults as offline cache, Firestore as source of truth for social features

**Files to create:**
- `SimFolio/Services/AuthenticationService.swift`
- `SimFolio/Services/UserProfileService.swift`
- `SimFolio/Features/Auth/SignInView.swift`
- `SimFolio/Features/Auth/SignInWithAppleButton.swift`
- `SimFolio/Models/DentalSchool.swift` (curated school list and picker model)
- `SimFolio/Features/Auth/SchoolPickerView.swift` (searchable school selector)
- `SimFolio/Features/Auth/SchoolMigrationSheet.swift` (one-time migration prompt for existing users)

**Files to modify:**
- `SimFolio/Features/Profile/ProfileView.swift` (add sign-in prompt, account deletion)
- `SimFolio/Features/Profile/Settings/DataManagementView.swift` (account deletion)
- `SimFolio/App/AppState.swift` (add auth state)
- `SimFolio/Core/Navigation.swift` (add `.signIn` sheet type)
- `SimFolio/Features/Onboarding/` (replace free-text school field with curated picker)

---

## Phase 2: Photo Sharing Pipeline

### 2.1 SharedPost Model

```
Models/SharedPost.swift
```

```swift
struct SharedPost: Codable, Identifiable {
    let id: String                  // Firestore document ID
    let userId: String              // Author's Firebase Auth UID
    let authorName: String          // Denormalized for feed display
    let authorSchool: String        // Denormalized for filtering
    let imageURL: String            // Firebase Storage download URL
    let thumbnailURL: String        // Smaller version for feed
    let caption: String?
    let procedure: String           // From PhotoMetadata
    let stage: String?
    let angle: String?
    let toothNumber: Int?
    let createdAt: Date
    let reactionCounts: [String: Int]  // e.g., ["🔥": 3, "👏": 5]
    let commentCount: Int
    let isSimulation: Bool          // Must be true for Tier 1
}
```

### 2.2 PhotoSharingService

```
Services/PhotoSharingService.swift
```

- `sharePhoto(assetId:caption:)` — uploads photo to Storage, creates Firestore post doc
- `deletePost(postId:)` — removes Storage file and Firestore doc
- `getSchoolFeed(school:limit:afterDoc:)` — paginated feed query
- `getUserPosts(userId:)` — user's own shared posts
- Compress photo before upload (max 2048px, JPEG quality 0.8)
- Generate thumbnail (400px) for feed display
- Strip EXIF metadata before upload

### 2.3 Upload Flow
When user taps "Share to Class Feed" on a photo:
1. Confirm the photo is simulation work (checkbox/toggle)
2. Optional caption input
3. Compress + strip metadata
4. Upload to `users/{userId}/photos/{postId}.jpg`
5. Upload thumbnail to `users/{userId}/thumbnails/{postId}.jpg`
6. Create Firestore doc in `posts` collection
7. Show success confirmation

### 2.4 Post-Capture Share Prompt
When a user saves a photo from the capture flow, show a prompt asking if they want to share it to the feed.

**Behavior:**
- Only shown to authenticated users who have opted into social
- On dismiss ("Not now"), suppress the prompt for the rest of the current capture session
- Resets when the user leaves and re-enters the camera
- Tapping "Share" opens the standard share flow (simulation confirmation + optional caption)
- Track a `@State` flag in the capture view to manage per-session suppression

### 2.5 Share UI Integration
- Add "Share to Feed" button in photo detail view (only if authenticated + opted in)
- Add share toggle in Library view's action menu
- Show share status indicator on already-shared photos

**Firestore `posts` collection schema:**
```
posts/{postId}
  ├── userId: String
  ├── authorName: String
  ├── authorSchool: String
  ├── imageURL: String
  ├── thumbnailURL: String
  ├── caption: String?
  ├── procedure: String
  ├── stage: String?
  ├── angle: String?
  ├── toothNumber: Int?
  ├── createdAt: Timestamp
  ├── reactionCounts: Map
  ├── commentCount: Int
  ├── isSimulation: Bool
  ├── reportCount: Int
  └── isHidden: Bool (for moderation)
```

**Files to create:**
- `SimFolio/Models/SharedPost.swift`
- `SimFolio/Services/PhotoSharingService.swift`
- `SimFolio/Features/Social/SharePhotoSheet.swift`

**Files to modify:**
- `SimFolio/Features/Library/LibraryView.swift` (add share action)
- `SimFolio/Features/Capture/` (add post-capture share prompt with per-session suppression)

---

## Phase 3: Social Feed UI

### 3.1 Feed View

```
Features/Social/SocialFeedView.swift
```

- Scrollable feed of shared photos from same school
- Each card shows: thumbnail, author name, procedure tag, caption, reaction counts
- Pull-to-refresh
- Infinite scroll pagination (20 posts per page)
- Filter by procedure type
- Empty state for schools with no posts yet

### 3.2 Post Detail View

```
Features/Social/PostDetailView.swift
```

- Full-resolution photo with zoom
- Author info header
- Procedure/stage/angle/tooth tags
- Caption
- Reaction bar
- Comments section
- Report and block actions (in overflow menu)

### 3.3 Tab Integration
**Decision: New dedicated 5th tab.** Add a "Feed" tab to the tab bar. Requires:
- Add `.feed` case to `MainTab` enum in `Navigation.swift`
- Update `DPTabBar` to render 5 tabs
- Add `SocialFeedView` as the root view for the new tab

### 3.4 "New Posts" Indicator
**Decision: Pull-to-refresh + lightweight new-post banner.**
- Pull-to-refresh as the primary refresh mechanism
- Single Firestore listener on the latest post timestamp for the user's school
- When new posts exist since last load, show a "New posts" banner at the top of the feed
- Tapping the banner scrolls to top and reloads

### 3.5 Feed Card Component

```
Features/Social/Components/FeedPostCard.swift
```

- Thumbnail image (lazy loaded, cached)
- Author name + school badge
- Procedure color tag (reuse `AppTheme.procedureColor`)
- Timestamp (relative: "2h ago")
- Reaction summary + comment count
- Tap to open PostDetailView

**Files to create:**
- `SimFolio/Features/Social/SocialFeedView.swift`
- `SimFolio/Features/Social/PostDetailView.swift`
- `SimFolio/Features/Social/Components/FeedPostCard.swift`
- `SimFolio/Features/Social/Components/ReactionBar.swift`

**Files to modify:**
- `SimFolio/Core/Navigation.swift` (add `.feed` tab case, update `DPTabBar`, add social navigation routes)
- `SimFolio/App/ContentView.swift` (add Feed tab view)

---

## Phase 4: Comments & Reactions

### 4.1 Comment Model

```
Models/Comment.swift
```

```swift
struct Comment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let authorName: String
    let text: String
    let createdAt: Date
    let isHidden: Bool
}
```

### 4.2 Firestore Schema

```
posts/{postId}/comments/{commentId}
  ├── userId: String
  ├── authorName: String
  ├── text: String
  ├── createdAt: Timestamp
  └── isHidden: Bool

posts/{postId}/reactions/{userId}
  └── type: String  // emoji: "🔥", "👏", "💯", "🦷", "⭐"
```

### 4.3 SocialInteractionService

```
Services/SocialInteractionService.swift
```

- `addComment(postId:text:)` — write to subcollection, increment `commentCount`
- `deleteComment(postId:commentId:)` — only own comments
- `getComments(postId:limit:afterDoc:)` — paginated
- `toggleReaction(postId:type:)` — add/remove reaction, update `reactionCounts` map
- Use Firestore transactions for atomic count updates

### 4.4 Reaction Picker
- Fixed set of 5 reactions: 🔥 (great work), 👏 (impressive), 💯 (perfect), 🦷 (dental-specific), ⭐ (favorite)
- Tap to toggle, long-press to see who reacted
- Show aggregated counts on feed cards

### 4.5 Comments UI
- Comment list below photo in PostDetailView
- Text input bar at bottom (keyboard-aware)
- Swipe to delete own comments
- Report option on others' comments

**Files to create:**
- `SimFolio/Models/Comment.swift`
- `SimFolio/Services/SocialInteractionService.swift`
- `SimFolio/Features/Social/Components/CommentListView.swift`
- `SimFolio/Features/Social/Components/CommentInputBar.swift`
- `SimFolio/Features/Social/Components/ReactionPicker.swift`

---

## Phase 5: Content Moderation & Safety

This is **required by Apple App Store Guideline 1.2** before submission. All four requirements must be met or the app will be rejected:
1. Method for filtering objectionable material
2. Mechanism to report offensive content with timely responses
3. Ability to block abusive users
4. Published contact information reachable from within the app

### 5.1 Report System

```
Services/ModerationService.swift
```

- `reportPost(postId:reason:)` — creates report doc, increments `reportCount`
- `reportComment(commentId:reason:)` — same pattern
- `blockUser(userId:)` — adds to user's `blockedUserIds` array
- `unblockUser(userId:)`
- Report reasons: "Inappropriate content", "Real patient photo", "Age-inappropriate content", "Harassment", "Spam", "Other"
- Auto-hide posts with 3+ reports until reviewed
- **Response SLA**: All reports must be reviewed within 24 hours. Set up Firebase Cloud Messaging or email alerts to notify you when new reports are filed.

**Firestore `reports` collection:**
```
reports/{reportId}
  ├── reporterId: String
  ├── targetType: String ("post" | "comment" | "user")
  ├── targetId: String
  ├── reason: String
  ├── details: String?
  ├── createdAt: Timestamp
  └── status: String ("pending" | "reviewed" | "resolved")
```

### 5.2 Block System
- Blocked users' posts are filtered out of feed queries client-side
- Blocked users cannot see the blocker's posts (enforced via security rules)
- Block list stored in user's Firestore document

### 5.3 Report UI
- "Report" option in overflow menu on every post and comment
- "Block User" option on every user profile/post
- Confirmation dialogs for both actions
- Report reason picker sheet

### 5.4 Moderation Dashboard (Phase 2 / Future)
For Tier 1, manual review via Firebase Console. Future: build admin dashboard or use Firebase Extensions for automated moderation.

### 5.5 Content Filtering
- Block posts with `isSimulation: false` at the security rules level
- Client-side: require simulation confirmation checkbox before sharing
- **Text filtering**: Pre-publication profanity/slur filter on captions and comments (basic word list). Reject submission if filter triggers, with user-facing message.
- **Image moderation**: Integrate a moderation API (e.g., Firebase ML, Google Cloud Vision SafeSearch, or similar) via Cloud Function to screen uploaded photos before they appear in the feed. Flag/reject objectionable images. Apple reviewers will test by attempting to upload inappropriate content.

### 5.6 In-App Contact Information (Guideline 1.2 requirement)
- Add a visible "Contact Support" / "Report a Problem" link in Profile > Settings
- Display support email directly in the app UI (not just in the privacy policy)
- Also link from the social feed overflow menu for easy access when viewing content

**Files to create:**
- `SimFolio/Services/ModerationService.swift`
- `SimFolio/Services/ContentFilterService.swift` (text + image moderation)
- `SimFolio/Features/Social/ReportSheet.swift`
- `SimFolio/Features/Social/BlockConfirmationView.swift`

**Files to modify:**
- `SimFolio/Features/Profile/ProfileView.swift` or Settings (add "Contact Support" link with visible email)

---

## Phase 6: Opt-In/Opt-Out & Privacy

### 6.1 Social Sharing Settings
In Profile > Settings, add a "Social" section:
- **Social Feed toggle** — master opt-in/opt-out (default: off)
- **Auto-share toggle** — automatically share new photos to feed (default: off)
- **Visibility** — "My School Only" (Tier 1 only option)
- **Who can comment** — "Everyone" or "No one"

### 6.2 First-Time Social Prompt
When user first navigates to the feed or taps "Share":
1. Explain what sharing does
2. Confirm photos are simulation-only
3. Accept Terms of Service for social features
4. Require authentication if not signed in

### 6.3 Terms of Service / EULA (Guideline 1.2 + EULA requirements)
- Add social-specific ToS that users must accept before using social features
- **Required content:**
  - Zero-tolerance language for real patient photos
  - Prohibited content list (objectionable, harmful, illegal content)
  - Consequences for violations (account suspension/termination)
  - Content ownership and license grant (user retains ownership, grants SimFolio display license)
  - Indemnification clause
  - Statement that EULA is between the developer and end user, not Apple (Apple minimum EULA terms)
- Store acceptance timestamp in Firestore user doc

### 6.4 Privacy Policy Update (Guideline 5.1.1(i))
Update `Documentation/PRIVACY_POLICY.md` and `Documentation/privacy-policy.html` to cover:
- **Firebase Auth**: User accounts, email addresses, Sign in with Apple identifiers
- **Firebase Firestore**: User profiles, posts, comments, reactions, reports, block lists
- **Firebase Storage**: Photos and thumbnails uploaded by users
- **Data shared with classmates**: Display name, school affiliation, shared photos, comments, reactions
- **Data retention and deletion**: Explain that account deletion removes all Firestore docs, Storage files, and Auth credentials. Shared content is also deleted.
- **Third-party services**: Firebase Auth, Firestore, Storage (in addition to existing Analytics, Crashlytics, RevenueCat)
- **AI-based moderation disclosure**: If image moderation API is used, explicitly disclose that uploaded photos are screened by an automated service

### 6.5 Privacy Manifest Update (`PrivacyInfo.xcprivacy`)
Add the following collected data type declarations:

| Data Type | `NSPrivacyCollectedDataType` Value | Linked to Identity | Purpose |
|-----------|------------------------------------|--------------------|---------|
| User ID | `NSPrivacyCollectedDataTypeUserID` | Yes | App Functionality |
| Email Address | `NSPrivacyCollectedDataTypeEmailAddress` | Yes | App Functionality |
| Name (display name) | `NSPrivacyCollectedDataTypeName` | Yes | App Functionality |
| Photos or Videos | `NSPrivacyCollectedDataTypePhotosorVideos` | Yes | App Functionality |
| Other User Content | `NSPrivacyCollectedDataTypeOtherUserContent` | Yes | App Functionality |

### 6.6 App Store Connect Privacy Labels
Update the App Store Connect privacy declarations to match the privacy manifest. Declare all new data types with:
- Collection purpose: App Functionality
- Linked to identity: Yes
- Used for tracking: No

### 6.7 Age Rating Questionnaire (Guideline 2.3.6)
Update the age rating questionnaire in App Store Connect:
- Answer **"Yes"** to "User Generated Content" — this will likely raise the age rating from 4+ to 12+ or higher
- Review and confirm all other age rating answers still accurate

**Files to create:**
- `SimFolio/Features/Social/SocialOnboardingSheet.swift`
- `SimFolio/Features/Social/SocialSettingsView.swift`
- `Documentation/SocialTermsOfService.md`

**Files to modify:**
- `SimFolio/Features/Profile/ProfileView.swift` (add social settings link, add "Contact Support" link)
- `SimFolio/PrivacyInfo.xcprivacy`
- `Documentation/PRIVACY_POLICY.md`
- `Documentation/privacy-policy.html`

---

## Phase 7: Analytics Integration

### 7.1 New Analytics Events
Add to `AnalyticsEvent` enum:
- `socialOptIn`, `socialOptOut`
- `photoShared`, `photoUnshared`
- `feedViewed`, `postViewed`
- `commentAdded`, `commentDeleted`
- `reactionAdded`, `reactionRemoved`
- `userReported`, `postReported`, `commentReported`
- `userBlocked`, `userUnblocked`

### 7.2 New User Properties
Add to `AnalyticsUserProperty` enum:
- `socialEnabled` — whether social features are active
- `sharedPhotoCount` — number of photos shared
- `commentCount` — total comments made

**Files to modify:**
- `SimFolio/Services/AnalyticsService.swift`

---

## Phase 8: Feature Gating

**Decision: Social is free for all users.** No feature gating needed for Tier 1. All social features (viewing, posting, commenting, reacting) are available to any authenticated user. This maximizes adoption and network effect. Can be re-evaluated for monetization once the feed has traction.

No changes needed to `FeatureGateService.swift` for Tier 1.

---

## Phase 9: Testing

### 9.1 Unit Tests
- `AuthenticationServiceTests.swift` — sign in/out flows, state management
- `PhotoSharingServiceTests.swift` — upload, delete, feed queries
- `SocialInteractionServiceTests.swift` — comments, reactions
- `ModerationServiceTests.swift` — report, block

### 9.2 UI Tests
- `SocialFeedUITests.swift` — feed loading, scrolling, filtering
- `PostDetailUITests.swift` — reactions, comments, reporting
- `SocialOnboardingUITests.swift` — opt-in flow, ToS acceptance

### 9.3 Test Data
- Add `--with-social-data` launch argument for UI testing with mock feed data
- Firebase Emulator Suite for local Firestore/Auth/Storage testing

**Files to create:**
- `SimFolioTests/AuthenticationServiceTests.swift`
- `SimFolioTests/PhotoSharingServiceTests.swift`
- `SimFolioTests/SocialInteractionServiceTests.swift`
- `SimFolioTests/ModerationServiceTests.swift`
- `SimFolioUITests/SocialFeedUITests.swift`
- `SimFolioTests/ContentFilterServiceTests.swift`

---

## Phase 10: App Store Submission Preparation

### 10.1 Demo Account for App Review
- Create a test account with credentials Apple's reviewer can use
- Pre-populate the account's school feed with sample posts, comments, and reactions
- Include credentials in the App Review Notes field in App Store Connect
- Ensure the demo account can exercise all social features: view feed, post, comment, react, report, block

### 10.2 App Review Notes
Include in the review notes:
- Demo account credentials
- Explanation that the social feed is school-scoped (reviewer will only see posts from the demo school)
- How to test moderation features (report, block)
- Note that content is simulation dental work only (mannequins/typodonts), not real patients

### 10.3 Pre-Submission Checklist
- [ ] Privacy policy updated and accessible in-app and on the web
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) declares all collected data types
- [ ] App Store Connect privacy labels match privacy manifest
- [ ] Age rating questionnaire updated (UGC = Yes)
- [ ] Terms of Service written and presented to users before social access
- [ ] In-app contact information visible in Settings
- [ ] Account deletion flow handles Sign in with Apple token revocation
- [ ] Account deletion flow handles active subscription warning
- [ ] Report system functional with all required reason options
- [ ] Block system functional
- [ ] Content filtering active (text + image)
- [ ] Demo account created and seeded with test data
- [ ] All social features tested on physical device

---

## Implementation Order

| Priority | Phase | Dependency | Estimated Scope |
|----------|-------|------------|-----------------|
| 1 | Phase 0: Firebase Infrastructure | None | Backend setup |
| 2 | Phase 1: Authentication | Phase 0 | Auth + accounts + school picker + deletion compliance |
| 3 | Phase 2: Photo Sharing Pipeline | Phase 1 | Upload + Firestore + post-capture prompt |
| 4 | Phase 3: Social Feed UI + 5th Tab | Phase 2 | Feed tab + views + new-post indicator |
| 5 | Phase 4: Comments & Reactions | Phase 3 | Interaction layer |
| 6 | Phase 5: Content Moderation | Phase 3 | Report + block + auto-hide + content filtering + in-app contact |
| 7 | Phase 6: Opt-In, Privacy & Compliance | Phase 1 | Settings + ToS/EULA + privacy policy + privacy manifest + age rating |
| 8 | Phase 7: Analytics | Any | Event tracking |
| 9 | Phase 8: Feature Gating | N/A | **No work needed** — social is free for all |
| 10 | Phase 9: Testing | All | Test coverage |
| 11 | Phase 10: App Store Submission Prep | All | Demo account + review notes + pre-submission checklist |

Phases 5, 6, and 10 are **required before App Store submission** with social features.

---

## New File Summary

```
SimFolio/
├── Features/
│   ├── Auth/
│   │   ├── SignInView.swift
│   │   ├── SignInWithAppleButton.swift
│   │   ├── SchoolPickerView.swift
│   │   └── SchoolMigrationSheet.swift
│   └── Social/
│       ├── SocialFeedView.swift
│       ├── PostDetailView.swift
│       ├── SharePhotoSheet.swift
│       ├── SocialOnboardingSheet.swift
│       ├── SocialSettingsView.swift
│       ├── ReportSheet.swift
│       ├── BlockConfirmationView.swift
│       └── Components/
│           ├── FeedPostCard.swift
│           ├── ReactionBar.swift
│           ├── ReactionPicker.swift
│           ├── CommentListView.swift
│           └── CommentInputBar.swift
├── Models/
│   ├── SharedPost.swift
│   ├── Comment.swift
│   └── DentalSchool.swift
├── Services/
│   ├── AuthenticationService.swift
│   ├── UserProfileService.swift
│   ├── PhotoSharingService.swift
│   ├── SocialInteractionService.swift
│   ├── ModerationService.swift
│   └── ContentFilterService.swift
Config/
├── firestore.rules
└── storage.rules
Documentation/
├── SocialTermsOfService.md
└── SocialFeaturePlan.md (this file)
```

---

## Decisions (Finalized)

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Social as free or premium? | **Free for all** | Maximize adoption and network effect. A gated feed can't reach critical mass. Can re-monetize later. |
| 2 | Feed scope | **School-only** | Core value is sharing with classmates in the same lab/curriculum. Cross-school can be added later by loosening the Firestore query filter. |
| 3 | Tab placement | **New 5th "Feed" tab** | Home tab is already occupied (slideshow, stats, portfolio navigator). Feed needs a first-class entry point for discoverability and engagement. |
| 4 | Auto-share default | **Off — manual share per photo** | Students are deliberate about which work they show. Manual sharing keeps feed quality high and avoids accidental posts. |
| 5 | Moderation approach | **Hybrid: auto-hide at 3 reports + manual review in Firebase Console** | Auto-hide handles urgent cases and satisfies App Store guideline 1.2. Manual review for final decisions. Add Cloud Functions automation when volume grows. |
| 6 | Real-time updates | **Pull-to-refresh + "New posts" indicator banner** | A school-scoped feed won't have high volume. A single Firestore listener on the latest post timestamp powers a lightweight banner without the cost of full real-time listeners. |
| 7 | School selection | **Curated list (~70 US dental schools) + "Other" request option** | Free-text school names would create duplicate feed silos ("UCSF" vs "UC San Francisco"). Curated list guarantees consistency. "Other" lets international/new schools request addition. Existing users prompted to re-select on next launch. |
