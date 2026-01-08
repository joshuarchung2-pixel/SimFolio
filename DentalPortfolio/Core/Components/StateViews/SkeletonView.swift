// SkeletonView.swift
// Dental Portfolio - Skeleton Loading Components
//
// Placeholder views for loading states that match content layout.
// Provides shimmer animation for visual loading feedback.
//
// Contents:
// - SkeletonModifier: Shimmer animation modifier
// - SkeletonRect/Circle: Basic skeleton shapes
// - Component-specific skeleton views
// - Full page skeleton views

import SwiftUI

// MARK: - Skeleton Modifier

/// ViewModifier that applies shimmer animation to skeleton views
struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 400 : -400)
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    /// Apply skeleton shimmer animation
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Basic Skeleton Shapes

/// Rectangle skeleton placeholder
struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.Colors.surfaceSecondary)
            .frame(width: width, height: height)
            .skeleton()
    }
}

/// Circle skeleton placeholder
struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(AppTheme.Colors.surfaceSecondary)
            .frame(width: size, height: size)
            .skeleton()
    }
}

// MARK: - Skeleton Card Components

/// Photo card skeleton placeholder
struct SkeletonPhotoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Photo placeholder
            SkeletonRect(height: 120, cornerRadius: AppTheme.CornerRadius.medium)

            // Tag placeholder
            SkeletonRect(width: 80, height: 20, cornerRadius: 10)

            // Date placeholder
            SkeletonRect(width: 60, height: 12)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

/// Portfolio card skeleton placeholder
struct SkeletonPortfolioCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Progress ring placeholder
            SkeletonCircle(size: 56)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                // Title
                SkeletonRect(width: 150, height: 18)

                // Subtitle
                SkeletonRect(width: 100, height: 14)

                // Progress bar
                SkeletonRect(height: 6, cornerRadius: 3)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

/// List row skeleton placeholder
struct SkeletonListRow: View {
    var hasIcon: Bool = true

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if hasIcon {
                SkeletonCircle(size: 40)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                SkeletonRect(width: 140, height: 16)
                SkeletonRect(width: 100, height: 12)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
    }
}

/// Stat card skeleton placeholder
struct SkeletonStatCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SkeletonCircle(size: 24)
            SkeletonRect(width: 50, height: 28, cornerRadius: 4)
            SkeletonRect(width: 70, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

/// Quick action card skeleton
struct SkeletonQuickActionCard: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            SkeletonCircle(size: 48)
            SkeletonRect(width: 60, height: 14)
        }
        .frame(width: 80, height: 90)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Skeleton Grids

/// Photo grid skeleton
struct SkeletonPhotoGrid: View {
    let columns: Int
    let rows: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: columns),
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(0..<(columns * rows), id: \.self) { _ in
                SkeletonRect(height: 100, cornerRadius: AppTheme.CornerRadius.small)
            }
        }
    }
}

// MARK: - Full Page Skeletons

/// Home view skeleton
struct SkeletonHomeView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Header placeholder
                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        SkeletonRect(width: 120, height: 14)
                        SkeletonRect(width: 180, height: 24)
                    }
                    Spacer()
                    SkeletonCircle(size: 44)
                }

                // Stats row
                HStack(spacing: AppTheme.Spacing.sm) {
                    SkeletonStatCard()
                    SkeletonStatCard()
                    SkeletonStatCard()
                }

                // Quick actions
                HStack(spacing: AppTheme.Spacing.sm) {
                    SkeletonQuickActionCard()
                    SkeletonQuickActionCard()
                    SkeletonQuickActionCard()
                    SkeletonQuickActionCard()
                }

                // Section header
                HStack {
                    SkeletonRect(width: 120, height: 20)
                    Spacer()
                    SkeletonRect(width: 60, height: 16)
                }

                // Portfolio cards
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonPortfolioCard()
                }

                // Another section
                HStack {
                    SkeletonRect(width: 100, height: 20)
                    Spacer()
                }

                // Photo grid
                SkeletonPhotoGrid(columns: 3, rows: 2)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}

/// Library view skeleton
struct SkeletonLibraryView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            HStack(spacing: AppTheme.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonRect(width: 70, height: 32, cornerRadius: 16)
                }
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)

            // Photo grid
            ScrollView(showsIndicators: false) {
                SkeletonPhotoGrid(columns: 3, rows: 6)
                    .padding(AppTheme.Spacing.md)
            }
        }
        .background(AppTheme.Colors.background)
    }
}

/// Portfolio detail skeleton
struct SkeletonPortfolioDetail: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Header card
                VStack(spacing: AppTheme.Spacing.md) {
                    SkeletonCircle(size: 80)
                    SkeletonRect(width: 150, height: 24)
                    SkeletonRect(width: 200, height: 16)
                    SkeletonRect(height: 8, cornerRadius: 4)
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.large)

                // Stats
                HStack(spacing: AppTheme.Spacing.md) {
                    SkeletonStatCard()
                    SkeletonStatCard()
                }

                // Requirements section
                HStack {
                    SkeletonRect(width: 140, height: 20)
                    Spacer()
                }

                ForEach(0..<5, id: \.self) { _ in
                    SkeletonListRow()
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}

/// Profile view skeleton
struct SkeletonProfileView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Profile header
                VStack(spacing: AppTheme.Spacing.md) {
                    SkeletonCircle(size: 80)
                    SkeletonRect(width: 140, height: 22)
                    SkeletonRect(width: 180, height: 16)
                }
                .padding(AppTheme.Spacing.lg)

                // Stats
                HStack(spacing: AppTheme.Spacing.md) {
                    SkeletonStatCard()
                    SkeletonStatCard()
                    SkeletonStatCard()
                }

                // Settings sections
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonListRow()
                            if true { // Add divider except last
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Basic shapes
            VStack(spacing: AppTheme.Spacing.md) {
                SkeletonRect(width: 200, height: 20)
                SkeletonRect(height: 100, cornerRadius: 12)
                HStack {
                    SkeletonCircle(size: 40)
                    SkeletonCircle(size: 50)
                    SkeletonCircle(size: 60)
                }
            }
            .padding()
            .background(AppTheme.Colors.background)
            .previewDisplayName("Basic Shapes")

            // Card components
            VStack(spacing: AppTheme.Spacing.md) {
                SkeletonPhotoCard()
                SkeletonPortfolioCard()
                SkeletonStatCard()
            }
            .padding()
            .background(AppTheme.Colors.background)
            .previewDisplayName("Card Components")

            // Home skeleton
            SkeletonHomeView()
                .previewDisplayName("Home Skeleton")

            // Library skeleton
            SkeletonLibraryView()
                .previewDisplayName("Library Skeleton")

            // Portfolio detail skeleton
            SkeletonPortfolioDetail()
                .previewDisplayName("Portfolio Detail Skeleton")
        }
    }
}
#endif
