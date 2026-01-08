// DynamicTypeSupport.swift
// Dental Portfolio - Dynamic Type and Scaling Support
//
// Components for supporting Dynamic Type and adaptive layouts.
// Ensures the app scales properly with user text size preferences.
//
// Contents:
// - ScaledValue: Property wrapper for scaled measurements
// - AdaptiveStack: Stack that switches orientation at accessibility sizes
// - MinimumTouchTarget: Ensures 44pt minimum touch targets
// - Accessible layout modifiers

import SwiftUI

// MARK: - Scaled Value Property Wrapper

/// Property wrapper that scales a value based on Dynamic Type settings
@propertyWrapper
struct ScaledValue: DynamicProperty {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let baseValue: CGFloat
    let relativeTo: Font.TextStyle
    let maxScale: CGFloat

    /// Create a scaled value
    /// - Parameters:
    ///   - wrappedValue: The base value at default text size
    ///   - relativeTo: The text style to scale relative to
    ///   - maxScale: Maximum scale factor (prevents excessive growth)
    init(wrappedValue: CGFloat, relativeTo: Font.TextStyle = .body, maxScale: CGFloat = 2.0) {
        self.baseValue = wrappedValue
        self.relativeTo = relativeTo
        self.maxScale = maxScale
    }

    var wrappedValue: CGFloat {
        let scale = dynamicTypeScaleFactor
        let scaledValue = baseValue * scale
        return min(scaledValue, baseValue * maxScale)
    }

    private var dynamicTypeScaleFactor: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.5
        case .accessibility2: return 1.7
        case .accessibility3: return 1.9
        case .accessibility4: return 2.1
        case .accessibility5: return 2.3
        @unknown default: return 1.0
        }
    }
}

// MARK: - Adaptive Stack

/// A stack that switches from horizontal to vertical at accessibility text sizes
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat
    let threshold: DynamicTypeSize
    @ViewBuilder let content: () -> Content

    /// Create an adaptive stack
    /// - Parameters:
    ///   - horizontalAlignment: Alignment when vertical
    ///   - verticalAlignment: Alignment when horizontal
    ///   - spacing: Spacing between elements
    ///   - threshold: Size at which to switch to vertical
    ///   - content: Stack content
    init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat = 8,
        threshold: DynamicTypeSize = .accessibility1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.threshold = threshold
        self.content = content
    }

    var body: some View {
        if shouldUseVerticalLayout {
            VStack(alignment: horizontalAlignment, spacing: spacing) {
                content()
            }
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) {
                content()
            }
        }
    }

    private var shouldUseVerticalLayout: Bool {
        dynamicTypeSize >= threshold
    }
}

// MARK: - Minimum Touch Target Modifier

/// ViewModifier that ensures minimum 44pt touch targets
struct MinimumTouchTargetModifier: ViewModifier {
    let minSize: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Ensure minimum touch target size (default 44pt per Apple HIG)
    /// - Parameter size: Minimum size in points
    func minimumTouchTarget(_ size: CGFloat = 44) -> some View {
        modifier(MinimumTouchTargetModifier(minSize: size))
    }
}

// MARK: - Accessible Layout Modifier

/// ViewModifier that provides accessible layout information
struct AccessibleLayoutModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var threshold: DynamicTypeSize = .accessibility1

    func body(content: Content) -> some View {
        content
    }

    var shouldUseVerticalLayout: Bool {
        dynamicTypeSize >= threshold
    }

    var isAccessibilitySize: Bool {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3,
             .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}

extension View {
    /// Add accessible layout awareness to a view
    func accessibleLayout(threshold: DynamicTypeSize = .accessibility1) -> some View {
        modifier(AccessibleLayoutModifier(threshold: threshold))
    }
}

// MARK: - Dynamic Type Aware Spacing

/// Get spacing that scales with Dynamic Type
struct DynamicSpacing {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    /// Small spacing that scales
    var small: CGFloat {
        scaledValue(AppTheme.Spacing.sm)
    }

    /// Medium spacing that scales
    var medium: CGFloat {
        scaledValue(AppTheme.Spacing.md)
    }

    /// Large spacing that scales
    var large: CGFloat {
        scaledValue(AppTheme.Spacing.lg)
    }

