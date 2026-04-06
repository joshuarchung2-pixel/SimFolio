// OnboardingView.swift
// SimFolio - Onboarding Flow
//
// This file contains the onboarding experience for new users.
// A 9-page flow with visual-rich screens, personalization, and permission requests.
//
// Contents:
// - OnboardingPageType: Enum for different page types
// - OnboardingView: Main onboarding container
// - Individual page view components

import SwiftUI
import Photos
import AVFoundation
import UserNotifications

// MARK: - Layout Constants

/// Shared layout constants for onboarding UI components
enum OnboardingLayout {
    // Visual page layout
    static let visualAreaHeight: CGFloat = 320
    static let appIconSize: CGFloat = 80
    static let appIconCornerRadius: CGFloat = 18

    // Mockup dimensions
    static let phoneMockupWidth: CGFloat = 240
    static let phoneMockupHeight: CGFloat = 360
    static let phoneMockupCornerRadius: CGFloat = 32

    // Progress card
    static let progressCardWidth: CGFloat = 280
    static let progressCircleSize: CGFloat = 60

    // Personalization
    static let yearButtonSize: CGFloat = 72

    // Legacy (for permission pages)
    static let iconOuterSize: CGFloat = 100
    static let iconInnerSize: CGFloat = 70
    static let iconFontSize: CGFloat = 32
    static let featureIconSize: CGFloat = 36
    static let featureIconFontSize: CGFloat = 14
    static let selectionIndicatorSize: CGFloat = 22
    static let selectionIndicatorInner: CGFloat = 12
}

// MARK: - Models

/// Types of onboarding pages
enum OnboardingPageType: Equatable {
    case welcome
    case smartCapture
    case requirementsTrack
    case photoEditing
    case exportReady
    case personalization
    case permission(PermissionType)
}

/// Model representing a single onboarding page
struct OnboardingPage: Identifiable {
    let id = UUID()
    let pageType: OnboardingPageType
    let title: String
    let subtitle: String

    // Legacy properties for permission/premium pages
    let icon: String
    let iconColor: Color
    let features: [OnboardingFeature]

    init(
        pageType: OnboardingPageType,
        title: String,
        subtitle: String,
        icon: String = "",
        iconColor: Color = .blue,
        features: [OnboardingFeature] = []
    ) {
        self.pageType = pageType
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.features = features
    }

    var isPermissionPage: Bool {
        if case .permission = pageType { return true }
        return false
    }

    var permissionType: PermissionType? {
        if case .permission(let type) = pageType { return type }
        return nil
    }
}

/// Model representing a feature item in the onboarding list
struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

/// Permission types that can be requested during onboarding
enum PermissionType {
    case camera
    case photos
    case notifications
}

// MARK: - OnboardingView

