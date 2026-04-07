// HomeView.swift
// SimFolio - Home Dashboard
//
// The main dashboard view - first screen users see after launch.
// Shows a full-screen photo slideshow with stats overlay and portfolio navigator.
//
// Sections:
// 1. Photo Slideshow - Edge-to-edge auto-fading slideshow with gradient and stats
// 2. Portfolio Navigator - Arrow-based navigation between portfolios

import SwiftUI
import Photos
import Combine

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared
    @StateObject private var portfolioNavState = PortfolioNavigatorState()

    private let slideshowHeight: CGFloat = 420
    @State private var isNavigatorSticky: Bool = false

    /// Check if there are any photos to display
    private var hasPhotos: Bool {
        !PhotoStorageService.shared.records.isEmpty
    }

    var body: some View {
        GeometryReader { outerGeometry in
            ZStack(alignment: .top) {
                // Background photo slideshow (fixed position)
                GeometryReader { geometry in
                    PhotoSlideshowBackground()
                        .frame(
                            width: geometry.size.width,
                            height: max(slideshowHeight, slideshowHeight + geometry.frame(in: .global).minY)
                        )
                        .offset(y: min(0, -geometry.frame(in: .global).minY))
                        .clipped()
                }
                .frame(height: slideshowHeight)

            // Scrollable content overlay
            if hasPhotos {
                // Normal scrollable content when photos exist
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Spacer to push content below the slideshow area
                        Color.clear
                            .frame(height: slideshowHeight - 110) // Position for tags and stats card

                        // Photo info overlay (tags and rating) - over the image, on top of gradient
                        PhotoInfoOverlaySection()
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.bottom, AppTheme.Spacing.md)
                            .offset(y: 24) // Move down to sit on top of gradient
                            .zIndex(2) // Render above the gradient

                        // Stats card with gradient behind it
                        ZStack(alignment: .top) {
                            // Gradient that transitions at the middle of the stats card
                            VStack(spacing: 0) {
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: AppTheme.Colors.background.opacity(0.3), location: 0.10),
                                        .init(color: AppTheme.Colors.background.opacity(0.6), location: 0.25),
                                        .init(color: AppTheme.Colors.background.opacity(0.85), location: 0.40),
                                        .init(color: AppTheme.Colors.background, location: 0.55),
                                        .init(color: AppTheme.Colors.background, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 140)

                                // Solid background continuation
                                AppTheme.Colors.background
                            }
                            .offset(y: -26) // Move gradient upward (adjusted to stay stationary while content moves up)

                            // Stats card positioned so gradient ends at its middle
                            PhotoStatsCardSection()
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.top, 38) // Position card so middle aligns with gradient end (moved up 12pt)
                        }
                        .frame(height: 130) // Stats card height + padding (reduced to account for gradient offset)
                        .zIndex(1) // Ensure stats card renders above portfolio background

                        // Content with background that covers the slideshow when scrolling
                        VStack(spacing: 0) {
                            // Portfolio Navigator Section
                            PortfolioNavigatorSection(navState: portfolioNavState, isSticky: $isNavigatorSticky)

                            Spacer(minLength: 100) // Space for tab bar
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50) // Extra top padding for background coverage during scroll
                        .background(AppTheme.Colors.background)
                        .offset(y: -50) // Move upward to close gap with stats card
                    }
                }
                .coordinateSpace(name: "scroll")
            } else {
                // Empty state content with portfolio section below
                ScrollView {
                    VStack(spacing: 0) {
                        // Empty state constrained to slideshow area
                        PhotoSlideshowEmptyContent(slideshowHeight: slideshowHeight)
                            .frame(height: slideshowHeight - 80) // Leave room for gradient overlap

                        // Gradient transition from slideshow to content
                        ZStack(alignment: .top) {
                            // Gradient that transitions to background
                            VStack(spacing: 0) {
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: AppTheme.Colors.background.opacity(0.3), location: 0.10),
                                        .init(color: AppTheme.Colors.background.opacity(0.6), location: 0.25),
                                        .init(color: AppTheme.Colors.background.opacity(0.85), location: 0.40),
                                        .init(color: AppTheme.Colors.background, location: 0.55),
                                        .init(color: AppTheme.Colors.background, location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 140)

                                // Solid background continuation
                                AppTheme.Colors.background
                            }
                            .offset(y: -26)
                        }
                        .frame(height: 80)

                        // Content with background that covers below slideshow
                        VStack(spacing: 0) {
                            // Portfolio Navigator Section
                            PortfolioNavigatorSection(navState: portfolioNavState, isSticky: $isNavigatorSticky)

                            Spacer(minLength: 100) // Space for tab bar
                        }
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Colors.background)
                    }
                }
                .coordinateSpace(name: "scroll")
            }

                // Sticky portfolio navigator header
                if isNavigatorSticky {
                    VStack(spacing: 0) {
                        PortfolioNavigatorHeader(navState: portfolioNavState)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.Colors.background)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                        Spacer()
                    }
                    .padding(.top, outerGeometry.safeAreaInsets.top)
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Photo Slideshow Background

