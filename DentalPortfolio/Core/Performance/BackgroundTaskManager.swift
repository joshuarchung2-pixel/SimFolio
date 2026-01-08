// BackgroundTaskManager.swift
// Dental Portfolio - Background Task Management
//
// Manages background tasks for exports, cleanup, and other
// operations that should continue when app is backgrounded.
//
// Features:
// - BGTaskScheduler integration
// - Export task handling
// - Cleanup task scheduling
// - Long-running task wrapper
// - Pending task queue management

import SwiftUI
import BackgroundTasks

// MARK: - Background Task Manager

/// Manages background task scheduling and execution
class BackgroundTaskManager {
    /// Shared singleton instance
    static let shared = BackgroundTaskManager()

    // MARK: - Task Identifiers

    /// Identifier for export processing task
    private let exportTaskIdentifier = "com.dentalportfolio.export"

    /// Identifier for cleanup task
    private let cleanupTaskIdentifier = "com.dentalportfolio.cleanup"

    /// Identifier for sync task
    private let syncTaskIdentifier = "com.dentalportfolio.sync"

    // MARK: - Pending Tasks

    /// Queue of pending export operations
    private var pendingExports: [ExportTask] = []

    /// Lock for thread-safe access
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Register all background tasks with the system
    /// Call this in application(_:didFinishLaunchingWithOptions:)
    func registerBackgroundTasks() {
        // Register export task (processing task for longer operations)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: exportTaskIdentifier,
            using: nil
        ) { task in
            self.handleExportTask(task as! BGProcessingTask)
        }

        // Register cleanup task (app refresh for periodic cleanup)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: cleanupTaskIdentifier,
            using: nil
        ) { task in
            self.handleCleanupTask(task as! BGAppRefreshTask)
        }

        print("Background tasks registered")
    }

    // MARK: - Scheduling

    /// Schedule export task for background processing
    func scheduleExportTask() {
        let request = BGProcessingTaskRequest(identifier: exportTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Export task scheduled")
        } catch {
            print("Failed to schedule export task: \(error)")
        }
    }

    /// Schedule cleanup task
    func scheduleCleanupTask() {
        let request = BGAppRefreshTaskRequest(identifier: cleanupTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Cleanup task scheduled for 24 hours from now")
        } catch {
            print("Failed to schedule cleanup task: \(error)")
        }
    }

    /// Cancel all pending background tasks
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("All background tasks cancelled")
    }

    // MARK: - Task Handling

    private func handleExportTask(_ task: BGProcessingTask) {
        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.saveExportProgress()
            task.setTaskCompleted(success: false)
        }

        Task {
            // Perform export operations
            let success = await performPendingExports()
            task.setTaskCompleted(success: success)
        }
    }

    private func handleCleanupTask(_ task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            // Clean up old cached data
            await performCleanup()

            // Schedule next cleanup
            scheduleCleanupTask()

            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Task Operations

    private func performPendingExports() async -> Bool {
        lock.lock()
        let exports = pendingExports
        lock.unlock()

        guard !exports.isEmpty else { return true }

        for export in exports {
            do {
                try await processExport(export)
                removeExport(export)
            } catch {
                print("Export failed: \(error)")
                return false
            }
        }

        return true
    }

    private func processExport(_ export: ExportTask) async throws {
        // Implementation depends on export type
        switch export.type {
        case .pdf:
            // Process PDF export
            break
        case .images:
            // Process image export
            break
        case .portfolio:
            // Process portfolio export
            break
        }
    }

    private func performCleanup() async {
        // Clear old cached images
        await ImageCache.shared.clearCache()

        // Clean up temporary files
        cleanupTemporaryFiles()

        // Optimize storage
        optimizeStorage()

        print("Background cleanup completed")
    }

    private func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago

            for file in contents {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: file)
                }
            }

            print("Cleaned up temporary files older than 7 days")
        } catch {
            print("Cleanup error: \(error)")
        }
    }

    private func optimizeStorage() {
        // Compact UserDefaults
        UserDefaults.standard.synchronize()
    }

    private func saveExportProgress() {
        // Save current export state for resumption
        lock.lock()
        defer { lock.unlock() }

        // Persist pending exports to UserDefaults or file
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingExports) {
            UserDefaults.standard.set(data, forKey: "pendingExports")
        }
    }

    // MARK: - Export Queue Management

    /// Add export task to pending queue
    /// - Parameter export: Export task to add
    func addExport(_ export: ExportTask) {
        lock.lock()
        defer { lock.unlock() }

        pendingExports.append(export)
        scheduleExportTask()
    }

    /// Remove export from queue
    /// - Parameter export: Export to remove
    func removeExport(_ export: ExportTask) {
        lock.lock()
        defer { lock.unlock() }

        pendingExports.removeAll { $0.id == export.id }
    }

    /// Load pending exports from storage
    func loadPendingExports() {
        guard let data = UserDefaults.standard.data(forKey: "pendingExports"),
              let exports = try? JSONDecoder().decode([ExportTask].self, from: data) else {
            return
        }

        lock.lock()
        pendingExports = exports
        lock.unlock()

        if !pendingExports.isEmpty {
            scheduleExportTask()
        }
    }
}

