// Components.swift
// Dental Portfolio - Reusable UI Components
//
// This file contains the foundational reusable components used throughout the app.
// All components use AppTheme values for consistent styling.
//
// Contents (Part 1):
// - DPCard: Standard card container with shadow
// - DPButton: Styled button with multiple variants
// - DPTagPill: Colored tag/pill for procedures, stages, angles
// - DPIconButton: Circular icon button

import SwiftUI

// MARK: - DPCard

/// Standard card container with configurable padding, background, corner radius, and shadow
struct DPCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var backgroundColor: Color
    var cornerRadius: CGFloat
    var shadowStyle: ShadowStyle

    /// Shadow style options for the card
    enum ShadowStyle {
        case none
        case small
        case medium
        case large
    }

    /// Create a card with default styling
    /// - Parameter content: The content to display inside the card
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = AppTheme.Spacing.md
        self.backgroundColor = AppTheme.Colors.surface
        self.cornerRadius = AppTheme.CornerRadius.medium
        self.shadowStyle = .medium
    }

    /// Create a card with custom styling
    /// - Parameters:
    ///   - padding: Inner padding of the card
    ///   - backgroundColor: Background color of the card
    ///   - cornerRadius: Corner radius of the card
    ///   - shadowStyle: Shadow style to apply
    ///   - content: The content to display inside the card
    init(
        padding: CGFloat = AppTheme.Spacing.md,
        backgroundColor: Color = AppTheme.Colors.surface,
        cornerRadius: CGFloat = AppTheme.CornerRadius.medium,
        shadowStyle: ShadowStyle = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadowStyle
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .modifier(CardShadowModifier(style: shadowStyle))
    }
}

/// Modifier to apply shadow based on DPCard.ShadowStyle
private struct CardShadowModifier: ViewModifier {
    let style: DPCard<EmptyView>.ShadowStyle

    func body(content: Content) -> some View {
        switch style {
        case .none:
            content
        case .small:
            content.shadowSmall()
        case .medium:
            content.shadowMedium()
        case .large:
            content.shadowLarge()
        }
    }
}

// MARK: - DPButton

/// Styled button with multiple variants, sizes, and states
struct DPButton: View {
    let title: String
    var icon: String?
    var style: Style
    var size: Size
    var isFullWidth: Bool
    var isLoading: Bool
    var isDisabled: Bool
    let action: () -> Void

    /// Button style variants
    enum Style {
        /// Blue background, white text - for primary actions
        case primary
        /// White background, blue text with border - for secondary actions
        case secondary
        /// Transparent background, blue text - for tertiary actions
        case tertiary
        /// Red background, white text - for destructive actions
        case destructive
    }

    /// Button size variants
    enum Size {
        case small   // Height: 32pt
        case medium  // Height: 44pt
        case large   // Height: 52pt
    }

    @State private var isPressed = false

    /// Create a button with the specified properties
    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        size: Size = .medium,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(size == .small ? 0.7 : 0.85)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }

                Text(title)
                    .font(font)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: style == .secondary ? 1.5 : 0)
            )
        }
        .buttonStyle(DPButtonStyle(isPressed: $isPressed, isDisabled: isDisabled || isLoading))
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
    }

    // MARK: - Computed Properties

    private var height: CGFloat {
        switch size {
        case .small: return 32
        case .medium: return 44
        case .large: return 52
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return AppTheme.Spacing.sm
        case .medium: return AppTheme.Spacing.md
        case .large: return AppTheme.Spacing.lg
        }
    }

    private var font: Font {
        switch size {
        case .small: return AppTheme.Typography.footnote
        case .medium: return AppTheme.Typography.headline
        case .large: return AppTheme.Typography.headline
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 18
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return AppTheme.CornerRadius.small
        case .medium: return AppTheme.CornerRadius.small
        case .large: return AppTheme.CornerRadius.medium
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return AppTheme.Colors.primary
        case .secondary:
            return AppTheme.Colors.surface
        case .tertiary:
            return .clear
        case .destructive:
            return AppTheme.Colors.error
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return AppTheme.Colors.primary
        case .tertiary:
            return AppTheme.Colors.primary
        case .destructive:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return AppTheme.Colors.primary
        default:
            return .clear
        }
    }
}

/// Custom button style for press state handling
private struct DPButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                if !isDisabled {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - DPTagPill

/// Colored tag/pill component for displaying procedures, stages, angles, etc.
struct DPTagPill: View {
    let text: String
    var color: Color
    var size: Size
    var isSelected: Bool
    var showRemoveButton: Bool
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    /// Size variants for the tag pill
    enum Size {
        case small   // caption2 font, 4pt vertical padding
        case medium  // caption font, 6pt vertical padding
        case large   // subheadline font, 8pt vertical padding
    }

    @State private var isPressed = false

