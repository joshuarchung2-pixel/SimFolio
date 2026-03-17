// DesignSystem.swift
// SimFolio - Design System Foundation
//
// This file contains the foundational design tokens and styles used throughout the app.
// Inspired by clean, modern UI patterns from Coinbase, Airbnb, and Notion.
//
// Contents:
// - Color extension for hex initialization
// - AppTheme: Central design system with Colors, Typography, Spacing, CornerRadius, Shadows
// - Shadow ViewModifiers for easy application
// - Procedure color helper function

import SwiftUI

// MARK: - Color Extension for Hex Initialization

extension Color {
    /// Initialize a Color from a hex string
    /// - Parameter hex: A hex color string (with or without #), e.g., "2563EB" or "#2563EB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - AppTheme

/// Central design system containing all design tokens for the SimFolio app
struct AppTheme {

    // MARK: - Colors

    /// Color palette for the app
    /// Supports both light and dark mode via asset catalog colors
    struct Colors {

        // MARK: Primary Colors

        /// Primary brand color - used for actions, links, and interactive elements
        static let primary = Color(hex: "2563EB")

        /// Secondary color - used for secondary text and less prominent elements
        static let secondary = Color(hex: "64748B")

        // MARK: Procedure Colors
        // These colors are consistent throughout the app for procedure identification

        /// Class I restoration - Blue
        static let class1 = Color(hex: "3B82F6")

        /// Class II restoration - Green
        static let class2 = Color(hex: "22C55E")

        /// Class III restoration - Orange
        static let class3 = Color(hex: "F97316")

        /// Crown procedure - Purple
        static let crown = Color(hex: "A855F7")

        // MARK: Status Colors

        /// Success state - Green
        static let success = Color(hex: "22C55E")

        /// Warning state - Yellow
        static let warning = Color(hex: "EAB308")

        /// Error state - Red
        static let error = Color(hex: "EF4444")

        /// Info state - Blue
        static let info = Color(hex: "3B82F6")

        // MARK: Background Colors (Adaptive)

        /// Main app background - adapts to light/dark mode
        static let background = Color("Background")

        /// Surface color for cards and elevated elements - adapts to light/dark mode
        static let surface = Color("Surface")

        /// Secondary surface for nested or grouped elements - adapts to light/dark mode
        static let surfaceSecondary = Color("SurfaceSecondary")

        // MARK: Text Colors (Adaptive)

        /// Primary text - used for headings and important content - adapts to light/dark mode
        static let textPrimary = Color("TextPrimary")

        /// Secondary text - used for body text and descriptions - adapts to light/dark mode
        static let textSecondary = Color("TextSecondary")

        /// Tertiary text - used for placeholders and subtle text - adapts to light/dark mode
        static let textTertiary = Color("TextTertiary")

        // MARK: Divider Colors (Adaptive)

        /// Divider color - used for separators and borders - adapts to light/dark mode
        static let divider = Color("Divider")
    }

    // MARK: - Typography

    /// Typography system using Nexa for headings and system font for body
    struct Typography {

        // MARK: Headings - Nexa Bold
        // Use these for titles, section headers, and prominent text

        /// Large title - 34pt Nexa Bold
        /// Use for main screen titles
        static let largeTitle = Font.custom("Nexa-Bold", size: 34)

        /// Title - 28pt Nexa Bold
        /// Use for prominent section headers
        static let title = Font.custom("Nexa-Bold", size: 28)

        /// Title 2 - 22pt Nexa Bold
        /// Use for secondary titles
        static let title2 = Font.custom("Nexa-Bold", size: 22)

        /// Title 3 - 20pt Nexa Bold
        /// Use for tertiary titles and card headers
        static let title3 = Font.custom("Nexa-Bold", size: 20)

        // MARK: Body - System Font
        // Use these for body text, labels, and general content

        /// Headline - 17pt Semibold
        /// Use for emphasized body text and list headers
        static let headline = Font.system(size: 17, weight: .semibold)

