// OnboardingView.swift
// SimFolio - Onboarding Flow
//
// Two-page onboarding: Sign-In (optional) and Profile Details (required).

import SwiftUI
import AuthenticationServices

// MARK: - Models

/// Types of onboarding pages
enum OnboardingPageType: Equatable {
    case signIn
    case personalization
}

/// Model representing a single onboarding page
struct OnboardingPage: Identifiable {
    let id = UUID()
    let pageType: OnboardingPageType
    let title: String
    let subtitle: String
}

// MARK: - OnboardingView

/// Main onboarding container view
/// Presents a 2-page onboarding experience: Sign-In then Profile Details
struct OnboardingView: View {
    @Binding var isPresented: Bool
    var onComplete: () -> Void

    // MARK: - State

    @State private var currentPage: Int = 0
    @State private var isKeyboardVisible: Bool = false

    // User profile state
    @State private var userProfile = UserOnboardingProfile()

    // Sign-in state (tracked so completeOnboarding can link data)
    @State private var didSignIn: Bool = false

    // Analytics tracking
    @State private var onboardingStartTime: Date = Date()

    // MARK: - Pages

    let pages: [OnboardingPage] = [
        // Page 1: Sign In (optional)
        OnboardingPage(
            pageType: .signIn,
            title: "Welcome to SimFolio",
            subtitle: "Create a free account to keep your data safe and never lose your work."
        ),

        // Page 2: Profile Details (required)
        OnboardingPage(
            pageType: .personalization,
            title: "Let's personalize\nyour experience",
            subtitle: "Tell us about yourself to customize SimFolio for you."
        ),
    ]

    // MARK: - Computed Properties

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    var canProceed: Bool {
        guard currentPage >= 0, currentPage < pages.count else { return false }
        let page = pages[currentPage]

        switch page.pageType {
        case .signIn:
            return true
        case .personalization:
            return !userProfile.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !userProfile.dentalSchoolAffiliation.trimmingCharacters(in: .whitespaces).isEmpty &&
                   userProfile.graduationYear != nil
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageContent(for: page, at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .onChange(of: currentPage) { newValue in
                    if newValue > pages.count - 1 {
                        withAnimation {
                            currentPage = pages.count - 1
                        }
                    }
                }

                // Bottom spacer for controls overlay
                if !isKeyboardVisible {
                    Spacer()
                        .frame(height: 120)
                }
            }

            // Bottom controls
            if !isKeyboardVisible {
                VStack {
                    Spacer()

                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Page indicators (2 dots)
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

                        // Skip option (sign-in page only)
                        if currentPage == 0 {
                            Button {
                                AnalyticsService.logEvent(.onboardingSkipped, parameters: ["page": "signIn"])
                                nextPage()
                            } label: {
                                Text("Skip for now")
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .underline()
                            }
                        }
                    }
                    .padding(.bottom, AppTheme.Spacing.xl)
                    .background(AppTheme.Colors.background)
                }
            }
        }
        .onAppear {
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

    // MARK: - Page Content Router

    @ViewBuilder
    private func pageContent(for page: OnboardingPage, at index: Int) -> some View {
        switch page.pageType {
        case .signIn:
            OnboardingSignInPageView(
                didSignIn: $didSignIn,
                onAdvance: { nextPage() }
            )
        case .personalization:
            OnboardingPersonalizationPageView(page: page, userProfile: $userProfile)
        }
    }

    // MARK: - Actions

    func nextPage() {
        guard currentPage < pages.count - 1 else {
            completeOnboarding()
            return
        }

        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )

        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }

    func completeOnboarding() {
        saveUserProfile()

        // Link onboarding data if user signed in
        if didSignIn {
            Task { try? await UserProfileService.shared.linkOnboardingData() }
        }

        let durationSeconds = Int(Date().timeIntervalSince(onboardingStartTime))
        AnalyticsService.logOnboardingCompleted(
            durationSeconds: durationSeconds,
            schoolSelected: !userProfile.dentalSchoolAffiliation.isEmpty
        )

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

    func saveUserProfile() {
        UserDefaults.standard.set(userProfile.displayName, forKey: "userName")
        UserDefaults.standard.set(userProfile.dentalSchoolAffiliation, forKey: "userSchool")

        if let year = userProfile.graduationYear {
            UserDefaults.standard.set(year, forKey: "userGraduationYear")
        }
    }
}

// MARK: - Sign In Page

/// Inline sign-in page with Apple Sign In + email/password form
struct OnboardingSignInPageView: View {
    @Binding var didSignIn: Bool
    var onAdvance: (() -> Void)?

    private let authService = AuthenticationService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.sm)

                // Header
                VStack(spacing: AppTheme.Spacing.md) {
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

                    Text("Welcome to SimFolio")
                        .font(AppTheme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Create a free account to keep your data safe and never lose your work.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Sign in with Apple
                SignInWithAppleButton(
                    onRequest: { request in
                        let appleRequest = authService.startSignInWithApple()
                        request.nonce = appleRequest.nonce
                        request.requestedScopes = appleRequest.requestedScopes
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                isLoading = true
                                do {
                                    try await authService.signInWithApple(authorization: authorization)
                                    didSignIn = true
                                    AnalyticsService.logEvent(.accountCreated, parameters: ["source": "onboarding", "method": "apple"])
                                    onAdvance?() // Advance to next page
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                                isLoading = false
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                )
                .frame(height: 50)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .padding(.horizontal, AppTheme.Spacing.lg)

                // Divider
                HStack {
                    Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                    Text("or")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                // Email/password form
                VStack(spacing: AppTheme.Spacing.md) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)

                    DPButton(
                        isSignUp ? "Create Account" : "Sign In",
                        style: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: isLoading
                    ) {
                        Task {
                            isLoading = true
                            do {
                                if isSignUp {
                                    try await authService.signUp(email: email, password: password)
                                } else {
                                    try await authService.signIn(email: email, password: password)
                                }
                                didSignIn = true
                                AnalyticsService.logEvent(.accountCreated, parameters: ["source": "onboarding", "method": "email"])
                                onAdvance?() // Advance to next page
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                            isLoading = false
                        }
                    }

                    Button {
                        isSignUp.toggle()
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                    }

                    if !isSignUp {
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $resetEmail)
            Button("Send Reset Link") {
                Task {
                    try? await authService.sendPasswordReset(email: resetEmail)
                    showResetConfirmation = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
        .alert("Check Your Email", isPresented: $showResetConfirmation) {
            Button("OK") {}
        } message: {
            Text("If an account exists with that email, you'll receive a password reset link.")
        }
    }
}

// MARK: - Personalization Page

/// Personalization page with name input, school input, and graduation year selection
struct OnboardingPersonalizationPageView: View {
    let page: OnboardingPage
    @Binding var userProfile: UserOnboardingProfile

    @FocusState private var isNameFieldFocused: Bool
    @State private var showSchoolPicker = false

    @State private var graduationYears: [Int] = {
        let year = Calendar.current.component(.year, from: Date())
        return Array(year...(year + 8))
    }()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer(minLength: AppTheme.Spacing.sm)

            // Header
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                Text(page.title)
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Form fields
            VStack(spacing: AppTheme.Spacing.md) {
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
                                        .stroke(isNameFieldFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: 1)
                                )
                                .focused($isNameFieldFocused)
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
                            .frame(height: 120)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    Spacer()
                }
            .onAppear {
                if userProfile.graduationYear == nil {
                    userProfile.graduationYear = graduationYears[0]
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
