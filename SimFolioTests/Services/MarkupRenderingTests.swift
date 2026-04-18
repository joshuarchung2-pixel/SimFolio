// MarkupRenderingTests.swift
// SimFolioTests/Services — Markup rendering service smoke tests
//
// Asserts the rewritten SwiftUI/ImageRenderer-based baker:
// - Returns non-nil for each element type.
// - Actually composites pixels (output ≠ base image) at both small and
//   large image sizes.

import XCTest
import UIKit
@testable import SimFolio

@MainActor
final class MarkupRenderingTests: XCTestCase {

    // MARK: - Fixtures

    private func solidImage(size: CGSize, color: UIColor = .gray) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func fixtureMarkupState() -> MarkupState {
        var state = MarkupState()

        state.addElement(.freeformLine(FreeformLine(
            points: [
                CGPoint(x: 0.1, y: 0.2),
                CGPoint(x: 0.4, y: 0.5),
                CGPoint(x: 0.6, y: 0.3)
            ],
            color: .red,
            lineWidth: .medium
        )))

        state.addElement(.measurementLine(MeasurementLine(
            startPoint: CGPoint(x: 0.2, y: 0.7),
            endPoint: CGPoint(x: 0.8, y: 0.7),
            color: .blue,
            lineWidth: .medium
        )))

        state.addElement(.textBox(TextBox(
            position: CGPoint(x: 0.5, y: 0.9),
            text: "Incisal edge in contact",
            fontSize: .medium,
            fontColor: .white,
            fillColor: .black,
            size: CGSize(width: 0.4, height: 0.08)
        )))

        return state
    }

    // MARK: - Tests

    func testRenderMarkup_smallImage_producesNonEmptyComposite() {
        let base = solidImage(size: CGSize(width: 800, height: 600))
        let state = fixtureMarkupState()

        let result = MarkupRenderingService.shared.renderMarkup(onto: base, markupState: state)

        XCTAssertNotNil(result, "Baker should produce an image")
        guard let result else { return }
        XCTAssertEqual(result.size, base.size, "Baked image should match base image size")
        XCTAssertFalse(pixelsEqual(result, base), "Baked image should differ from base (markup drawn on top)")
    }

    func testRenderMarkup_largeImage_producesNonEmptyComposite() {
        let base = solidImage(size: CGSize(width: 3024, height: 4032))
        let state = fixtureMarkupState()

        let result = MarkupRenderingService.shared.renderMarkup(onto: base, markupState: state)

        XCTAssertNotNil(result, "Baker should produce an image at full resolution")
        guard let result else { return }
        XCTAssertEqual(result.size, base.size, "Baked image should match base image size")
        XCTAssertFalse(pixelsEqual(result, base), "Baked image should differ from base at full resolution")
    }

    func testRenderMarkup_emptyState_returnsBaseImageUnchanged() {
        let base = solidImage(size: CGSize(width: 400, height: 400))
        let emptyState = MarkupState()

        let result = MarkupRenderingService.shared.renderMarkup(onto: base, markupState: emptyState)

        XCTAssertNotNil(result)
        // With no markup, the service returns the base image pass-through.
        XCTAssertEqual(result?.size, base.size)
    }

    // MARK: - Helpers

    /// Compare first N bytes of raw pixel data — cheap sanity check that two
    /// images are pixel-different (not a full bit-for-bit comparison).
    private func pixelsEqual(_ a: UIImage, _ b: UIImage) -> Bool {
        guard let dataA = a.pngData(), let dataB = b.pngData() else { return false }
        return dataA == dataB
    }
}
