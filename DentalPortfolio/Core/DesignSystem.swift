// DesignSystem.swift
// Dental Portfolio - Design System Foundation
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

/// Central design system containing all design tokens for the Dental Portfolio app
struct AppTheme {

    // MARK: - Colors

    /// Color palette for the app
    /// Light mode only (for now)
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

        // MARK: Background Colors

        /// Main app background - Light gray
        static let background = Color(hex: "F8FAFC")

        /// Surface color for cards and elevated elements - White
        static let surface = Color(hex: "FFFFFF")

        /// Secondary surface for nested or grouped elements
        static let surfaceSecondary = Color(hex: "F1F5F9")

        // MARK: Text Colors

        /// Primary text - used for headings and important content
        static let textPrimary = Color(hex: "0F172A")

        /// Secondary text - used for body text and descriptions
        static let textSecondary = Color(hex: "64748B")

        /// Tertiary text - used for placeholders and subtle text
        static let textTertiary = Color(hex: "94A3B8")
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

        /// Subheadline - 15pt Regular
        /// Use for secondary body text
        static let subheadline = Font.system(size: 15, weight: .regular)

        /// Footnote - 13pt Regular
        /// Use for supporting text and metadata
        static let footnote = Font.system(size: 13, weight: .regular)

        /// Caption - 12pt Regular
        /// Use for labels and small descriptive text
        static let caption = Font.system(size: 12, weight: .regular)

        /// Caption 2 - 11pt Regular
        /// Use for very small text like timestamps
        static let caption2 = Font.system(size: 11, weight: .regular)
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
