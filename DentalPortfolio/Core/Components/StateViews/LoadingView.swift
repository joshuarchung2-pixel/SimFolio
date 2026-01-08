// LoadingView.swift
// Dental Portfolio - Loading State Views
//
// Reusable loading indicators for various contexts throughout the app.
// Supports full screen, inline, overlay, and minimal styles.
//
// Contents:
// - LoadingStyle: Enum for different loading display styles
// - LoadingView: Main loading view with multiple style options
// - SpinnerModifier: Animation modifier for continuous rotation

import SwiftUI

// MARK: - Loading View Styles

/// Style variants for loading indicators
enum LoadingStyle {
    /// Full screen loading with centered spinner
    case fullScreen
    /// Inline loading for use within content
    case inline
    /// Overlay loading with dimmed backdrop
    case overlay
    /// Minimal spinner only
    case minimal
}

// MARK: - LoadingView

/// Versatile loading view supporting multiple display styles
struct LoadingView: View {
    let style: LoadingStyle
    var message: String? = nil
    var progress: Double? = nil

    var body: some View {
        switch style {
        case .fullScreen:
            fullScreenLoading
        case .inline:
            inlineLoading
        case .overlay:
            overlayLoading
        case .minimal:
            minimalLoading
        }
    }

    // MARK: - Full Screen Loading

    private var fullScreenLoading: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            // Animated spinner
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AppTheme.Colors.primary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .modifier(SpinnerModifier())
            }

            if let message = message {
                Text(message)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            if let progress = progress {
                VStack(spacing: AppTheme.Spacing.xs) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.Colors.primary))
                        .frame(width: 200)

                    Text("\(Int(progress * 100))%")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }

    // MARK: - Inline Loading

    private var inlineLoading: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))

            if let message = message {
                Text(message)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    // MARK: - Overlay Loading

    private var overlayLoading: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                if let message = message {
                    Text(message)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.white)
                }

                if let progress = progress {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 180)

                        Text("\(Int(progress * 100))%")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }

    // MARK: - Minimal Loading

    private var minimalLoading: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
    }
}

// MARK: - Spinner Animation Modifier

/// ViewModifier that applies continuous rotation animation
struct SpinnerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - View Extension for Loading Overlay

extension View {
    /// Add a loading overlay to a view
    /// - Parameters:
    ///   - isLoading: Binding to control visibility
    ///   - message: Optional loading message
    ///   - progress: Optional progress value (0.0 to 1.0)
    /// - Returns: View with loading overlay
    func loadingOverlay(
        isLoading: Bool,
        message: String? = nil,
        progress: Double? = nil
    ) -> some View {
        ZStack {
            self

            if isLoading {
                LoadingView(style: .overlay, message: message, progress: progress)
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full screen
            LoadingView(style: .fullScreen, message: "Loading photos...")
                .previewDisplayName("Full Screen")

            // Full screen with progress
            LoadingView(style: .fullScreen, message: "Exporting portfolio...", progress: 0.65)
                .previewDisplayName("Full Screen with Progress")

            // Inline
            LoadingView(style: .inline, message: "Loading...")
                .previewDisplayName("Inline")

            // Overlay
            ZStack {
                Color.blue
                LoadingView(style: .overlay, message: "Saving...", progress: 0.3)
            }
            .previewDisplayName("Overlay")

            // Minimal
            LoadingView(style: .minimal)
                .previewDisplayName("Minimal")
        }
    }
}
#endif