/// Main onboarding container view
/// Presents a 9-page onboarding experience for new users
struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    // MARK: - State

    @State private var currentPage: Int = 0
    @State private var cameraPermissionGranted: Bool = false
    @State private var photosPermissionGranted: Bool = false
    @State private var notificationsPermissionGranted: Bool = false
    @State private var isKeyboardVisible: Bool = false

    // User profile state
    @State private var userProfile = UserOnboardingProfile()

    // Analytics tracking
    @State private var onboardingStartTime: Date = Date()

    // MARK: - Pages

    let pages: [OnboardingPage] = [
        // Page 1: Welcome
        OnboardingPage(
            pageType: .welcome,
            title: "Your Clinical Portfolio,\nOrganized",
            subtitle: "Capture, tag, and track your dental procedure photos with ease."
        ),

        // Page 2: Smart Capture
        OnboardingPage(
            pageType: .smartCapture,
            title: "Capture With Context",
            subtitle: "Tag photos before you shoot—procedure, stage, angle, and tooth number all in one tap."
        ),

        // Page 3: Requirements Tracking
        OnboardingPage(
            pageType: .requirementsTrack,
            title: "Never Miss a Requirement",
            subtitle: "Visual checklists show exactly what photos you still need for each portfolio."
        ),

        // Page 4: Photo Editing
        OnboardingPage(
            pageType: .photoEditing,
            title: "Perfect Every Shot",
            subtitle: "Crop, rotate, and adjust brightness, contrast, and more—right in the app."
        ),

        // Page 5: Export Ready
        OnboardingPage(
            pageType: .exportReady,
            title: "Submit in Seconds",
            subtitle: "Export your portfolio as a ZIP or share individual photos—organized and ready to go."
        ),

        // Page 6: Personalization
        OnboardingPage(
            pageType: .personalization,
            title: "Let's personalize\nyour experience",
            subtitle: "Tell us about yourself to customize SimFolio for you."
        ),

        // Page 7: Camera Permission
        OnboardingPage(
            pageType: .permission(.camera),
            title: "Camera Access",
            subtitle: "We need camera access to capture your clinical photos.",
            icon: "camera.fill",
            iconColor: .blue
        ),

        // Page 8: Photos Permission
        OnboardingPage(
            pageType: .permission(.photos),
            title: "Photo Library",
            subtitle: "Access your photo library to organize and view your captures.",
            icon: "photo.fill.on.rectangle.fill",
            iconColor: .purple
        ),

        // Page 9: Notifications Permission
        OnboardingPage(
            pageType: .permission(.notifications),
            title: "Stay on Track",
            subtitle: "Get reminders about upcoming deadlines and portfolio milestones.",
            icon: "bell.fill",
            iconColor: .red
        )
    ]

    // MARK: - Computed Properties

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    var canProceed: Bool {
        guard currentPage >= 0, currentPage < pages.count else {
            return false
        }
        let page = pages[currentPage]

        switch page.pageType {
        case .welcome, .smartCapture, .requirementsTrack, .photoEditing, .exportReady:
            return true
        case .personalization:
            // All personalization fields are required
            return !userProfile.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !userProfile.dentalSchoolAffiliation.trimmingCharacters(in: .whitespaces).isEmpty &&
                   userProfile.graduationYear != nil
        case .permission:
            // Permission pages always allow proceeding via the bottom Continue button.
            // The permission request or auto-advance handles the flow.
            return true
        }
    }

    /// Maximum page the user can navigate to based on required selections
    var maxAllowedPage: Int {
        for i in 0..<pages.count {
            let page = pages[i]
            if case .personalization = page.pageType {
                if userProfile.displayName.trimmingCharacters(in: .whitespaces).isEmpty ||
                   userProfile.dentalSchoolAffiliation.trimmingCharacters(in: .whitespaces).isEmpty ||
                   userProfile.graduationYear == nil {
                    return i
                }
            }
        }
        return pages.count - 1
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(
                            page: page,
                            pageIndex: index,
                            currentPage: currentPage,
                            userProfile: $userProfile,
                            cameraGranted: $cameraPermissionGranted,
                            photosGranted: $photosPermissionGranted,
                            notificationsGranted: $notificationsPermissionGranted,
                            onContinue: page.isPermissionPage ? { nextPage() } : nil
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .onChange(of: currentPage) { newValue in
                    // Prevent swiping past pages that require interaction
                    if newValue > maxAllowedPage {
                        withAnimation {
                            currentPage = maxAllowedPage
                        }
                    }
                }

                // Spacer to account for bottom controls overlay (hidden when keyboard visible)
                if !isKeyboardVisible {
                    Spacer()
                        .frame(height: 120)
                }
            }

            // Bottom controls - hidden when keyboard is visible
            if !isKeyboardVisible {
                VStack {
                    Spacer()

                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Page indicators (pill style)
                        HStack(spacing: AppTheme.Spacing.xs) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentPage ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.3))
                                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                            }
                        }

                        // Action button
                        DPButton(
                            isLastPage ? "Get Started" : "Continue",
                            icon: isLastPage ? "checkmark" : "arrow.right",
                            style: .primary,
                            size: .large,
                            isFullWidth: true,
                            isDisabled: !canProceed
                        ) {
                            if isLastPage {
                                completeOnboarding()
                            } else {
                                nextPage()
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                    .padding(.bottom, AppTheme.Spacing.xl)
                    .background(AppTheme.Colors.background)
                }
            }
        }
        .onAppear {
            checkExistingPermissions()
            onboardingStartTime = Date()
            AnalyticsService.logEvent(.onboardingStarted)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    // MARK: - Actions

    /// Advance to the next page
    func nextPage() {
        guard currentPage < pages.count - 1 else {
            // On last page, complete onboarding instead
            completeOnboarding()
            return
        }

        // Dismiss keyboard before navigation
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )

        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }

    /// Complete onboarding and dismiss
    func completeOnboarding() {
        // Save user profile data
        saveUserProfile()

        // Log analytics
        let durationSeconds = Int(Date().timeIntervalSince(onboardingStartTime))
        AnalyticsService.logOnboardingCompleted(
            durationSeconds: durationSeconds,
            schoolSelected: !userProfile.dentalSchoolAffiliation.isEmpty
        )

        // Set user properties for analytics
        if !userProfile.dentalSchoolAffiliation.isEmpty {
            AnalyticsService.setUserProperty(userProfile.dentalSchoolAffiliation, for: .schoolName)
        }
        if let year = userProfile.graduationYear {
            AnalyticsService.setUserProperty(String(year), for: .graduationYear)
        }

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(Date(), forKey: "userCreatedDate")
        onComplete()
        isPresented = false
    }

    /// Save user profile to UserDefaults
    func saveUserProfile() {
        UserDefaults.standard.set(userProfile.displayName, forKey: "userName")
        UserDefaults.standard.set(userProfile.dentalSchoolAffiliation, forKey: "userSchool")

        if let year = userProfile.graduationYear {
            UserDefaults.standard.set(year, forKey: "userGraduationYear")
        }
    }

    /// Check existing permission status when view appears
    func checkExistingPermissions() {
        // Check camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        default:
            cameraPermissionGranted = false
        }

        // Check photos
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            photosPermissionGranted = true
        default:
            photosPermissionGranted = false
        }

        // Check notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
}