// MARK: - Export Task

/// Represents a pending export operation
struct ExportTask: Codable, Identifiable {
    let id: UUID
    let type: ExportType
    let assetIdentifiers: [String]
    let createdAt: Date
    var progress: Double

    enum ExportType: String, Codable {
        case pdf
        case images
        case portfolio
    }

    init(
        type: ExportType,
        assetIdentifiers: [String]
    ) {
        self.id = UUID()
        self.type = type
        self.assetIdentifiers = assetIdentifiers
        self.createdAt = Date()
        self.progress = 0
    }
}

// MARK: - Long Running Task Wrapper

/// Wrapper for tasks that need to continue in background
class LongRunningTask {
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let name: String

    init(name: String = "LongRunningTask") {
        self.name = name
    }

    /// Begin background task
    func begin() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }

        if backgroundTaskID != .invalid {
            print("Background task started: \(name)")
        }
    }

    /// End background task
    func end() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("Background task ended: \(name)")
        }
    }

    /// Remaining background time
    var remainingTime: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }

    deinit {
        end()
    }
}

// MARK: - Task Wrapper View Extension

extension View {
    /// Wrap a long-running async task
    /// - Parameters:
    ///   - task: Async task to execute
    ///   - onComplete: Called when task completes
    func longRunningTask<T>(
        _ task: @escaping () async throws -> T,
        onComplete: @escaping (Result<T, Error>) -> Void
    ) -> some View {
        self.task {
            let backgroundTask = LongRunningTask()
            backgroundTask.begin()

            do {
                let result = try await task()
                onComplete(.success(result))
            } catch {
                onComplete(.failure(error))
            }

            backgroundTask.end()
        }
    }
}

// MARK: - Async Task Queue

/// Queue for managing sequential async tasks
actor AsyncTaskQueue {
    private var tasks: [() async -> Void] = []
    private var isProcessing = false

    /// Add task to queue
    /// - Parameter task: Task to add
    func enqueue(_ task: @escaping () async -> Void) {
        tasks.append(task)
        processQueue()
    }

    private func processQueue() {
        guard !isProcessing, !tasks.isEmpty else { return }

        isProcessing = true

        Task {
            while !tasks.isEmpty {
                let task = tasks.removeFirst()
                await task()
            }
            isProcessing = false
        }
    }

    /// Clear all pending tasks
    func clear() {
        tasks.removeAll()
    }

    /// Number of pending tasks
    var pendingCount: Int {
        tasks.count
    }
}

// MARK: - Cancelable Task

/// A task that can be cancelled
class CancelableTask<T> {
    private var task: Task<T, Error>?

    /// Execute task
    /// - Parameter operation: Async operation to execute
    /// - Returns: Task result
    @discardableResult
    func execute(_ operation: @escaping () async throws -> T) -> Task<T, Error> {
        cancel()

        let newTask = Task {
            try await operation()
        }

        task = newTask
        return newTask
    }

    /// Cancel the current task
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Whether task is currently running
    var isRunning: Bool {
        guard let task = task else { return false }
        return !task.isCancelled
    }
}

// MARK: - Preview Provider

#if DEBUG
struct BackgroundTaskManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Background Tasks")
                .font(AppTheme.Typography.title2)

            DPButton("Schedule Cleanup") {
                BackgroundTaskManager.shared.scheduleCleanupTask()
            }

            DPButton("Cancel All Tasks", style: .secondary) {
                BackgroundTaskManager.shared.cancelAllTasks()
            }
        }
        .padding()
    }
}
#endif
