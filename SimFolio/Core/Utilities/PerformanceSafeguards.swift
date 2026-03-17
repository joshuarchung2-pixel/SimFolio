// PerformanceSafeguards.swift
// SimFolio - Performance and Memory Safeguards
//
// Provides utilities for memory management, throttling, batching,
// and preventing performance issues in the app.

import Foundation
import SwiftUI
import Combine

// MARK: - Memory Pressure Handler

/// Monitors and responds to system memory pressure
@MainActor
class MemoryPressureHandler: ObservableObject {
    static let shared = MemoryPressureHandler()

    @Published private(set) var isUnderMemoryPressure = false
    @Published private(set) var pressureLevel: MemoryPressureLevel = .normal

    enum MemoryPressureLevel {
        case normal
        case warning
        case critical

        var shouldReduceQuality: Bool {
            self != .normal
        }

        var shouldPurgeCache: Bool {
            self == .critical
        }
    }

    private var pressureSource: DispatchSourceMemoryPressure?
    private var memoryWarningObserver: NSObjectProtocol?

    private init() {
        setupMemoryPressureMonitoring()
        setupMemoryWarningObserver()
    }

    deinit {
        pressureSource?.cancel()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupMemoryPressureMonitoring() {
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        pressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = self.pressureSource?.data ?? []

            Task { @MainActor in
                if event.contains(.critical) {
                    self.pressureLevel = .critical
                    self.isUnderMemoryPressure = true
                    self.handleCriticalMemoryPressure()
                } else if event.contains(.warning) {
                    self.pressureLevel = .warning
                    self.isUnderMemoryPressure = true
                    self.handleWarningMemoryPressure()
                }
            }
        }

        pressureSource?.resume()
    }

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pressureLevel = .warning
                self?.isUnderMemoryPressure = true
                self?.handleWarningMemoryPressure()
            }
        }
    }

    private func handleWarningMemoryPressure() {
        ErrorLogger.log("Memory pressure warning received")
        NotificationCenter.default.post(name: .memoryPressureWarning, object: nil)

        // Schedule pressure level reset after some time
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if pressureLevel == .warning {
                pressureLevel = .normal
                isUnderMemoryPressure = false
            }
        }
    }

    private func handleCriticalMemoryPressure() {
        ErrorLogger.log("Critical memory pressure received")
        NotificationCenter.default.post(name: .memoryPressureCritical, object: nil)

        // Schedule pressure level reset after some time
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            if pressureLevel == .critical {
                pressureLevel = .normal
                isUnderMemoryPressure = false
            }
        }
    }

    /// Manually trigger a memory pressure response (for testing)
    func simulateMemoryPressure(level: MemoryPressureLevel) {
        pressureLevel = level
        isUnderMemoryPressure = level != .normal

        switch level {
        case .warning:
            handleWarningMemoryPressure()
        case .critical:
            handleCriticalMemoryPressure()
        case .normal:
            break
        }
    }

    /// Reset memory pressure state
    func resetPressure() {
        pressureLevel = .normal
        isUnderMemoryPressure = false
    }
}

// MARK: - Memory Pressure Notifications

extension Notification.Name {
    static let memoryPressureWarning = Notification.Name("memoryPressureWarning")
    static let memoryPressureCritical = Notification.Name("memoryPressureCritical")
}

// MARK: - Throttled Publisher

extension Publisher {
    /// Throttle emissions to prevent excessive updates
    func throttled(
        for interval: TimeInterval,
        scheduler: some Scheduler = DispatchQueue.main,
        latest: Bool = true
    ) -> AnyPublisher<Output, Failure> {
        throttle(
            for: .seconds(interval),
            scheduler: scheduler,
            latest: latest
        )
        .eraseToAnyPublisher()
    }

