// Components.swift
// Dental Portfolio - Reusable UI Components
//
// This file contains the foundational reusable components used throughout the app.
// All components use AppTheme values for consistent styling.
//
// Contents (Part 1 - Basic Components):
// - DPCard: Standard card container with shadow
// - DPButton: Styled button with multiple variants
// - DPTagPill: Colored tag/pill for procedures, stages, angles
// - DPIconButton: Circular icon button
//
// Contents (Part 2 - Progress & Feedback):
// - DPProgressBar: Linear progress indicator with auto-coloring
// - DPProgressRing: Circular progress indicator with label
// - DPEmptyState: Empty state view with icon, title, message, action
// - DPSectionHeader: List section header with optional action
// - DPToast: Temporary feedback message with ToastManager

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
        // Accessibility
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isDisabled || isLoading ? .isButton : [])
        .accessibilityAddTraits(isDisabled || isLoading ? .isStaticText : [])
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if isLoading {
            return "\(title), loading"
        }
        return title
    }

    private var accessibilityHint: String {
        if isDisabled {
            return "Button disabled"
        }
        if isLoading {
            return "Please wait"
        }
        return "Double tap to activate"
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
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tagAccessibilityLabel)
        .accessibilityHint(tagAccessibilityHint)
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Accessibility

    private var tagAccessibilityLabel: String {
        var label = "\(text) tag"
        if isSelected {
            label += ", selected"
        }
        return label
    }

    private var tagAccessibilityHint: String {
        if showRemoveButton {
            return "Double tap to remove"
        }
        if onTap != nil {
            return isSelected ? "Double tap to deselect" : "Double tap to select"
        }
        return ""
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

// MARK: - DPProgressBar

/// Linear progress indicator with auto-coloring based on progress level
struct DPProgressBar: View {
    let progress: Double
    var height: CGFloat
    var backgroundColor: Color
    var foregroundColor: Color?
    var cornerRadius: CGFloat?
    var showPercentageLabel: Bool
    var animate: Bool

    /// Create a linear progress bar
    /// - Parameters:
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - height: Height of the progress bar (default 8pt)
    ///   - backgroundColor: Background track color
    ///   - foregroundColor: Fill color (nil = auto-color based on progress)
    ///   - cornerRadius: Corner radius (nil = half of height)
    ///   - showPercentageLabel: Show percentage label on the right
    ///   - animate: Animate progress changes
    init(
        progress: Double,
        height: CGFloat = 8,
        backgroundColor: Color = AppTheme.Colors.surfaceSecondary,
        foregroundColor: Color? = nil,
        cornerRadius: CGFloat? = nil,
        showPercentageLabel: Bool = false,
        animate: Bool = true
    ) {
        self.progress = min(max(progress, 0), 1)
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.showPercentageLabel = showPercentageLabel
        self.animate = animate
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: effectiveCornerRadius)
                        .fill(backgroundColor)
                        .frame(height: height)

                    // Progress fill
                    RoundedRectangle(cornerRadius: effectiveCornerRadius)
                        .fill(effectiveForegroundColor)
                        .frame(width: geometry.size.width * progress, height: height)
                        .animation(animate ? .easeInOut(duration: 0.3) : nil, value: progress)
                }
            }
            .frame(height: height)

            if showPercentageLabel {
                Text("\(Int(progress * 100))%")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 40, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? (height / 2)
    }

    private var effectiveForegroundColor: Color {
        if let color = foregroundColor {
            return color
        }
        return Self.autoColor(for: progress)
    }

    /// Get auto-color based on progress level
    /// - Parameter progress: Progress value from 0.0 to 1.0
    /// - Returns: Color based on progress thresholds
    static func autoColor(for progress: Double) -> Color {
        switch progress {
        case ..<0.25:
            return AppTheme.Colors.error
        case ..<0.50:
            return Color(hex: "F97316") // Orange
        case ..<0.75:
            return AppTheme.Colors.warning
        default:
            return AppTheme.Colors.success
        }
    }
}

// MARK: - DPProgressRing

/// Circular progress indicator with centered label
struct DPProgressRing: View {
    let progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    var backgroundColor: Color
    var foregroundColor: Color?
    var showLabel: Bool
    var labelStyle: LabelStyle

    /// Label style options for the progress ring
    enum LabelStyle {
        /// Show percentage (e.g., "75%")
        case percentage
        /// Show fraction (e.g., "3/4")
        case fraction(current: Int, total: Int)
        /// Show custom text
        case custom(String)
    }

