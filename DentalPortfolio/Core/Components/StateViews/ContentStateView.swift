// ContentStateView.swift
// Dental Portfolio - Content State Wrapper
//
// Generic wrapper view for handling loading, loaded, empty, and error states.
// Simplifies state management in views with async content.
//
// Contents:
// - ContentState: Enum representing possible content states
// - ContentStateView: Generic view that displays appropriate UI for each state

import SwiftUI

// MARK: - Content State

/// Represents the possible states of async content
enum ContentState<T> {
    /// Content is loading
    case loading
    /// Content loaded successfully
    case loaded(T)
    /// Content is empty (loaded but no data)
    case empty
    /// An error occurred
    case error(Error)
}

// MARK: - ContentStateView

/// Generic view that displays appropriate UI based on content state
struct ContentStateView<T, Content: View, EmptyContent: View, LoadingContent: View>: View {
    let state: ContentState<T>
    let content: (T) -> Content
    let emptyContent: () -> EmptyContent
    let loadingContent: () -> LoadingContent
    var onRetry: (() -> Void)? = nil

    init(
        state: ContentState<T>,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.emptyContent = emptyContent
        self.loadingContent = loadingContent
        self.onRetry = onRetry
    }

    var body: some View {
        switch state {
        case .loading:
            loadingContent()
        case .loaded(let data):
            content(data)
        case .empty:
            emptyContent()
        case .error(let error):
            ErrorView(
                title: "Error Loading Content",
                message: error.localizedDescription,
                retryAction: onRetry
            )
        }
    }
}

// MARK: - Convenience Initializers

extension ContentStateView where LoadingContent == LoadingView {
    /// Initialize with default full-screen loading view
    init(
        state: ContentState<T>,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.emptyContent = emptyContent
        self.loadingContent = { LoadingView(style: .fullScreen) }
        self.onRetry = onRetry
    }
}

extension ContentStateView where LoadingContent == LoadingView, EmptyContent == EmptyStateView {
    /// Initialize with default loading and empty views
    init(
        state: ContentState<T>,
        emptyIcon: String = "tray",
        emptyTitle: String = "No Content",
        emptyMessage: String = "There's nothing to show here.",
        @ViewBuilder content: @escaping (T) -> Content,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.emptyContent = {
            EmptyStateView(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage
            )
        }
        self.loadingContent = { LoadingView(style: .fullScreen) }
        self.onRetry = onRetry
    }
}

// MARK: - Simple State View

/// Simplified content state view with default components
struct SimpleContentStateView<T, Content: View>: View {
    let state: ContentState<T>
    let emptyConfig: EmptyStateConfig
    let content: (T) -> Content
    var onRetry: (() -> Void)? = nil

    struct EmptyStateConfig {
        let icon: String
        let title: String
        let message: String
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil

        static var `default`: EmptyStateConfig {
            EmptyStateConfig(
                icon: "tray",
                title: "No Content",
                message: "There's nothing to show here."
            )
        }
    }

    init(
        state: ContentState<T>,
        emptyConfig: EmptyStateConfig = .default,
        @ViewBuilder content: @escaping (T) -> Content,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.emptyConfig = emptyConfig
        self.content = content
        self.onRetry = onRetry
    }

    var body: some View {
        switch state {
        case .loading:
            LoadingView(style: .fullScreen)

        case .loaded(let data):
            content(data)

        case .empty:
            EmptyStateView(
                icon: emptyConfig.icon,
                title: emptyConfig.title,
                message: emptyConfig.message,
                actionTitle: emptyConfig.actionTitle,
                action: emptyConfig.action
            )

        case .error(let error):
            ErrorView(
                title: "Error Loading Content",
                message: error.localizedDescription,
                retryAction: onRetry
            )
        }
    }
}

// MARK: - State View Modifier

/// ViewModifier for adding state handling to any view
struct StateOverlayModifier<T>: ViewModifier {
    let state: ContentState<T>
    var onRetry: (() -> Void)? = nil

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(shouldShowContent ? 1 : 0)

            switch state {
            case .loading:
                LoadingView(style: .fullScreen)
            case .empty:
                EmptyStateView(
                    icon: "tray",
                    title: "No Content",
                    message: "There's nothing to show here."
                )
            case .error(let error):
                ErrorView(
                    title: "Error",
                    message: error.localizedDescription,
                    retryAction: onRetry
                )
            case .loaded:
                EmptyView()
            }
        }
    }

    private var shouldShowContent: Bool {
        if case .loaded = state {
            return true
        }
        return false
    }
}

extension View {
    /// Add state overlay to handle loading, empty, and error states
    func stateOverlay<T>(
        _ state: ContentState<T>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(StateOverlayModifier(state: state, onRetry: onRetry))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ContentStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading state
            ContentStateView(
                state: ContentState<[String]>.loading,
                content: { items in
                    List(items, id: \.self) { item in
                        Text(item)
                    }
                },
                emptyContent: {
                    EmptyStateView.noPhotos()
                }
            )
            .previewDisplayName("Loading State")

            // Loaded state
            ContentStateView(
                state: ContentState.loaded(["Item 1", "Item 2", "Item 3"]),
                content: { items in
                    List(items, id: \.self) { item in
                        Text(item)
                    }
                },
                emptyContent: {
                    EmptyStateView.noPhotos()
                }
            )
            .previewDisplayName("Loaded State")

            // Empty state
            ContentStateView(
                state: ContentState<[String]>.empty,
                content: { items in
                    List(items, id: \.self) { item in
                        Text(item)
                    }
                },
                emptyContent: {
                    EmptyStateView.noPhotos {
                        print("Capture tapped")
                    }
                }
            )
            .previewDisplayName("Empty State")

            // Error state
            ContentStateView(
                state: ContentState<[String]>.error(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load data"])),
                content: { items in
                    List(items, id: \.self) { item in
                        Text(item)
                    }
                },
                emptyContent: {
                    EmptyStateView.noPhotos()
                },
                onRetry: {
                    print("Retry tapped")
                }
            )
            .previewDisplayName("Error State")

            // Simple content state view
            SimpleContentStateView(
                state: ContentState<[String]>.empty,
                emptyConfig: .init(
                    icon: "photo.stack",
                    title: "No Photos",
                    message: "Your photos will appear here.",
                    actionTitle: "Take Photo",
                    action: { print("Take photo") }
                ),
                content: { items in
                    List(items, id: \.self) { Text($0) }
                }
            )
            .previewDisplayName("Simple Content State")
        }
    }
}
#endif
