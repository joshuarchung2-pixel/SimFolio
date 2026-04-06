// Components.swift
// SimFolio - Reusable UI Components
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
// - DPEmptyState: Empty state view with icon, title, message, action
// - DPSectionHeader: List section header with optional action
// - DPToast: Temporary feedback message with ToastManager

import SwiftUI
import Combine

// MARK: - DPCard

/// Standard card container with configurable padding, background, corner radius, and shadow
struct DPCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var backgroundColor: Color
    var cornerRadius: CGFloat
    var shadowStyle: CardShadowStyle

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
        shadowStyle: CardShadowStyle = .medium,
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
    }
}

/// Shadow style options for cards (standalone enum for better type inference)
enum CardShadowStyle {
    case none
    case small
    case medium
    case large
}

/// Modifier to apply shadow based on CardShadowStyle
private struct CardShadowModifier: ViewModifier {
    let style: CardShadowStyle

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
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
        return AppTheme.CornerRadius.medium
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
            return Color(hex: "C44040")
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

// MARK: - Card Press Button Style

/// A button style for cards that scales slightly on press without blocking scroll gestures
struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Scale Button Style

/// A button style that scales down on press with a bounce animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
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
                .foregroundStyle(isSelected ? color : AppTheme.Colors.textSecondary)

            if showRemoveButton {
                Button(action: {
                    onRemove?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: removeIconSize, weight: .semibold))
                        .foregroundStyle(isSelected ? color : AppTheme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(isSelected ? color.opacity(0.12) : AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                .strokeBorder(isSelected ? color : AppTheme.Colors.divider, lineWidth: 1)
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
    var shadowStyle: CardShadowStyle
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
        shadowStyle: CardShadowStyle = .small,
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
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
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
        height: CGFloat = 3,
        backgroundColor: Color = AppTheme.Colors.divider,
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
                    .foregroundStyle(AppTheme.Colors.textSecondary)
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
        if let foregroundColor = foregroundColor {
            return foregroundColor
        }
        switch progress {
        case 0..<0.25:
            return Color(hex: "C47070")
        case 0.25..<0.50:
            return Color(hex: "C49A5C")
        case 0.50..<0.75:
            return Color(hex: "C49A5C")
        default:
            return AppTheme.Colors.primary
        }
    }

    /// Get auto-color based on progress level
    /// - Parameter progress: Progress value from 0.0 to 1.0
    /// - Returns: Color based on progress thresholds
    static func autoColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.25:
            return Color(hex: "C47070")
        case 0.25..<0.50:
            return Color(hex: "C49A5C")
        case 0.50..<0.75:
            return Color(hex: "C49A5C")
        default:
            return AppTheme.Colors.primary
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
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .frame(width: 64, height: 64)
                .background(AppTheme.Colors.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
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
                    .font(AppTheme.Typography.sectionLabel)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.primary)
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
                .frame(width: 4, height: 24)

            // Icon
            Image(systemName: icon ?? type.defaultIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(type.color)

            // Message
            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.horizontal, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
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
        content
            .overlay(alignment: .top) {
                if toastManager.isShowing, let toast = toastManager.currentToast {
                    DPToast(toast.message, type: toast.type, icon: toast.icon)
                        .padding(.top, AppTheme.Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture {
                            toastManager.dismiss()
                        }
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

// MARK: - DPTextField

/// Standardized text field component with validation states and consistent styling
struct DPTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String
    var icon: String?
    var state: State
    var errorMessage: String?
    var helperText: String?
    var isSecure: Bool
    var keyboardType: UIKeyboardType
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    /// Validation state for the text field
    enum State {
        case normal
        case error
        case success
        case disabled
    }

    /// Create a text field with the specified properties
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        state: State = .normal,
        errorMessage: String? = nil,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.state = state
        self.errorMessage = errorMessage
        self.helperText = helperText
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Title label
            if !title.isEmpty {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(labelColor)
            }

            // Text field container
            HStack(spacing: AppTheme.Spacing.sm) {
                // Leading icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: AppTheme.IconSize.md, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: AppTheme.IconSize.lg)
                }

                // Text input
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(textColor)
                        .focused($isFocused)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(autocapitalization)
                        .onSubmit { onSubmit?() }
                        .disabled(state == .disabled)
                } else {
                    TextField(placeholder, text: $text)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(textColor)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(autocapitalization)
                        .onSubmit { onSubmit?() }
                        .disabled(state == .disabled)
                }

                // Trailing state icon
                if let stateIcon = stateIcon {
                    Image(systemName: stateIcon)
                        .font(.system(size: AppTheme.IconSize.sm, weight: .medium))
                        .foregroundStyle(stateIconColor)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm + AppTheme.Spacing.xs)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)

            // Helper or error text
            if let errorMessage = errorMessage, state == .error {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: AppTheme.IconSize.xs))
                    Text(errorMessage)
                        .font(AppTheme.Typography.caption)
                }
                .foregroundStyle(AppTheme.Colors.error)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .opacity(state == .disabled ? AppTheme.Opacity.heavy : AppTheme.Opacity.full)
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(text.isEmpty ? "Empty" : text)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = title
        if state == .error, let errorMessage = errorMessage {
            label += ", error: \(errorMessage)"
        }
        return label
    }

    private var accessibilityHint: String {
        if state == .disabled {
            return "Text field is disabled"
        }
        return "Double tap to edit"
    }

    // MARK: - Computed Properties

    private var labelColor: Color {
        switch state {
        case .error:
            return AppTheme.Colors.error
        case .disabled:
            return AppTheme.Colors.textTertiary
        default:
            return AppTheme.Colors.textSecondary
        }
    }

    private var textColor: Color {
        state == .disabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary
    }

    private var iconColor: Color {
        if isFocused {
            return state == .error ? AppTheme.Colors.error : AppTheme.Colors.primary
        }
        return AppTheme.Colors.textTertiary
    }

    private var backgroundColor: Color {
        state == .disabled ? AppTheme.Colors.surfaceSecondary : AppTheme.Colors.surface
    }

    private var borderColor: Color {
        if isFocused {
            switch state {
            case .error:
                return AppTheme.Colors.error
            case .success:
                return AppTheme.Colors.success
            default:
                return AppTheme.Colors.primary
            }
        }

        switch state {
        case .error:
            return AppTheme.Colors.error
        case .success:
            return AppTheme.Colors.success
        default:
            return AppTheme.Colors.divider
        }
    }

    private var stateIcon: String? {
        switch state {
        case .error:
            return "exclamationmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        default:
            return nil
        }
    }

    private var stateIconColor: Color {
        switch state {
        case .error:
            return AppTheme.Colors.error
        case .success:
            return AppTheme.Colors.success
        default:
            return .clear
        }
    }
}

// MARK: - DPTextEditor

/// Standardized multi-line text editor with validation states
struct DPTextEditor: View {
    let title: String
    @Binding var text: String
    var placeholder: String
    var state: DPTextField.State
    var errorMessage: String?
    var helperText: String?
    var minHeight: CGFloat

