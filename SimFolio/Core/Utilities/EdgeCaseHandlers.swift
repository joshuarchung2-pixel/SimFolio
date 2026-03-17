// EdgeCaseHandlers.swift
// SimFolio - Edge Case Handling Views and Utilities
//
// Provides views and utilities for handling edge cases in the UI.
// Includes safe image loading, bounds checking, and navigation guards.

import SwiftUI
import Photos

// MARK: - Safe Async Image Loading

/// Safely loads images from PHAsset with loading and error states
struct SafeAsyncImage: View {
    let asset: PHAsset?
    let targetSize: CGSize
    var contentMode: ContentMode = .fill
    var placeholder: AnyView?
    var errorView: AnyView?

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loadFailed {
                errorContent
            } else if isLoading {
                loadingContent
            } else {
                errorContent
            }
        }
        .task(id: asset?.localIdentifier) {
            await loadImage()
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        if let placeholder = placeholder {
            placeholder
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                )
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let errorView = errorView {
            errorView
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                        .font(.title2)
                )
        }
    }

    private func loadImage() async {
        guard let asset = asset else {
            loadFailed = true
            isLoading = false
            return
        }

        isLoading = true
        loadFailed = false

        let loaded = await loadImageFromAsset(asset)
        image = loaded
        loadFailed = loaded == nil
        isLoading = false
    }

    private func loadImageFromAsset(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode == .fill ? .aspectFill : .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil

                // Only continue if we have the final image
                if !isDegraded && !isCancelled {
                    if hasError || image == nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: image)
                    }
                }
            }
        }
    }
}

// MARK: - Safe Navigation Link

/// Navigation link with guard condition and fallback
struct SafeNavigationLink<Label: View, Destination: View>: View {
    let condition: Bool
    let destination: () -> Destination
    let label: () -> Label
    let fallbackAction: (() -> Void)?
    let fallbackMessage: String

    @State private var showFallbackAlert = false

    init(
        isActive condition: Bool,
        fallbackMessage: String = "This content is not available.",
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label,
        fallbackAction: (() -> Void)? = nil
    ) {
        self.condition = condition
        self.fallbackMessage = fallbackMessage
        self.destination = destination
        self.label = label
        self.fallbackAction = fallbackAction
    }

    var body: some View {
        if condition {
            NavigationLink(destination: destination, label: label)
        } else {
            Button(action: {
                if let fallback = fallbackAction {
                    fallback()
                } else {
                    showFallbackAlert = true
                }
            }, label: label)
            .alert("Not Available", isPresented: $showFallbackAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(fallbackMessage)
            }
        }
    }
}

// MARK: - Guarded View

/// View that shows content only when condition is met
struct GuardedView<Content: View, Fallback: View>: View {
    let condition: Bool
    let content: () -> Content
    let fallback: () -> Fallback

    init(
        _ condition: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.condition = condition
        self.content = content
        self.fallback = fallback
    }

    var body: some View {
        if condition {
            content()
        } else {
            fallback()
        }
    }
}

// MARK: - Optional View

/// View that unwraps an optional and provides the value to content
struct OptionalView<T, Content: View, Fallback: View>: View {
    let value: T?
    let content: (T) -> Content
    let fallback: () -> Fallback

    init(
        _ value: T?,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.value = value
        self.content = content
        self.fallback = fallback
    }

    var body: some View {
        if let value = value {
            content(value)
        } else {
            fallback()
        }
    }
}

// MARK: - Safe ForEach with Empty State

/// ForEach with built-in empty state handling
struct SafeForEach<Data: RandomAccessCollection, Content: View, Empty: View>: View
where Data.Element: Identifiable {

    let data: Data
    let content: (Data.Element) -> Content
    let emptyView: () -> Empty

    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content,
        @ViewBuilder empty: @escaping () -> Empty
    ) {
        self.data = data
        self.content = content
        self.emptyView = empty
    }

    var body: some View {
        if data.isEmpty {
            emptyView()
        } else {
            ForEach(data) { item in
                content(item)
            }
        }
    }
}

// MARK: - Bounds-Checked Selection

/// Manages a selection that stays within valid bounds
@propertyWrapper
struct BoundsCheckedSelection<ID: Hashable> {
    private var _selection: ID?
    private var validIDs: Set<ID>

    var wrappedValue: ID? {
        get {
            guard let selection = _selection, validIDs.contains(selection) else {
                return nil
            }
            return selection
        }
        set {
            if let id = newValue, validIDs.contains(id) {
                _selection = id
            } else {
                _selection = nil
            }
        }
    }

    init(wrappedValue: ID?, validIDs: Set<ID> = []) {
        self._selection = wrappedValue
        self.validIDs = validIDs
    }

    mutating func updateValidIDs(_ ids: Set<ID>) {
        validIDs = ids
        // Clear selection if no longer valid
        if let selection = _selection, !validIDs.contains(selection) {
            _selection = nil
        }
    }
}

// MARK: - Safe Sheet Presentation

/// Sheet modifier with safe dismissal
struct SafeSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let content: () -> SheetContent

    @State private var isDismissing = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if !isDismissing {
                    onDismiss?()
                }
            } content: {
                self.content()
                    .onDisappear {
                        // Ensure state is consistent
                        if isPresented {
                            isDismissing = true
                            isPresented = false
                            DispatchQueue.main.async {
                                isDismissing = false
                            }
                        }
                    }
            }
    }
}

extension View {
    func safeSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SafeSheetModifier(isPresented: isPresented, onDismiss: onDismiss, content: content))
    }
}

// MARK: - Tap Debouncer

/// Prevents rapid tap gestures
struct DebouncedTapModifier: ViewModifier {
    let action: () -> Void
    let debounceTime: TimeInterval

    @State private var lastTapTime: Date?

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                let now = Date()
                if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < debounceTime {
                    return
                }
                lastTapTime = now
                action()
            }
    }
}

extension View {
    /// Add debounced tap gesture
    func onDebouncedTap(debounceTime: TimeInterval = 0.3, perform action: @escaping () -> Void) -> some View {
        modifier(DebouncedTapModifier(action: action, debounceTime: debounceTime))
    }
}

// MARK: - Safe Button

/// Button that prevents double-taps and shows loading state
struct SafeButton<Label: View>: View {
    let action: () async -> Void
    let label: () -> Label

    @State private var isLoading = false
    @State private var lastTapTime: Date?

    private let debounceTime: TimeInterval = 0.5

    init(action: @escaping () async -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            guard !isLoading else { return }

            let now = Date()
            if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < debounceTime {
                return
            }
            lastTapTime = now

            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            if isLoading {
                ProgressView()
            } else {
                label()
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Clamp Value

/// Clamps a value to a range
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Safe Progress Value

/// Ensures progress value is between 0 and 1
struct SafeProgressValue {
    let value: Double

    init(_ value: Double) {
        self.value = value.clamped(to: 0...1)
    }

    init(current: Int, total: Int) {
        if total <= 0 {
            self.value = 0
        } else {
            self.value = Double(max(0, current)) / Double(total)
        }
    }
}

// MARK: - Nil-Coalescing ForEach

/// ForEach that handles nil data
struct NilCoalescingForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    let data: Data?
    let id: KeyPath<Data.Element, ID>
    let content: (Data.Element) -> Content

    var body: some View {
        if let data = data {
            ForEach(data, id: id) { item in
                content(item)
            }
        }
    }
}