    /// Create a circular progress ring
    /// - Parameters:
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - size: Diameter of the ring (default 60pt)
    ///   - lineWidth: Width of the ring stroke (default 6pt)
    ///   - backgroundColor: Background track color
    ///   - foregroundColor: Progress color (nil = auto-color based on progress)
    ///   - showLabel: Show label in center
    ///   - labelStyle: Style of the label
    init(
        progress: Double,
        size: CGFloat = 60,
        lineWidth: CGFloat = 6,
        backgroundColor: Color = AppTheme.Colors.surfaceSecondary,
        foregroundColor: Color? = nil,
        showLabel: Bool = true,
        labelStyle: LabelStyle = .percentage
    ) {
        self.progress = min(max(progress, 0), 1)
        self.size = size
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.showLabel = showLabel
        self.labelStyle = labelStyle
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    effectiveForegroundColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Label
            if showLabel {
                Text(labelText)
                    .font(labelFont)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringAccessibilityLabel)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    // MARK: - Accessibility

    private var ringAccessibilityLabel: String {
        switch labelStyle {
        case .percentage:
            return "Progress"
        case .fraction(_, let total):
            return "Progress, \(total) total"
        case .custom(let text):
            return "\(text) progress"
        }
    }

    private var effectiveForegroundColor: Color {
        foregroundColor ?? DPProgressBar.autoColor(for: progress)
    }

    private var labelText: String {
        switch labelStyle {
        case .percentage:
            return "\(Int(progress * 100))%"
        case .fraction(let current, let total):
            return "\(current)/\(total)"
        case .custom(let text):
            return text
        }
    }

    private var labelFont: Font {
        if size < 50 {
            return AppTheme.Typography.caption2
        } else if size < 80 {
            return AppTheme.Typography.footnote
        } else {
            return AppTheme.Typography.subheadline
        }
    }
}

// MARK: - DPEmptyState

/// Empty state view with icon, title, message, and optional action
struct DPEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    /// Create an empty state view
    /// - Parameters:
    ///   - icon: SF Symbol name for the icon
    ///   - title: Title text
    ///   - message: Description message
    ///   - actionTitle: Optional action button title
    ///   - action: Optional action to perform
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                DPButton(actionTitle, style: .primary, size: .medium) {
                    action()
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DPSectionHeader

/// Section header with title, optional subtitle, and optional action
struct DPSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    /// Create a section header
    /// - Parameters:
    ///   - title: Main title text
    ///   - subtitle: Optional subtitle text
    ///   - actionTitle: Optional action link text (e.g., "See All")
    ///   - action: Optional action to perform
    init(
        _ title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - DPToast

/// Temporary feedback message with type-based styling
struct DPToast: View {
    let message: String
    var type: ToastType
    var icon: String?

    /// Toast type variants
    enum ToastType {
        case success
        case warning
        case error
        case info

        var color: Color {
            switch self {
            case .success: return AppTheme.Colors.success
            case .warning: return AppTheme.Colors.warning
            case .error: return AppTheme.Colors.error
            case .info: return AppTheme.Colors.primary
            }
        }

        var defaultIcon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    /// Create a toast message
    /// - Parameters:
    ///   - message: Message text to display
    ///   - type: Type of toast (success, warning, error, info)
    ///   - icon: Custom SF Symbol icon (nil = auto based on type)
    init(
        _ message: String,
        type: ToastType = .info,
        icon: String? = nil
    ) {
        self.message = message
        self.type = type
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Colored left border
            RoundedRectangle(cornerRadius: 2)
                .fill(type.color)
                .frame(width: 4)

            // Icon
            Image(systemName: icon ?? type.defaultIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(type.color)

            // Message
            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.trailing, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.small)
        .shadowMedium()
    }
}

// MARK: - ToastManager

/// Observable object for managing toast display
class ToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    @Published var isShowing: Bool = false

    private var dismissTask: DispatchWorkItem?

    /// Data for a toast message
    struct ToastData: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: DPToast.ToastType
        let icon: String?
        let duration: TimeInterval

        static func == (lhs: ToastData, rhs: ToastData) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Show a toast message
    /// - Parameters:
    ///   - message: Message to display
    ///   - type: Toast type
    ///   - icon: Custom icon (optional)
    ///   - duration: Display duration in seconds (default 3)
    func show(
        _ message: String,
        type: DPToast.ToastType = .info,
        icon: String? = nil,
        duration: TimeInterval = 3.0
    ) {
        // Cancel any pending dismiss
        dismissTask?.cancel()

        // Update toast
        currentToast = ToastData(message: message, type: type, icon: icon, duration: duration)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowing = true
        }

        // Schedule auto-dismiss
        let task = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    /// Dismiss the current toast
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            isShowing = false
        }
        // Clear toast data after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.currentToast = nil
        }
    }

