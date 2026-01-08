// Extensions.swift
// Swift extensions and helpers
//
// Will contain:
//
// Color Extensions:
// - init?(hex:): Create Color from hex string
// - toHex() -> String?: Convert Color to hex string
//
// View Extensions:
// - .cornerRadius(_:corners:): Apply radius to specific corners
// - .readSize(onChange:): Read view size via GeometryReader
// - .hideKeyboard(): Dismiss keyboard
// - .onFirstAppear(_:): Execute only on first appearance
// - .eraseToAnyView(): Type-erase view
//
// Date Extensions:
// - startOfDay: Date at midnight
// - isToday, isTomorrow, isYesterday: Bool
// - daysUntil(_:) -> Int: Days between dates
// - formatted(style:): Formatted string
//
// String Extensions:
// - isBlank: Bool - Empty or whitespace only
// - trimmed: String - Whitespace trimmed
//
// Array Extensions:
// - safe subscript: Return nil for out-of-bounds
// - chunked(into:): Split into chunks
//
// UIImage Extensions:
// - resized(to:): Resize image
// - cropped(to:): Crop to rect
// - rotated(by:): Rotate by degrees
//
// Binding Extensions:
// - onChange(_:): Add side effect to binding changes
//
// PreferenceKey:
// - ScrollOffsetPreferenceKey: Track scroll position
// - SizePreferenceKey: Track view size
//
// Migration notes:
// - Extract Color extensions from gem1 lines 1751-1774
// - Extract ScrollOffsetPreferenceKey from lines 10-16
// - Add commonly needed extensions
// - Consider splitting into multiple files if large

import SwiftUI
import UIKit

// Placeholder - implementation will be migrated and expanded