    @FocusState private var isFocused: Bool

    /// Create a text editor with the specified properties
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        state: DPTextField.State = .normal,
        errorMessage: String? = nil,
        helperText: String? = nil,
        minHeight: CGFloat = 100
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.state = state
        self.errorMessage = errorMessage
        self.helperText = helperText
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Title label
            if !title.isEmpty {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(labelColor)
            }

            // Text editor
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .padding(.horizontal, AppTheme.Spacing.xs)
                        .padding(.vertical, AppTheme.Spacing.sm)
                }

                TextEditor(text: $text)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(textColor)
                    .focused($isFocused)
                    .disabled(state == .disabled)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .frame(minHeight: minHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)

            // Helper or error text
            if let errorMessage = errorMessage, state == .error {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: AppTheme.IconSize.xs))
                    Text(errorMessage)
                        .font(AppTheme.Typography.caption)
                }
                .foregroundStyle(AppTheme.Colors.error)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .opacity(state == .disabled ? AppTheme.Opacity.heavy : AppTheme.Opacity.full)
    }

    // MARK: - Computed Properties

    private var labelColor: Color {
        switch state {
        case .error:
            return AppTheme.Colors.error
        case .disabled:
            return AppTheme.Colors.textTertiary
        default:
            return AppTheme.Colors.textSecondary
        }
    }

    private var textColor: Color {
        state == .disabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary
    }

    private var backgroundColor: Color {
        state == .disabled ? AppTheme.Colors.surfaceSecondary : AppTheme.Colors.surface
    }

    private var borderColor: Color {
        if isFocused {
            switch state {
            case .error:
                return AppTheme.Colors.error
            case .success:
                return AppTheme.Colors.success
            default:
                return AppTheme.Colors.primary
            }
        }

        switch state {
        case .error:
            return AppTheme.Colors.error
        case .success:
            return AppTheme.Colors.success
        default:
            return AppTheme.Colors.divider
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
                                .foregroundStyle(AppTheme.Colors.textSecondary)
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

                // MARK: DPTextField Preview
                DPTextFieldPreview()

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

// MARK: - DPTextField Preview
private struct DPTextFieldPreview: View {
    @State private var normalText = ""
    @State private var emailText = "john@example.com"
    @State private var errorText = "invalid-email"
    @State private var successText = "valid@email.com"
    @State private var disabledText = "Disabled content"
    @State private var notesText = ""

    var body: some View {
        Group {
            Text("DPTextField")
                .font(AppTheme.Typography.title3)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: AppTheme.Spacing.md) {
                DPTextField(
                    "Email Address",
                    text: $normalText,
                    placeholder: "Enter your email",
                    icon: "envelope",
                    helperText: "We'll never share your email"
                )

                DPTextField(
                    "Email (Error)",
                    text: $errorText,
                    placeholder: "Enter your email",
                    icon: "envelope",
                    state: .error,
                    errorMessage: "Please enter a valid email address"
                )

                DPTextField(
                    "Email (Success)",
                    text: $successText,
                    placeholder: "Enter your email",
                    icon: "envelope",
                    state: .success
                )

                DPTextField(
                    "Disabled Field",
                    text: $disabledText,
                    placeholder: "Cannot edit",
                    icon: "lock",
                    state: .disabled
                )

                DPTextField(
                    "Password",
                    text: $normalText,
                    placeholder: "Enter password",
                    icon: "lock",
                    isSecure: true
                )

                DPTextEditor(
                    "Notes",
                    text: $notesText,
                    placeholder: "Add any additional notes...",
                    helperText: "Optional"
                )
            }
        }
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