    /// Debounce emissions for a specified interval
    func debounced(
        for interval: TimeInterval,
        scheduler: some Scheduler = DispatchQueue.main
    ) -> AnyPublisher<Output, Failure> {
        debounce(
            for: .seconds(interval),
            scheduler: scheduler
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - Batch Processor

/// Processes items in batches to prevent UI blocking
actor BatchProcessor<T> {
    private let batchSize: Int
    private let delayBetweenBatches: TimeInterval

    init(batchSize: Int = 10, delayBetweenBatches: TimeInterval = 0.05) {
        self.batchSize = batchSize
        self.delayBetweenBatches = delayBetweenBatches
    }

    /// Process items in batches
    func process<R>(
        items: [T],
        operation: @escaping (T) async -> R
    ) async -> [R] {
        var results: [R] = []
        results.reserveCapacity(items.count)

        for batch in items.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: R.self) { group in
                for item in batch {
                    group.addTask {
                        await operation(item)
                    }
                }

                var batchResults: [R] = []
                for await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }

            results.append(contentsOf: batchResults)

            // Small delay between batches to let UI breathe
            if delayBetweenBatches > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenBatches * 1_000_000_000))
            }
        }

        return results
    }

    /// Process items sequentially in batches
    func processSequentially(
        items: [T],
        operation: @escaping (T) async throws -> Void
    ) async throws {
        for batch in items.chunked(into: batchSize) {
            for item in batch {
                try await operation(item)
            }

            // Small delay between batches
            if delayBetweenBatches > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenBatches * 1_000_000_000))
            }
        }
    }
}

// MARK: - Array Chunking Extension

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Load Limited View

/// View that limits rendering based on memory pressure
struct LoadLimitedView<Content: View, LowMemoryContent: View>: View {
    @ObservedObject private var memoryHandler = MemoryPressureHandler.shared

    let content: () -> Content
    let lowMemoryContent: () -> LowMemoryContent

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder lowMemory: @escaping () -> LowMemoryContent
    ) {
        self.content = content
        self.lowMemoryContent = lowMemory
    }

    var body: some View {
        if memoryHandler.pressureLevel.shouldReduceQuality {
            lowMemoryContent()
        } else {
            content()
        }
    }
}

// MARK: - Chunked ForEach

/// ForEach that loads items in chunks for better performance
struct ChunkedForEach<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {

    let data: Data
    let chunkSize: Int
    let content: (Data.Element) -> Content

    @State private var loadedCount: Int

    init(
        _ data: Data,
        chunkSize: Int = 20,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.chunkSize = chunkSize
        self.content = content
        self._loadedCount = State(initialValue: min(chunkSize, data.count))
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(data.prefix(loadedCount))) { item in
                content(item)
            }

            if loadedCount < data.count {
                ProgressView()
                    .onAppear {
                        loadMoreItems()
                    }
            }
        }
    }

    private func loadMoreItems() {
        let newCount = min(loadedCount + chunkSize, data.count)
        withAnimation(.easeInOut(duration: 0.2)) {
            loadedCount = newCount
        }
    }
}

// MARK: - Lazy Loading Image Grid

/// Grid that lazily loads images with memory management
struct LazyImageGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let content: (Item) -> Content

    @ObservedObject private var memoryHandler = MemoryPressureHandler.shared

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    init(
        items: [Item],
        columns: Int = 3,
        spacing: CGFloat = 2,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(items) { item in
                content(item)
                    .id(item.id)
            }
        }
    }
}

// MARK: - Image Cache Manager

/// Manages image caching with memory pressure awareness
actor ImageCacheManager {
    static let shared = ImageCacheManager()

    private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        return cache
    }()

    private var memoryObserver: NSObjectProtocol?

    private init() {
        Task { await setupMemoryObserver() }
    }

    private func setupMemoryObserver() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: .memoryPressureCritical,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.clearCache()
            }
        }
    }

    /// Get image from cache
    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Store image in cache
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory cost
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Remove image from cache
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Clear entire cache
    func clearCache() {
        cache.removeAllObjects()
        ErrorLogger.info("Image cache cleared")
    }

    /// Reduce cache size (for memory pressure)
    func reduceCache() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        ErrorLogger.info("Image cache reduced")
    }

    /// Restore normal cache size
    func restoreNormalCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
}

// MARK: - Frame Drop Monitor

/// Monitors frame drops for debugging
class FrameDropMonitor {
    static let shared = FrameDropMonitor()

    private var frameDropCount = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    private init() {}

    deinit {
        stopMonitoring()
    }

