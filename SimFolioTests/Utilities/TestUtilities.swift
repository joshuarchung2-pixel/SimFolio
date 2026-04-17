import XCTest
import UIKit
@testable import SimFolio

enum TestUtilities {

    /// Create a date relative to today (for tests that need live-date behavior)
    static func dateRelativeToToday(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: Date()))!
    }

    /// Create a date from components
    static func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    /// Generate a solid-color test image
    static func generateTestImage(width: Int = 100, height: Int = 100, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Generate JPEG image data
    static func generateTestImageData(width: Int = 100, height: Int = 100) -> Data {
        generateTestImage(width: width, height: height).jpegData(compressionQuality: 0.8)!
    }

    /// Create a temporary directory for file-based tests
    static func createTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimFolioTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Remove a temporary directory
    static func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
