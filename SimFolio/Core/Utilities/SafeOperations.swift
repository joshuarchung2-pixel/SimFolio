// SafeOperations.swift
// SimFolio - Safe Operation Utilities
//
// Provides defensive coding patterns for common operations.
// Includes safe JSON handling, file operations, and task execution.

import Foundation
import SwiftUI
import Photos

// MARK: - Safe JSON Operations

/// Safe JSON encoding and decoding with error handling
struct SafeJSON {

    /// Safely encode a value to JSON data
    static func encode<T: Encodable>(
        _ value: T,
        context: String = "",
        outputFormatting: JSONEncoder.OutputFormatting = []
    ) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = outputFormatting
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(value)
        } catch {
            ErrorLogger.log("JSON Encode Error [\(context)]", error: error)
            return nil
        }
    }

    /// Safely decode JSON data to a value
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        context: String = ""
    ) -> T? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            ErrorLogger.log("JSON Decode Error [\(context)]", error: error)
            return nil
        }
    }

    /// Safely decode JSON string to a value
    static func decode<T: Decodable>(
        _ type: T.Type,
        from jsonString: String,
        context: String = ""
    ) -> T? {
        guard let data = jsonString.data(using: .utf8) else {
            ErrorLogger.log("Invalid JSON string encoding [\(context)]")
            return nil
        }
        return decode(type, from: data, context: context)
    }
}

// MARK: - Safe UserDefaults

/// Safe UserDefaults operations with automatic encoding/decoding
struct SafeUserDefaults {

    private static let defaults = UserDefaults.standard

    /// Save a Codable value to UserDefaults
    static func set<T: Encodable>(_ value: T, forKey key: String) {
        if let data = SafeJSON.encode(value, context: "UserDefaults.\(key)") {
            defaults.set(data, forKey: key)
        }
    }

    /// Load a Codable value from UserDefaults
    static func get<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return SafeJSON.decode(type, from: data, context: "UserDefaults.\(key)")
    }

    /// Load a Codable value with a default fallback
    static func get<T: Decodable>(_ type: T.Type, forKey key: String, default defaultValue: T) -> T {
        get(type, forKey: key) ?? defaultValue
    }

    /// Remove a value from UserDefaults
    static func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// Check if a key exists
    static func exists(forKey key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }

    /// Safely get a string value
    static func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    /// Safely get a bool value
    static func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    /// Safely get an integer value
    static func integer(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    /// Safely get a double value
    static func double(forKey key: String) -> Double {
        defaults.double(forKey: key)
    }

    /// Save and synchronize (for critical data)
    static func synchronize() {
        defaults.synchronize()
    }
}

// MARK: - Safe File Operations

/// Safe file system operations with error handling
struct SafeFileManager {

    private static let fileManager = FileManager.default

    /// Check if a file exists at URL
    static func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    /// Check if a directory exists at URL
    static func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Create a directory (including intermediate directories)
    @discardableResult
    static func createDirectory(at url: URL) -> Bool {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            ErrorLogger.log("Create Directory Error at \(url.path)", error: error)
            return false
        }
    }

    /// Write data to a file
    @discardableResult
    static func write(_ data: Data, to url: URL, atomic: Bool = true) -> Bool {
        do {
            try data.write(to: url, options: atomic ? .atomic : [])
            return true
        } catch {
            ErrorLogger.log("Write File Error at \(url.path)", error: error)
            return false
        }
    }

    /// Read data from a file
    static func read(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            ErrorLogger.log("Read File Error at \(url.path)", error: error)
            return nil
        }
    }

    /// Delete a file or directory
    @discardableResult
    static func delete(at url: URL) -> Bool {
        guard fileExists(at: url) else { return true }

        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            ErrorLogger.log("Delete File Error at \(url.path)", error: error)
            return false
        }
    }

    /// Move a file or directory
    @discardableResult
    static func move(from source: URL, to destination: URL) -> Bool {
        do {
            // Remove destination if it exists
            if fileExists(at: destination) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
            return true
        } catch {
            ErrorLogger.log("Move File Error from \(source.path) to \(destination.path)", error: error)
            return false
        }
    }

    /// Copy a file or directory
    @discardableResult
    static func copy(from source: URL, to destination: URL) -> Bool {
        do {
            // Remove destination if it exists
            if fileExists(at: destination) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            return true
        } catch {
            ErrorLogger.log("Copy File Error from \(source.path) to \(destination.path)", error: error)
            return false
        }
    }

    /// List contents of a directory
    static func contentsOfDirectory(at url: URL) -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        } catch {
            ErrorLogger.log("List Directory Error at \(url.path)", error: error)
            return []
        }
    }

    /// Get file size in bytes
    static func fileSize(at url: URL) -> Int64? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            ErrorLogger.log("Get File Size Error at \(url.path)", error: error)
            return nil
        }
    }

    /// Get available disk space
    static var availableDiskSpace: Int64? {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64
        } catch {
            ErrorLogger.log("Get Disk Space Error", error: error)
            return nil
        }
    }

    /// App's documents directory
    static var documentsDirectory: URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents directory unavailable
            return fileManager.temporaryDirectory
        }
        return url
    }

    /// App's caches directory
    static var cachesDirectory: URL {
        guard let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if caches directory unavailable
            return fileManager.temporaryDirectory
        }
        return url
    }

    /// App's temporary directory
    static var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }
}

