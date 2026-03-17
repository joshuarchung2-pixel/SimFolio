// StageConfig.swift
// SimFolio - Stage Configuration Model
//
// This model represents a configurable stage type with
// custom colors, icons, enable/disable state, and sort ordering.
//
// Features:
// - Persistent storage via Codable
// - Default stages (Pre-Op, Preparation, Restoration) with preset colors/icons
// - Custom stage support
// - Enable/disable without deletion
// - Custom sort ordering

import SwiftUI

// MARK: - StageConfig

/// Configuration for a stage type
struct StageConfig: Identifiable, Codable, Equatable {
    /// Unique identifier
    let id: String

    /// Display name of the stage
    var name: String

    /// Hex color string (e.g., "#EAB308")
    var colorHex: String

    /// SF Symbol name or "custom:AssetName" for asset catalog images
    var iconName: String

    /// Whether this is a built-in default stage
    var isDefault: Bool

    /// Whether this stage is enabled (appears in capture/tagging)
    var isEnabled: Bool

    /// Sort order for display
    var sortOrder: Int

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        iconName: String,
        isDefault: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.isDefault = isDefault
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    // MARK: - Computed Properties

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex)
    }

    /// Whether the icon is a custom asset (vs SF Symbol)
    var isCustomIcon: Bool {
        iconName.hasPrefix("custom:")
    }

    /// The asset name for custom icons
    var customIconName: String? {
        guard isCustomIcon else { return nil }
        return String(iconName.dropFirst("custom:".count))
    }

    /// The SF Symbol name (returns nil if custom icon)
    var sfSymbolName: String? {
        guard !isCustomIcon else { return nil }
        return iconName
    }

    // MARK: - Default Stages

    /// Default stage configurations
    static let defaultStages: [StageConfig] = [
        StageConfig(
            id: "pre-op",
            name: "Pre-Op",
            colorHex: "#3B82F6",  // Blue
            iconName: "custom:ToothIcon",
            isDefault: true,
            isEnabled: true,
            sortOrder: 0
        ),
        StageConfig(
            id: "preparation",
            name: "Preparation",
            colorHex: "#EAB308",  // Yellow/Warning
            iconName: "wrench.and.screwdriver.fill",
            isDefault: true,
            isEnabled: true,
            sortOrder: 1
        ),
        StageConfig(
            id: "restoration",
            name: "Restoration",
            colorHex: "#22C55E",  // Green/Success
            iconName: "checkmark.seal.fill",
            isDefault: true,
            isEnabled: true,
            sortOrder: 2
        )
    ]

    /// Default color for custom stages (Indigo)
    static let defaultCustomColorHex = "#6366F1"

    /// Default icon for custom stages
    static let defaultCustomIconName = "tag.fill"

    /// Neutral color for inactive/deleted stages
    static let inactiveColorHex = "#9CA3AF"  // Gray
}

// MARK: - Stage Icon View

/// A view that displays either an SF Symbol or custom asset icon for a stage
struct StageIconView: View {
    let stageConfig: StageConfig
    var size: CGFloat = 24
    var foregroundColor: Color? = nil

    var body: some View {
        if stageConfig.isCustomIcon, let assetName = stageConfig.customIconName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(foregroundColor ?? stageConfig.color)
        } else if let symbolName = stageConfig.sfSymbolName {
            Image(systemName: symbolName)
                .font(.system(size: size))
                .foregroundStyle(foregroundColor ?? stageConfig.color)
        } else {
            // Fallback
            Image(systemName: "tag.fill")
                .font(.system(size: size))
                .foregroundStyle(foregroundColor ?? stageConfig.color)
        }
    }
}
