// ProcedureConfig.swift
// Dental Portfolio - Procedure Configuration Model
//
// This model represents a configurable dental procedure type with
// custom colors, enable/disable state, and sort ordering.
//
// Features:
// - Persistent storage via Codable
// - Default procedures with preset colors
// - Custom procedure support
// - Enable/disable without deletion
// - Custom sort ordering

import SwiftUI

// MARK: - ProcedureConfig

/// Configuration for a dental procedure type
struct ProcedureConfig: Identifiable, Codable, Equatable {
    /// Unique identifier
    let id: String

    /// Display name of the procedure
    var name: String

    /// Hex color string (e.g., "#3B82F6")
    var colorHex: String

    /// Whether this is a built-in default procedure
    var isDefault: Bool

    /// Whether this procedure is enabled (appears in capture/tagging)
    var isEnabled: Bool

    /// Sort order for display
    var sortOrder: Int

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        isDefault: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    // MARK: - Computed Properties

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex)
    }

    // MARK: - Default Procedures

    /// Default procedure configurations
    static let defaultProcedures: [ProcedureConfig] = [
        ProcedureConfig(name: "Class 1", colorHex: "#3B82F6", isDefault: true, sortOrder: 0),
        ProcedureConfig(name: "Class 2", colorHex: "#10B981", isDefault: true, sortOrder: 1),
        ProcedureConfig(name: "Class 3", colorHex: "#8B5CF6", isDefault: true, sortOrder: 2),
        ProcedureConfig(name: "Class 4", colorHex: "#F59E0B", isDefault: true, sortOrder: 3),
        ProcedureConfig(name: "Class 5", colorHex: "#EF4444", isDefault: true, sortOrder: 4),
        ProcedureConfig(name: "Crown", colorHex: "#EC4899", isDefault: true, sortOrder: 5),
        ProcedureConfig(name: "Bridge", colorHex: "#06B6D4", isDefault: true, sortOrder: 6),
        ProcedureConfig(name: "Veneer", colorHex: "#84CC16", isDefault: true, sortOrder: 7),
        ProcedureConfig(name: "Inlay", colorHex: "#F97316", isDefault: true, sortOrder: 8),
        ProcedureConfig(name: "Onlay", colorHex: "#6366F1", isDefault: true, sortOrder: 9),
        ProcedureConfig(name: "Root Canal", colorHex: "#14B8A6", isDefault: true, sortOrder: 10),
        ProcedureConfig(name: "Extraction", colorHex: "#DC2626", isDefault: true, sortOrder: 11)
    ]
}

// MARK: - Color Hex Conversion Extension

extension Color {
    /// Convert Color to hex string
    /// - Returns: Hex string in format "#RRGGBB"
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }

        let r: Int
        let g: Int
        let b: Int

        if components.count >= 3 {
            r = Int(components[0] * 255)
            g = Int(components[1] * 255)
            b = Int(components[2] * 255)
        } else {
            // Grayscale
            r = Int(components[0] * 255)
            g = Int(components[0] * 255)
            b = Int(components[0] * 255)
        }

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
