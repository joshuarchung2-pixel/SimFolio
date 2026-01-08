// OnboardingView.swift
// Dental Portfolio - Onboarding Flow
//
// This file contains the onboarding experience for new users.
// A 5-page flow explaining app features and requesting permissions.
//
// Contents:
// - OnboardingPage: Model for onboarding page data
// - OnboardingFeature: Model for feature list items
// - PermissionType: Enum for permission types
// - OnboardingView: Main onboarding container
// - OnboardingPageView: Individual page content view

import SwiftUI
import Photos
import AVFoundation
import UserNotifications

// MARK: - Models

/// Model representing a single onboarding page
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]
    let isPermissionPage: Bool
    let permissionType: PermissionType?

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        features: [OnboardingFeature] = [],
        isPermissionPage: Bool = false,
        permissionType: PermissionType? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.isPermissionPage = isPermissionPage
        self.permissionType = permissionType
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
/// Presents a 5-page onboarding experience for new users
struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    // MARK: - State

    @State private var currentPage: Int = 0
    @State private var cameraPermissionGranted: Bool = false
    @State private var photosPermissionGranted: Bool = false
    @State private var notificationsPermissionGranted: Bool = false

    // MARK: - Pages

    let pages: [OnboardingPage] = [
        // Page 1: Welcome
        OnboardingPage(
            icon: "camera.fill",
            iconColor: .blue,
            title: "Welcome to\nDental Portfolio",
            subtitle: "The smart way to capture, organize, and track your dental school clinical work.",
            features: []
        ),

        // Page 2: Capture Features
        OnboardingPage(
            icon: "camera.viewfinder",
            iconColor: .green,
            title: "Smart Capture",
            subtitle: "Tag photos before you take them for effortless organization.",
            features: [
                OnboardingFeature(
                    icon: "tag.fill",
                    title: "Pre-Tagging",
                    description: "Set procedure, stage, and angle before capturing"
                ),
                OnboardingFeature(
                    icon: "square.stack.3d.up.fill",
                    title: "Batch Capture",
                    description: "Take multiple photos with the same tags"
                ),
                OnboardingFeature(
                    icon: "star.fill",
                    title: "Quality Rating",
                    description: "Rate photos immediately after capture"
                )
            ]
        ),

        // Page 3: Portfolio Features
        OnboardingPage(
            icon: "folder.fill",
            iconColor: .orange,
            title: "Portfolio Tracking",
            subtitle: "Never miss a requirement with smart portfolio management.",
            features: [
                OnboardingFeature(
                    icon: "checklist",
                    title: "Requirement Checklists",
                    description: "Track exactly what photos you need"
                ),
                OnboardingFeature(
                    icon: "calendar.badge.clock",
                    title: "Due Date Reminders",
                    description: "Get notified before deadlines"
                ),
                OnboardingFeature(
                    icon: "square.and.arrow.up",
                    title: "Easy Export",
                    description: "Export as ZIP, PDF, or individual files"
                )
            ]
        ),

        // Page 4: Camera Permission
        OnboardingPage(
            icon: "camera.fill",
            iconColor: .blue,
            title: "Camera Access",
            subtitle: "We need camera access to capture your clinical photos.",
            features: [],
            isPermissionPage: true,
            permissionType: .camera
        ),

        // Page 5: Photos Permission
        OnboardingPage(
            icon: "photo.fill.on.rectangle.fill",
            iconColor: .purple,
            title: "Photo Library",
            subtitle: "Access your photo library to organize and view your captures.",
            features: [],
            isPermissionPage: true,
            permissionType: .photos
        )
    ]

    // MARK: - Computed Properties

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    var canProceed: Bool {
        let page = pages[currentPage]

        if page.isPermissionPage {
            switch page.permissionType {
            case .camera:
                return cameraPermissionGranted
            case .photos:
                return photosPermissionGranted
            case .notifications:
                return notificationsPermissionGranted
            case .none:
                return true
            }
        }

        return true
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()

                    if currentPage < pages.count - 1 && !pages[currentPage].isPermissionPage {
                        Button(action: skipOnboarding) {
                            Text("Skip")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(.trailing, AppTheme.Spacing.md)
                    }
                }
                .frame(height: 44)
                .padding(.top, AppTheme.Spacing.sm)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(
                            page: page,
                            cameraGranted: $cameraPermissionGranted,
                            photosGranted: $photosPermissionGranted,
                            notificationsGranted: $notificationsPermissionGranted
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Page indicators
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
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
            }
        }
        .onAppear {
            checkExistingPermissions()
        }
    }

    // MARK: - Actions

    /// Advance to the next page
    func nextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
        HapticsManager.shared.selectionChanged()
    }

    /// Skip to the first permission page
    func skipOnboarding() {
        // Skip to first permission page
        if let permissionIndex = pages.firstIndex(where: { $0.isPermissionPage }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = permissionIndex
            }
        } else {
            completeOnboarding()
        }
        HapticsManager.shared.lightTap()
    }

    /// Complete onboarding and dismiss
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(Date(), forKey: "userCreatedDate")
        HapticsManager.shared.success()
        onComplete()
        isPresented = false
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

