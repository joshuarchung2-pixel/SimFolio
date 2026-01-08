// ViewPerformanceHelpers.swift
// Dental Portfolio - View Performance Utilities
//
// Provides performance optimization utilities for SwiftUI views
// including debouncing, throttling, and efficient rendering.
//
// Features:
// - Debounced state property wrapper
// - Throttled action execution
// - Lazy view loading
// - Conditional modifiers
// - Drawing optimization
// - Task debouncing

import SwiftUI
import Combine

// MARK: - Equatable View Wrapper

/// Wraps a view with an equatable value to prevent unnecessary redraws
struct EquatableView<Content: View, Value: Equatable>: View, Equatable {
    let content: Content
    let value: Value

    init(value: Value, @ViewBuilder content: () -> Content) {
        self.value = value
        self.content = content()
    }

    var body: some View {
        content
    }

    static func == (lhs: EquatableView, rhs: EquatableView) -> Bool {
        lhs.value == rhs.value
    }
}

// MARK: - Draw Performance Modifier

/// Modifier that optimizes drawing performance
struct DrawPerformanceModifier: ViewModifier {
    let enabled: Bool
    let isOpaque: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .drawingGroup(opaque: isOpaque)
        } else {
            content
        }
    }
}

extension View {
    /// Apply drawing group optimization for complex views
    /// - Parameters:
    ///   - enabled: Whether to enable optimization
    ///   - opaque: Whether the content is opaque
    func optimizedDrawing(_ enabled: Bool = true, opaque: Bool = false) -> some View {
        modifier(DrawPerformanceModifier(enabled: enabled, isOpaque: opaque))
    }
}

// MARK: - Debounced State

/// Property wrapper that debounces state changes
@propertyWrapper
struct DebouncedState<Value>: DynamicProperty {
    @State private var value: Value
    @State private var debouncedValue: Value
    @State private var debounceTask: Task<Void, Never>?

    private let delay: TimeInterval

    init(wrappedValue: Value, delay: TimeInterval = 0.3) {
        self._value = State(initialValue: wrappedValue)
        self._debouncedValue = State(initialValue: wrappedValue)
        self.delay = delay
    }

    var wrappedValue: Value {
        get { value }
        nonmutating set {
            value = newValue
            debounce()
        }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { debouncedValue },
            set: { _ in }
        )
    }

    private func debounce() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            debouncedValue = value
        }
    }
}

// MARK: - Throttled Action

/// Throttles action execution to prevent rapid firing
class ThrottledAction {
    private var lastExecutionTime: Date?
    private let minimumInterval: TimeInterval
    private let queue: DispatchQueue

    init(minimumInterval: TimeInterval = 0.3, queue: DispatchQueue = .main) {
        self.minimumInterval = minimumInterval
        self.queue = queue
    }

    /// Execute action if minimum interval has passed
    /// - Parameter action: Action to execute
    func execute(_ action: @escaping () -> Void) {
        let now = Date()

        if let lastTime = lastExecutionTime,
           now.timeIntervalSince(lastTime) < minimumInterval {
            return
        }

        lastExecutionTime = now
        queue.async {
            action()
        }
    }

    /// Execute async action if minimum interval has passed
    /// - Parameter action: Async action to execute
    func executeAsync(_ action: @escaping () async -> Void) {
        let now = Date()

        if let lastTime = lastExecutionTime,
           now.timeIntervalSince(lastTime) < minimumInterval {
            return
        }

        lastExecutionTime = now
        Task {
            await action()
        }
    }

    /// Reset the throttle timer
    func reset() {
        lastExecutionTime = nil
    }
}

// MARK: - Lazy View

/// Lazily constructs a view only when needed
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

// MARK: - Conditional Modifier