    /// Create a tag pill with the specified properties
    init(
        _ text: String,
        color: Color = AppTheme.Colors.primary,
        size: Size = .medium,
        isSelected: Bool = false,
        showRemoveButton: Bool = false,
        onTap: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.text = text
        self.color = color
        self.size = size
        self.isSelected = isSelected
        self.showRemoveButton = showRemoveButton
        self.onTap = onTap
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text(text)
                .font(font)
                .foregroundColor(color)

            if showRemoveButton {
                Button(action: {
                    onRemove?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: removeIconSize, weight: .semibold))
                        .foregroundColor(color)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(color.opacity(0.15))
        .cornerRadius(AppTheme.CornerRadius.full)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                .strokeBorder(isSelected ? color : .clear, lineWidth: 1.5)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onTapGesture {
            if let onTap = onTap {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    onTap()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var font: Font {
        switch size {
        case .small: return AppTheme.Typography.caption2
        case .medium: return AppTheme.Typography.caption
        case .large: return AppTheme.Typography.subheadline
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return AppTheme.Spacing.sm
        case .medium: return AppTheme.Spacing.sm + 2
        case .large: return AppTheme.Spacing.md
        }
    }

    private var removeIconSize: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
}

// MARK: - DPIconButton

/// Circular icon button with configurable size, colors, and shadow
struct DPIconButton: View {
    let icon: String
    var size: CGFloat
    var backgroundColor: Color
    var iconColor: Color
    var shadowStyle: DPCard<EmptyView>.ShadowStyle
    let action: () -> Void

    @State private var isPressed = false

    /// Create a circular icon button
    /// - Parameters:
    ///   - icon: SF Symbol name
    ///   - size: Button diameter (default 44pt)
    ///   - backgroundColor: Background color of the button
    ///   - iconColor: Color of the icon
    ///   - shadowStyle: Shadow style to apply
    ///   - action: Action to perform on tap
    init(
        icon: String,
        size: CGFloat = 44,
        backgroundColor: Color = AppTheme.Colors.surface,
        iconColor: Color = AppTheme.Colors.textPrimary,
        shadowStyle: DPCard<EmptyView>.ShadowStyle = .small,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
        self.shadowStyle = shadowStyle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
                .modifier(CardShadowModifier(style: shadowStyle))
        }
        .buttonStyle(DPIconButtonStyle(isPressed: $isPressed))
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
    }

    private var iconSize: CGFloat {
        size * 0.45
    }
}

/// Custom button style for icon button press state
private struct DPIconButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct Components_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // MARK: DPCard Preview
                Group {
                    Text("DPCard")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DPCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Card Title")
                                .font(AppTheme.Typography.headline)
                            Text("This is a standard card with medium shadow.")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }

                    DPCard(shadowStyle: .large) {
                        Text("Card with large shadow")
                            .font(AppTheme.Typography.body)
                    }
                }

                Divider()

                // MARK: DPButton Preview
                Group {
                    Text("DPButton")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: AppTheme.Spacing.sm) {
                        DPButton("Primary Button", icon: "plus") { }
                        DPButton("Secondary", style: .secondary) { }
                        DPButton("Tertiary", style: .tertiary) { }
                        DPButton("Destructive", icon: "trash", style: .destructive) { }
                        DPButton("Loading...", isLoading: true) { }
                        DPButton("Disabled", isDisabled: true) { }
                        DPButton("Full Width", isFullWidth: true) { }
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        DPButton("Small", size: .small) { }
                        DPButton("Medium", size: .medium) { }
                        DPButton("Large", size: .large) { }
                    }
                }

                Divider()

                // MARK: DPTagPill Preview
                Group {
                    Text("DPTagPill")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        DPTagPill("Class I", color: AppTheme.Colors.class1)
                        DPTagPill("Class II", color: AppTheme.Colors.class2)
                        DPTagPill("Class III", color: AppTheme.Colors.class3)
                        DPTagPill("Crown", color: AppTheme.Colors.crown)
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        DPTagPill("Small", size: .small)
                        DPTagPill("Medium", size: .medium)
                        DPTagPill("Large", size: .large)
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        DPTagPill("Selected", isSelected: true)
                        DPTagPill("Remove", showRemoveButton: true, onRemove: { })
                    }
                }

                Divider()

                // MARK: DPIconButton Preview
                Group {
                    Text("DPIconButton")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: AppTheme.Spacing.md) {
                        DPIconButton(icon: "camera.fill") { }
                        DPIconButton(icon: "photo.fill") { }
                        DPIconButton(icon: "square.and.arrow.up") { }
                        DPIconButton(
                            icon: "xmark",
                            backgroundColor: AppTheme.Colors.error,
                            iconColor: .white
                        ) { }
                    }

                    HStack(spacing: AppTheme.Spacing.md) {
                        DPIconButton(icon: "star.fill", size: 32) { }
                        DPIconButton(icon: "star.fill", size: 44) { }
                        DPIconButton(icon: "star.fill", size: 56) { }
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}
#endif
