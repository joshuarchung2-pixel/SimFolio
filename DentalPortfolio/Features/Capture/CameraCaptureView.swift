// CameraCaptureView.swift
// Dental Portfolio - Camera Capture Interface
//
// A simplified camera interface with batch capture support.
// Features:
// - Full-screen camera preview with gestures
// - Focus indicator on tap
// - Grid overlay (toggleable)
// - Batch capture with thumbnail preview
// - Quick tag editing

import SwiftUI
import AVFoundation

// MARK: - Camera Capture View

/// Active camera view with minimal controls for batch capture
struct CameraCaptureView: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var cameraService: CameraService
    @ObservedObject var orientationManager = OrientationManager.shared
    @EnvironmentObject var router: NavigationRouter

    // MARK: - State

    @State private var showTagEditor = false
    @State private var showGrid = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusIndicator = false
    @State private var showShutterFlash = false

    // MARK: - Computed Properties

    var flashModeIcon: String {
        switch flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    var flashModeLabel: String {
        switch flashMode {
        case .off: return "Flash Off"
        case .on: return "Flash On"
        case .auto: return "Flash Auto"
        @unknown default: return "Flash Off"
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreview(session: cameraService.session)
                    .ignoresSafeArea()
                    .gesture(
                        TapGesture()
                            .onEnded { _ in
                                // This won't work for location, use overlay instead
                            }
                    )
                    .overlay(
                        // Tap gesture overlay for focus
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTapToFocus(at: value.location, in: geometry.size)
                                    }
                            )
                            .gesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        if let point = focusPoint {
                                            handleLongPress(at: point, in: geometry.size)
                                        }
                                    }
                            )
                    )

                // Grid overlay
                if showGrid {
                    GridOverlay()
                        .ignoresSafeArea()
                }

                // Focus indicator
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicator()
                        .position(point)
                }

                // Shutter flash effect
                if showShutterFlash {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // UI Overlay
                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    Spacer()

                    // Bottom controls
                    bottomControls
                }
            }
        }
        .onChange(of: cameraService.capturedImage) { newImage in
            if let image = newImage {
                captureState.addPhoto(image: image)
                cameraService.retake()
                triggerShutterFlash()
            }
        }
        .onAppear {
            orientationManager.startMonitoring()
            cameraService.startSession()
        }
        .onDisappear {
            orientationManager.stopMonitoring()
        }
        .sheet(isPresented: $showTagEditor) {
            QuickTagEditorSheet(captureState: captureState)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Close button
            Button(action: handleClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Tag summary pill
            Button(action: { showTagEditor = true }) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(captureState.tagSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(captureState.hasAllTags ? AppTheme.Colors.success : Color.black.opacity(0.5))
                .cornerRadius(AppTheme.CornerRadius.full)
            }

            Spacer()

            // Settings menu
            Menu {
                Button(action: { showGrid.toggle() }) {
                    Label(showGrid ? "Hide Grid" : "Show Grid", systemImage: showGrid ? "grid" : "grid")
                }

                Button(action: cycleFlashMode) {
                    Label(flashModeLabel, systemImage: flashModeIcon)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Batch indicator
            if !captureState.capturedPhotos.isEmpty {
                Button(action: { captureState.finishCapturing() }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text("\(captureState.capturedPhotos.count) photo\(captureState.capturedPhotos.count == 1 ? "" : "s") captured")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(.white)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.full)
                }
            }

            // Main controls row
            HStack(alignment: .center) {
                // Thumbnail / Photo count
                thumbnailButton
                    .frame(width: 60)

                Spacer()

                // Shutter button
                shutterButton

                Spacer()

                // Flash toggle
                flashButton
                    .frame(width: 60)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            // Zoom controls
            zoomControls
                .padding(.bottom, AppTheme.Spacing.lg)
        }
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - Thumbnail Button

    private var thumbnailButton: some View {
        Button(action: {
            if !captureState.capturedPhotos.isEmpty {
                captureState.finishCapturing()
            }
        }) {
            ZStack {
                if let lastPhoto = captureState.capturedPhotos.last {
                    Image(uiImage: lastPhoto.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

                    // Photo count badge
                    if captureState.capturedPhotos.count > 0 {
                        Text("\(captureState.capturedPhotos.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Circle())
                            .offset(x: 24, y: -24)
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
        }
        .disabled(captureState.capturedPhotos.isEmpty)
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button(action: takePhoto) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                // Inner circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
            }
        }
        .buttonStyle(ShutterButtonStyle())
    }

    // MARK: - Flash Button

    private var flashButton: some View {
        Button(action: cycleFlashMode) {
            Image(systemName: flashModeIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(flashMode == .off ? .white : .yellow)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            ForEach([0.5, 1.0, 2.0], id: \.self) { zoom in
                Button(action: { cameraService.setZoom(factor: zoom) }) {
                    Text("\(zoom, specifier: zoom == 1.0 ? "%.0f" : "%.1f")x")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(isZoomSelected(zoom) ? .yellow : .white)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(isZoomSelected(zoom) ? Color.white.opacity(0.2) : Color.clear)
                        .cornerRadius(AppTheme.CornerRadius.small)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func isZoomSelected(_ zoom: Double) -> Bool {
        let current = cameraService.currentZoom
        if zoom == 0.5 {
            return current < 0.75
        } else if zoom == 1.0 {
            return current >= 0.75 && current < 1.5
        } else {
            return current >= 1.5
        }
    }

    private func takePhoto() {
        cameraService.flashMode = flashMode
        cameraService.takePhoto()
        HapticsManager.shared.heavyTap()
    }

    private func cycleFlashMode() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        HapticsManager.shared.selectionChanged()
    }

    private func handleClose() {
        if captureState.capturedPhotos.isEmpty {
            captureState.currentStep = .setup
        } else {
            // Show confirmation - handled by parent CaptureFlowView
            captureState.currentStep = .setup
        }
    }

    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        focusPoint = location

        // Convert to normalized coordinates for camera
        let normalizedPoint = CGPoint(
            x: location.y / size.height,
            y: 1.0 - (location.x / size.width)
        )

        cameraService.focusAndExpose(at: normalizedPoint)

        // Show focus indicator
        withAnimation(.easeOut(duration: 0.15)) {
            showFocusIndicator = true
        }

        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFocusIndicator = false
            }
        }

        HapticsManager.shared.lightTap()
    }

    private func handleLongPress(at location: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(
            x: location.y / size.height,
            y: 1.0 - (location.x / size.width)
        )

        cameraService.lockAEAF(at: normalizedPoint)

        withAnimation(.easeOut(duration: 0.15)) {
            showFocusIndicator = true
        }

        HapticsManager.shared.success()
    }

    private func triggerShutterFlash() {
        withAnimation(.easeIn(duration: 0.05)) {
            showShutterFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.1)) {
                showShutterFlash = false
            }
        }
    }
}

// MARK: - Shutter Button Style

/// Custom button style for the shutter button with scale animation
private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Grid Overlay

/// Rule of thirds grid overlay for composition
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            Path { path in
                // Vertical lines
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))

                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))

                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))

                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        }
    }
}