extension View {
    /// Apply a transform conditionally
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - transform: Transform to apply if condition is true
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a transform based on optional value
    /// - Parameters:
    ///   - value: Optional value
    ///   - transform: Transform to apply if value exists
    @ViewBuilder
    func ifLet<Value, Transform: View>(
        _ value: Value?,
        transform: (Self, Value) -> Transform
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    /// Apply different transforms based on condition
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - ifTrue: Transform if true
    ///   - ifFalse: Transform if false
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTrue: (Self) -> TrueContent,
        else ifFalse: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }
}

// MARK: - Task Debouncer

/// Actor that debounces async tasks
actor TaskDebouncer {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    /// Debounce an async action
    /// - Parameter action: Action to debounce
    func debounce(action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancel pending debounced action
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Debounced Search

/// Observable object for debounced search functionality
class DebouncedSearch: ObservableObject {
    @Published var searchText: String = ""
    @Published var debouncedText: String = ""

    private var cancellable: AnyCancellable?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
        setupDebounce()
    }

    private func setupDebounce() {
        cancellable = $searchText
            .debounce(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.debouncedText = value
            }
    }

    /// Clear search
    func clear() {
        searchText = ""
    }
}

// MARK: - Rate Limiter

/// Limits the rate of action execution
class RateLimiter {
    private let limit: Int
    private let interval: TimeInterval
    private var executionTimes: [Date] = []
    private let lock = NSLock()

    init(limit: Int, per interval: TimeInterval) {
        self.limit = limit
        self.interval = interval
    }

    /// Check if action can be executed
    var canExecute: Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let cutoff = now.addingTimeInterval(-interval)

        // Remove old executions
        executionTimes = executionTimes.filter { $0 > cutoff }

        return executionTimes.count < limit
    }

    /// Execute action if within rate limit
    /// - Parameter action: Action to execute
    /// - Returns: Whether action was executed
    @discardableResult
    func execute(_ action: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let cutoff = now.addingTimeInterval(-interval)

        // Remove old executions
        executionTimes = executionTimes.filter { $0 > cutoff }

        guard executionTimes.count < limit else {
            return false
        }

        executionTimes.append(now)
        action()
        return true
    }

    /// Reset rate limiter
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        executionTimes.removeAll()
    }
}

// MARK: - Animation Reducer

/// Reduces animation complexity under system load
struct AnimationReducer {
    static var shouldReduceAnimations: Bool {
        // Check if reduce motion is enabled
        if UIAccessibility.isReduceMotionEnabled {
            return true
        }

        // Check if low power mode is enabled
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return true
        }

        // Check thermal state
        if ProcessInfo.processInfo.thermalState == .critical ||
           ProcessInfo.processInfo.thermalState == .serious {
            return true
        }

        return false
    }

    /// Get appropriate animation for current conditions
    /// - Parameter defaultAnimation: Default animation to use
    /// - Returns: Reduced or default animation
    static func animation(_ defaultAnimation: Animation = .default) -> Animation? {
        shouldReduceAnimations ? nil : defaultAnimation
    }

    /// Get appropriate animation duration
    /// - Parameter defaultDuration: Default duration
    /// - Returns: Reduced or default duration
    static func duration(_ defaultDuration: Double) -> Double {
        shouldReduceAnimations ? defaultDuration * 0.5 : defaultDuration
    }
}

// MARK: - View Caching

/// Caches expensive view computations
class ViewCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private let lock = NSLock()

    func value(for key: Key, compute: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] {
            return cached
        }

        let value = compute()
        cache[key] = value
        return value
    }

    func invalidate(key: Key) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ViewPerformanceHelpers_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Performance Helpers")
                .font(AppTheme.Typography.title2)

            Text("Reduce Animations: \(AnimationReducer.shouldReduceAnimations ? "Yes" : "No")")
                .font(AppTheme.Typography.body)

            // LazyView example
            LazyView(
                Text("Lazily loaded content")
                    .font(AppTheme.Typography.body)
            )
        }
        .padding()
    }
}
#endif