/// Individual page content view
struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var cameraGranted: Bool
    @Binding var photosGranted: Bool
    @Binding var notificationsGranted: Bool

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            // Icon
            iconView

            // Text content
            VStack(spacing: AppTheme.Spacing.md) {
                Text(page.title)
                    .font(AppTheme.Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }

            // Features list (if any)
            if !page.features.isEmpty {
                featuresListView
            }

            // Permission button (if permission page)
            if page.isPermissionPage {
                permissionButton
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Icon View

    var iconView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(page.iconColor.opacity(0.1))
                .frame(width: 160, height: 160)

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [page.iconColor, page.iconColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: page.iconColor.opacity(0.4), radius: 20, x: 0, y: 10)

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 50))
                .foregroundColor(.white)
        }
    }

    // MARK: - Features List

    var featuresListView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(page.features) { feature in
                HStack(spacing: AppTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(page.iconColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: feature.icon)
                            .font(.system(size: 18))
                            .foregroundColor(page.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text(feature.description)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.large)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Permission Button

    var permissionButton: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if isPermissionGranted {
                // Granted state
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.success)

                    Text("Permission Granted")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.success)
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
                    .foregroundColor(.white)
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
                .foregroundColor(AppTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Permission Helpers

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
        switch page.permissionType {
        case .camera:
            return "Allow Camera Access"
        case .photos:
            return "Allow Photo Access"
        case .notifications:
            return "Enable Notifications"
        case .none:
            return "Continue"
        }
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
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraGranted = granted
                if granted {
                    HapticsManager.shared.success()
                }
            }
        }
    }

    func requestPhotosPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                photosGranted = status == .authorized || status == .limited
                if photosGranted {
                    HapticsManager.shared.success()
                }
            }
        }
    }

    func requestNotificationsPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                if granted {
                    HapticsManager.shared.success()
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

struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview feature page
        OnboardingPageView(
            page: OnboardingPage(
                icon: "camera.viewfinder",
                iconColor: .green,
                title: "Smart Capture",
                subtitle: "Tag photos before you take them for effortless organization.",
                features: [
                    OnboardingFeature(
                        icon: "tag.fill",
                        title: "Pre-Tagging",
                        description: "Set procedure, stage, and angle before capturing"
                    ),
                    OnboardingFeature(
                        icon: "square.stack.3d.up.fill",
                        title: "Batch Capture",
                        description: "Take multiple photos with the same tags"
                    ),
                    OnboardingFeature(
                        icon: "star.fill",
                        title: "Quality Rating",
                        description: "Rate photos immediately after capture"
                    )
                ]
            ),
            cameraGranted: .constant(false),
            photosGranted: .constant(false),
            notificationsGranted: .constant(false)
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Feature Page")

        // Preview permission page
        OnboardingPageView(
            page: OnboardingPage(
                icon: "camera.fill",
                iconColor: .blue,
                title: "Camera Access",
                subtitle: "We need camera access to capture your clinical photos.",
                features: [],
                isPermissionPage: true,
                permissionType: .camera
            ),
            cameraGranted: .constant(false),
            photosGranted: .constant(false),
            notificationsGranted: .constant(false)
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Permission Page")

        // Preview granted state
        OnboardingPageView(
            page: OnboardingPage(
                icon: "camera.fill",
                iconColor: .blue,
                title: "Camera Access",
                subtitle: "We need camera access to capture your clinical photos.",
                features: [],
                isPermissionPage: true,
                permissionType: .camera
            ),
            cameraGranted: .constant(true),
            photosGranted: .constant(false),
            notificationsGranted: .constant(false)
        )
        .background(AppTheme.Colors.background)
        .previewDisplayName("Permission Granted")
    }
}
#endif
