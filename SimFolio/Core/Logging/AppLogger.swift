// AppLogger.swift
// SimFolio - Structured Logging
//
// Provides os.Logger instances organized by subsystem and category.
// Use these instead of print() or ErrorLogger for all logging.

import os

// MARK: - Test Log Sink

/// Protocol for capturing log entries during tests.
/// Set `AppLogger.testSink` to an instance in test setUp().
protocol TestLogSink: AnyObject {
    func log(level: OSLogType, subsystem: String, category: String, message: String)
}

// MARK: - App Logger

enum AppLogger {
    /// When non-nil, log entries are also forwarded here (test use only).
    /// Production code never sets this — zero overhead.
    static weak var testSink: TestLogSink?

    // MARK: - App Subsystem

    static let app = Logger(subsystem: "com.simfolio.app", category: "lifecycle")
    static let permissions = Logger(subsystem: "com.simfolio.app", category: "permissions")
    static let state = Logger(subsystem: "com.simfolio.app", category: "state")

    // MARK: - Services Subsystem

    static let metadata = Logger(subsystem: "com.simfolio.services", category: "metadata")
    static let storage = Logger(subsystem: "com.simfolio.services", category: "storage")
    static let notifications = Logger(subsystem: "com.simfolio.services", category: "notifications")
    static let auth = Logger(subsystem: "com.simfolio.services", category: "auth")

    // MARK: - Editor Subsystem

    static let editor = Logger(subsystem: "com.simfolio.editor", category: "processing")
    static let editPersistence = Logger(subsystem: "com.simfolio.editor", category: "persistence")
    static let editHistory = Logger(subsystem: "com.simfolio.editor", category: "history")

    // MARK: - UI Subsystem

    static let navigation = Logger(subsystem: "com.simfolio.ui", category: "navigation")
    static let capture = Logger(subsystem: "com.simfolio.ui", category: "capture")
    static let library = Logger(subsystem: "com.simfolio.ui", category: "library")
    static let portfolio = Logger(subsystem: "com.simfolio.ui", category: "portfolio")
}
