// CameraCaptureView.swift
// SimFolio - Camera Capture Interface
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
    @State private var showShutterFlash = false

    // Focus gesture state
    @State private var isDraggingExposure = false
    @State private var initialExposure: Float = 0
    @State private var dragStartLocation: CGPoint? = nil
    @State private var gestureStartTime: Date? = nil

    // Pinch-to-zoom state
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isPinchZooming: Bool = false
    @State private var previousZoom: CGFloat = 1.0

    // Requirement counter state
    @State private var showRequirementSatisfied: Bool = false
    @State private var previousRequiredCount: Int = 0

    // Ghost overlay state
    private static let ghostReferenceMapKey = "ghostReferenceMap"
    @State private var ghostEnabled: Bool = false
    @State private var ghostImage: UIImage? = nil
    @State private var ghostAssetId: String? = nil
    @State private var ghostOpacity: Double = 0.35
    @State private var showGhostPicker: Bool = false

    // MARK: - Computed Properties

    /// Whether the ghost overlay is active and has an image to display
    private var isGhostActive: Bool {
        ghostEnabled && ghostImage != nil
    }

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

    /// Current requirement info for the selected tags
    var currentRequirement: RequirementInfo? {
        captureState.getCurrentRequirementInfo()
    }

    /// Number of photos still required (accounting for photos captured in this session)
    var remainingRequired: Int {
        guard let req = currentRequirement else { return 0 }
        let sessionPhotos = captureState.capturedPhotos.count
        return max(0, req.missing - sessionPhotos)
    }

    /// Whether the current tag combination has a portfolio requirement
    var hasActiveRequirement: Bool {
        currentRequirement != nil && currentRequirement!.missing > 0
    }

    /// Whether the requirement was just satisfied (for showing the green checkmark)
    var isRequirementSatisfied: Bool {
        guard let req = currentRequirement else { return false }
        let sessionPhotos = captureState.capturedPhotos.count
        return req.current + sessionPhotos >= req.required
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview with focus gesture and pinch-to-zoom
                CameraPreview(session: cameraService.session)
                    .ignoresSafeArea()
                    .overlay(
                        // Combined gesture overlay for focus, long press, and exposure drag
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleFocusGestureChange(value, in: geometry.size)
                                    }
                                    .onEnded { value in
                                        handleFocusGestureEnd(value, in: geometry.size)
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        if !isPinchZooming {
                                            isPinchZooming = true
                                            previousZoom = cameraService.currentZoom
                                        }
                                        let delta = scale / lastZoomScale
                                        lastZoomScale = scale
                                        let newZoom = cameraService.currentZoom * delta
                                        cameraService.setZoom(factor: newZoom)
                                    }
                                    .onEnded { _ in
                                        lastZoomScale = 1.0
                                        // Hide indicator after a short delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                isPinchZooming = false
                                            }
                                        }
                                    }
                            )
                    )

                // Grid overlay
                if showGrid {
                    GridOverlay()
                        .ignoresSafeArea()
                }

                // Ghost overlay
                if ghostEnabled, let ghostImg = ghostImage {
                    Image(uiImage: ghostImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(ghostOpacity)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }

                // Focus indicator (Apple-style)
                if cameraService.showFocusIndicator, let normalizedPoint = cameraService.focusPoint {
                    let screenPoint = convertFocusToScreen(normalizedPoint, in: geometry.size)
                    FocusIndicatorView(
                        position: screenPoint,
                        isLocked: cameraService.isAEAFLocked,
                        exposureValue: cameraService.exposureValue,
                        onExposureChange: { value in
                            cameraService.setExposureCompensation(value)
                        }
                    )
                }

                // Shutter flash effect
                if showShutterFlash {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // UI Overlay
                VStack(spacing: 0) {
                    // AE/AF Lock banner at top
                    AEAFLockBanner(isVisible: cameraService.isAEAFLocked)
                        .padding(.top, 8)

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
                // Store previous required count before adding photo
                let previousRemaining = remainingRequired

                captureState.addPhoto(image: image)
                cameraService.retake()

                // Check if requirement was just satisfied (went from 1 to 0)
                if previousRemaining == 1 && currentRequirement != nil {
                    // Requirement just satisfied - show green indicator
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRequirementSatisfied = true
                    }

                    // Hide the satisfied indicator after 1.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRequirementSatisfied = false
                        }
                    }
                }
            }
        }
        .onAppear {
            orientationManager.startMonitoring()
            cameraService.startSession()
            hapticFeedback.prepare()
            loadGhostSelection()
        }
        .onDisappear {
            orientationManager.stopMonitoring()
            cameraService.stopSession()
        }
        .sheet(isPresented: $showTagEditor) {
            QuickTagEditorSheet(captureState: captureState)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showGhostPicker) {
            GhostPhotoPickerSheet(
                procedure: captureState.selectedProcedure,
                toothNumber: captureState.selectedToothNumber,
                onSelect: { assetId in
                    ghostAssetId = assetId
                    saveGhostSelection()
                    loadGhostImage(assetId: assetId)
                },
                onClear: {
                    clearGhostSelection()
                }
            )
        }
        .onChange(of: captureState.selectedProcedure) { _ in
            loadGhostSelection()
        }
        .onChange(of: captureState.selectedToothNumber) { _ in
            loadGhostSelection()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Close button
            Button(action: handleClose) {
                Image(systemName: "xmark")
                    .font(.system(size: AppTheme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(AppTheme.Opacity.heavy))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Return to tag setup")

            // Ghost overlay button
            Image(systemName: isGhostActive ? "rectangle.stack.fill" : "rectangle.stack")
                .font(.system(size: AppTheme.IconSize.sm, weight: .semibold))
                .foregroundStyle(isGhostActive ? .cyan : .white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(AppTheme.Opacity.heavy))
                .clipShape(Circle())
                .onTapGesture {
                    if ghostImage != nil {
                        ghostEnabled.toggle()
                    } else {
                        showGhostPicker = true
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showGhostPicker = true
                }
                .accessibilityLabel(isGhostActive ? "Ghost Overlay On" : "Ghost Overlay Off")
                .accessibilityHint("Tap to toggle ghost overlay. Long press to change reference photo.")

            Spacer()

            // Tag summary pill
            Button(action: { showTagEditor = true }) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(captureState.tagSummary)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: AppTheme.IconSize.xs - 2, weight: .semibold))
                        .foregroundStyle(.white.opacity(AppTheme.Opacity.prominent))
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(captureState.hasAllTags ? AppTheme.Colors.success : Color.black.opacity(AppTheme.Opacity.heavy))
                .cornerRadius(AppTheme.CornerRadius.full)
            }
            .accessibilityLabel("Edit Tags: \(captureState.tagSummary)")
            .accessibilityHint("Double tap to edit photo tags")

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
                    .font(.system(size: AppTheme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(AppTheme.Opacity.heavy))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Camera Settings")
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
                            .foregroundStyle(.white)

                        Image(systemName: "arrow.right")
                            .font(.system(size: AppTheme.IconSize.xs, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.full)
                }
            }

            // Requirement counter or Zoom indicator (zoom takes priority when active)
            if isPinchZooming {
                ZoomIndicatorView(
                    currentZoom: cameraService.currentZoom,
                    previousZoom: previousZoom
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if showRequirementSatisfied {
                // Show satisfied state (temporary celebration)
                RequirementCounterView(
                    remainingRequired: 0,
                    isSatisfied: true,
                    portfolioName: currentRequirement?.portfolioName
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if currentRequirement != nil && remainingRequired > 0 {
                // Show active requirement counter (only when photos still needed)
                RequirementCounterView(
                    remainingRequired: remainingRequired,
                    isSatisfied: false,
                    portfolioName: currentRequirement?.portfolioName
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Ghost opacity slider
            if isGhostActive {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))

                    Slider(value: $ghostOpacity, in: 0.2...0.6, step: 0.05)
                        .tint(.cyan)

                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                    if captureState.displayPhotoCount > 0 {
                        Text("\(captureState.displayPhotoCount)")
                            .font(.system(size: AppTheme.IconSize.xs, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Circle())
                            .offset(x: 24, y: -24)
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.textTertiary.opacity(AppTheme.Opacity.medium))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: AppTheme.IconSize.md))
                                .foregroundStyle(.white.opacity(AppTheme.Opacity.heavy))
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
        .accessibilityLabel("Take Photo")
        .accessibilityHint("Double tap to capture a photo")
    }

    // MARK: - Flash Button

    private var flashButton: some View {
        Button(action: cycleFlashMode) {
            Image(systemName: flashModeIcon)
                .font(.system(size: AppTheme.IconSize.md, weight: .medium))
                .foregroundStyle(flashMode == .off ? .white : AppTheme.Colors.warning)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(AppTheme.Opacity.medium))
                .clipShape(Circle())
        }
        .accessibilityLabel(flashModeLabel)
        .accessibilityHint("Double tap to change flash mode")
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            ForEach([1.0, 2.0, 3.0], id: \.self) { zoom in
                Button(action: {
                    cameraService.setZoom(factor: zoom)
                }) {
                    Text("\(Int(zoom))x")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(isZoomSelected(zoom) ? AppTheme.Colors.warning : .white)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(isZoomSelected(zoom) ? Color.white.opacity(AppTheme.Opacity.light) : Color.clear)
                        .cornerRadius(AppTheme.CornerRadius.small)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Helper Methods

    private func isZoomSelected(_ zoom: Double) -> Bool {
        let current = cameraService.currentZoom
        if zoom == 1.0 {
            return current < 1.5
        } else if zoom == 2.0 {
            return current >= 1.5 && current < 2.5
        } else {
            return current >= 2.5
        }
    }

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    private func takePhoto() {
        // Immediate visual + haptic feedback
        triggerShutterFlash()
        hapticFeedback.impactOccurred()
        captureState.pendingCaptureCount += 1

        // Then start async capture
        cameraService.flashMode = flashMode
        cameraService.takePhoto()
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
    }

    private func handleClose() {
        if captureState.capturedPhotos.isEmpty {
            captureState.currentStep = .setup
        } else {
            // Show confirmation - handled by parent CaptureFlowView
            captureState.currentStep = .setup
        }
    }

    // MARK: - Focus Gesture Handling

    /// Handle drag gesture changes for focus, long press detection, and exposure adjustment
    private func handleFocusGestureChange(_ value: DragGesture.Value, in size: CGSize) {
        let location = value.location
        let translation = value.translation

        // Initialize gesture tracking on first call
        if gestureStartTime == nil {
            gestureStartTime = Date()
            dragStartLocation = value.startLocation
            initialExposure = cameraService.exposureValue
        }

        // Detect if user is swiping (moved more than threshold)
        let isSwiping = abs(translation.width) > 15 || abs(translation.height) > 15

        // Handle exposure adjustment when swiping vertically (only if we have a focus point)
        if cameraService.showFocusIndicator && isSwiping && abs(translation.height) > abs(translation.width) {
            isDraggingExposure = true

            // Calculate exposure change based on drag distance
            // Reduced sensitivity by 50% (200 instead of 100)
            let dragAmount = -(location.y - (dragStartLocation?.y ?? location.y))
            let exposureChange = Float(dragAmount / 200)
            let newExposure = max(-2.0, min(2.0, initialExposure + exposureChange))
            cameraService.setExposureCompensation(newExposure)
        }
    }

    /// Handle drag gesture end - focus is set here on tap release
    private func handleFocusGestureEnd(_ value: DragGesture.Value, in size: CGSize) {
        let translation = value.translation
        let tapLocation = value.startLocation

        // Check if this was a tap (not a swipe) - finger didn't move much
        let wasTap = abs(translation.width) <= 15 && abs(translation.height) <= 15

        // Define restricted zones (above tag pill ~100pt from top, below shutter ~180pt from bottom)
        let topExclusionZone: CGFloat = 100
        let bottomExclusionZone: CGFloat = 180
        let isInFocusableArea = tapLocation.y > topExclusionZone && tapLocation.y < (size.height - bottomExclusionZone)

        // Only set focus point if this was a tap (not a swipe) and in focusable area
        if wasTap && !isDraggingExposure && isInFocusableArea {
            let normalizedPoint = convertToNormalizedPoint(tapLocation, in: size)

            // If we already have a focus point and we're locked, unlock first
            if cameraService.isAEAFLocked {
                cameraService.unlockAEAF()
            }

            // Set the new focus point
            cameraService.setFocusPoint(normalizedPoint)

            // Check if this was a long press (held for 1.25+ seconds)
            if let startTime = gestureStartTime {
                let holdDuration = Date().timeIntervalSince(startTime)
                if holdDuration >= 1.25 {
                    // Trigger AE/AF lock
                    cameraService.lockAEAF()
                }
            }
        }

        // Reset all gesture state
        isDraggingExposure = false
        dragStartLocation = nil
        gestureStartTime = nil
    }

    /// Convert screen coordinates to normalized (0-1) coordinates for camera
    private func convertToNormalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        // Camera coordinate system is rotated relative to screen
        CGPoint(
            x: point.y / size.height,
            y: 1.0 - (point.x / size.width)
        )
    }

    /// Convert normalized focus point back to screen coordinates
    private func convertFocusToScreen(_ normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (1.0 - normalizedPoint.y) * size.width,
            y: normalizedPoint.x * size.height
        )
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

    // MARK: - Ghost Overlay Helpers

    /// Persistence key derived from current procedure + tooth selection
    private var ghostPersistenceKey: String? {
        guard let procedure = captureState.selectedProcedure else { return nil }
        let tooth = captureState.selectedToothNumber ?? 0
        return "\(procedure)-\(tooth)"
    }

    /// Reset ghost overlay state to default
    private func resetGhostState() {
        ghostEnabled = false
        ghostImage = nil
        ghostAssetId = nil
    }

    /// Save current ghost selection to UserDefaults
    private func saveGhostSelection() {
        guard let key = ghostPersistenceKey, let assetId = ghostAssetId else { return }
        var map = UserDefaults.standard.dictionary(forKey: Self.ghostReferenceMapKey) as? [String: String] ?? [:]
        map[key] = assetId
        UserDefaults.standard.set(map, forKey: Self.ghostReferenceMapKey)
    }

    /// Load saved ghost selection for current procedure + tooth
    private func loadGhostSelection() {
        guard let key = ghostPersistenceKey else {
            resetGhostState()
            return
        }

        let map = UserDefaults.standard.dictionary(forKey: Self.ghostReferenceMapKey) as? [String: String] ?? [:]
        if let savedId = map[key] {
            ghostAssetId = savedId
            loadGhostImage(assetId: savedId)
        } else {
            resetGhostState()
        }
    }

    /// Load a ghost image from app storage by asset ID
    private func loadGhostImage(assetId: String) {
        guard let uuid = UUID(uuidString: assetId),
              let image = PhotoStorageService.shared.loadEditedImage(id: uuid) else {
            resetGhostState()
            return
        }

        guard ghostAssetId == assetId else { return }
        ghostImage = image
        ghostEnabled = true
    }

    /// Clear ghost selection from state and persistence
    private func clearGhostSelection() {
        resetGhostState()

        if let key = ghostPersistenceKey {
            var map = UserDefaults.standard.dictionary(forKey: Self.ghostReferenceMapKey) as? [String: String] ?? [:]
            map.removeValue(forKey: key)
            UserDefaults.standard.set(map, forKey: Self.ghostReferenceMapKey)
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

// MARK: - Zoom Indicator View

/// Zoom indicator with ticker animation that appears during pinch-to-zoom
struct ZoomIndicatorView: View {
    let currentZoom: CGFloat
    let previousZoom: CGFloat

    // Computed property to determine zoom direction
    private var isZoomingIn: Bool {
        currentZoom > previousZoom
    }

    // Ticker offset based on zoom level
    private var tickerOffset: CGFloat {
        // Map zoom (1.0 to 10.0) to offset range
        let normalizedZoom = (currentZoom - 1.0) / 9.0 // 0 to 1 for 1x-10x range
        return normalizedZoom * 160 // Total scroll distance for full range
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            // Zoom multiplier text (matches zoom button caption size)
            Text(String(format: "%.1fx", currentZoom))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.warning)

            // Ticker ruler animation
            ZStack {
                // Ticker marks (ruler-like) - enough ticks for full 10x range
                HStack(spacing: 3) {
                    ForEach(0..<60, id: \.self) { index in
                        let isMajor = index % 5 == 0
                        Rectangle()
                            .fill(Color.white.opacity(isMajor ? 0.9 : 0.4))
                            .frame(width: isMajor ? 1.5 : 0.5, height: isMajor ? 8 : 4)
                    }
                }
                .offset(x: 40 - tickerOffset) // Start with some ticks visible, scroll as zoom increases
                .frame(width: 80, height: 12)
                .clipped()

                // Center indicator line
                Rectangle()
                    .fill(AppTheme.Colors.warning)
                    .frame(width: 1.5, height: 10)
            }
            .frame(width: 80, height: 12)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - Requirement Counter View

/// Shows the number of photos still required for the current portfolio requirement
/// Displays countdown animation as photos are taken and turns green when satisfied
struct RequirementCounterView: View {
    let remainingRequired: Int
    let isSatisfied: Bool
    let portfolioName: String?

    @State private var animateNumber: Bool = false
    @State private var showConfetti: Bool = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var previousRemainingRequired: Int?
    @State private var previousIsSatisfied: Bool?

    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(confettiParticles) { particle in
                ConfettiParticleView(particle: particle)
            }

            // Main pill
            HStack(spacing: AppTheme.Spacing.sm) {
                if isSatisfied {
                    // Satisfied state - green with checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.success)

                    Text("Portfolio requirement satisfied")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.success)
                } else {
                    // Active counting state
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(remainingRequired) photo\(remainingRequired == 1 ? "" : "s") required")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: remainingRequired)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                    .fill(isSatisfied ? AppTheme.Colors.success.opacity(0.2) : Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                            .strokeBorder(
                                isSatisfied ? AppTheme.Colors.success.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(animateNumber ? 1.05 : 1.0)
        }
        .onAppear {
            previousRemainingRequired = remainingRequired
            previousIsSatisfied = isSatisfied
        }
        .onChange(of: remainingRequired) { newValue in
            // Animate when count changes (decreases)
            if let oldValue = previousRemainingRequired, newValue < oldValue {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    animateNumber = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        animateNumber = false
                    }
                }
            }
            previousRemainingRequired = newValue
        }
        .onChange(of: isSatisfied) { newValue in
            // Trigger confetti when transitioning to satisfied
            if let oldValue = previousIsSatisfied, newValue && !oldValue {
                triggerConfetti()
            }
            previousIsSatisfied = newValue
        }
    }

    /// Trigger the confetti animation
    private func triggerConfetti() {
        // Create confetti particles
        var particles: [ConfettiParticle] = []
        for i in 0..<20 {
            particles.append(ConfettiParticle(
                id: i,
                startX: CGFloat.random(in: -20...20),
                startY: 0,
                endX: CGFloat.random(in: -80...80),
                endY: CGFloat.random(in: -100 ... -40),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.4...1.0),
                delay: Double.random(in: 0...0.15)
            ))
        }

        withAnimation {
            confettiParticles = particles
            showConfetti = true
        }

        // Clear confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                confettiParticles = []
                showConfetti = false
            }
        }
    }
}

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id: Int
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let rotation: Double
    let scale: CGFloat
    let delay: Double
}

// MARK: - Confetti Particle View

struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    @State private var isAnimating = false

    var body: some View {
        // Green confetti shapes
        Group {
            if particle.id % 3 == 0 {
                Circle()
                    .fill(AppTheme.Colors.success)
                    .frame(width: 6 * particle.scale, height: 6 * particle.scale)
            } else if particle.id % 3 == 1 {
                Rectangle()
                    .fill(AppTheme.Colors.success.opacity(0.8))
                    .frame(width: 4 * particle.scale, height: 8 * particle.scale)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: 8 * particle.scale))
                    .foregroundStyle(AppTheme.Colors.success.opacity(0.9))
            }
        }
        .offset(
            x: isAnimating ? particle.endX : particle.startX,
            y: isAnimating ? particle.endY : particle.startY
        )
        .rotationEffect(.degrees(isAnimating ? particle.rotation : 0))
        .opacity(isAnimating ? 0 : 1)
        .onAppear {
            withAnimation(
                .easeOut(duration: 0.8)
                .delay(particle.delay)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Quick Tag Editor Sheet

/// Sheet for quickly editing tags during capture
struct QuickTagEditorSheet: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showToothChart = false
    @State private var showAddProcedure = false
    @State private var showAddStageSheet = false

    // MARK: - Computed Properties

    /// Current selected tags as array for display
    private var currentTags: [String] {
        var tags: [String] = []
        if let procedure = captureState.selectedProcedure {
            tags.append(procedure)
        }
        if let tooth = captureState.selectedToothNumber {
            tags.append("#\(tooth)")
        }
        if let stage = captureState.selectedStage {
            tags.append(stage)
        }
        if let angle = captureState.selectedAngle {
            tags.append(angle)
        }
        return tags
    }

    /// Get color for a specific tag
    private func tagColor(for tag: String) -> Color {
        if MetadataManager.baseProcedures.contains(tag) {
            return AppTheme.procedureColor(for: tag)
        } else if tag.hasPrefix("#") {
            return AppTheme.Colors.info
        } else if metadataManager.getEnabledStageNames().contains(tag) {
            return metadataManager.stageColor(for: tag)
        } else if MetadataManager.angles.contains(tag) {
            return AppTheme.Colors.crown
        }
        return AppTheme.Colors.textSecondary
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Current tags summary
                    if !currentTags.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("CURRENT TAGS")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            FlowLayout(spacing: AppTheme.Spacing.xs) {
                                ForEach(currentTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, AppTheme.Spacing.sm)
                                        .padding(.vertical, AppTheme.Spacing.xxs)
                                        .background(tagColor(for: tag))
                                        .cornerRadius(AppTheme.CornerRadius.full)
                                }
                            }
                        }
                        .padding(.bottom, AppTheme.Spacing.sm)
                    }

                    // Procedure selection
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("PROCEDURE")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(metadataManager.procedures, id: \.self) { procedure in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if captureState.selectedProcedure == procedure {
                                                captureState.selectedProcedure = nil
                                            } else {
                                                captureState.selectedProcedure = procedure
                                            }
                                        }
                                    }) {
                                        Text(procedure)
                                            .font(AppTheme.Typography.subheadline.weight(.medium))
                                            .foregroundStyle(captureState.selectedProcedure == procedure ? .white : AppTheme.Colors.textPrimary)
                                            .padding(.horizontal, AppTheme.Spacing.sm)
                                            .padding(.vertical, AppTheme.Spacing.xs)
                                            .background(captureState.selectedProcedure == procedure ? AppTheme.procedureColor(for: procedure) : AppTheme.Colors.surfaceSecondary)
                                            .cornerRadius(AppTheme.CornerRadius.full)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Add new procedure button (as list item)
                                Button(action: { showAddProcedure = true }) {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(AppTheme.Colors.primary.opacity(0.15))
                                    .cornerRadius(AppTheme.CornerRadius.full)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Tooth selection (always visible)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("TOOTH")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                // Show selected tooth first if it exists
                                if let selectedTooth = captureState.selectedToothNumber {
                                    Button(action: {
                                        // Already selected, do nothing or deselect
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            captureState.selectedToothNumber = nil
                                        }
                                    }) {
                                        Text("#\(selectedTooth)")
                                            .font(AppTheme.Typography.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, AppTheme.Spacing.sm)
                                            .padding(.vertical, AppTheme.Spacing.xs)
                                            .background(AppTheme.Colors.info)
                                            .cornerRadius(AppTheme.CornerRadius.small)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Recent teeth (excluding currently selected)
                                let procedure = captureState.selectedProcedure ?? ""
                                let recentTeeth = metadataManager.getToothEntries(for: procedure)
                                    .filter { $0.toothNumber != captureState.selectedToothNumber }
                                    .prefix(5)
                                ForEach(recentTeeth.map { $0 }, id: \.id) { entry in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            captureState.selectedToothNumber = entry.toothNumber
                                            captureState.selectedToothDate = entry.date
                                        }
                                    }) {
                                        Text("#\(entry.toothNumber)")
                                            .font(AppTheme.Typography.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                            .padding(.horizontal, AppTheme.Spacing.sm)
                                            .padding(.vertical, AppTheme.Spacing.xs)
                                            .background(AppTheme.Colors.surfaceSecondary)
                                            .cornerRadius(AppTheme.CornerRadius.small)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Button to open tooth picker
                                Button(action: { showToothChart = true }) {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Select")
                                            .font(AppTheme.Typography.subheadline.weight(.medium))
                                    }
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(AppTheme.Colors.primary.opacity(0.15))
                                    .cornerRadius(AppTheme.CornerRadius.small)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Stage selection
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("STAGE")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(metadataManager.getEnabledStages()) { stageConfig in
                                    StagePillWithDelete(
                                        stageConfig: stageConfig,
                                        isSelected: captureState.selectedStage == stageConfig.name,
                                        onSelect: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if captureState.selectedStage == stageConfig.name {
                                                    captureState.selectedStage = nil
                                                } else {
                                                    captureState.selectedStage = stageConfig.name
                                                }
                                            }
                                        },
                                        onDelete: stageConfig.isDefault ? nil : {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if captureState.selectedStage == stageConfig.name {
                                                    captureState.selectedStage = nil
                                                }
                                                metadataManager.deleteStage(stageConfig.id)
                                            }
                                        }
                                    )
                                }

                                // Add stage button
                                Button(action: { showAddStageSheet = true }) {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Add")
                                            .font(AppTheme.Typography.subheadline.weight(.medium))
                                    }
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(AppTheme.Colors.surfaceSecondary)
                                    .cornerRadius(AppTheme.CornerRadius.full)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Angle selection
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("ANGLE")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(MetadataManager.angles, id: \.self) { angle in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if captureState.selectedAngle == angle {
                                                captureState.selectedAngle = nil
                                            } else {
                                                captureState.selectedAngle = angle
                                            }
                                        }
                                    }) {
                                        Text(angle)
                                            .font(AppTheme.Typography.subheadline.weight(.medium))
                                            .foregroundStyle(captureState.selectedAngle == angle ? .white : AppTheme.Colors.textPrimary)
                                            .padding(.horizontal, AppTheme.Spacing.sm)
                                            .padding(.vertical, AppTheme.Spacing.xs)
                                            .background(captureState.selectedAngle == angle ? AppTheme.Colors.crown : AppTheme.Colors.surfaceSecondary)
                                            .cornerRadius(AppTheme.CornerRadius.full)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    // Clear all button
                    if !currentTags.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                captureState.selectedProcedure = nil
                                captureState.selectedToothNumber = nil
                                captureState.selectedStage = nil
                                captureState.selectedAngle = nil
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear All Tags")
                            }
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.error)
                        }
                        .padding(.top, AppTheme.Spacing.sm)
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
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showToothChart) {
            ToothScrollPickerSheet(captureState: captureState)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddStageSheet) {
            AddStageSheet(isPresented: $showAddStageSheet)
        }
    }
}