        /// Body - 17pt Regular
        /// Use for main body text
        static let body = Font.system(size: 17, weight: .regular)

        /// Body Bold - 17pt Semibold
        /// Use for emphasized body text
        static let bodyBold = Font.system(size: 17, weight: .semibold)

        /// Subheadline - 15pt Regular
        /// Use for secondary body text
        static let subheadline = Font.system(size: 15, weight: .regular)

        /// Footnote - 13pt Regular
        /// Use for supporting text and metadata
        static let footnote = Font.system(size: 13, weight: .regular)

        /// Caption - 12pt Regular
        /// Use for labels and small descriptive text
        static let caption = Font.system(size: 12, weight: .regular)

        /// Caption 2 - Caption size
        /// Use for very small text like timestamps
        static let caption2 = Font.caption
    }

    // MARK: - Spacing

    /// Consistent spacing scale based on 4pt grid
    struct Spacing {
        /// Extra extra small - 2pt
        static let xxs: CGFloat = 2

        /// Extra small - 4pt
        static let xs: CGFloat = 4

        /// Small - 8pt
        static let sm: CGFloat = 8

        /// Medium - 16pt (base unit)
        static let md: CGFloat = 16

        /// Large - 24pt
        static let lg: CGFloat = 24

        /// Extra large - 32pt
        static let xl: CGFloat = 32

        /// Extra extra large - 48pt
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    /// Corner radius presets for consistent rounded corners
    struct CornerRadius {
        /// Extra extra small radius - 2pt
        /// Use for minimal rounding, thin badges
        static let xxs: CGFloat = 2

        /// Extra small radius - 4pt
        /// Use for small badges, indicators, compact elements
        static let xs: CGFloat = 4

        /// Small radius - 8pt
        /// Use for buttons, small cards, input fields
        static let small: CGFloat = 8

        /// Medium radius - 12pt
        /// Use for cards, modals
        static let medium: CGFloat = 12

        /// Large radius - 16pt
        /// Use for large cards, sheets
        static let large: CGFloat = 16

        /// Extra large radius - 20pt
        /// Use for prominent containers
        static let xl: CGFloat = 20

        /// Full/Pill radius - 9999pt
        /// Use for pills, tags, fully rounded buttons
        static let full: CGFloat = 9999
    }

    // MARK: - Opacity

    /// Standardized opacity values for consistent transparency
    struct Opacity {
        /// Subtle opacity - 10%
        /// Use for very light overlays, disabled backgrounds
        static let subtle: Double = 0.1

        /// Light opacity - 20%
        /// Use for light overlays, hover states
        static let light: Double = 0.2

        /// Medium opacity - 30%
        /// Use for moderate overlays, secondary elements
        static let medium: Double = 0.3

        /// Heavy opacity - 50%
        /// Use for prominent overlays, dimmed backgrounds
        static let heavy: Double = 0.5

        /// Prominent opacity - 70%
        /// Use for strong overlays, modal backgrounds
        static let prominent: Double = 0.7

        /// Strong opacity - 80%
        /// Use for near-solid overlays
        static let strong: Double = 0.8

        /// Full opacity - 100%
        /// Use for solid elements (reference value)
        static let full: Double = 1.0
    }

    // MARK: - Icon Sizes

    /// Standardized icon sizes for consistent iconography
    struct IconSize {
        /// Extra small - 12pt
        /// Use for inline indicators, badges
        static let xs: CGFloat = 12

        /// Small - 16pt
        /// Use for small buttons, list accessories
        static let sm: CGFloat = 16

        /// Medium - 20pt
        /// Use for standard icons, toolbar items
        static let md: CGFloat = 20

        /// Large - 24pt
        /// Use for prominent icons, navigation
        static let lg: CGFloat = 24

        /// Extra large - 32pt
        /// Use for feature icons, empty states
        static let xl: CGFloat = 32

        /// Extra extra large - 48pt
        /// Use for hero icons, illustrations
        static let xxl: CGFloat = 48
    }