// MARK: - OnboardingPageView

/// Individual page content view - routes to appropriate page type
struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int
    @Binding var userProfile: UserOnboardingProfile
    @Binding var cameraGranted: Bool
    @Binding var photosGranted: Bool
    @Binding var notificationsGranted: Bool
    var onContinue: (() -> Void)?

    var body: some View {
        switch page.pageType {
        case .welcome:
            OnboardingWelcomePageView(page: page)
        case .smartCapture:
            OnboardingSmartCapturePageView(page: page)
        case .requirementsTrack:
            OnboardingRequirementsPageView(page: page)
        case .photoEditing:
            OnboardingPhotoEditingPageView(page: page)
        case .exportReady:
            OnboardingExportPageView(page: page)
        case .personalization:
            OnboardingPersonalizationPageView(page: page, userProfile: $userProfile)
        case .permission:
            OnboardingPermissionPageView(
                page: page,
                cameraGranted: $cameraGranted,
                photosGranted: $photosGranted,
                notificationsGranted: $notificationsGranted,
                onContinue: onContinue
            )
        }
    }
}

// MARK: - Welcome Page

/// Welcome page with hero visual and app icon
struct OnboardingWelcomePageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Hero visual area
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
                    .fill(AppTheme.Colors.surface)
                    .frame(height: OnboardingLayout.visualAreaHeight)

                VStack(spacing: AppTheme.Spacing.lg) {
                    // App icon
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: OnboardingLayout.appIconSize, height: OnboardingLayout.appIconSize)
                        .clipShape(RoundedRectangle(cornerRadius: OnboardingLayout.appIconCornerRadius))

                    // Decorative elements
                    HStack(spacing: AppTheme.Spacing.md) {
                        ForEach(["camera.fill", "photo.stack.fill", "folder.fill"], id: \.self) { icon in
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                )
                                .shadowSmall()
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Smart Capture Page

/// Smart capture page with camera mockup and tagging UI
struct OnboardingSmartCapturePageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Smart capture screenshot
            Image("OnboardingSmartCapture")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: OnboardingLayout.phoneMockupHeight)
                .clipShape(RoundedRectangle(cornerRadius: OnboardingLayout.phoneMockupCornerRadius))
                .shadowMedium()

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Requirements Page