    private func scaledValue(_ base: CGFloat) -> CGFloat {
        let scale: CGFloat
        switch dynamicTypeSize {
        case .xSmall, .small: scale = 0.9
        case .medium, .large: scale = 1.0
        case .xLarge, .xxLarge: scale = 1.1
        case .xxxLarge: scale = 1.2
        case .accessibility1: scale = 1.3
        case .accessibility2: scale = 1.4
        case .accessibility3, .accessibility4, .accessibility5: scale = 1.5
        @unknown default: scale = 1.0
        }
        return base * scale
    }
}

// MARK: - Scaled Padding Modifier

/// ViewModifier that applies padding that scales with Dynamic Type
struct ScaledPaddingModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let edges: Edge.Set
    let baseAmount: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(edges, scaledPadding)
    }

    private var scaledPadding: CGFloat {
        let scale: CGFloat
        switch dynamicTypeSize {
        case .xSmall, .small: scale = 0.9
        case .medium, .large: scale = 1.0
        case .xLarge, .xxLarge: scale = 1.1
        case .xxxLarge: scale = 1.2
        case .accessibility1: scale = 1.3
        case .accessibility2: scale = 1.4
        case .accessibility3, .accessibility4, .accessibility5: scale = 1.5
        @unknown default: scale = 1.0
        }
        return baseAmount * scale
    }
}

extension View {
    /// Apply padding that scales with Dynamic Type
    /// - Parameters:
    ///   - edges: Edges to apply padding to
    ///   - amount: Base padding amount
    func scaledPadding(_ edges: Edge.Set = .all, _ amount: CGFloat) -> some View {
        modifier(ScaledPaddingModifier(edges: edges, baseAmount: amount))
    }
}

// MARK: - Scaled Frame Modifier

/// ViewModifier that applies frame sizes that scale with Dynamic Type
struct ScaledFrameModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let baseWidth: CGFloat?
    let baseHeight: CGFloat?
    let maxScale: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(
                width: baseWidth.map { $0 * scale },
                height: baseHeight.map { $0 * scale }
            )
    }

    private var scale: CGFloat {
        let rawScale: CGFloat
        switch dynamicTypeSize {
        case .xSmall, .small: rawScale = 0.9
        case .medium, .large: rawScale = 1.0
        case .xLarge, .xxLarge: rawScale = 1.1
        case .xxxLarge: rawScale = 1.2
        case .accessibility1: rawScale = 1.3
        case .accessibility2: rawScale = 1.5
        case .accessibility3: rawScale = 1.7
        case .accessibility4: rawScale = 1.9
        case .accessibility5: rawScale = 2.0
        @unknown default: rawScale = 1.0
        }
        return min(rawScale, maxScale)
    }
}

extension View {
    /// Apply frame that scales with Dynamic Type
    /// - Parameters:
    ///   - width: Base width
    ///   - height: Base height
    ///   - maxScale: Maximum scale factor
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil, maxScale: CGFloat = 2.0) -> some View {
        modifier(ScaledFrameModifier(baseWidth: width, baseHeight: height, maxScale: maxScale))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DynamicTypeSupport_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal size
            DynamicTypePreviewContent()
                .environment(\.dynamicTypeSize, .medium)
                .previewDisplayName("Medium")

            // Large size
            DynamicTypePreviewContent()
                .environment(\.dynamicTypeSize, .xxxLarge)
                .previewDisplayName("XXX Large")

            // Accessibility size
            DynamicTypePreviewContent()
                .environment(\.dynamicTypeSize, .accessibility3)
                .previewDisplayName("Accessibility 3")
        }
    }

    struct DynamicTypePreviewContent: View {
        var body: some View {
            VStack(spacing: 20) {
                Text("Adaptive Stack Demo")
                    .font(.headline)

                AdaptiveStack(spacing: 12) {
                    Text("Item 1")
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)

                    Text("Item 2")
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)

                    Text("Item 3")
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }

                Divider()

                Text("Touch Target Demo")
                    .font(.headline)

                Button("Tap Me") { }
                    .minimumTouchTarget()
                    .background(Color.blue.opacity(0.1))
            }
            .padding()
        }
    }
}
#endif
