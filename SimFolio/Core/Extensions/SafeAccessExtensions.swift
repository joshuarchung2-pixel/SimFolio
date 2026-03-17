// SafeAccessExtensions.swift
// SimFolio - Safe Access Extensions
//
// Provides safe access patterns for collections, optionals, and common types.
// Prevents crashes from out-of-bounds access and nil dereferences.

import Foundation
import SwiftUI
import Photos

// MARK: - Safe Array Access

extension Array {
    /// Safely access array element at index, returning nil if out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    /// Safely access first n elements
    func safePrefix(_ maxLength: Int) -> [Element] {
        Array(prefix(Swift.max(0, maxLength)))
    }

    /// Safely access last n elements
    func safeSuffix(_ maxLength: Int) -> [Element] {
        Array(suffix(Swift.max(0, maxLength)))
    }

    /// Safely remove element at index if it exists
    @discardableResult
    mutating func safeRemove(at index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return remove(at: index)
    }

    /// Safely insert element at index, appending if index is at end
    mutating func safeInsert(_ element: Element, at index: Index) {
        if index >= count {
            append(element)
        } else if index >= 0 {
            insert(element, at: index)
        }
    }

    /// Safely replace element at index
    @discardableResult
    mutating func safeReplace(at index: Index, with element: Element) -> Bool {
        guard indices.contains(index) else { return false }
        self[index] = element
        return true
    }
}

// MARK: - Safe Collection Access

extension Collection {
    /// Check if collection is not empty
    var isNotEmpty: Bool {
        !isEmpty
    }

    /// Safely get element at offset from start
    func element(atOffset offset: Int) -> Element? {
        guard offset >= 0, offset < count else { return nil }
        let idx = index(startIndex, offsetBy: offset)
        return self[idx]
    }
}

// MARK: - Safe Dictionary Access

extension Dictionary {
    /// Get value with default if key doesn't exist
    func value(forKey key: Key, default defaultValue: Value) -> Value {
        self[key] ?? defaultValue
    }

    /// Safely merge another dictionary, optionally overwriting existing keys
    mutating func safeMerge(_ other: [Key: Value], overwrite: Bool = true) {
        for (key, value) in other {
            if overwrite || self[key] == nil {
                self[key] = value
            }
        }
    }
}

// MARK: - Safe String Operations

extension String {
    /// Safely truncate string to max length with ellipsis
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        guard maxLength > 0 else { return "" }
        guard count > maxLength else { return self }
        let truncateAt = max(0, maxLength - trailing.count)
        return String(prefix(truncateAt)) + trailing
    }

    /// Check if string is not empty after trimming whitespace
    var isNotBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Trimmed string (removes whitespace and newlines)
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Safely convert to Int
    var safeInt: Int? {
        Int(self)
    }

    /// Safely convert to Double
    var safeDouble: Double? {
        Double(self)
    }

    /// Safely get substring in range
    func safeSubstring(from start: Int, length: Int) -> String? {
        guard start >= 0, length > 0, start < count else { return nil }
        let startIndex = index(self.startIndex, offsetBy: start)
        let endIndex = index(startIndex, offsetBy: min(length, count - start))
        return String(self[startIndex..<endIndex])
    }

    /// Remove all occurrences of a character
    func removing(_ character: Character) -> String {
        filter { $0 != character }
    }
}

// MARK: - Safe Optional String

extension Optional where Wrapped == String {
    /// Returns the string or empty string if nil
    var orEmpty: String {
        self ?? ""
    }

    /// Returns true if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    /// Returns true if nil or blank (only whitespace)
    var isNilOrBlank: Bool {
        self?.isNotBlank == false
    }

    /// Returns nil if the string is empty, otherwise returns the string
    var nilIfEmpty: String? {
        guard let self = self, !self.isEmpty else { return nil }
        return self
    }
}

// MARK: - Safe Optional Collection