/// Requirements tracking page with progress card UI
struct OnboardingRequirementsPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Progress card mockup
            VStack(spacing: AppTheme.Spacing.md) {
                // Card
                VStack(spacing: AppTheme.Spacing.md) {
                    // Header with progress circle
                    HStack(spacing: AppTheme.Spacing.md) {
                        // Progress circle
                        ZStack {
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 4)
                                .frame(width: OnboardingLayout.progressCircleSize, height: OnboardingLayout.progressCircleSize)

                            Circle()
                                .trim(from: 0, to: 0.65)
                                .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: OnboardingLayout.progressCircleSize, height: OnboardingLayout.progressCircleSize)
                                .rotationEffect(.degrees(-90))

                            Text("65%")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fall 2024 Portfolio")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("13 of 20 requirements")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        Spacer()
                    }

                    // Checklist items
                    VStack(spacing: AppTheme.Spacing.xs) {
                        ChecklistItem(text: "Class 1 - Preparation - Occlusal", isComplete: true)
                        ChecklistItem(text: "Class 1 - Final - Occlusal", isComplete: true)
                        ChecklistItem(text: "Class 2 - Preparation - Buccal", isComplete: false)
                        ChecklistItem(text: "Crown - Matrix - Facial", isComplete: false)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.large)
                .shadowMedium()
            }
            .frame(width: OnboardingLayout.progressCardWidth)

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

/// Checklist item component
struct ChecklistItem: View {
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isComplete ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                .strikethrough(isComplete, color: AppTheme.Colors.textTertiary)

            Spacer()
        }
    }
}

// MARK: - Photo Editing Page

/// Photo editing page with editor mockup
struct OnboardingPhotoEditingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Photo editing screenshot
            Image("OnboardingPhotoEditing")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: OnboardingLayout.phoneMockupHeight)
                .clipShape(RoundedRectangle(cornerRadius: OnboardingLayout.phoneMockupCornerRadius))
                .shadowMedium()

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Export Page

/// Export page with file/folder illustration
struct OnboardingExportPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Export illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(AppTheme.Colors.success.opacity(0.1))
                    .frame(width: 200, height: 200)

                // Floating files/folders
                Group {
                    // Folder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.warning)
                            .frame(width: 80, height: 60)

                        Image(systemName: "folder.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .offset(x: -40, y: -20)
                    .rotationEffect(.degrees(-8))

                    // ZIP file
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 70, height: 50)

                        VStack(spacing: 2) {
                            Image(systemName: "doc.zipper")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                            Text(".ZIP")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .offset(x: 45, y: 10)
                    .rotationEffect(.degrees(6))

                    // Upload indicator
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 0, y: -60)
                }
                .shadowMedium()
            }
            .frame(height: OnboardingLayout.visualAreaHeight - 40)

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Personalization Page

/// Personalization page with name input, school input, and graduation year selection
struct OnboardingPersonalizationPageView: View {
    let page: OnboardingPage
    @Binding var userProfile: UserOnboardingProfile

    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isSchoolFieldFocused: Bool
    @State private var showSchoolPicker = false
    @State private var selectedSchoolId: String = ""

    // Graduation years (cached to avoid recomputation on layout passes)
    @State private var graduationYears: [Int] = {
        let year = Calendar.current.component(.year, from: Date())
        return Array(year...(year + 8))
    }()

    var body: some View {
        ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    Spacer(minLength: AppTheme.Spacing.lg)

                    // Header
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }

                        Text(page.title)
                            .font(AppTheme.Typography.title)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(page.subtitle)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Form fields
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Name field
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            HStack(spacing: 2) {
                                Text("Your Name")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Text("*")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }

                            TextField("Enter your name", text: $userProfile.displayName)
                                .font(AppTheme.Typography.body)
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .cornerRadius(AppTheme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .stroke(isNameFieldFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: isNameFieldFocused ? 2 : 1)
                                )
                                .focused($isNameFieldFocused)
                                .submitLabel(.next)
                                .onSubmit { isSchoolFieldFocused = true }
                        }
                        .id("nameField")

                        // School field
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            HStack(spacing: 2) {
                                Text("Dental School")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Text("*")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                isNameFieldFocused = false
                                showSchoolPicker = true
                            } label: {
                                HStack {
                                    Text(userProfile.dentalSchoolAffiliation.isEmpty
                                         ? "Select your school"
                                         : userProfile.dentalSchoolAffiliation)
                                        .font(AppTheme.Typography.body)
                                        .foregroundColor(userProfile.dentalSchoolAffiliation.isEmpty
                                                         ? AppTheme.Colors.textTertiary
                                                         : AppTheme.Colors.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .cornerRadius(AppTheme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                                )
                            }
                        }
                        .id("schoolField")
                        .sheet(isPresented: $showSchoolPicker) {
                            NavigationView {
                                SchoolPickerView { school in
                                    userProfile.dentalSchoolAffiliation = school.name
                                    selectedSchoolId = school.id
                                    showSchoolPicker = false
                                }
                                .navigationTitle("Select School")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button("Cancel") {
                                            showSchoolPicker = false
                                        }
                                    }
                                }
                            }
                        }

                        // Graduation year wheel picker
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            HStack(spacing: 2) {
                                Text("Expected Graduation Year")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Text("*")
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }

                            Picker("Graduation Year", selection: Binding(
                                get: { userProfile.graduationYear ?? graduationYears[0] },
                                set: { userProfile.graduationYear = $0 }
                            )) {
                                ForEach(graduationYears, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 150)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    Spacer(minLength: 140)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                // Set default graduation year so the picker's displayed value
                // matches the model — otherwise graduationYear stays nil and
                // the Continue button remains disabled.
                if userProfile.graduationYear == nil {
                    userProfile.graduationYear = graduationYears[0]
                }
            }
    }
}

// MARK: - Permission Page

/// Permission request page
struct OnboardingPermissionPageView: View {
    let page: OnboardingPage
    @Binding var cameraGranted: Bool
    @Binding var photosGranted: Bool
    @Binding var notificationsGranted: Bool
    var onContinue: (() -> Void)?

    @State private var showPermissionDeniedAlert = false
    @State private var animateGranted: Bool = false

    var isPermissionGranted: Bool {
        switch page.permissionType {
        case .camera:
            return cameraGranted
        case .photos:
            return photosGranted
        case .notifications:
            return notificationsGranted
        case .none:
            return true
        }
    }

    var permissionIcon: String {
        switch page.permissionType {
        case .camera:
            return "camera.fill"
        case .photos:
            return "photo.fill"
        case .notifications:
            return "bell.fill"
        case .none:
            return "checkmark"
        }
    }

    var permissionButtonText: String {
        return "Continue"
    }

    var privacyNote: String {
        switch page.permissionType {
        case .camera:
            return "Your photos are stored only on your device and never uploaded to any server."
        case .photos:
            return "We only access photos you've taken with this app. Your other photos remain private."
        case .notifications:
            return "We'll only send you helpful reminders about upcoming due dates."
        case .none:
            return ""
        }
    }

