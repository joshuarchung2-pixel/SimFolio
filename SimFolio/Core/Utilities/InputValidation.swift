// InputValidation.swift
// SimFolio - Input Validation Utilities
//
// Provides validation functions for user input throughout the app.
// Ensures data integrity and provides meaningful error messages.

import Foundation
import SwiftUI

// MARK: - Validation Result

/// Result of a validation check
enum ValidationResult: Equatable {
    case valid
    case invalid(String)

    /// Whether the validation passed
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    /// Error message if validation failed
    var errorMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }

    /// Combine multiple validation results (returns first error)
    static func combine(_ results: ValidationResult...) -> ValidationResult {
        for result in results {
            if case .invalid = result {
                return result
            }
        }
        return .valid
    }
}

// MARK: - Input Validator

/// Central validator for all app inputs
struct InputValidator {

    // MARK: - Text Validation

    /// Validate portfolio name
    static func validatePortfolioName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Portfolio name is required")
        }

        if trimmed.count < 2 {
            return .invalid("Portfolio name must be at least 2 characters")
        }

        if trimmed.count > 100 {
            return .invalid("Portfolio name must be less than 100 characters")
        }

        return .valid
    }

    /// Validate procedure name
    static func validateProcedureName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Procedure name is required")
        }

        if trimmed.count < 2 {
            return .invalid("Procedure name must be at least 2 characters")
        }

        if trimmed.count > 50 {
            return .invalid("Procedure name must be less than 50 characters")
        }

        return .valid
    }

    /// Validate user name (first or last)
    static func validateUserName(_ name: String, fieldName: String = "Name") -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .valid // Names are optional
        }

        if trimmed.count > 50 {
            return .invalid("\(fieldName) must be less than 50 characters")
        }

        // Check for invalid characters
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))

        if trimmed.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return .invalid("\(fieldName) contains invalid characters")
        }

        return .valid
    }

    /// Validate notes text
    static func validateNotes(_ notes: String) -> ValidationResult {
        if notes.count > 1000 {
            return .invalid("Notes must be less than 1000 characters")
        }

        return .valid
    }

    /// Validate school name
    static func validateSchoolName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .valid // School is optional
        }

        if trimmed.count > 100 {
            return .invalid("School name must be less than 100 characters")
        }

        return .valid
    }

    // MARK: - Numeric Validation

    /// Validate tooth number
    /// Valid ranges: 1-32 (permanent), 51-55, 61-65, 71-75, 81-85 (primary/deciduous)
    static func validateToothNumber(_ number: Int?) -> ValidationResult {
        guard let number = number else {
            return .valid // Tooth number is optional
        }

        // Permanent teeth: 1-32
        // Primary teeth: 51-55 (upper right), 61-65 (upper left), 71-75 (lower left), 81-85 (lower right)
        let validRanges: [ClosedRange<Int>] = [
            1...32,
            51...55,
            61...65,
            71...75,
            81...85
        ]

        if !validRanges.contains(where: { $0.contains(number) }) {
            return .invalid("Invalid tooth number. Use 1-32 for permanent teeth.")
        }

        return .valid
    }

    /// Validate star rating
    static func validateRating(_ rating: Int) -> ValidationResult {
        if rating < 0 || rating > 5 {
            return .invalid("Rating must be between 0 and 5")
        }

        return .valid
    }

    /// Validate photos per angle count
    static func validatePhotosPerAngle(_ count: Int) -> ValidationResult {
        if count < 1 {
            return .invalid("Must require at least 1 photo per angle")
        }

        if count > 10 {
            return .invalid("Cannot require more than 10 photos per angle")
        }

        return .valid
    }

    /// Validate class year
    static func validateClassYear(_ year: Int?) -> ValidationResult {
        guard let year = year else {
            return .valid // Class year is optional
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let validRange = (currentYear - 10)...(currentYear + 10)

        if !validRange.contains(year) {
            return .invalid("Class year must be within 10 years of current year")
        }

        return .valid
    }

    // MARK: - Date Validation

    /// Validate portfolio due date
    static func validateDueDate(_ date: Date?) -> ValidationResult {
        guard let date = date else {
            return .valid // Due date is optional
        }

        // Due date shouldn't be more than 5 years in the future
        let maxFutureDate = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date()

        if date > maxFutureDate {
            return .invalid("Due date is too far in the future")
        }

        return .valid
    }

    /// Validate date is not in the past
    static func validateNotInPast(_ date: Date?, fieldName: String = "Date") -> ValidationResult {
        guard let date = date else {
            return .valid
        }

        let startOfToday = Calendar.current.startOfDay(for: Date())

        if date < startOfToday {
            return .invalid("\(fieldName) cannot be in the past")
        }

        return .valid
    }

    // MARK: - Color Validation

    /// Validate hex color string
    static func validateHexColor(_ hex: String) -> ValidationResult {
        let hexPattern = "^#[0-9A-Fa-f]{6}$"
        guard let regex = try? NSRegularExpression(pattern: hexPattern) else {
            return .invalid("Invalid color format")
        }

        let range = NSRange(hex.startIndex..., in: hex)

        if regex.firstMatch(in: hex, range: range) == nil {
            return .invalid("Color must be in #RRGGBB format")
        }

        return .valid
    }

    // MARK: - Collection Validation

    /// Validate requirement has at least one stage selected
    static func validateStagesSelection(_ stages: [String]) -> ValidationResult {
        if stages.isEmpty {
            return .invalid("Select at least one stage")
        }

        return .valid
    }

    /// Validate requirement has at least one angle selected
    static func validateAnglesSelection(_ angles: [String]) -> ValidationResult {
        if angles.isEmpty {
            return .invalid("Select at least one angle")
        }

        return .valid
    }

    /// Validate portfolio has at least one requirement
    static func validateRequirements(_ requirements: [PortfolioRequirement]) -> ValidationResult {
        if requirements.isEmpty {
            return .invalid("Add at least one requirement to the portfolio")
        }

        return .valid
    }

    // MARK: - Composite Validation

    /// Validate complete portfolio creation form
    static func validatePortfolioForm(
        name: String,
        dueDate: Date?,
        requirements: [PortfolioRequirement]
    ) -> ValidationResult {
        return ValidationResult.combine(
            validatePortfolioName(name),
            validateDueDate(dueDate),
            validateRequirements(requirements)
        )
    }

    /// Validate complete requirement form
    static func validateRequirementForm(
        procedure: String,
        stages: [String],
        angles: [String],
        photosPerAngle: Int
    ) -> ValidationResult {
        return ValidationResult.combine(
            validateProcedureName(procedure),
            validateStagesSelection(stages),
            validateAnglesSelection(angles),
            validatePhotosPerAngle(photosPerAngle)
        )
    }

    /// Validate complete user profile form
    static func validateProfileForm(
        firstName: String,
        lastName: String,
        school: String,
        classYear: Int?
    ) -> ValidationResult {
        return ValidationResult.combine(
            validateUserName(firstName, fieldName: "First name"),
            validateUserName(lastName, fieldName: "Last name"),
            validateSchoolName(school),
            validateClassYear(classYear)
        )
    }
}

