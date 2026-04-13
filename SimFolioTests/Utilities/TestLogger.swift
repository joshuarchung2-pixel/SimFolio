import XCTest
import os
@testable import SimFolio

// MARK: - Test Log Entry

struct TestLogEntry {
    let timestamp: Date
    let level: OSLogType
    let subsystem: String
    let category: String
    let message: String
}

// MARK: - Test Log Sink

final class TestLogCapture: TestLogSink {
    private(set) var entries: [TestLogEntry] = []
    private let lock = NSLock()

    func log(level: OSLogType, subsystem: String, category: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(TestLogEntry(
            timestamp: Date(),
            level: level,
            subsystem: subsystem,
            category: category,
            message: message
        ))
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    /// Dump all captured log entries to test output
    func dump() {
        lock.lock()
        let snapshot = entries
        lock.unlock()

        if snapshot.isEmpty {
            print("[TestLogger] No log entries captured")
            return
        }

        print("[TestLogger] --- Captured \(snapshot.count) log entries ---")
        for entry in snapshot {
            let levelStr: String
            switch entry.level {
            case .debug: levelStr = "DEBUG"
            case .info: levelStr = "INFO"
            case .error: levelStr = "ERROR"
            case .fault: levelStr = "FAULT"
            default: levelStr = "LOG"
            }
            print("  [\(levelStr)] \(entry.subsystem)/\(entry.category): \(entry.message)")
        }
        print("[TestLogger] --- End ---")
    }

    // MARK: - Assertions

    func assertNoErrors(file: StaticString = #filePath, line: UInt = #line) {
        lock.lock()
        let errorEntries = entries.filter { $0.level == .error || $0.level == .fault }
        lock.unlock()

        if !errorEntries.isEmpty {
            let messages = errorEntries.map { $0.message }.joined(separator: "\n  ")
            XCTFail("Expected no errors but found \(errorEntries.count):\n  \(messages)", file: file, line: line)
        }
    }

    func assertContains(message substring: String, file: StaticString = #filePath, line: UInt = #line) {
        lock.lock()
        let found = entries.contains { $0.message.contains(substring) }
        lock.unlock()

        XCTAssertTrue(found, "Expected log entry containing \"\(substring)\" but none found", file: file, line: line)
    }
}

// MARK: - Test Observer (auto-dump on failure)

final class TestLogObserver: NSObject, XCTestObservation {
    static let shared = TestLogObserver()
    var logCapture: TestLogCapture?

    func testCaseDidFinish(_ testCase: XCTestCase) {
        if testCase.testRun?.hasSucceeded == false {
            logCapture?.dump()
        }
        logCapture?.reset()
    }
}