    var permissionDeniedMessage: String {
        switch page.permissionType {
        case .camera:
            return "Camera access was previously denied. Please enable it in Settings to capture photos."
        case .photos:
            return "Photo library access was previously denied. Please enable it in Settings to view your photos."
        case .notifications:
            return "Notifications were previously denied. Please enable them in Settings to receive reminders."
        case .none:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.sm)

            // Icon with pulse/glow animation when permission granted
            ZStack {
                // Outer glow circle (animated)
                Circle()
                    .fill(page.iconColor.opacity(animateGranted ? 0.3 : 0.1))
                    .frame(width: OnboardingLayout.iconOuterSize, height: OnboardingLayout.iconOuterSize)
                    .scaleEffect(animateGranted ? 1.15 : 1.0)

                // Inner circle
                Circle()
                    .fill(page.iconColor)
                    .frame(width: OnboardingLayout.iconInnerSize, height: OnboardingLayout.iconInnerSize)
                    .scaleEffect(animateGranted ? 1.1 : 1.0)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: OnboardingLayout.iconFontSize))
                    .foregroundStyle(.white)
                    .scaleEffect(animateGranted ? 1.1 : 1.0)
            }
            .animation(.easeInOut(duration: 0.4).repeatCount(2, autoreverses: true), value: animateGranted)

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Permission button
            VStack(spacing: AppTheme.Spacing.md) {
                if isPermissionGranted {
                    // Granted state
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.Colors.success)

                        Text("Permission Granted")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.success.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.medium)
                } else {
                    // Request permission button
                    Button(action: requestPermission) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: permissionIcon)
                                .font(.system(size: 18))

                            Text(permissionButtonText)
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                        .background(page.iconColor)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }

                // Privacy note
                Text(privacyNote)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }

            Spacer()
            Spacer()
        }
        .alert("Permission Required", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                onContinue?()
            }
            Button("Not Now", role: .cancel) {
                onContinue?()
            }
        } message: {
            Text(permissionDeniedMessage)
        }
        .onChange(of: isPermissionGranted) { granted in
            if granted {
                animateGranted = true
                // Reset after animation completes (2 cycles of 0.4s each = 1.6s, add buffer)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation {
                        animateGranted = false
                    }
                }
            }
        }
    }

    func requestPermission() {
        switch page.permissionType {
        case .camera:
            requestCameraPermission()
        case .photos:
            requestPhotosPermission()
        case .notifications:
            requestNotificationsPermission()
        case .none:
            break
        }
    }

    func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraGranted = granted
                    onContinue?()
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert = true
        case .authorized:
            cameraGranted = true
            onContinue?()
        @unknown default:
            break
        }
    }

    func requestPhotosPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    photosGranted = newStatus == .authorized || newStatus == .limited
                    onContinue?()
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert = true
        case .authorized, .limited:
            photosGranted = true
            onContinue?()
        @unknown default:
            break
        }
    }

    func requestNotificationsPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            notificationsGranted = granted
                            onContinue?()
                        }
                    }
                case .denied:
                    showPermissionDeniedAlert = true
                case .authorized, .provisional, .ephemeral:
                    notificationsGranted = true
                    onContinue?()
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true)) {
            print("Onboarding completed")
        }
    }
}

struct OnboardingWelcomePageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomePageView(
            page: OnboardingPage(
                pageType: .welcome,
                title: "Your Clinical Portfolio,\nOrganized",
                subtitle: "Capture, tag, and track your dental procedure photos with ease."
            )
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Welcome Page")
    }
}

struct OnboardingSmartCapturePageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSmartCapturePageView(
            page: OnboardingPage(
                pageType: .smartCapture,
                title: "Capture With Context",
                subtitle: "Tag photos before you shoot—procedure, stage, angle, and tooth number all in one tap."
            )
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Smart Capture Page")
    }
}

struct OnboardingPersonalizationPageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPersonalizationPageView(
            page: OnboardingPage(
                pageType: .personalization,
                title: "Let's personalize\nyour experience",
                subtitle: "Tell us about yourself to customize SimFolio for you."
            ),
            userProfile: .constant(UserOnboardingProfile())
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Personalization Page")
    }
}
#endif
