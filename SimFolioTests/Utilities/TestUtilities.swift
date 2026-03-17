// TestUtilities.swift
// SimFolioTests - Test Utilities
//
// Provides helper functions and extensions for unit testing.
// Includes async waiting, temporary file management, and test image generation.

import XCTest
import SwiftUI
import Photos
@testable import SimFolio

// MARK: - Test Utilities

class TestUtilities {

    /// Wait for async operations to complete
    static func waitForAsync(timeout: TimeInterval = 5.0, completion: @escaping () -> Void) {
        let expectation = XCTestExpectation(description: "Async operation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
            expectation.fulfill()
        }

        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }

    /// Create temporary directory for tests
    static func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        return tempDir
    }

    /// Clean up temporary directory
    static func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Generate test image
    static func generateTestImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .red) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    /// Generate test image data
    static func generateTestImageData(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .red) -> Data? {
        let image = generateTestImage(size: size, color: color)
        return image.jpegData(compressionQuality: 0.8)
    }

    /// Create a date with specific components
    static func createDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Get date relative to today
    static func dateRelativeToToday(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {

    /// Wait for a condition to become true
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool,
        description: String = "Condition"
    ) {
        let expectation = XCTestExpectation(description: description)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()

        if result == .timedOut {
            XCTFail("Timed out waiting for: \(description)")
        }
    }

    /// Assert a condition eventually becomes true
    func assertEventually(
        timeout: TimeInterval = 5.0,
        message: String = "",
        condition: @escaping () -> Bool
    ) {
        waitForCondition(timeout: timeout, condition: condition, description: message)
    }

    /// Wait for published value to change
    func waitForPublishedValue<T: ObservableObject, V: Equatable>(
        on object: T,
        keyPath: KeyPath<T, V>,
        toEqual expectedValue: V,
        timeout: TimeInterval = 5.0
    ) {
        let expectation = XCTestExpectation(description: "Wait for published value")

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if object[keyPath: keyPath] == expectedValue {
                timer.invalidate()
                expectation.fulfill()
            }
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()

        if result == .timedOut {
            XCTFail("Value at keyPath did not equal expected value within timeout")
        }
    }

    /// Track memory leaks in test
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {

    /// Run async code in tests
    func runAsyncTest(
        timeout: TimeInterval = 10.0,
        test: @escaping () async throws -> Void
    ) {
        let expectation = XCTestExpectation(description: "Async test")

        Task {
            do {
                try await test()
                expectation.fulfill()
            } catch {
                XCTFail("Async test threw error: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Mock UserDefaults

class MockUserDefaults {
    private var storage: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) {
        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func string(forKey key: String) -> String? {
        storage[key] as? String
    }

    func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    func integer(forKey key: String) -> Int {
        storage[key] as? Int ?? 0
    }

    func double(forKey key: String) -> Double {
        storage[key] as? Double ?? 0.0
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func array(forKey key: String) -> [Any]? {
        storage[key] as? [Any]
    }

    func dictionary(forKey key: String) -> [String: Any]? {
        storage[key] as? [String: Any]
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    func reset() {
        storage = [:]
    }

    var allKeys: [String] {
        Array(storage.keys)
    }
}

// MARK: - Test Output Helpers

extension XCTestCase {

    /// Log a test step for debugging
    func logTestStep(_ message: String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("[\(filename):\(line)] \(message)")
    }
}
