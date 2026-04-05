# Social Feature — Manual Steps Checklist

These steps cannot be automated and require human action in external systems. Complete all before submitting the social feature update to the App Store.

**Branch:** `feature/social-feed`

---

## Firebase Console (https://console.firebase.google.com)

- [ ] **1. Enable Authentication Providers**
  - Go to Authentication > Sign-in method
  - Enable **Sign in with Apple**
    - Requires Apple Developer configuration first (see step 6)
  - Enable **Email/Password**

- [ ] **2. Deploy Firestore Security Rules**
  - Go to Firestore Database > Rules
  - Copy contents of `Config/firestore.rules` and paste into the editor
  - Click "Publish"

- [ ] **3. Deploy Storage Security Rules**
  - Go to Storage > Rules
  - Copy contents of `Config/storage.rules` and paste into the editor
  - Click "Publish"

- [ ] **4. Create Firestore Indexes**
  - Go to Firestore Database > Indexes > Composite
  - Create index #1:
    - Collection: `posts`
    - Fields: `authorSchool` Ascending, `isHidden` Ascending, `createdAt` Descending
    - Query scope: Collection
  - Create index #2:
    - Collection: `posts`
    - Fields: `userId` Ascending, `createdAt` Descending
    - Query scope: Collection
  - Wait for indexes to finish building (can take a few minutes)

- [ ] **5. Set Up Report Alerts**
  - Option A: Use Firebase Extensions > "Send Email" triggered on new docs in `reports` collection
  - Option B: Manually check the `reports` collection in Firebase Console daily
  - Goal: Be notified within 24 hours when content is reported (App Store compliance)

---

## Apple Developer Portal (https://developer.apple.com)

- [ ] **6. Configure Sign in with Apple**
  - Go to Certificates, Identifiers & Profiles > Identifiers
  - Select your App ID (`com.joshuachung.simfolio`)
  - Enable "Sign in with Apple" capability
  - Click Configure:
    - Primary App ID: `com.joshuachung.simfolio`
    - If using a web-based redirect (Firebase default), create a Services ID:
      - Register a new Services ID (e.g., `com.joshuachung.simfolio.auth`)
      - Enable Sign in with Apple
      - Configure domains: add your Firebase Auth domain (`simfolio-XXXXX.firebaseapp.com`)
      - Add return URL: `https://simfolio-XXXXX.firebaseapp.com/__/auth/handler`
      - (Replace XXXXX with your actual Firebase project ID)

- [ ] **7. Update Provisioning Profile**
  - Regenerate provisioning profiles after enabling the capability
  - Download and install the updated profile in Xcode

---

## Xcode

- [ ] **8. Add Sign in with Apple Capability**
  - Open SimFolio.xcodeproj
  - Select the SimFolio target > Signing & Capabilities
  - Click "+ Capability" > search "Sign in with Apple" > add it
  - This adds the entitlement to your app

- [ ] **9. Build the Project**
  - Clean build folder (Cmd+Shift+K)
  - Build (Cmd+B)
  - All SourceKit "Cannot find" errors should resolve after the first successful build
  - Fix any remaining compile errors
  - Test on simulator: verify all 5 tabs appear, Feed tab shows sign-in prompt

---

## App Store Connect (https://appstoreconnect.apple.com)

- [ ] **10. Update Age Rating Questionnaire**
  - Go to your app > App Information > Age Rating
  - Answer **"Yes"** to: "Does your app contain user-generated content?"
  - Review all other questions — answers may need updating
  - Save — age rating will likely increase to 12+ or higher

- [ ] **11. Update App Privacy Labels**
  - Go to your app > App Privacy
  - Add new data types collected:
    - **Contact Info > Email Address** — linked to identity, App Functionality, not tracking
    - **Contact Info > Name** — linked to identity, App Functionality, not tracking
    - **Identifiers > User ID** — linked to identity, App Functionality, not tracking
    - **User Content > Photos or Videos** — linked to identity, App Functionality, not tracking
    - **User Content > Other User Content** — linked to identity, App Functionality, not tracking
  - Keep existing declarations (Usage Data, Diagnostics, etc.)
  - Save and submit

- [ ] **12. Create Demo Account for App Review**
  - In the live Firebase project:
    - Create a test user via Firebase Console > Authentication > Add User
    - Email: `appreview@simfolio-test.com` (or similar)
    - Password: use a strong password, note it down
  - Create a Firestore user document in `users` collection with the test user's UID:
    ```json
    {
      "userId": "<uid>",
      "displayName": "App Review Tester",
      "school": "University of California San Francisco School of Dentistry",
      "schoolId": "ucsf",
      "graduationYear": 2027,
      "createdAt": "<timestamp>",
      "socialOptIn": true,
      "blockedUserIds": [],
      "isActive": true,
      "tosAcceptedAt": "<timestamp>",
      "commentSetting": "everyone"
    }
    ```

- [ ] **13. Add Demo Credentials to App Review Notes**
  - Go to your app version > App Review Information
  - Sign-in required: Yes
  - Demo Account:
    - Username: `appreview@simfolio-test.com`
    - Password: `<your password>`
  - Notes for reviewer:
    ```
    Social Feed: The "Feed" tab shows a school-scoped social feed.
    The demo account is set to UCSF. You will see sample posts
    from other UCSF accounts in the feed.

    To test moderation: tap the "..." menu on any post to see
    Report and Block options.

    Content is simulation dental work only (mannequins/typodonts),
    not real patients.
    ```

---

## Content Seeding

- [ ] **14. Seed Demo School Feed**
  - Create 2-3 additional test accounts at the same school (UCSF)
  - Using each account, share 2-4 simulation photos to the feed with:
    - Various procedures (Class 1, Class 2, Crown)
    - Captions on some posts
    - Comments between the accounts
    - Some reactions on posts
  - This ensures the App Review tester sees a populated feed
  - Can be done via the app on a test device or by writing directly to Firestore

- [ ] **15. Review Terms of Service**
  - File: `Documentation/SocialTermsOfService.md`
  - Review with legal counsel if available
  - Ensure zero-tolerance language for real patient photos is clear
  - Ensure HIPAA reference is appropriate for your context
  - The ToS is displayed in-app via `SocialOnboardingSheet` — users must accept before using social features

---

## Post-Launch Monitoring

- [ ] **16. Set Up Daily Report Review Routine**
  - Check Firebase Console > Firestore > `reports` collection daily
  - Review flagged content and take action:
    - If legitimate violation: delete the post/comment, consider suspending user
    - If false report: mark as `resolved`, no action needed
  - Auto-hidden posts (3+ reports) are in `posts` where `isHidden == true`
  - Response SLA: 24 hours (per App Store commitment)

- [ ] **17. Monitor Crashlytics**
  - Watch for new crash clusters related to social features
  - Key areas: photo upload, Firestore queries, auth flows
  - Firebase Console > Crashlytics