// MARK: - Validation View Modifier

/// View modifier to display validation errors
struct ValidationModifier: ViewModifier {
    let validation: ValidationResult
    let showError: Bool

    init(validation: ValidationResult, showError: Bool = true) {
        self.validation = validation
        self.showError = showError
    }

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content

            if showError, let errorMessage = validation.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validation)
    }
}

extension View {
    /// Add validation error display to a view
    func validation(_ result: ValidationResult, showError: Bool = true) -> some View {
        modifier(ValidationModifier(validation: result, showError: showError))
    }
}

// MARK: - Validated Text Field

/// Text field with built-in validation
struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validator: (String) -> ValidationResult
    let placeholder: String

    @State private var validationResult: ValidationResult = .valid
    @State private var hasEdited = false
    @FocusState private var isFocused: Bool

    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        validator: @escaping (String) -> ValidationResult
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.validator = validator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    hasEdited = true
                    validationResult = validator(newValue)
                }
                .onChange(of: isFocused) { focused in
                    if !focused && hasEdited {
                        validationResult = validator(text)
                    }
                }

            if hasEdited && !isFocused, let errorMessage = validationResult.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    var isValid: Bool {
        validationResult.isValid
    }
}

// MARK: - Character Limit Modifier

/// View modifier to enforce character limits on text fields
struct CharacterLimitModifier: ViewModifier {
    @Binding var text: String
    let limit: Int
    let showCount: Bool

    func body(content: Content) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            content
                .onChange(of: text) { newValue in
                    if newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }

            if showCount {
                Text("\(text.count)/\(limit)")
                    .font(.caption)
                    .foregroundStyle(text.count >= limit ? .red : .secondary)
            }
        }
    }
}

extension View {
    /// Limit text input to a maximum number of characters
    func characterLimit(_ limit: Int, text: Binding<String>, showCount: Bool = false) -> some View {
        modifier(CharacterLimitModifier(text: text, limit: limit, showCount: showCount))
    }
}