    // MARK: - Shadows

    /// Shadow presets for elevation hierarchy
    struct Shadows {
        /// Small shadow - subtle elevation
        /// Use for buttons, small interactive elements
        static let small = ShadowStyle(
            color: Color.black.opacity(0.04),
            radius: 4,
            x: 0,
            y: 2
        )

        /// Medium shadow - moderate elevation
        /// Use for cards, dropdowns
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )

        /// Large shadow - prominent elevation
        /// Use for modals, popovers, floating elements
        static let large = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 8
        )
    }

    // MARK: - Procedure Color Helper

    /// Get the appropriate color for a dental procedure type
    /// - Parameter procedure: The procedure name (case-insensitive)
    /// - Returns: The corresponding procedure color, or secondary color if not found
    static func procedureColor(for procedure: String) -> Color {
        switch procedure.lowercased() {
        case "class 1", "class1", "class i":
            return Colors.class1
        case "class 2", "class2", "class ii":
            return Colors.class2
        case "class 3", "class3", "class iii":
            return Colors.class3
        case "crown", "crowns":
            return Colors.crown
        default:
            return Colors.secondary
        }
    }

    // MARK: - Stage Color Helper

    /// Get the appropriate color for a stage
    /// - Parameter stage: The stage name
    /// - Returns: The stage's color from MetadataManager, or gray for unknown stages
    static func stageColor(for stage: String) -> Color {
        MetadataManager.shared.stageColor(for: stage)
    }

    /// Get the icon name for a stage
    /// - Parameter stage: The stage name
    /// - Returns: The stage's icon name from MetadataManager
    static func stageIcon(for stage: String) -> String {
        MetadataManager.shared.stageIcon(for: stage)
    }

    // MARK: - Angle Color Helper

    /// Get the appropriate color for a viewing angle
    /// - Parameter angle: The angle name (case-insensitive)
    /// - Returns: The corresponding angle color
    static func angleColor(for angle: String) -> Color {
        switch angle.lowercased() {
        case "occlusal", "incisal", "occlusal/incisal":
            return Colors.class1 // Blue
        case "buccal", "facial", "buccal/facial":
            return Colors.class2 // Green
        case "lingual", "palatal":
            return Colors.class3 // Orange
        case "mesial":
            return Colors.crown // Purple
        case "distal":
            return Color(hex: "EC4899") // Pink
        case "facial straight":
            return Color(hex: "14B8A6") // Teal
        case "facial retracted":
            return Color(hex: "8B5CF6") // Violet
        default:
            return Colors.secondary
        }
    }
}

// MARK: - Shadow Style

/// A struct to encapsulate shadow properties
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Shadow View Modifier

/// A ViewModifier that applies a shadow style
struct ShadowModifier: ViewModifier {
    let style: ShadowStyle

    func body(content: Content) -> some View {
        content.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - View Extension for Shadows

extension View {
    /// Apply a small shadow (subtle elevation)
    func shadowSmall() -> some View {
        modifier(ShadowModifier(style: AppTheme.Shadows.small))
    }

    /// Apply a medium shadow (moderate elevation)
    func shadowMedium() -> some View {
        modifier(ShadowModifier(style: AppTheme.Shadows.medium))
    }

    /// Apply a large shadow (prominent elevation)
    func shadowLarge() -> some View {
        modifier(ShadowModifier(style: AppTheme.Shadows.large))
    }

    /// Apply a custom shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        modifier(ShadowModifier(style: style))
    }
}

// MARK: - Convenience Type Aliases

/// Shorthand aliases for common design system access
typealias Theme = AppTheme
typealias ThemeColors = AppTheme.Colors
typealias ThemeTypography = AppTheme.Typography
typealias ThemeSpacing = AppTheme.Spacing
typealias ThemeCornerRadius = AppTheme.CornerRadius
typealias ThemeShadows = AppTheme.Shadows
typealias ThemeOpacity = AppTheme.Opacity
typealias ThemeIconSize = AppTheme.IconSize