    /// Show a success toast
    func success(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .success, duration: duration)
    }

    /// Show a warning toast
    func warning(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .warning, duration: duration)
    }

    /// Show an error toast
    func error(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .error, duration: duration)
    }

    /// Show an info toast
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .info, duration: duration)
    }
}

// MARK: - Toast ViewModifier

/// ViewModifier for displaying toasts at the top of a view
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if toastManager.isShowing, let toast = toastManager.currentToast {
                DPToast(toast.message, type: toast.type, icon: toast.icon)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        toastManager.dismiss()
                    }
                    .zIndex(1000)
            }
        }
    }
}

// MARK: - View Extension for Toast

extension View {
    /// Add toast support to a view
    /// - Parameter toastManager: The ToastManager to use
    /// - Returns: Modified view with toast overlay
    func toast(_ toastManager: ToastManager) -> some View {
        modifier(ToastModifier(toastManager: toastManager))
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

                Divider()

                // MARK: DPProgressBar Preview
                Group {
                    Text("DPProgressBar")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: AppTheme.Spacing.md) {
                        DPProgressBar(progress: 0.15)
                        DPProgressBar(progress: 0.35)
                        DPProgressBar(progress: 0.65)
                        DPProgressBar(progress: 0.85)
                        DPProgressBar(progress: 0.5, showPercentageLabel: true)
                        DPProgressBar(progress: 0.7, foregroundColor: AppTheme.Colors.primary)
                    }
                }

                Divider()

                // MARK: DPProgressRing Preview
                Group {
                    Text("DPProgressRing")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: AppTheme.Spacing.lg) {
                        DPProgressRing(progress: 0.25, size: 50)
                        DPProgressRing(progress: 0.50, size: 60)
                        DPProgressRing(progress: 0.75, size: 70)
                        DPProgressRing(progress: 1.0, size: 80)
                    }

                    HStack(spacing: AppTheme.Spacing.lg) {
                        DPProgressRing(
                            progress: 0.75,
                            size: 70,
                            labelStyle: .fraction(current: 3, total: 4)
                        )
                        DPProgressRing(
                            progress: 0.5,
                            size: 70,
                            foregroundColor: AppTheme.Colors.primary,
                            labelStyle: .custom("50")
                        )
                    }
                }

                Divider()

                // MARK: DPEmptyState Preview
                Group {
                    Text("DPEmptyState")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DPCard {
                        DPEmptyState(
                            icon: "photo.on.rectangle.angled",
                            title: "No Photos Yet",
                            message: "Start capturing your dental work to build your portfolio.",
                            actionTitle: "Take Photo"
                        ) { }
                    }
                }

                Divider()

                // MARK: DPSectionHeader Preview
                Group {
                    Text("DPSectionHeader")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: AppTheme.Spacing.md) {
                        DPSectionHeader("Recent Photos")

                        DPSectionHeader(
                            "Procedures",
                            subtitle: "Organized by type"
                        )

                        DPSectionHeader(
                            "All Photos",
                            actionTitle: "See All"
                        ) { }
                    }
                }

                Divider()

                // MARK: DPToast Preview
                Group {
                    Text("DPToast")
                        .font(AppTheme.Typography.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: AppTheme.Spacing.sm) {
                        DPToast("Photo saved successfully!", type: .success)
                        DPToast("Please check your input", type: .warning)
                        DPToast("Failed to upload photo", type: .error)
                        DPToast("Syncing your photos...", type: .info)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Toast Preview with Manager
struct ToastPreview: View {
    @StateObject private var toastManager = ToastManager()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Toast Manager Demo")
                .font(AppTheme.Typography.title3)

            HStack(spacing: AppTheme.Spacing.sm) {
                DPButton("Success", style: .primary, size: .small) {
                    toastManager.success("Operation completed!")
                }
                DPButton("Warning", style: .secondary, size: .small) {
                    toastManager.warning("Please review")
                }
                DPButton("Error", style: .destructive, size: .small) {
                    toastManager.error("Something went wrong")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .toast(toastManager)
    }
}

struct ToastPreview_Previews: PreviewProvider {
    static var previews: some View {
        ToastPreview()
    }
}
#endif