/// Shared slideshow state manager to sync between background and overlay
class SlideshowStateManager: ObservableObject {
    static let shared = SlideshowStateManager()

    @Published var currentIndex: Int = 0

    private init() {}
}

/// Fixed background slideshow of user's highest-rated photos
struct PhotoSlideshowBackground: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var slideshowState = SlideshowStateManager.shared

    @State private var timer: Timer?
    @State private var loadedImages: [String: UIImage] = [:]

    private let autoPlayInterval: TimeInterval = 5.0
    private let maxPhotos: Int = 10

    /// Get photos sorted by rating (4-5 stars first), falling back to all photos
    var slideshowPhotos: [PHAsset] {
        let allAssets = library.assets

        // Get highly rated photos (4-5 stars)
        let highlyRated = allAssets.filter { asset in
            let rating = metadataManager.getRating(for: asset.localIdentifier) ?? 0
            return rating >= 4
        }

        // If we have highly rated photos, use them; otherwise fall back to all
        let photosToShow = highlyRated.isEmpty ? Array(allAssets.prefix(maxPhotos)) : Array(highlyRated.prefix(maxPhotos))
        return photosToShow
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if slideshowPhotos.isEmpty {
                // Empty state background
                PhotoSlideshowEmptyBackground()
            } else {
                // Fading slideshow with explicit frame constraints
                GeometryReader { geometry in
                    ZStack {
                        ForEach(Array(slideshowPhotos.enumerated()), id: \.element.localIdentifier) { index, asset in
                            if let image = loadedImages[asset.localIdentifier] {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .opacity(index == slideshowState.currentIndex ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.8), value: slideshowState.currentIndex)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadImages()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: slideshowPhotos.count) { newCount in
            if slideshowState.currentIndex >= newCount {
                slideshowState.currentIndex = 0
            }
            loadImages()
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        guard slideshowPhotos.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: autoPlayInterval, repeats: true) { _ in
            withAnimation {
                slideshowState.currentIndex = (slideshowState.currentIndex + 1) % slideshowPhotos.count
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func loadImages() {
        for asset in slideshowPhotos {
            guard loadedImages[asset.localIdentifier] == nil else { continue }
            PhotoLibraryManager.shared.requestImage(for: asset) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        loadedImages[asset.localIdentifier] = image
                    }
                }
            }
        }
    }
}

// MARK: - Photo Info Overlay Section

/// Section that displays photo tags and rating, scrolls with content
struct PhotoInfoOverlaySection: View {
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var slideshowState = SlideshowStateManager.shared

    private let maxPhotos: Int = 10

    /// Get photos sorted by rating (4-5 stars first), falling back to all photos
    var slideshowPhotos: [PHAsset] {
        let allAssets = library.assets

        // Get highly rated photos (4-5 stars)
        let highlyRated = allAssets.filter { asset in
            let rating = metadataManager.getRating(for: asset.localIdentifier) ?? 0
            return rating >= 4
        }

        // If we have highly rated photos, use them; otherwise fall back to all
        let photosToShow = highlyRated.isEmpty ? Array(allAssets.prefix(maxPhotos)) : Array(highlyRated.prefix(maxPhotos))
        return photosToShow
    }

    /// Current photo's metadata
    var currentMetadata: PhotoMetadata? {
        guard !slideshowPhotos.isEmpty, slideshowState.currentIndex < slideshowPhotos.count else { return nil }
        let asset = slideshowPhotos[slideshowState.currentIndex]
        return metadataManager.getMetadata(for: asset.localIdentifier)
    }

    var body: some View {
        if !slideshowPhotos.isEmpty {
            HStack(alignment: .bottom) {
                // Tags on bottom-left
                PhotoTagsOverlay(metadata: currentMetadata)

                Spacer()

                // Rating on bottom-right
                PhotoRatingOverlay(metadata: currentMetadata)
            }
        }
    }
}

// MARK: - Photo Slideshow Empty Background

/// Empty state background gradient when no photos exist (non-interactive)
struct PhotoSlideshowEmptyBackground: View {
    var body: some View {
        // Gradient background only - interactive content is in PhotoSlideshowEmptyContent
        LinearGradient(
            gradient: Gradient(colors: [
                AppTheme.Colors.primary.opacity(0.3),
                AppTheme.Colors.secondary.opacity(0.2),
                AppTheme.Colors.background
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Photo Slideshow Empty Content

/// Empty state interactive content (icon, text, button) - placed in ScrollView for proper touch handling
struct PhotoSlideshowEmptyContent: View {
    @EnvironmentObject var router: NavigationRouter
    let slideshowHeight: CGFloat

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            Text("No Photos Yet")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Start capturing your dental work")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            DPButton("Take Photo", icon: "camera", style: .primary, size: .medium) {
                router.navigateToCapture()
            }
        }
        .frame(height: slideshowHeight)
        .frame(maxWidth: .infinity, maxHeight: slideshowHeight, alignment: .center)
    }
}

// MARK: - Photo Stats Card Section

/// Stats card that scrolls with content
struct PhotoStatsCardSection: View {
    @ObservedObject var storageService = PhotoStorageService.shared
    @ObservedObject var metadataManager = MetadataManager.shared

    /// Calculate total outstanding requirements across all portfolios
    var outstandingRequirements: Int {
        var total = 0
        for portfolio in metadataManager.portfolios {
            let stats = metadataManager.getPortfolioStats(portfolio)
            total += (stats.total - stats.fulfilled)
        }
        return total
    }

    /// Calculate average rating of all rated photos
    var averageRating: Double {
        let allRatings = storageService.records.compactMap { record -> Int? in
            let rating = metadataManager.getRating(for: record.id.uuidString)
            return (rating ?? 0) > 0 ? rating : nil
        }
        guard !allRatings.isEmpty else { return 0 }
        return Double(allRatings.reduce(0, +)) / Double(allRatings.count)
    }

    var body: some View {
        PhotoStatsCard(
            totalPhotos: storageService.records.count,
            outstandingRequirements: outstandingRequirements,
            averageRating: averageRating
        )
    }
}

// MARK: - Recent Thumbnail View

/// Thumbnail view for a single photo loaded from app storage
struct RecentThumbnailView: View {
    let record: PhotoRecord
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.surfaceSecondary)
            }
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}

// MARK: - Photo Tags Overlay

/// Shows photo tags (procedure, stage, angle) on bottom-left
struct PhotoTagsOverlay: View {
    let metadata: PhotoMetadata?

    var body: some View {
        if let metadata = metadata, metadata.procedure != nil {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                if let procedure = metadata.procedure {
                    Text(procedure)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .padding(.leading, AppTheme.Spacing.sm)
                }

                HStack(spacing: AppTheme.Spacing.xs) {
                    if let stage = metadata.stage {
                        TagPill(text: stage)
                    }
                    if let angle = metadata.angle {
                        TagPill(text: angle)
                    }
                }
            }
        }
    }
}

/// Small pill-shaped tag
struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(Color.black.opacity(0.4))
            .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Photo Rating Overlay

/// Shows star rating on bottom-right
struct PhotoRatingOverlay: View {
    let metadata: PhotoMetadata?

    var body: some View {
        if let rating = metadata?.rating, rating > 0 {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(star <= rating ? .yellow : .white.opacity(0.5))
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(Color.black.opacity(0.4))
            .cornerRadius(AppTheme.CornerRadius.small)
        }
    }
}

// MARK: - Photo Stats Card

/// Card showing total photos, outstanding requirements, and average rating
struct PhotoStatsCard: View {
    let totalPhotos: Int
    let outstandingRequirements: Int
    let averageRating: Double

    var body: some View {
        HStack(spacing: 0) {
            // Total Photos
            statItem(
                value: "\(totalPhotos)",
                label: "Photos",
                color: AppTheme.Colors.primary
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, AppTheme.Spacing.md)

            // Outstanding Requirements
            statItem(
                value: "\(outstandingRequirements)",
                label: "Outstanding",
                color: outstandingRequirements > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, AppTheme.Spacing.md)

            // Average Rating
            statItem(
                value: averageRating > 0 ? String(format: "%.1f", averageRating) : "-",
                label: "Avg Rating",
                color: AppTheme.Colors.textSecondary
            )
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadowMedium()
    }

    func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Portfolio Navigator State

/// Shared state for portfolio navigator to sync between sticky header and main section
class PortfolioNavigatorState: ObservableObject {
    @Published var currentIndex: Int = 0
}

// MARK: - Portfolio Navigator Header

/// Sticky header version of the portfolio navigator
/// Shows when user scrolls past the main filing tabs - provides compact navigation
struct PortfolioNavigatorHeader: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var navState: PortfolioNavigatorState

    var portfolios: [Portfolio] {
        metadataManager.portfolios
    }

    var currentPortfolio: Portfolio? {
        guard !portfolios.isEmpty, navState.currentIndex < portfolios.count else { return nil }
        return portfolios[navState.currentIndex]
    }

    var body: some View {
        HStack {
            // Left arrow for quick navigation when scrolled
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if navState.currentIndex > 0 {
                        navState.currentIndex -= 1
                    } else {
                        navState.currentIndex = max(0, portfolios.count - 1)
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(portfolios.count <= 1 ? AppTheme.Colors.textTertiary : AppTheme.Colors.textSecondary)
            }
            .disabled(portfolios.count <= 1)

            // Center content - current portfolio name in filing tab style
            if let portfolio = currentPortfolio {
                Button(action: {
                    router.navigateToPortfolio(id: portfolio.id)
                }) {
                    Text(portfolio.name)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(
                            FilingTabShape()
                                .fill(AppTheme.Colors.primary)
                        )
                }
                .frame(maxWidth: .infinity)
            } else {
                Button(action: {
                    router.presentSheet(.portfolioList)
                }) {
                    Text("Create Portfolio")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                Spacer()
            }

            // Right arrow for quick navigation when scrolled
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if navState.currentIndex < portfolios.count - 1 {
                        navState.currentIndex += 1
                    } else {
                        navState.currentIndex = 0
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(portfolios.count <= 1 ? AppTheme.Colors.textTertiary : AppTheme.Colors.textSecondary)
            }
            .disabled(portfolios.count <= 1)
        }
    }
}

// MARK: - Portfolio Navigator Section

/// Date-picker style navigator for portfolios
struct PortfolioNavigatorSection: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var navState: PortfolioNavigatorState
    @Binding var isSticky: Bool

    var portfolios: [Portfolio] {
        metadataManager.portfolios
    }

    var currentPortfolio: Portfolio? {
        guard !portfolios.isEmpty, navState.currentIndex < portfolios.count else { return nil }
        return portfolios[navState.currentIndex]
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Invisible tracker for sticky behavior
            Color.clear
                .frame(height: 1)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: NavigatorOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                    }
                )
                .onPreferenceChange(NavigatorOffsetPreferenceKey.self) { offset in
                    let shouldBeSticky = offset < 0
                    if shouldBeSticky != isSticky {
                        isSticky = shouldBeSticky
                    }
                }

            // Portfolio card with filing tabs
            if !portfolios.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    FullPortfolioCard(
                        portfolios: portfolios,
                        selectedIndex: $navState.currentIndex,
                        onAddTap: { router.presentSheet(.portfolioList) }
                    )
                    if let portfolio = currentPortfolio {
                        PortfolioManagementButtons(portfolio: portfolio)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .id(currentPortfolio?.id ?? "") // Force view refresh on change
            } else {
                EmptyPortfolioCard()
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .onChange(of: portfolios.count) { newCount in
            if navState.currentIndex >= newCount {
                navState.currentIndex = max(0, newCount - 1)
            }
        }
    }
}

// MARK: - Navigator Offset Preference Key

/// Preference key to track the navigator's scroll position
struct NavigatorOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Filing Tab Shape

/// A shape that creates a filing tab appearance with rounded top corners
/// and a flat bottom edge that connects to the card below
struct FilingTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topCornerRadius: CGFloat = 8

        var path = Path()

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: rect.height))

        // Left edge up to top-left corner
        path.addLine(to: CGPoint(x: 0, y: topCornerRadius))

        // Top-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: topCornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Top edge
        path.addLine(to: CGPoint(x: rect.width - topCornerRadius, y: 0))

        // Top-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: topCornerRadius),
            control: CGPoint(x: rect.width, y: 0)
        )

        // Right edge down
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))

        path.closeSubpath()
        return path
    }
}