// MARK: - Tooth Scroll Picker Sheet

/// Scrollable tooth picker with tooth names
struct ToothScrollPickerSheet: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTooth: Int? = nil

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(1...32, id: \.self) { tooth in
                            ToothScrollRow(
                                number: tooth,
                                name: toothName(for: tooth),
                                isSelected: selectedTooth == tooth
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTooth = tooth
                                }
                            }
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .onAppear {
                    // Scroll to selected tooth if one is already selected
                    if let currentTooth = captureState.selectedToothNumber {
                        selectedTooth = currentTooth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentTooth, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Select Tooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        if let tooth = selectedTooth {
                            captureState.selectedToothNumber = tooth
                            captureState.selectedToothDate = Date()

                            // Add to tooth history if procedure is selected
                            if let procedure = captureState.selectedProcedure {
                                let entry = ToothEntry(
                                    procedure: procedure,
                                    toothNumber: tooth,
                                    date: Date()
                                )
                                metadataManager.addToothEntry(entry)
                            }
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedTooth == nil)
                }
            }
        }
    }

    /// Get the anatomical name for a tooth number
    func toothName(for number: Int) -> String {
        switch number {
        // Upper right (1-8)
        case 1: return "Upper Right 3rd Molar"
        case 2: return "Upper Right 2nd Molar"
        case 3: return "Upper Right 1st Molar"
        case 4: return "Upper Right 2nd Premolar"
        case 5: return "Upper Right 1st Premolar"
        case 6: return "Upper Right Canine"
        case 7: return "Upper Right Lateral Incisor"
        case 8: return "Upper Right Central Incisor"
        // Upper left (9-16)
        case 9: return "Upper Left Central Incisor"
        case 10: return "Upper Left Lateral Incisor"
        case 11: return "Upper Left Canine"
        case 12: return "Upper Left 1st Premolar"
        case 13: return "Upper Left 2nd Premolar"
        case 14: return "Upper Left 1st Molar"
        case 15: return "Upper Left 2nd Molar"
        case 16: return "Upper Left 3rd Molar"
        // Lower left (17-24)
        case 17: return "Lower Left 3rd Molar"
        case 18: return "Lower Left 2nd Molar"
        case 19: return "Lower Left 1st Molar"
        case 20: return "Lower Left 2nd Premolar"
        case 21: return "Lower Left 1st Premolar"
        case 22: return "Lower Left Canine"
        case 23: return "Lower Left Lateral Incisor"
        case 24: return "Lower Left Central Incisor"
        // Lower right (25-32)
        case 25: return "Lower Right Central Incisor"
        case 26: return "Lower Right Lateral Incisor"
        case 27: return "Lower Right Canine"
        case 28: return "Lower Right 1st Premolar"
        case 29: return "Lower Right 2nd Premolar"
        case 30: return "Lower Right 1st Molar"
        case 31: return "Lower Right 2nd Molar"
        case 32: return "Lower Right 3rd Molar"
        default: return "Tooth \(number)"
        }
    }
}