    /// Start monitoring frame drops
    func startMonitoring() {
        #if DEBUG
        displayLink = CADisplayLink(target: self, selector: #selector(frameCallback))
        displayLink?.add(to: .main, forMode: .common)
        #endif
    }

    /// Stop monitoring
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func frameCallback(link: CADisplayLink) {
        if lastFrameTime > 0 {
            let frameDuration = link.timestamp - lastFrameTime
            let targetDuration = link.targetTimestamp - link.timestamp

            // If frame took more than 2x the target, count as drop
            if frameDuration > targetDuration * 2 {
                frameDropCount += 1
                if frameDropCount % 10 == 0 {
                    ErrorLogger.log("Frame drops detected: \(frameDropCount)")
                }
            }
        }
        lastFrameTime = link.timestamp
    }

    /// Get current frame drop count
    var currentFrameDrops: Int {
        frameDropCount
    }

    /// Reset frame drop counter
    func resetCounter() {
        frameDropCount = 0
    }
}

// MARK: - Async Operation Queue

/// Limits concurrent async operations
actor AsyncOperationQueue {
    private let maxConcurrent: Int
    private var currentOperations = 0
    private var waitingOperations: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int = 4) {
        self.maxConcurrent = maxConcurrent
    }

    /// Execute operation with concurrency limit
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        await waitForSlot()

        defer {
            Task { await releaseSlot() }
        }

        return try await operation()
    }

    private func waitForSlot() async {
        if currentOperations < maxConcurrent {
            currentOperations += 1
            return
        }

        await withCheckedContinuation { continuation in
            waitingOperations.append(continuation)
        }

        currentOperations += 1
    }

    private func releaseSlot() {
        currentOperations -= 1

        if let waiting = waitingOperations.first {
            waitingOperations.removeFirst()
            waiting.resume()
        }
    }
}

// MARK: - Prefetch Manager

/// Manages prefetching for collections
@MainActor
class PrefetchManager<ID: Hashable>: ObservableObject {
    private var prefetchedIDs: Set<ID> = []
    private let prefetchThreshold: Int
    private var prefetchTask: Task<Void, Never>?

    init(prefetchThreshold: Int = 5) {
        self.prefetchThreshold = prefetchThreshold
    }

    /// Check if item should trigger prefetch
    func shouldPrefetch(currentIndex: Int, totalCount: Int) -> Bool {
        currentIndex >= totalCount - prefetchThreshold
    }

    /// Mark ID as prefetched
    func markPrefetched(_ id: ID) {
        prefetchedIDs.insert(id)
    }

    /// Check if ID is prefetched
    func isPrefetched(_ id: ID) -> Bool {
        prefetchedIDs.contains(id)
    }

    /// Cancel any pending prefetch
    func cancelPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    /// Clear prefetch cache
    func clearCache() {
        prefetchedIDs.removeAll()
    }
}

// MARK: - View Lifecycle Tracker

/// Tracks view lifecycle for debugging
struct ViewLifecycleModifier: ViewModifier {
    let viewName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                ErrorLogger.info("\(viewName) appeared")
                #endif
            }
            .onDisappear {
                #if DEBUG
                ErrorLogger.info("\(viewName) disappeared")
                #endif
            }
    }
}

extension View {
    /// Track view lifecycle for debugging
    func trackLifecycle(_ viewName: String) -> some View {
        modifier(ViewLifecycleModifier(viewName: viewName))
    }
}

// MARK: - Task Timeout

/// Execute a task with automatic timeout
func withAutoTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T,
    onTimeout: (() -> Void)? = nil
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            onTimeout?()
            throw AppError.timeout
        }

        guard let result = try await group.next() else {
            throw AppError.timeout
        }

        group.cancelAll()
        return result
    }
}

// MARK: - Deferred Execution

/// Delays execution for non-critical tasks
func deferExecution(
    delay: TimeInterval = 0.1,
    operation: @escaping () async -> Void
) {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await operation()
    }
}

/// Execute on next run loop
func executeOnNextRunLoop(_ operation: @escaping () -> Void) {
    DispatchQueue.main.async {
        operation()
    }
}