extension Optional where Wrapped: Collection {
    /// Returns true if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

extension Optional where Wrapped: RangeReplaceableCollection {
    /// Returns empty collection if nil
    var orEmpty: Wrapped {
        self ?? Wrapped()
    }
}

// MARK: - Safe Optional Numeric

extension Optional where Wrapped: Numeric {
    /// Returns zero if nil
    var orZero: Wrapped {
        self ?? 0
    }
}

extension Optional where Wrapped == Int {
    /// Returns nil if the value is zero, otherwise returns the value
    var nilIfZero: Int? {
        guard let self = self, self != 0 else { return nil }
        return self
    }
}

// MARK: - Safe Date Operations

extension Date {
    /// Safely add time interval, clamping to valid date range
    func safeAddingTimeInterval(_ interval: TimeInterval) -> Date {
        let maxDate = Date.distantFuture
        let minDate = Date.distantPast

        let newDate = addingTimeInterval(interval)

        if newDate > maxDate { return maxDate }
        if newDate < minDate { return minDate }
        return newDate
    }

    /// Safely add date components
    func safeAdding(_ component: Calendar.Component, value: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: component, value: value, to: self) ?? self
    }

    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }

    /// Check if date is in the future
    var isFuture: Bool {
        self > Date()
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Days from now (negative if in past)
    var daysFromNow: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: self)).day ?? 0
    }
}

// MARK: - Safe Optional Date

extension Optional where Wrapped == Date {
    /// Returns current date if nil
    var orNow: Date {
        self ?? Date()
    }

    /// Check if date is in the past (false if nil)
    var isPast: Bool {
        self?.isPast ?? false
    }

    /// Check if date is in the future (false if nil)
    var isFuture: Bool {
        self?.isFuture ?? false
    }
}

// MARK: - Safe PHAsset Operations

extension PHAsset {
    /// Safely get creation date or current date
    var safeCreationDate: Date {
        creationDate ?? Date()
    }

    /// Safely get modification date or creation date or current date
    var safeModificationDate: Date {
        modificationDate ?? creationDate ?? Date()
    }

    /// Safely get location coordinates
    var safeLocation: (latitude: Double, longitude: Double)? {
        guard let location = location else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
}

// MARK: - Safe URL Operations

extension URL {
    /// Safely append path component
    func safeAppendingPathComponent(_ pathComponent: String) -> URL {
        guard !pathComponent.isEmpty else { return self }
        return appendingPathComponent(pathComponent)
    }

    /// Check if URL is reachable (file URLs only)
    var isReachable: Bool {
        guard isFileURL else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}

// MARK: - Safe Binding Extensions

extension Binding {
    /// Create a binding with a default value for nil optionals
    func defaultValue<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == String? {
    /// Convert optional string binding to non-optional with empty string default
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == Int? {
    /// Convert optional int binding to non-optional with zero default
    func orZero() -> Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue ?? 0 },
            set: { self.wrappedValue = $0 == 0 ? nil : $0 }
        )
    }
}

extension Binding where Value == Double? {
    /// Convert optional double binding to non-optional with zero default
    func orZero() -> Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue ?? 0.0 },
            set: { self.wrappedValue = $0 == 0.0 ? nil : $0 }
        )
    }
}

// MARK: - Safe Index Binding

struct SafeIndexBinding {
    /// Create a safe binding that clamps to valid indices
    static func create<T>(
        for array: [T],
        index: Binding<Int>,
        fallback: Int = 0
    ) -> Binding<Int> {
        Binding(
            get: {
                let idx = index.wrappedValue
                guard array.indices.contains(idx) else { return fallback }
                return idx
            },
            set: { newValue in
                guard array.indices.contains(newValue) else { return }
                index.wrappedValue = newValue
            }
        )
    }

    /// Create a safe optional binding for array selection
    static func createOptional<T, ID: Hashable>(
        for array: [T],
        selection: Binding<ID?>,
        idKeyPath: KeyPath<T, ID>
    ) -> Binding<ID?> {
        Binding(
            get: {
                guard let id = selection.wrappedValue else { return nil }
                return array.contains { $0[keyPath: idKeyPath] == id } ? id : nil
            },
            set: { newValue in
                if let id = newValue, array.contains(where: { $0[keyPath: idKeyPath] == id }) {
                    selection.wrappedValue = id
                } else {
                    selection.wrappedValue = nil
                }
            }
        )
    }
}
