import SwiftUI
import AuthenticationServices

enum SignInContext {
    case generic
    case socialFeed
}

struct SignInView: View {
    var context: SignInContext = .generic
    var onSignIn: (() -> Void)? = nil

    @ObservedObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss

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
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Header
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: context == .socialFeed ? "person.2.fill" : "person.crop.circle.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text(context == .socialFeed ? "Join Your Class Feed" : "Back Up Your Portfolio")
                            .font(AppTheme.Typography.title)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text(context == .socialFeed ? "Sign in to share simulation photos with your classmates" : "Create a free account to keep your data safe")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

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
                                        onSignIn?()
                                        dismiss()
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

                    // Divider
                    HStack {
                        Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                        Text("or")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                    }

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
                                    onSignIn?()
                                    dismiss()
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
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { dismiss() }
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
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
}
