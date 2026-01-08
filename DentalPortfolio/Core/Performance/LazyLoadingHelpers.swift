// LazyLoadingHelpers.swift
// Dental Portfolio - Lazy Loading Utilities
//
// Provides lazy loading components for efficient data display
// with pagination, prefetching, and infinite scroll support.
//
// Features:
// - Lazy photo grid with automatic prefetching
// - Paginated list with load-more detection
// - Infinite scroll modifier
// - Visibility tracking for optimization

import SwiftUI
import Photos

// MARK: - Lazy Photo Grid

/// A lazy-loading photo grid with automatic prefetching and pagination
struct LazyPhotoGrid<Content: View>: View {
    let assets: [PHAsset]
    let columns: Int
    let spacing: CGFloat
    let onAppearThreshold: Int
    let onLoadMore: (() -> Void)?
    @ViewBuilder let content: (PHAsset) -> Content

    @State private var visibleRange: Range<Int> = 0..<0
    @State private var prefetcher = ImagePrefetcher()

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    private var thumbnailSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let itemWidth = (screenWidth - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        let scale = UIScreen.main.scale
        return CGSize(width: itemWidth * scale, height: itemWidth * scale)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    content(asset)
                        .onAppear {
                            handleItemAppear(index: index)
                        }
                        .onDisappear {
                            handleItemDisappear(index: index)
                        }
                }
            }
            .padding(spacing)
        }
        .onDisappear {
            prefetcher.reset()
        }
    }

    private func handleItemAppear(index: Int) {
        // Update visible range
        let newStart = min(visibleRange.lowerBound, index)
        let newEnd = max(visibleRange.upperBound, index + 1)
        visibleRange = newStart..<newEnd

        // Check if we need to load more
        if let onLoadMore = onLoadMore,
           index >= assets.count - onAppearThreshold {
            onLoadMore()
        }

        // Prefetch nearby images
        prefetchImages(around: index)
    }

    private func handleItemDisappear(index: Int) {
        // Cancel loading for off-screen items
        let asset = assets[index]
        let cacheKey = "\(asset.localIdentifier)-\(Int(thumbnailSize.width))x\(Int(thumbnailSize.height))"
        Task {
            await ImageCache.shared.cancelRequest(forKey: cacheKey)
        }
    }

    private func prefetchImages(around index: Int) {
        let prefetchRange = max(0, index - 10)..<min(assets.count, index + 20)
        let prefetchAssets = Array(assets[prefetchRange])

        prefetcher.prefetch(assets: prefetchAssets, targetSize: thumbnailSize)
    }
}

// MARK: - Paginated List

/// A list with built-in pagination support
struct PaginatedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let pageSize: Int
    let hasMorePages: Bool
    let isLoading: Bool
    let onLoadMore: () -> Void
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        List {
            ForEach(items) { item in
                content(item)
                    .onAppear {
                        checkLoadMore(item: item)
                    }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if hasMorePages {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        onLoadMore()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
    }

    private func checkLoadMore(item: Item) {
        guard hasMorePages, !isLoading else { return }

        // Load more when reaching last few items
        if let index = items.firstIndex(where: { $0.id == item.id }),
           index >= items.count - 5 {
            onLoadMore()
        }
    }
}

// MARK: - Infinite Scroll Modifier

/// Modifier that adds infinite scroll behavior to scrollable views
struct InfiniteScrollModifier: ViewModifier {
    let isLoading: Bool
    let hasMoreContent: Bool
    let threshold: Int
    let loadMore: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isLoading {
                    loadingIndicator
                }
            }
    }

    private var loadingIndicator: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))

            Text("Loading...")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            Capsule()
                .fill(AppTheme.Colors.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.bottom, AppTheme.Spacing.lg)
    }
}

extension View {
    /// Add infinite scroll behavior
    /// - Parameters:
    ///   - isLoading: Whether currently loading more content
    ///   - hasMoreContent: Whether more content is available
    ///   - threshold: Number of items from end to trigger load
    ///   - loadMore: Action to load more content
    func infiniteScroll(
        isLoading: Bool,
        hasMoreContent: Bool,
        threshold: Int = 5,
        loadMore: @escaping () -> Void
    ) -> some View {
        modifier(InfiniteScrollModifier(
            isLoading: isLoading,
            hasMoreContent: hasMoreContent,
            threshold: threshold,
            loadMore: loadMore
        ))
    }
}

// MARK: - Load More Trigger View

/// Invisible view that triggers loading when it appears
struct LoadMoreTrigger: View {
    let isLoading: Bool
    let hasMore: Bool
    let onLoadMore: () -> Void

    var body: some View {
        Group {
            if hasMore && !isLoading {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        onLoadMore()
                    }
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Visibility Tracker

/// Tracks which items are visible in a scrollable view
struct VisibilityTracker<Item: Hashable>: ViewModifier {
    let item: Item
    @Binding var visibleItems: Set<Item>

    func body(content: Content) -> some View {
        content
            .onAppear {
                visibleItems.insert(item)
            }
            .onDisappear {
                visibleItems.remove(item)
            }
    }
}

extension View {
    /// Track visibility of this view
    /// - Parameters:
    ///   - item: Item to track
    ///   - visibleItems: Set of currently visible items
    func trackVisibility<Item: Hashable>(
        _ item: Item,
        visibleItems: Binding<Set<Item>>
    ) -> some View {
        modifier(VisibilityTracker(item: item, visibleItems: visibleItems))
    }
}

// MARK: - Lazy Section

/// A section that lazily loads its content
struct LazySection<Header: View, Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            if isExpanded {
                content()
            }
        } header: {
            header()
        }
    }
}

// MARK: - On Scroll Position Change

/// Modifier that reports scroll position changes
struct ScrollPositionModifier: ViewModifier {
    let coordinateSpace: String
    let onPositionChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named(coordinateSpace)).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                onPositionChange(value)
            }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Track scroll position changes
    /// - Parameters:
    ///   - coordinateSpace: Named coordinate space to track within
    ///   - onPositionChange: Called when position changes
    func onScrollPositionChange(
        coordinateSpace: String = "scroll",
        onPositionChange: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(ScrollPositionModifier(
            coordinateSpace: coordinateSpace,
            onPositionChange: onPositionChange
        ))
    }
}

// MARK: - Batch Loading Helper

/// Manages batch loading of items
class BatchLoader<Item>: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    @Published var error: Error?

    private let pageSize: Int
    private var currentPage: Int = 0
    private let loadPage: (Int, Int) async throws -> [Item]

    init(
        pageSize: Int = 20,
        loadPage: @escaping (Int, Int) async throws -> [Item]
    ) {
        self.pageSize = pageSize
        self.loadPage = loadPage
    }

    @MainActor
    func loadInitial() async {
        currentPage = 0
        items = []
        hasMore = true
        error = nil
        await loadNext()
    }

    @MainActor
    func loadNext() async {
        guard !isLoading, hasMore else { return }

        isLoading = true
        error = nil

        do {
            let newItems = try await loadPage(currentPage, pageSize)
            items.append(contentsOf: newItems)
            hasMore = newItems.count >= pageSize
            currentPage += 1
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func reset() {
        currentPage = 0
        items = []
        hasMore = true
        error = nil
        isLoading = false
    }
}

// MARK: - Preview Provider

#if DEBUG
struct LazyLoadingHelpers_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(0..<20, id: \.self) { index in
                    Text("Item \(index)")
                }

                LoadMoreTrigger(
                    isLoading: true,
                    hasMore: true,
                    onLoadMore: {}
                )
            }
            .navigationTitle("Lazy Loading")
        }
    }
}
#endif
