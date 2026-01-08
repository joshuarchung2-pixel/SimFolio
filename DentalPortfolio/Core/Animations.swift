// Animations.swift
// Dental Portfolio - Animation Presets and View Modifiers
//
// This file contains standardized animation presets and view modifiers
// for consistent motion design throughout the app.
//
// Contents:
// - Animation presets (spring, ease variants)
// - Transition presets (slide, scale, fade)
// - View modifiers (press effect, shake, staggered appearance)
// - GeometryEffects (shake)

import SwiftUI

// MARK: - Animation Presets

extension Animation {
    /// Standard spring animation - balanced response and damping
    /// Use for most UI interactions
    static let dpSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// Fast spring animation - quick response with good damping
    /// Use for button presses, toggles, small state changes
    static let dpSpringFast = Animation.spring(response: 0.25, dampingFraction: 0.8)

    /// Bouncy spring animation - more playful motion
    /// Use for success states, celebrations, attention-grabbing elements
    static let dpSpringBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    /// Quick ease-out animation
    /// Use for dismissals, fade-outs
    static let dpEaseOut = Animation.easeOut(duration: 0.2)

    /// Standard ease-in-out animation
    /// Use for general transitions
    static let dpEaseInOut = Animation.easeInOut(duration: 0.25)

    /// Slow ease-in-out animation
    /// Use for page transitions, modal presentations
    static let dpEaseInOutSlow = Animation.easeInOut(duration: 0.35)
}

// MARK: - Transition Presets

extension AnyTransition {
    /// Slide up from bottom with fade
    /// Use for sheets, bottom modals, action menus
    static let dpSlideUp = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// Slide down from top with fade
    /// Use for toasts, notifications, top banners
    static let dpSlideDown = AnyTransition.move(edge: .top).combined(with: .opacity)

    /// Scale with fade
    /// Use for popovers, context menus, alerts
    static let dpScale = AnyTransition.scale(scale: 0.9).combined(with: .opacity)

    /// Scale from small with fade
    /// Use for appearing elements, photo thumbnails
    static let dpScaleSmall = AnyTransition.scale(scale: 0.8).combined(with: .opacity)

    /// Simple fade
    /// Use for subtle content changes
    static let dpFade = AnyTransition.opacity

    /// Asymmetric slide - slides in from bottom, fades out
    /// Use for cards, list items
    static let dpCard = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )

    /// Slide from leading edge
    /// Use for navigation forward
    static let dpSlideLeading = AnyTransition.move(edge: .leading).combined(with: .opacity)

    /// Slide from trailing edge
    /// Use for navigation back
    static let dpSlideTrailing = AnyTransition.move(edge: .trailing).combined(with: .opacity)
}

// MARK: - Press Effect Modifier

/// Adds a press effect that scales the view when pressed
struct PressEffectModifier: ViewModifier {
    let isPressed: Bool
    var scale: CGFloat

    /// Create a press effect modifier
    /// - Parameters:
    ///   - isPressed: Whether the view is currently pressed
    ///   - scale: Scale factor when pressed (default 0.97)
    init(isPressed: Bool, scale: CGFloat = 0.97) {
        self.isPressed = isPressed
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.dpSpringFast, value: isPressed)
    }
}

// MARK: - Shake Effect

/// A geometry effect that shakes the view horizontally
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var shakesPerUnit: Int
    var animatableData: CGFloat

    /// Create a shake effect
    /// - Parameters:
    ///   - amount: Maximum shake offset in points (default 10)
    ///   - shakesPerUnit: Number of shakes per animation cycle (default 3)
    ///   - animatableData: Animation progress (0 to 1)
    init(amount: CGFloat = 10, shakesPerUnit: Int = 3, animatableData: CGFloat) {
        self.amount = amount
        self.shakesPerUnit = shakesPerUnit
        self.animatableData = animatableData
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Shake Modifier

/// Modifier that triggers a shake animation
struct ShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    var amount: CGFloat
    var shakesPerUnit: Int

    @State private var shakeProgress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(amount: amount, shakesPerUnit: shakesPerUnit, animatableData: shakeProgress))
            .onChange(of: trigger) { newValue in
                if newValue {
                    withAnimation(.linear(duration: 0.4)) {
                        shakeProgress = 1
                    }
                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        shakeProgress = 0
                        trigger = false
                    }
                }
            }
    }
}

// MARK: - Staggered Appearance Modifier