// MARK: - Debounced Save Manager

/// Manages debounced save operations to prevent excessive disk writes
actor DebouncedSaveManager {
    private var pendingSaveTask: Task<Void, Never>?
    private let delay: TimeInterval

    init(delay: TimeInterval = 1.0) {
        self.delay = delay
    }

    /// Schedule a save operation (debounced)
    func scheduleSave(_ saveOperation: @escaping () async -> Void) {
        // Cancel any pending save
        pendingSaveTask?.cancel()

        // Schedule new save
        pendingSaveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await saveOperation()
        }
    }

    /// Force immediate save (cancels pending)
    func saveImmediately(_ saveOperation: @escaping () async -> Void) async {
        pendingSaveTask?.cancel()
        await saveOperation()
    }

    /// Cancel any pending save
    func cancelPending() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
    }
}

// MARK: - Async Rate Limiter

/// Limits the rate of async operations (one execution per minimum interval)
actor AsyncRateLimiter {
    private var lastExecutionTime: Date?
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    /// Check if enough time has passed since last execution
    func shouldExecute() -> Bool {
        let now = Date()

        guard let lastTime = lastExecutionTime else {
            lastExecutionTime = now
            return true
        }

        if now.timeIntervalSince(lastTime) >= minimumInterval {
            lastExecutionTime = now
            return true
        }

        return false
    }

    /// Execute operation if rate limit allows
    func execute(_ operation: () async -> Void) async {
        guard await shouldExecute() else { return }
        await operation()
    }

    /// Reset the rate limiter
    func reset() {
        lastExecutionTime = nil
    }
}

// MARK: - Safe Task Execution

/// Execute a closure with automatic error handling
func safeExecute<T>(
    context: String = "",
    fallback: T,
    operation: () throws -> T
) -> T {
    do {
        return try operation()
    } catch {
        ErrorLogger.log(context, error: error)
        return fallback
    }
}

/// Execute an async closure with automatic error handling
func safeExecuteAsync<T>(
    context: String = "",
    fallback: T,
    operation: () async throws -> T
) async -> T {
    do {
        return try await operation()
    } catch {
        ErrorLogger.log(context, error: error)
        return fallback
    }
}

/// Execute a closure and report errors to ErrorHandler
func executeWithErrorReporting<T>(
    context: String = "",
    fallback: T,
    operation: () throws -> T
) -> T {
    do {
        return try operation()
    } catch {
        Task { @MainActor in
            ErrorHandler.shared.handle(error, context: context)
        }
        return fallback
    }
}

/// Execute an async closure and report errors to ErrorHandler
func executeAsyncWithErrorReporting<T>(
    context: String = "",
    fallback: T,
    operation: () async throws -> T
) async -> T {
    do {
        return try await operation()
    } catch {
        await ErrorHandler.shared.handle(error, context: context)
        return fallback
    }
}

// MARK: - Cancellable Task Manager

/// Manages a single cancellable task
actor CancellableTaskManager<T> {
    private var currentTask: Task<T, Error>?

    /// Run a new task, cancelling any existing one
    func run(_ operation: @escaping () async throws -> T) async throws -> T {
        // Cancel existing task
        currentTask?.cancel()

        // Create new task
        let task = Task {
            try await operation()
        }

        currentTask = task

        return try await task.value
    }

    /// Cancel current task if any
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Check if a task is currently running
    var isRunning: Bool {
        currentTask != nil && currentTask?.isCancelled == false
    }
}

// MARK: - Retry Logic

/// Retry an operation with exponential backoff
func retryWithBackoff<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 30.0,
    operation: () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay = min(currentDelay * 2, maxDelay)
            }
        }
    }

    throw lastError ?? AppError.unknown("All retry attempts failed")
}

// MARK: - Timeout Wrapper

/// Execute an operation with a timeout
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AppError.timeout
        }

        guard let result = try await group.next() else {
            throw AppError.timeout
        }
        group.cancelAll()
        return result
    }
}
