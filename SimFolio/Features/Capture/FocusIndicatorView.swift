// FocusIndicatorView.swift
// SimFolio - Apple-style Camera Focus Indicator
//
// A focus indicator view that mimics Apple's native Camera app behavior:
// - Yellow focus square with corner accents
// - Scale-in animation on appear
// - Exposure slider with sun icon
// - AE/AF Lock state visual feedback

import SwiftUI

// MARK: - Focus Indicator View

/// Apple-style focus indicator with exposure slider
struct FocusIndicatorView: View {
    let position: CGPoint
    let isLocked: Bool
    let exposureValue: Float
    let onExposureChange: (Float) -> Void

    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 0.0
    @State private var showExposureSlider: Bool = false

    private let boxSize: CGFloat = 76
    private let sliderHeight: CGFloat = 150

    var body: some View {
        ZStack {
            // Focus square
            focusSquare

            // Exposure slider (appears to the right of focus square)
            if showExposureSlider || abs(exposureValue) > 0.01 {
                exposureSlider
                    .offset(x: boxSize / 2 + 30)
            }
        }
        .position(x: position.x, y: position.y)
        .onAppear {
            animateAppearance()
        }
        .onChange(of: position) { _ in
            animateAppearance()
        }
        .onChange(of: isLocked) { locked in
            if locked {
                animateLock()
            }
        }
    }

    // MARK: - Focus Square

    private var focusSquare: some View {
        ZStack {
            // Main square border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: boxSize, height: boxSize)

            // Corner accents (Apple style)
            FocusCorners(size: boxSize)
                .stroke(Color.yellow, lineWidth: 2.5)

            // Sun icon indicator (for exposure)
            sunIcon
                .offset(x: boxSize / 2 + 14, y: 0)
                .opacity(showExposureSlider || abs(exposureValue) > 0.01 ? 1 : 0)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }

    // MARK: - Sun Icon

    private var sunIcon: some View {
        ZStack {
            // Glow effect based on exposure
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 28, height: 28)
                .scaleEffect(1.0 + CGFloat(exposureValue) * 0.15)
                .blur(radius: 4)

            // Sun icon
            Image(systemName: sunIconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow)
        }
    }

    private var sunIconName: String {
        if exposureValue > 0.5 {
            return "sun.max.fill"
        } else if exposureValue < -0.5 {
            return "sun.min.fill"
        } else {
            return "sun.max.fill"
        }
    }

    // MARK: - Exposure Slider

    private var exposureSlider: some View {
        ZStack {
            // Slider track
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: sliderHeight)

            // Center indicator (zero point)
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 6)

            // Slider indicator (sun)
            Circle()
                .fill(Color.yellow)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                )
                .offset(y: -CGFloat(exposureValue) * (sliderHeight / 4))
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    showExposureSlider = true
                    // Convert drag to exposure value
                    // Reduced sensitivity by 50% (sliderHeight / 2 instead of sliderHeight / 4)
                    let dragAmount = -value.translation.height
                    let exposureChange = Float(dragAmount / (sliderHeight / 2))
                    let newExposure = max(-2.0, min(2.0, exposureChange))
                    onExposureChange(newExposure)
                }
                .onEnded { _ in
                    // Keep slider visible if exposure is adjusted
                    if abs(exposureValue) < 0.01 {
                        withAnimation(.easeOut(duration: 0.3).delay(1.5)) {
                            showExposureSlider = false
                        }
                    }
                }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
        .animation(.easeOut(duration: 0.2), value: showExposureSlider)
    }

    // MARK: - Animations

    private func animateAppearance() {
        scale = 1.5
        opacity = 0
        showExposureSlider = false

        withAnimation(.easeOut(duration: 0.15)) {
            scale = 1.0
            opacity = 1.0
        }
    }

    private func animateLock() {
        // Pulse animation for lock
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = 1.15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                scale = 1.0
            }
        }
    }

    /// Show the exposure slider
    func showExposure() {
        withAnimation(.easeOut(duration: 0.2)) {
            showExposureSlider = true
        }
    }

    /// Hide the exposure slider
    func hideExposure() {
        withAnimation(.easeOut(duration: 0.2)) {
            showExposureSlider = false
        }
    }
}

// MARK: - Focus Corners Shape

/// Custom shape for the corner accents of the focus indicator
struct FocusCorners: Shape {
    let size: CGFloat
    private let cornerLength: CGFloat = 15

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let halfSize = size / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Top-left corner
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y - halfSize + cornerLength))
        path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x - halfSize + cornerLength, y: center.y - halfSize))

        // Top-right corner
        path.move(to: CGPoint(x: center.x + halfSize - cornerLength, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y - halfSize + cornerLength))

        // Bottom-right corner
        path.move(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize - cornerLength))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize))
        path.addLine(to: CGPoint(x: center.x + halfSize - cornerLength, y: center.y + halfSize))

        // Bottom-left corner
        path.move(to: CGPoint(x: center.x - halfSize + cornerLength, y: center.y + halfSize))
        path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))
        path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize - cornerLength))

        return path
    }
}

// MARK: - AE/AF Lock Banner

/// Yellow banner shown when AE/AF is locked
struct AEAFLockBanner: View {
    let isVisible: Bool

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        Text("AE/AF LOCK")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: isVisible) { visible in
                withAnimation(.easeInOut(duration: 0.2)) {
                    opacity = visible ? 1.0 : 0.0
                    scale = visible ? 1.0 : 0.9
                }
            }
            .onAppear {
                if isVisible {
                    opacity = 1.0
                    scale = 1.0
                }
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct FocusIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Preview with exposure slider visible
            FocusIndicatorView(
                position: CGPoint(x: 200, y: 400),
                isLocked: false,
                exposureValue: 0.5,
                onExposureChange: { _ in }
            )

            // AE/AF Lock banner at top
            VStack {
                AEAFLockBanner(isVisible: true)
                    .padding(.top, 60)
                Spacer()
            }
        }
    }
}
#endif