/// Modifier that animates items appearing with a staggered delay
struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    let totalCount: Int
    var baseDelay: Double

    @State private var isVisible = false

    /// Create a staggered appearance modifier
    /// - Parameters:
    ///   - index: Index of this item in the list
    ///   - totalCount: Total number of items (for limiting max delay)
    ///   - baseDelay: Delay between each item (default 0.05s)
    init(index: Int, totalCount: Int, baseDelay: Double = 0.05) {
        self.index = index
        self.totalCount = totalCount
        self.baseDelay = baseDelay
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                // Limit delay to prevent very long waits for large lists
                let maxDelay = min(Double(index) * baseDelay, 0.5)
                withAnimation(.dpSpring.delay(maxDelay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Pulse Effect Modifier

/// Modifier that creates a pulsing glow effect
struct PulseGlowModifier: ViewModifier {
    let color: Color
    let isActive: Bool

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(isPulsing ? 0.6 : 0.2) : .clear,
                radius: isPulsing ? 12 : 6
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}

// MARK: - Shimmer Effect Modifier

/// Modifier that creates a loading shimmer effect
struct ShimmerModifier: ViewModifier {
    let isActive: Bool

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                phase = 1
                            }
                        }
                    }
                }
                .mask(content)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Add a press effect that scales the view when pressed
    /// - Parameters:
    ///   - isPressed: Whether the view is currently pressed
    ///   - scale: Scale factor when pressed (default 0.97)
    func pressEffect(isPressed: Bool, scale: CGFloat = 0.97) -> some View {
        modifier(PressEffectModifier(isPressed: isPressed, scale: scale))
    }

    /// Add staggered appearance animation for list items
    /// - Parameters:
    ///   - index: Index of this item in the list
    ///   - totalCount: Total number of items
    ///   - baseDelay: Delay between each item appearance
    func staggeredAppearance(index: Int, totalCount: Int, baseDelay: Double = 0.05) -> some View {
        modifier(StaggeredAppearanceModifier(index: index, totalCount: totalCount, baseDelay: baseDelay))
    }

    /// Add a shake effect triggered by a boolean
    /// - Parameters:
    ///   - trigger: Binding that triggers the shake when set to true
    ///   - amount: Maximum shake offset
    ///   - shakesPerUnit: Number of shakes per animation
    func shake(trigger: Binding<Bool>, amount: CGFloat = 10, shakesPerUnit: Int = 3) -> some View {
        modifier(ShakeModifier(trigger: trigger, amount: amount, shakesPerUnit: shakesPerUnit))
    }

    /// Add a pulsing glow effect
    /// - Parameters:
    ///   - color: Color of the glow
    ///   - isActive: Whether the pulse is active
    func pulseGlow(color: Color, isActive: Bool = true) -> some View {
        modifier(PulseGlowModifier(color: color, isActive: isActive))
    }

    /// Add a shimmer loading effect
    /// - Parameter isActive: Whether the shimmer is active
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Preview Provider

#if DEBUG
struct Animations_Previews: PreviewProvider {
    static var previews: some View {
        AnimationsPreviewContainer()
    }
}

struct AnimationsPreviewContainer: View {
    @State private var isPressed = false
    @State private var shakeTrigger = false
    @State private var showItems = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Press Effect
                Text("Press Effect")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DPCard {
                    Text("Press and hold me")
                        .font(AppTheme.Typography.body)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .pressEffect(isPressed: isPressed)
                .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                    isPressed = pressing
                }, perform: {})

                Divider()

                // Shake Effect
                Text("Shake Effect")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("Error field")
                        .padding()
                        .background(AppTheme.Colors.surfaceSecondary)
                        .cornerRadius(AppTheme.CornerRadius.small)
                        .shake(trigger: $shakeTrigger)

                    Spacer()

                    DPButton("Shake", size: .small) {
                        shakeTrigger = true
                    }
                }

                Divider()

                // Staggered Appearance
                Text("Staggered Appearance")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DPButton(showItems ? "Hide Items" : "Show Items", style: .secondary) {
                    showItems.toggle()
                }

                if showItems {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<5, id: \.self) { index in
                            DPCard {
                                Text("Item \(index + 1)")
                                    .font(AppTheme.Typography.body)
                            }
                            .staggeredAppearance(index: index, totalCount: 5)
                        }
                    }
                }

                Divider()

                // Pulse Glow
                Text("Pulse Glow")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: AppTheme.Spacing.lg) {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 50, height: 50)
                        .pulseGlow(color: AppTheme.Colors.success)

                    Circle()
                        .fill(AppTheme.Colors.error)
                        .frame(width: 50, height: 50)
                        .pulseGlow(color: AppTheme.Colors.error)

                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 50, height: 50)
                        .pulseGlow(color: AppTheme.Colors.primary)
                }

                Divider()

                // Shimmer
                Text("Shimmer Loading")
                    .font(AppTheme.Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.surfaceSecondary)
                    .frame(height: 100)
                    .shimmer()
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
    }
}
#endif