// MARK: - Tooth Scroll Row

/// Row for tooth selection in scroll picker
struct ToothScrollRow: View {
    let number: Int
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Tooth number
                Text("#\(number)")
                    .font(AppTheme.Typography.title2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                    .frame(width: 60)

                // Tooth name
                Text(name)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.Colors.textSecondary)

                Spacer()

                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(isSelected ? AppTheme.Colors.info : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .id(number)
    }
}

// MARK: - Quick Tooth Cell (Legacy - kept for compatibility)

/// Compact tooth cell for quick selection
struct QuickToothCell: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .frame(width: 20, height: 28)
                .background(isSelected ? AppTheme.Colors.info : AppTheme.Colors.surfaceSecondary)
                .cornerRadius(AppTheme.CornerRadius.xs)
        }
    }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps content to the next line
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Ghost Photo Picker Sheet

/// Sheet for selecting a reference photo for the ghost overlay
struct GhostPhotoPickerSheet: View {
    let procedure: String?
    let toothNumber: Int?
    let onSelect: (String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var thumbnails: [(id: String, image: UIImage)] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationView {
            Group {
                if procedure == nil {
                    // No procedure selected
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "tag")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text("Select a procedure first")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Set a procedure tag to see matching photos for the ghost overlay.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if thumbnails.isEmpty {
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text("No matching photos")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Capture some photos with this procedure first.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(thumbnails, id: \.id) { item in
                                Button(action: {
                                    onSelect(item.id)
                                    dismiss()
                                }) {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(minHeight: 120)
                                        .clipped()
                                }
                            }
                        }
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Ghost Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        onClear()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            loadThumbnails()
        }
    }

    private func loadThumbnails() {
        guard let procedure = procedure else {
            isLoading = false
            return
        }

        let assetIds = MetadataManager.shared.getMatchingAssetIds(
            procedure: procedure,
            prioritizingTooth: toothNumber
        )

        guard !assetIds.isEmpty else {
            isLoading = false
            return
        }

        let storage = PhotoStorageService.shared
        let loaded: [(id: String, image: UIImage)] = assetIds
            .prefix(50)
            .compactMap { idString in
                guard let uuid = UUID(uuidString: idString),
                      let image = storage.loadEditedThumbnail(id: uuid) else { return nil }
                return (id: idString, image: image)
            }

        thumbnails = loaded
        isLoading = false
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