// MARK: - Focus Indicator

/// Yellow square indicator shown at focus point
struct FocusIndicator: View {
    var body: some View {
        Rectangle()
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
    }
}

// MARK: - Quick Tag Editor Sheet

/// Sheet for quickly editing tags during capture
struct QuickTagEditorSheet: View {
    @ObservedObject var captureState: CaptureFlowState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Procedure
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("PROCEDURE")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(MetadataManager.baseProcedures, id: \.self) { procedure in
                                    DPTagPill(
                                        procedure,
                                        color: AppTheme.procedureColor(for: procedure),
                                        isSelected: captureState.selectedProcedure == procedure
                                    ) {
                                        captureState.selectedProcedure = procedure
                                        HapticsManager.shared.selectionChanged()
                                    }
                                }
                            }
                        }
                    }

                    // Stage
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("STAGE")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(MetadataManager.stages, id: \.self) { stage in
                                DPTagPill(
                                    stage,
                                    color: stage == "Preparation" ? AppTheme.Colors.warning : AppTheme.Colors.success,
                                    isSelected: captureState.selectedStage == stage
                                ) {
                                    captureState.selectedStage = stage
                                    HapticsManager.shared.selectionChanged()
                                }
                            }
                        }
                    }

                    // Angle
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("ANGLE")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(MetadataManager.angles, id: \.self) { angle in
                                    DPTagPill(
                                        angle,
                                        color: .purple,
                                        isSelected: captureState.selectedAngle == angle
                                    ) {
                                        captureState.selectedAngle = angle
                                        HapticsManager.shared.selectionChanged()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CameraCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CameraCaptureViewPreviewContainer()
    }
}

struct CameraCaptureViewPreviewContainer: View {
    @StateObject private var captureState = CaptureFlowState()
    @StateObject private var cameraService = CameraService()
    @StateObject private var router = NavigationRouter()

    var body: some View {
        CameraCaptureView(captureState: captureState, cameraService: cameraService)
            .environmentObject(router)
    }
}
#endif