// MARK: - Filing Tabs Row

/// Preference key for tracking scroll offset
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Preference key for tracking content width
private struct ContentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Horizontal row of portfolio tabs arranged like a filing cabinet
/// Oldest portfolios on the left, plus button on the right
struct FilingTabsRow: View {
    let portfolios: [Portfolio]
    @Binding var selectedIndex: Int
    let onAddTap: () -> Void

    @EnvironmentObject var router: NavigationRouter

    // Track scroll offset to show/hide edge fades
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    /// Portfolios sorted by creation date (oldest first)
    var sortedPortfolios: [Portfolio] {
        portfolios.sorted { $0.createdDate < $1.createdDate }
    }

    /// Find the index in sorted array for the currently selected portfolio
    var selectedPortfolioId: String? {
        guard selectedIndex < portfolios.count else { return nil }
        return portfolios[selectedIndex].id
    }

    // Show left fade when scrolled right (content hidden on left)
    private var showLeftFade: Bool {
        // Always show left fade when there are multiple portfolios for testing
        return portfolios.count > 1
    }

    // Show right fade when more content exists on right
    // Show by default until we confirm all content is visible
    private var showRightFade: Bool {
        // If we haven't measured yet, show fade if we have multiple portfolios
        if contentWidth == 0 || containerWidth == 0 {
            return portfolios.count > 1
        }
        let maxOffset = contentWidth - containerWidth
        return maxOffset > 10 && scrollOffset < maxOffset - 10
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main scrollable content
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: -4) {
                            // Portfolio tabs (oldest to newest)
                            ForEach(Array(sortedPortfolios.enumerated()), id: \.element.id) { index, portfolio in
                                let isSelected = portfolio.id == selectedPortfolioId

                                FilingTab(
                                    title: portfolio.name,
                                    isSelected: isSelected,
                                    onTap: {
                                        // Find original index in unsorted array
                                        if let originalIndex = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedIndex = originalIndex
                                            }
                                        }
                                    },
                                    onDoubleTap: {
                                        router.navigateToPortfolio(id: portfolio.id)
                                    }
                                )
                                .id(portfolio.id)
                                .zIndex(isSelected ? 10 : Double(sortedPortfolios.count - index))
                            }

                            // Plus button tab on the right
                            AddFilingTab(onTap: onAddTap)
                                .padding(.leading, AppTheme.Spacing.sm)
                                .zIndex(0)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.leading, AppTheme.Spacing.sm)
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: -contentGeometry.frame(in: .named("tabsScroll")).origin.x
                                    )
                                    .preference(
                                        key: ContentWidthPreferenceKey.self,
                                        value: contentGeometry.size.width
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "tabsScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    .onPreferenceChange(ContentWidthPreferenceKey.self) { value in
                        contentWidth = value
                    }
                    .onChange(of: selectedPortfolioId) { newId in
                        if let id = newId {
                            withAnimation {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }

                // Left fade gradient overlay
                if showLeftFade {
                    HStack {
                        LinearGradient(
                            colors: [AppTheme.Colors.background, AppTheme.Colors.background.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 40)
                        .allowsHitTesting(false)

                        Spacer()
                    }
                    .transition(.opacity)
                }

                // Right fade gradient overlay
                if showRightFade {
                    HStack {
                        Spacer()

                        LinearGradient(
                            colors: [AppTheme.Colors.background.opacity(0), AppTheme.Colors.background],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 40)
                        .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                containerWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { newWidth in
                containerWidth = newWidth
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Filing Tab

/// Individual filing tab for a portfolio
struct FilingTab: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    private let selectedHeight: CGFloat = 36
    private let unselectedHeight: CGFloat = 28

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(isSelected ? AppTheme.Typography.subheadline : AppTheme.Typography.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : .white)
                .lineLimit(1)
                .padding(.horizontal, isSelected ? AppTheme.Spacing.md : AppTheme.Spacing.sm)
                .frame(height: isSelected ? selectedHeight : unselectedHeight)
                .frame(maxWidth: isSelected ? .none : 100)
                .background(
                    FilingTabShape()
                        .fill(isSelected ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                )
                .overlay(
                    FilingTabShape()
                        .stroke(
                            isSelected ? AppTheme.Colors.divider : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { onDoubleTap() }
        )
    }
}

// MARK: - Add Filing Tab

/// Plus button tab for adding new portfolios
struct AddFilingTab: View {
    let onTap: () -> Void

    private let tabHeight: CGFloat = 28

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: tabHeight)
                .background(
                    FilingTabShape()
                        .fill(AppTheme.Colors.secondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Full Portfolio Card

/// Full-size portfolio card with progress, quick actions, and expandable requirements
/// Now includes a row of filing tabs for all portfolios
struct FullPortfolioCard: View {
    let portfolios: [Portfolio]
    @Binding var selectedIndex: Int
    let onAddTap: () -> Void

    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var showExportSheet: Bool = false
    @State private var showPremiumPaywall: Bool = false

    /// Currently selected portfolio
    var portfolio: Portfolio {
        guard selectedIndex < portfolios.count else {
            return portfolios.first ?? Portfolio(name: "")
        }
        return portfolios[selectedIndex]
    }

    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    var isComplete: Bool {
        stats.total > 0 && stats.fulfilled >= stats.total
    }

    var dueStatus: (text: String, color: Color, icon: String) {
        guard let dueDate = portfolio.dueDate else {
            return ("No deadline", AppTheme.Colors.textTertiary, "calendar")
        }

        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if days < 0 {
            let absDays = abs(days)
            return ("Overdue by \(absDays) day\(absDays == 1 ? "" : "s")", AppTheme.Colors.error, "exclamationmark.circle.fill")
        } else if days == 0 {
            return ("Due today", AppTheme.Colors.error, "exclamationmark.circle.fill")
        } else if days == 1 {
            return ("Due tomorrow", AppTheme.Colors.warning, "clock.fill")
        } else if days <= 7 {
            return ("Due in \(days) days", AppTheme.Colors.warning, "clock")
        } else {
            return ("Due in \(days) days", AppTheme.Colors.textSecondary, "calendar")
        }
    }

    /// Find first incomplete requirement for capture navigation
    var firstIncompleteRequirement: (procedure: String, stage: String?, angle: String?)? {
        for requirement in portfolio.requirements {
            for stage in requirement.stages {
                for angle in requirement.angles {
                    let count = metadataManager.getMatchingPhotoCount(
                        procedure: requirement.procedure,
                        stage: stage,
                        angle: angle
                    )
                    let needed = requirement.angleCounts[angle] ?? 1
                    if count < needed {
                        return (requirement.procedure, stage, angle)
                    }
                }
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Filing tabs row showing all portfolios
            FilingTabsRow(
                portfolios: portfolios,
                selectedIndex: $selectedIndex,
                onAddTap: onAddTap
            )
            .padding(.horizontal, AppTheme.Spacing.md)

            // Main card body
            cardBodySection
                .padding(.horizontal, AppTheme.Spacing.md)
        }
        .sheet(isPresented: $showExportSheet) {
            PortfolioExportSheet(portfolio: portfolio, isPresented: $showExportSheet)
        }
        .premiumGate(for: .portfolioExport, showPaywall: $showPremiumPaywall)
    }

    // MARK: - Card Body Section

    /// Main card body with the new background color (#FAFFFF)
    private var cardBodySection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // 1. Progress Section (tappable)
            progressSection

            // 2. Requirements Section (expandable)
            requirementsSection

            // 3. Quick Actions Section
            quickActionsSection
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadowMedium()
    }

    // MARK: - Progress Section

    /// Formatted due date string
    private var formattedDueDate: String? {
        guard let dueDate = portfolio.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: dueDate)
    }

    private var progressSection: some View {
        Button(action: {
            router.navigateToPortfolio(id: portfolio.id)
        }) {
            VStack(spacing: AppTheme.Spacing.md) {
                // Progress ring on left, stats on right
                HStack {
                    // Progress ring with custom label
                    ZStack {
                        DPProgressRing(
                            progress: progress,
                            size: 100,
                            lineWidth: 8,
                            foregroundColor: isComplete ? AppTheme.Colors.success : nil,
                            showLabel: false
                        )

                        // Custom two-line label
                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(AppTheme.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("complete")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                    }

                    Spacer()

                    // Stats arranged vertically, aligned to right
                    VStack(alignment: .trailing, spacing: AppTheme.Spacing.sm) {
                        statItemHorizontal(
                            value: "\(stats.fulfilled)",
                            label: "Complete",
                            color: AppTheme.Colors.success
                        )

                        statItemHorizontal(
                            value: "\(stats.total - stats.fulfilled)",
                            label: "Remaining",
                            color: (stats.total - stats.fulfilled) > 0 ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary
                        )

                        statItemHorizontal(
                            value: "\(stats.total)",
                            label: "Total",
                            color: AppTheme.Colors.textSecondary
                        )
                    }
                }

                // Due date status badge with actual date
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: dueStatus.icon)
                        .font(.system(size: 16))
                    Text(dueStatus.text)
                        .font(AppTheme.Typography.subheadline)
                    if let dateString = formattedDueDate {
                        Text("•")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(dueStatus.color.opacity(0.6))
                        Text(dateString)
                            .font(AppTheme.Typography.subheadline)
                    }
                }
                .foregroundStyle(dueStatus.color)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(dueStatus.color.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.small)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Horizontal stat item with dotted line between number and label
    private func statItemHorizontal(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 0) {
            // Number aligned to left
            Text(value)
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .frame(width: 24, alignment: .leading)

            // Dotted line spacer
            DottedLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .foregroundStyle(AppTheme.Colors.textTertiary.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 2)

            // Label aligned to right
            Text(label)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(width: 120)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Quick Actions")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.bottom, AppTheme.Spacing.xxs)

            // Capture Missing Photos
            QuickActionButton(
                icon: "camera.fill",
                iconColor: AppTheme.Colors.primary,
                title: "Capture Missing Photos",
                subtitle: isComplete ? "All photos captured" : "\(stats.total - stats.fulfilled) photos needed",
                isDisabled: isComplete
            ) {
                if let incomplete = firstIncompleteRequirement {
                    router.navigateToCapture(
                        procedure: incomplete.procedure,
                        stage: incomplete.stage,
                        angle: incomplete.angle,
                        forPortfolioId: portfolio.id
                    )
                }
            }

            // Export Portfolio
            QuickActionButton(
                icon: "square.and.arrow.up",
                iconColor: AppTheme.Colors.success,
                title: "Export Portfolio",
                subtitle: "ZIP or individual files",
                isDisabled: stats.fulfilled == 0
            ) {
                requirePremium(.portfolioExport, showPaywall: $showPremiumPaywall) {
                    showExportSheet = true
                }
            }
        }
    }

    // MARK: - Requirements Section

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header (non-collapsible)
            Text("Requirements")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.bottom, AppTheme.Spacing.xxs)

            // Always-visible requirements list with expandable items
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(portfolio.requirements) { requirement in
                    ExpandableRequirementRow(
                        requirement: requirement,
                        portfolioId: portfolio.id,
                        metadataManager: metadataManager
                    )
                }
            }
        }
    }

    // MARK: - Helper Views

    func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Dotted Line Shape

/// A horizontal dotted line shape for connecting elements
struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Expandable Requirement Row

/// A requirement row that can be expanded to show stage/angle details
/// Features: progress ring with count inside, camera quick capture button
struct ExpandableRequirementRow: View {
    let requirement: PortfolioRequirement
    let portfolioId: String
    @ObservedObject var metadataManager: MetadataManager
    @EnvironmentObject var router: NavigationRouter

    @State private var isExpanded: Bool = false

    /// Calculate fulfilled and total counts for this requirement
    var stats: (fulfilled: Int, total: Int) {
        var fulfilled = 0
        var total = 0

        for stage in requirement.stages {
            for angle in requirement.angles {
                let count = metadataManager.getMatchingPhotoCount(
                    procedure: requirement.procedure,
                    stage: stage,
                    angle: angle
                )
                let needed = requirement.angleCounts[angle] ?? 1
                fulfilled += min(count, needed)
                total += needed
            }
        }

        return (fulfilled, total)
    }

    var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    var isComplete: Bool {
        stats.fulfilled >= stats.total
    }

    /// Find first incomplete stage/angle combo for this requirement
    var firstIncompleteCombo: (stage: String, angle: String)? {
        for stage in requirement.stages {
            for angle in requirement.angles {
                let count = metadataManager.getMatchingPhotoCount(
                    procedure: requirement.procedure,
                    stage: stage,
                    angle: angle
                )
                let needed = requirement.angleCounts[angle] ?? 1
                if count < needed {
                    return (stage, angle)
                }
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: AppTheme.Spacing.md) {
                // Expand/collapse button with procedure info
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        // Chevron indicator
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                            .frame(width: 16)

                        // Procedure color indicator
                        Circle()
                            .fill(AppTheme.procedureColor(for: requirement.procedure))
                            .frame(width: 12, height: 12)

                        // Procedure name
                        Text(requirement.procedure)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Progress ring with count inside
                ZStack {
                    DPProgressRing(
                        progress: progress,
                        size: 40,
                        lineWidth: 4,
                        foregroundColor: isComplete ? AppTheme.Colors.success : nil,
                        showLabel: false
                    )

                    // Count inside the ring
                    Text("\(stats.fulfilled)/\(stats.total)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                }

                // Quick capture camera button
                Button(action: {
                    if let combo = firstIncompleteCombo {
                        router.navigateToCapture(
                            procedure: requirement.procedure,
                            stage: combo.stage,
                            angle: combo.angle,
                            forPortfolioId: portfolioId
                        )
                    } else {
                        // All complete, still allow capture for this procedure
                        router.navigateToCapture(
                            procedure: requirement.procedure,
                            stage: requirement.stages.first,
                            angle: requirement.angles.first,
                            forPortfolioId: portfolioId
                        )
                    }
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isComplete ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isComplete ? AppTheme.Colors.surface : AppTheme.Colors.primary.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppTheme.Spacing.md)

            // Expanded details - show each stage/angle combination
            if isExpanded {
                VStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(requirement.stages, id: \.self) { stage in
                        ForEach(requirement.angles, id: \.self) { angle in
                            RequirementDetailRow(
                                procedure: requirement.procedure,
                                stage: stage,
                                angle: angle,
                                needed: requirement.angleCounts[angle] ?? 1,
                                portfolioId: portfolioId,
                                metadataManager: metadataManager
                            )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.textTertiary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Requirement Detail Row

/// Shows a single stage/angle combination with its completion status
struct RequirementDetailRow: View {
    let procedure: String
    let stage: String
    let angle: String
    let needed: Int
    let portfolioId: String
    @ObservedObject var metadataManager: MetadataManager
    @EnvironmentObject var router: NavigationRouter

    var count: Int {
        metadataManager.getMatchingPhotoCount(
            procedure: procedure,
            stage: stage,
            angle: angle
        )
    }

    var isComplete: Bool {
        count >= needed
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Indent space
            Spacer()
                .frame(width: 28)

            // Completion indicator
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)

            // Stage - Angle label
            Text("\(stage) • \(angle)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()

            // Count
            Text("\(min(count, needed))/\(needed)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)

            // Quick capture for this specific combo
            Button(action: {
                router.navigateToCapture(
                    procedure: procedure,
                    stage: stage,
                    angle: angle,
                    forPortfolioId: portfolioId
                )
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 12))
                    .foregroundStyle(isComplete ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isComplete)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.background.opacity(0.5))
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Portfolio Management Buttons

/// Standalone buttons for creating and deleting portfolios, displayed outside the card
struct PortfolioManagementButtons: View {
    let portfolio: Portfolio

    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Create Portfolio Button
            Button(action: {
                router.presentSheet(.portfolioList)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Create Portfolio")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .buttonStyle(CardPressButtonStyle())

            // Delete Portfolio Button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                    Text("Delete Portfolio")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.Colors.error.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .buttonStyle(CardPressButtonStyle())
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .alert("Delete Portfolio", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePortfolio()
            }
        } message: {
            Text("Are you sure you want to delete \"\(portfolio.name)\"? This action cannot be undone.")
        }
    }

    private func deletePortfolio() {
        metadataManager.deletePortfolio(portfolio.id)
    }
}

// MARK: - Empty Portfolio Card

/// Empty state shown when no portfolios exist
struct EmptyPortfolioCard: View {
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        DPCard {
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.textTertiary)

                Text("No Portfolios Yet")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Create your first portfolio to track your progress")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                DPButton("Create Portfolio", style: .primary, size: .medium) {
                    router.presentSheet(.portfolioList)
                }
            }
            .padding(.vertical, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
                .environmentObject(NavigationRouter())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
#endif
