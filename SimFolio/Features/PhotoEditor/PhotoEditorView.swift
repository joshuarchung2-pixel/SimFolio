// PhotoEditorView.swift
// Main photo editing interface
//
// Features:
// - Two editing modes: Transform and Adjust
// - Transform: crop, fine-rotate, 90-degree rotate
// - Adjust: brightness, exposure, highlights, shadows, contrast, black point,
//           saturation, brilliance, sharpness, definition
// - Real-time preview with efficient processing
// - Save changes to Photos library

import SwiftUI
import Combine
import UIKit

// MARK: - Photo Editor View

/// Main photo editing view with transform and adjust modes
struct PhotoEditorView: View {
    // MARK: - Properties

    let photoId: UUID
    @Binding var isPresented: Bool
    let onSave: ((UIImage) -> Void)?

    // MARK: - State

    @StateObject private var viewModel: PhotoEditorViewModel

    @State private var editorMode: EditorMode = .adjust
    @State private var showCancelConfirmation = false
    @State private var isSaving = false
    @State private var showSaveError = false
    // Inline text editing state
    @State private var isEditingText = false
    @State private var pendingTextPosition: CGPoint?
    @State private var pendingTextContent: String = ""
    // Track previous markup sub-mode for iOS 16 onChange compatibility
    @State private var previousMarkupSubMode: MarkupSubMode?
    @State private var showPremiumPaywall = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(photoId: UUID, isPresented: Binding<Bool>, onSave: ((UIImage) -> Void)? = nil) {
        self.photoId = photoId
        self._isPresented = isPresented
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: PhotoEditorViewModel(assetId: photoId.uuidString))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    // Image preview
                    imagePreview(geometry: geometry)

                    // Mode picker
                    modePicker

                    // Controls for current mode
                    controlsView
                        .frame(height: 230)
                }

                // Saving overlay
                if isSaving {
                    savingOverlay
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            loadImage()
            previousMarkupSubMode = viewModel.markupSubMode
        }
        .confirmationDialog(
            "Discard Changes?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                isPresented = false
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Failed to process image edits. Please try again.")
        }
        .onChange(of: editorMode) { newMode in
            // When switching to transform mode with crop sub-mode, enter reposition mode
            // This ensures the full image is shown immediately for previously cropped images
            if newMode == .transform && viewModel.transformSubMode == .crop {
                viewModel.enterRepositionMode()
                viewModel.updateCropPreview()
            }
        }
        .onChange(of: viewModel.markupSubMode) { newMode in
            // Deselect any selected element when switching markup sub-modes
            // (except when switching TO select mode, where selection is the purpose)
            if let oldMode = previousMarkupSubMode, oldMode == .select && newMode != .select {
                viewModel.selectMarkupElement(id: nil)
            }
            previousMarkupSubMode = newMode
        }
        .premiumGate(for: .advancedPhotoEditing, showPaywall: $showPremiumPaywall)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Cancel button
            Button(action: { handleCancel() }) {
                Text("Cancel")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white)
            }
            .padding(.leading, AppTheme.Spacing.md)

            // Undo button — markup mode only
            if editorMode == .markup {
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(viewModel.history.canUndo ? 1.0 : 0.4)
                }
                .disabled(!viewModel.history.canUndo)
                .padding(.leading, AppTheme.Spacing.md)
                .accessibilityLabel("Undo")
            }

            Spacer()

            // Title
            Text("Edit Photo")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)

            Spacer()

            // Save button
            Button(action: { saveEdits() }) {
                Text("Done")
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(viewModel.editState.hasChanges ? AppTheme.Colors.primary : .gray)
            }
            .disabled(!viewModel.editState.hasChanges || isSaving)
            .padding(.trailing, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Image Preview

    private func imagePreview(geometry: GeometryProxy) -> some View {
        Group {
            if editorMode == .transform && viewModel.transformSubMode == .crop && viewModel.isActivelyCropping {
                // Actively editing crop
                if let existingCrop = viewModel.editState.transform.cropRect,
                   let cropPreview = viewModel.previewImageForCrop {
                    // Has existing crop: show zoomable reposition view
                    ZoomableCropView(
                        image: cropPreview,
                        initialCropRect: existingCrop,
                        cropRect: $viewModel.tempCropRect,
                        scale: $viewModel.repositionScale,
                        offset: $viewModel.repositionOffset
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(viewModel.cropSessionId)
                } else if let cropPreview = viewModel.previewImageForCrop {
                    // No existing crop: show traditional crop overlay
                    CropOverlayView(
                        image: cropPreview,
                        cropRect: $viewModel.tempCropRect,
                        aspectRatio: viewModel.selectedAspectRatio,
                        onDragStarted: { viewModel.isActivelyCropping = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let previewImage = viewModel.previewImage {
                    // Fallback to regular preview
                    CropOverlayView(
                        image: previewImage,
                        cropRect: $viewModel.tempCropRect,
                        aspectRatio: viewModel.selectedAspectRatio,
                        onDragStarted: { viewModel.isActivelyCropping = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if editorMode == .transform && viewModel.transformSubMode == .crop {
                // In crop mode but not actively editing: show cropped result without handles
                // User must use "Reset Crop" button to access full image
                if let previewImage = viewModel.previewImage {
                    ZStack {
                        Color.black
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let previewImage = viewModel.previewImage {
                // Show regular preview with black background to match CropOverlayView
                // Apply visual rotation animation when in rotate mode
                ZStack {
                    Color.black
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(viewModel.visualRotationAngle.truncatingRemainder(dividingBy: 360)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.visualRotationAngle)
                        .overlay {
                            // Markup canvas overlay (visible when markup exists or in markup mode)
                            if editorMode == .markup || viewModel.editState.markup.hasMarkup {
                                GeometryReader { geo in
                                    markupCanvasOverlay(previewImage: previewImage, geometry: geo)
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            ForEach(EditorMode.allCases) { mode in
                let isLocked = mode == .markup && !FeatureGateService.isAvailable(.advancedPhotoEditing)
                Button(action: {
                    if isLocked {
                        showPremiumPaywall = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            editorMode = mode
                        }
                    }
                }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 22))
                            if isLocked {
                                PremiumLockBadge()
                                    .offset(x: 6, y: -4)
                            }
                        }
                        Text(mode.rawValue)
                            .font(AppTheme.Typography.caption)
                    }
                    .foregroundStyle(editorMode == mode ? AppTheme.Colors.primary : .gray)
                    .frame(minWidth: 80)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }

    // MARK: - Controls View

    @ViewBuilder
    private var controlsView: some View {
        switch editorMode {
        case .transform:
            TransformControlsView(viewModel: viewModel)
        case .adjust:
            AdjustControlsView(viewModel: viewModel, showPremiumPaywall: $showPremiumPaywall)
        case .markup:
            markupControlsView
        }
    }

    // MARK: - Markup Canvas Overlay

    @ViewBuilder
    private func markupCanvasOverlay(previewImage: UIImage, geometry: GeometryProxy) -> some View {
        // Calculate the actual image rect within the geometry
        let imageSize = calculateFitSize(imageSize: previewImage.size, containerSize: geometry.size)
        let xOffset = (geometry.size.width - imageSize.width) / 2
        let yOffset = (geometry.size.height - imageSize.height) / 2

        MarkupCanvasView(
            markupState: $viewModel.editState.markup,
            subMode: viewModel.markupSubMode,
            isEditable: editorMode == .markup,
            selectedColor: viewModel.selectedMarkupColor,
            selectedLineWidth: viewModel.selectedLineWidth,
            selectedFontSize: viewModel.selectedFontSize,
            selectedFillColor: viewModel.selectedFillColor,
            currentDrawingPoints: $viewModel.currentDrawingPoints,
            isDrawing: $viewModel.isDrawingMarkup,
            measurementStartPoint: $viewModel.measurementStartPoint,
            measurementEndPoint: $viewModel.measurementEndPoint,
            isEditingText: $isEditingText,
            pendingTextPosition: $pendingTextPosition,
            pendingTextContent: $pendingTextContent,
            onDrawingComplete: { points in
                viewModel.commitFreeformLine(points: points)
            },
            onMeasurementComplete: { start, end in
                viewModel.commitMeasurementLine(start: start, end: end)
            },
            onTextCommit: { position, text, canvasSize in
                viewModel.commitTextBox(at: position, text: text, canvasSize: canvasSize)
            },
            onElementSelected: { id in
                viewModel.selectMarkupElement(id: id)
            },
            onElementMoved: { delta in
                viewModel.moveSelectedMarkupElement(by: delta)
            },
            onElementMoveComplete: {
                viewModel.commitMarkupMove()
            },
            onElementRotated: { degrees in
                viewModel.rotateSelectedMarkupElement(by: degrees)
            },
            onElementRotateComplete: {
                viewModel.commitMarkupRotation()
            },
            onElementScaled: { scale in
                viewModel.scaleSelectedMarkupElement(by: scale)
            },
            onElementScaleComplete: {
                viewModel.commitMarkupScale()
            },
            onHandleDrag: { handleType, delta in
                viewModel.handleDrag(handleType: handleType, delta: delta)
            },
            onHandleDragEnd: { handleType in
                viewModel.commitHandleDrag(handleType: handleType)
            },
            onAutoSwitchToSelectMode: {
                viewModel.markupSubMode = .select
            }
        )
        .frame(width: imageSize.width, height: imageSize.height)
        .offset(x: xOffset, y: yOffset)
    }

    // MARK: - Markup Controls View

    private var markupControlsView: some View {
        MarkupControlsView(
            subMode: $viewModel.markupSubMode,
            selectedColor: $viewModel.selectedMarkupColor,
            selectedLineWidth: $viewModel.selectedLineWidth,
            selectedFontSize: $viewModel.selectedFontSize,
            selectedFillColor: $viewModel.selectedFillColor,
            hasSelection: viewModel.editState.markup.selectedElementId != nil,
            selectedElementType: viewModel.selectedMarkupElementType,
            isMarkupEmpty: !viewModel.editState.markup.hasMarkup,
            onDelete: {
                viewModel.deleteSelectedMarkupElement()
            },
            onBringToFront: {
                viewModel.bringSelectedMarkupToFront()
            },
            onSendToBack: {
                viewModel.sendSelectedMarkupToBack()
            },
            onColorChanged: { color in
                viewModel.updateSelectedMarkupColor(color)
            },
            onLineWidthChanged: { width in
                viewModel.updateSelectedMarkupLineWidth(width)
            },
            onFontSizeChanged: { size in
                viewModel.updateSelectedMarkupFontSize(size)
            },
            onFillColorChanged: { color in
                viewModel.updateSelectedMarkupFillColor(color)
            },
            onClearAll: {
                viewModel.clearAllMarkup()
            }
        )
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)

                Text("Saving...")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Actions

    private func loadImage() {
        if let image = PhotoStorageService.shared.loadImage(id: photoId) {
            viewModel.setOriginalImage(image)
        }
    }

    private func handleCancel() {
        if viewModel.editState.hasChanges {
            showCancelConfirmation = true
        } else {
            isPresented = false
        }
    }

    private func saveEdits() {
        guard let originalImage = viewModel.originalImage else { return }

        isSaving = true

        let editStateSnapshot = viewModel.editState

        // Process at full quality
        DispatchQueue.global(qos: .userInitiated).async {
            let processedImage = ImageProcessingService.shared.applyEdits(
                to: originalImage,
                editState: editStateSnapshot
            )

            DispatchQueue.main.async {
                isSaving = false

                if let processedImage = processedImage {
                    // Save edit state for persistence
                    PhotoEditPersistenceService.shared.saveEditState(
                        editStateSnapshot,
                        for: photoId.uuidString
                    )
                    onSave?(processedImage)
                    isPresented = false
                } else {
                    showSaveError = true
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Calculate the size that fits an image within a container while maintaining aspect ratio
    private func calculateFitSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
}

// MARK: - Photo Editor View Model

/// View model for photo editing state management
class PhotoEditorViewModel: ObservableObject {
    // MARK: - Published State

    @Published var editState: EditState
    @Published var originalImage: UIImage?
    @Published var previewImage: UIImage?
    /// Preview image without crop applied (for crop mode editing)
    @Published var previewImageForCrop: UIImage?
    @Published var transformSubMode: TransformSubMode = .crop
    @Published var selectedAspectRatio: AspectRatioPreset = .freeform
    @Published var selectedAdjustment: AdjustmentType = .brightness
    @Published var tempCropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Whether the user is actively adjusting the crop (dragging handles)
    /// When false and a crop exists, shows the cropped result
    /// When true, shows the full uncropped image with crop overlay
    @Published var isActivelyCropping: Bool = false

    /// Image scale for reposition mode (1.0 = crop fills the view)
    @Published var repositionScale: CGFloat = 1.0
    /// Image offset for reposition mode
    @Published var repositionOffset: CGSize = .zero

    /// Visual rotation angle for smooth animation (in degrees, 0-360)
    @Published var visualRotationAngle: Double = 0

    /// Unique identifier for each crop editing session, used to force view recreation
    @Published var cropSessionId: UUID = UUID()

    // MARK: - Markup State

    /// Current markup sub-mode
    @Published var markupSubMode: MarkupSubMode = .select

    /// Selected color for new markup elements
    @Published var selectedMarkupColor: MarkupColor = .red

    /// Selected line width for drawing and measurement
    @Published var selectedLineWidth: LineWidth = .medium

    /// Selected font size for text boxes
    @Published var selectedFontSize: FontSize = .medium

    /// Selected fill color for text boxes (nil = no fill)
    @Published var selectedFillColor: MarkupColor? = nil

    /// Points for current freeform drawing in progress
    @Published var currentDrawingPoints: [CGPoint] = []

    /// Whether currently drawing
    @Published var isDrawingMarkup: Bool = false

    /// Start point for measurement line in progress
    @Published var measurementStartPoint: CGPoint? = nil

    /// End point for measurement line in progress
    @Published var measurementEndPoint: CGPoint? = nil

    /// Saved state before starting a move operation
    private var markupMoveStartState: MarkupState?

    @Published private(set) var history = EditHistory()

    private var processingTask: Task<Void, Never>?
    private var cropPreviewTask: Task<Void, Never>?

    /// Throttle for preview updates during slider drags (~30fps)
    private let previewThrottle = ThrottledAction(minimumInterval: 0.033)

    /// Throttle for crop preview updates during fine rotation (~30fps)
    private let cropPreviewThrottle = ThrottledAction(minimumInterval: 0.033)

    /// Whether the user is actively dragging an adjustment slider
    @Published var isActivelyAdjusting: Bool = false

    // MARK: - Init

    init(assetId: String) {
        // Load existing edit state if available
        if let savedState = PhotoEditPersistenceService.shared.getEditState(for: assetId) {
            self.editState = savedState
            // Initialize tempCropRect from saved state if crop exists
            if let savedCrop = savedState.transform.cropRect {
                self.tempCropRect = savedCrop
            }
        } else {
            self.editState = EditState(assetId: assetId)
        }
    }

    // MARK: - Image Management

    func setOriginalImage(_ image: UIImage) {
        originalImage = image
        updatePreview()
        updateCropPreview()
    }

    // MARK: - Preview Updates

    func updatePreview(afterRotation: Bool = false) {
        processingTask?.cancel()

        processingTask = Task { @MainActor in
            guard let original = originalImage else { return }

            // Use a smaller preview for real-time editing
            let preview = ImageProcessingService.shared.generatePreview(
                from: original,
                editState: editState,
                maxDimension: 1200
            )

            if !Task.isCancelled {
                if afterRotation {
                    // Wait for animation to complete before swapping image
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms for animation

                    if !Task.isCancelled {
                        // Reset visual rotation and update preview simultaneously
                        withAnimation(.none) {
                            self.visualRotationAngle = 0
                        }
                        self.previewImage = preview
                    }
                } else {
                    self.previewImage = preview
                }
            }
        }
    }

    /// Generate preview without crop applied (for crop mode editing)
    func updateCropPreview() {
        cropPreviewTask?.cancel()

        cropPreviewTask = Task { @MainActor in
            guard let original = originalImage else { return }

            // Create a copy of edit state without crop
            var stateWithoutCrop = editState
            stateWithoutCrop.transform.cropRect = nil

            let preview = ImageProcessingService.shared.generatePreview(
                from: original,
                editState: stateWithoutCrop,
                maxDimension: 1200
            )

            if !Task.isCancelled {
                self.previewImageForCrop = preview
            }
        }
    }

    // MARK: - Edit Operations

    func recordStateForUndo() {
        history.record(editState)
    }

    func undo() {
        if let previousState = history.undo(currentState: editState) {
            editState = previousState
            updatePreview()
        }
    }

    func redo() {
        if let nextState = history.redo(currentState: editState) {
            editState = nextState
            updatePreview()
        }
    }

    func resetAll() {
        recordStateForUndo()
        editState.resetAll()
        tempCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        updatePreview()
        updateCropPreview()
    }

    func resetAdjustments() {
        recordStateForUndo()
        editState.resetAdjustments()
        updatePreview()
        updateCropPreview()
    }

    func resetTransform() {
        recordStateForUndo()
        editState.resetTransform()
        tempCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        updatePreview()
        updateCropPreview()
    }

    // MARK: - Adjustment Updates

    func updateAdjustment(_ type: AdjustmentType, value: Double) {
        type.setValue(value, in: &editState.adjustments)
        throttledPreviewUpdate()
    }

    func commitAdjustment() {
        recordStateForUndo()
    }

    /// Throttled preview update for smooth slider performance
    @MainActor
    private func throttledPreviewUpdate() {
        previewThrottle.executeAsyncWithTrailing { [weak self] in
            await self?.generateThrottledPreview()
        }
    }

    /// Generate preview with resolution based on whether user is actively adjusting
    @MainActor
    private func generateThrottledPreview() async {
        processingTask?.cancel()

        guard let original = originalImage else { return }

        // Use lower resolution during active adjustment for faster feedback
        let maxDim: CGFloat = isActivelyAdjusting ? 600 : 1200

        let preview = ImageProcessingService.shared.generatePreview(
            from: original,
            editState: editState,
            maxDimension: maxDim
        )

        if !Task.isCancelled {
            self.previewImage = preview
        }
    }

    /// Throttled crop preview update for smooth fine rotation
    @MainActor
    private func throttledCropPreviewUpdate() {
        cropPreviewThrottle.executeAsyncWithTrailing { [weak self] in
            await self?.generateThrottledCropPreview()
        }
    }

    /// Generate crop preview with resolution based on whether user is actively adjusting
    @MainActor
    private func generateThrottledCropPreview() async {
        cropPreviewTask?.cancel()

        guard let original = originalImage else { return }

        var stateWithoutCrop = editState
        stateWithoutCrop.transform.cropRect = nil

        let maxDim: CGFloat = isActivelyAdjusting ? 600 : 1200

        let preview = ImageProcessingService.shared.generatePreview(
            from: original,
            editState: stateWithoutCrop,
            maxDimension: maxDim
        )

        if !Task.isCancelled {
            self.previewImageForCrop = preview
        }
    }

    /// Generate final high-quality preview after adjustment ends
    func generateFinalPreview() {
        processingTask?.cancel()

        processingTask = Task { @MainActor in
            guard let original = originalImage else { return }

            let preview = ImageProcessingService.shared.generatePreview(
                from: original,
                editState: editState,
                maxDimension: 1200
            )

            if !Task.isCancelled {
                self.previewImage = preview
            }
        }

        updateCropPreview()
    }

    // MARK: - Transform Updates

    func rotate90Clockwise() {
        recordStateForUndo()

        // Transform the crop rectangle to match the new orientation
        if let crop = editState.transform.cropRect {
            // For 90° CW rotation of normalized coordinates:
            // new_x = 1 - old_y - old_height
            // new_y = old_x
            // new_width = old_height
            // new_height = old_width
            let newCrop = CGRect(
                x: 1 - crop.origin.y - crop.height,
                y: crop.origin.x,
                width: crop.height,
                height: crop.width
            )
            editState.transform.cropRect = newCrop
            tempCropRect = newCrop
        }

        editState.transform.rotate90Clockwise()

        // Animate the visual rotation
        withAnimation(.easeInOut(duration: 0.3)) {
            visualRotationAngle += 90
        }

        updatePreview(afterRotation: true)
        updateCropPreview()
    }

    func rotate90CounterClockwise() {
        recordStateForUndo()

        // Transform the crop rectangle to match the new orientation
        if let crop = editState.transform.cropRect {
            // For 90° CCW rotation of normalized coordinates:
            // new_x = old_y
            // new_y = 1 - old_x - old_width
            // new_width = old_height
            // new_height = old_width
            let newCrop = CGRect(
                x: crop.origin.y,
                y: 1 - crop.origin.x - crop.width,
                width: crop.height,
                height: crop.width
            )
            editState.transform.cropRect = newCrop
            tempCropRect = newCrop
        }

        editState.transform.rotate90CounterClockwise()

        // Animate the visual rotation
        withAnimation(.easeInOut(duration: 0.3)) {
            visualRotationAngle -= 90
        }

        updatePreview(afterRotation: true)
        updateCropPreview()
    }

    func updateFineRotation(_ degrees: Double) {
        editState.transform.fineRotation = degrees
        throttledPreviewUpdate()
        throttledCropPreviewUpdate()
    }

    func commitFineRotation() {
        recordStateForUndo()
    }

    func applyCrop() {
        // Only save if the crop is not full image
        let isFullImage = tempCropRect.origin.x < 0.001 &&
                          tempCropRect.origin.y < 0.001 &&
                          tempCropRect.width > 0.999 &&
                          tempCropRect.height > 0.999

        recordStateForUndo()

        if isFullImage {
            // No actual crop, just reset
            editState.transform.cropRect = nil
        } else {
            editState.transform.cropRect = tempCropRect
        }

        // Reset reposition state for next edit
        repositionScale = 1.0
        repositionOffset = .zero

        // Exit active cropping mode to show the cropped result
        isActivelyCropping = false

        updatePreview()
    }

    func cancelCrop() {
        tempCropRect = editState.transform.cropRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func resetCrop() {
        recordStateForUndo()
        tempCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        editState.transform.cropRect = nil
        editState.transform.fineRotation = 0
        repositionScale = 1.0
        repositionOffset = .zero
        updatePreview()
        updateCropPreview()
    }

    /// Enter reposition mode from applied crop state
    /// Sets up initial scale so that zooming out reveals more of the full image
    func enterRepositionMode() {
        guard editState.transform.cropRect != nil else {
            // No crop applied, just enter active cropping mode normally
            isActivelyCropping = true
            return
        }

        // Generate new session ID to force ZoomableCropView recreation with fresh state
        cropSessionId = UUID()

        // Reset scale and offset - ZoomableCropView will initialize them on appear
        // based on the current crop rect
        repositionScale = 1.0
        repositionOffset = .zero

        isActivelyCropping = true
    }

    // MARK: - Markup Operations

    /// Get the type of the currently selected markup element
    var selectedMarkupElementType: MarkupElementType? {
        guard let element = editState.markup.selectedElement else { return nil }
        switch element {
        case .freeformLine: return .freeformLine
        case .measurementLine: return .measurementLine
        case .textBox: return .textBox
        }
    }

    /// Commit a freeform line drawing
    func commitFreeformLine(points: [CGPoint]) {
        recordStateForUndo()
        let line = FreeformLine(
            points: points,
            color: selectedMarkupColor,
            lineWidth: selectedLineWidth
        )
        editState.markup.addElement(.freeformLine(line))
    }

    /// Commit a measurement line
    func commitMeasurementLine(start: CGPoint, end: CGPoint) {
        recordStateForUndo()
        let line = MeasurementLine(
            startPoint: start,
            endPoint: end,
            color: selectedMarkupColor,
            lineWidth: selectedLineWidth
        )
        editState.markup.addElement(.measurementLine(line))
    }

    /// Commit a text box with calculated size based on text content
    func commitTextBox(at position: CGPoint, text: String, canvasSize: CGSize) {
        recordStateForUndo()

        // Calculate text size using UIKit text measurement
        let font = UIFont.systemFont(ofSize: selectedFontSize.pointSize, weight: .medium)
        let maxWidth = canvasSize.width * 0.8  // Allow text to be at most 80% of canvas width
        let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)

        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let textRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes,
            context: nil
        )

        // Add padding for the text box (same as InlineTextEditorView: horizontal 8, vertical 4)
        let paddedWidth = textRect.width + 16  // 8 padding on each side
        let paddedHeight = textRect.height + 8  // 4 padding on top and bottom

        // Convert to normalized coordinates
        let normalizedWidth = paddedWidth / canvasSize.width
        let normalizedHeight = paddedHeight / canvasSize.height

        // Ensure minimum size
        let finalWidth = max(normalizedWidth, 0.05)
        let finalHeight = max(normalizedHeight, 0.03)

        let box = TextBox(
            position: position,
            text: text,
            fontSize: selectedFontSize,
            fontColor: selectedMarkupColor,
            fillColor: selectedFillColor,
            size: CGSize(width: finalWidth, height: finalHeight)
        )
        editState.markup.addElement(.textBox(box))
    }

    /// Select a markup element
    func selectMarkupElement(id: UUID?) {
        editState.markup.select(id: id)

        // Update selected properties from the element
        if let element = editState.markup.selectedElement {
            selectedMarkupColor = element.color
            switch element {
            case .freeformLine(let line):
                selectedLineWidth = line.lineWidth
            case .measurementLine(let line):
                selectedLineWidth = line.lineWidth
            case .textBox(let box):
                selectedFontSize = box.fontSize
                selectedFillColor = box.fillColor
            }
        }
    }

    /// Move the selected markup element
    func moveSelectedMarkupElement(by delta: CGSize) {
        if markupMoveStartState == nil {
            markupMoveStartState = editState.markup
        }
        editState.markup.moveSelectedElement(by: delta)
    }

    /// Commit the markup move operation
    func commitMarkupMove() {
        if markupMoveStartState != nil {
            recordStateForUndo()
            markupMoveStartState = nil
        }
    }

    /// Rotate the selected markup element
    func rotateSelectedMarkupElement(by degrees: Double) {
        if markupMoveStartState == nil {
            markupMoveStartState = editState.markup
        }
        editState.markup.rotateSelectedElement(by: degrees)
    }

    /// Commit the markup rotation
    func commitMarkupRotation() {
        if markupMoveStartState != nil {
            recordStateForUndo()
            markupMoveStartState = nil
        }
    }

    /// Scale the selected markup element
    func scaleSelectedMarkupElement(by scale: CGFloat) {
        if markupMoveStartState == nil {
            markupMoveStartState = editState.markup
        }
        editState.markup.scaleSelectedElement(by: scale)
    }

    /// Commit the markup scale
    func commitMarkupScale() {
        if markupMoveStartState != nil {
            recordStateForUndo()
            markupMoveStartState = nil
        }
    }

    /// Delete the selected markup element
    func deleteSelectedMarkupElement() {
        guard let selectedId = editState.markup.selectedElementId else { return }
        recordStateForUndo()
        editState.markup.removeElement(id: selectedId)
    }

    /// Bring selected element to front
    func bringSelectedMarkupToFront() {
        guard let selectedId = editState.markup.selectedElementId else { return }
        recordStateForUndo()
        editState.markup.bringToFront(id: selectedId)
    }

    /// Send selected element to back
    func sendSelectedMarkupToBack() {
        guard let selectedId = editState.markup.selectedElementId else { return }
        recordStateForUndo()
        editState.markup.sendToBack(id: selectedId)
    }

    /// Update the color of the selected element
    func updateSelectedMarkupColor(_ color: MarkupColor) {
        selectedMarkupColor = color
        if editState.markup.selectedElementId != nil {
            recordStateForUndo()
            editState.markup.updateSelectedElementColor(color)
        }
    }

    /// Update the line width of the selected element
    func updateSelectedMarkupLineWidth(_ width: LineWidth) {
        selectedLineWidth = width
        if editState.markup.selectedElementId != nil {
            recordStateForUndo()
            editState.markup.updateSelectedLineWidth(width)
        }
    }

    /// Update the font size of the selected text box
    func updateSelectedMarkupFontSize(_ size: FontSize) {
        selectedFontSize = size
        if let selectedId = editState.markup.selectedElementId {
            recordStateForUndo()
            editState.markup.updateTextBox(id: selectedId, fontSize: size)
        }
    }

    /// Update the fill color of the selected text box
    func updateSelectedMarkupFillColor(_ color: MarkupColor?) {
        selectedFillColor = color
        if let selectedId = editState.markup.selectedElementId {
            recordStateForUndo()
            editState.markup.updateTextBox(id: selectedId, fillColor: color)
        }
    }

    /// Clear all markup
    func clearAllMarkup() {
        recordStateForUndo()
        editState.markup.clearAll()
    }

    /// Resize or move endpoint of selected element via handle drag
    func handleDrag(handleType: HandleType, delta: CGSize) {
        if markupMoveStartState == nil {
            markupMoveStartState = editState.markup
        }

        // Use endpoint movement for measurement lines, resize for others
        if let element = editState.markup.selectedElement {
            switch element {
            case .measurementLine:
                editState.markup.moveEndpoint(handleType: handleType, by: delta)
            case .textBox, .freeformLine:
                editState.markup.resizeSelectedElement(handleType: handleType, by: delta)
            }
        }
    }

    /// Commit the handle drag operation
    func commitHandleDrag(handleType: HandleType) {
        if markupMoveStartState != nil {
            recordStateForUndo()
            markupMoveStartState = nil
        }
    }

}

// MARK: - Transform Controls View

/// Controls for transform mode (crop, rotate)
struct TransformControlsView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Transform action buttons
            HStack(spacing: AppTheme.Spacing.lg) {
                // Crop button - switches to crop sub-mode
                Button(action: {
                    viewModel.transformSubMode = .crop
                    // Enter reposition mode to show full image with crop overlay
                    // This handles both new crops and existing crops properly
                    viewModel.enterRepositionMode()
                }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "crop")
                            .font(.system(size: 20))
                        Text("Crop")
                            .font(AppTheme.Typography.caption)
                    }
                    .foregroundStyle(viewModel.transformSubMode == .crop ? .white : .gray)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(
                        viewModel.transformSubMode == .crop ?
                        AppTheme.Colors.primary.opacity(0.3) : Color.clear
                    )
                    .cornerRadius(AppTheme.CornerRadius.small)
                }

                // Rotate button - directly rotates the image 90° clockwise
                Button(action: {
                    viewModel.rotate90Clockwise()
                }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 20))
                        Text("Rotate")
                            .font(AppTheme.Typography.caption)
                    }
                    .foregroundStyle(.gray)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(Color.clear)
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
            }
            .padding(.top, AppTheme.Spacing.sm)

            // Show crop controls when in crop mode
            // Rotate action is immediate, no sub-controls needed
            if viewModel.transformSubMode == .crop {
                cropControls
                    .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Crop Controls

    private var cropControls: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Fine rotation slider
            VStack(spacing: AppTheme.Spacing.xs) {
                HStack {
                    Text("Fine rotate")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(String(format: "%.1f°", viewModel.editState.transform.fineRotation))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.editState.transform.fineRotation },
                        set: { viewModel.updateFineRotation($0) }
                    ),
                    in: -45...45,
                    onEditingChanged: { editing in
                        viewModel.isActivelyAdjusting = editing
                        if !editing {
                            viewModel.commitFineRotation()
                            viewModel.generateFinalPreview()
                        }
                    }
                )
                .tint(AppTheme.Colors.primary)
            }

            // Apply/Reset buttons
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    viewModel.resetCrop()
                } label: {
                    Text("Reset Crop")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(AppTheme.CornerRadius.small)
                        .contentShape(Rectangle())
                }

                Button {
                    viewModel.applyCrop()
                } label: {
                    Text("Apply")
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(AppTheme.CornerRadius.small)
                        .contentShape(Rectangle())
                }
            }
        }
    }

}

// MARK: - Adjust Controls View

/// Controls for adjustment mode (sliders for various image adjustments)
struct AdjustControlsView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @Binding var showPremiumPaywall: Bool

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Adjustment type picker (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(AdjustmentType.allCases) { type in
                        let isLocked = type.isPremium && !FeatureGateService.isAvailable(.advancedPhotoEditing)
                        AdjustmentTypeButton(
                            type: type,
                            isSelected: viewModel.selectedAdjustment == type,
                            hasChanges: hasChanges(for: type),
                            isLocked: isLocked
                        ) {
                            if isLocked {
                                showPremiumPaywall = true
                            } else {
                                viewModel.selectedAdjustment = type
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }

            // Current adjustment slider
            VStack(spacing: AppTheme.Spacing.xs) {
                // Value display (right-aligned, no label)
                HStack {
                    Spacer()
                    Text(formatValue(
                        viewModel.selectedAdjustment.getValue(from: viewModel.editState.adjustments),
                        for: viewModel.selectedAdjustment
                    ))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                }

                // Slider
                AdjustmentSlider(
                    value: Binding(
                        get: { viewModel.selectedAdjustment.getValue(from: viewModel.editState.adjustments) },
                        set: { viewModel.updateAdjustment(viewModel.selectedAdjustment, value: $0) }
                    ),
                    type: viewModel.selectedAdjustment,
                    onEditingChanged: { editing in
                        if !editing {
                            viewModel.commitAdjustment()
                        }
                    },
                    onDragStarted: {
                        viewModel.isActivelyAdjusting = true
                    },
                    onDragEnded: {
                        viewModel.isActivelyAdjusting = false
                        viewModel.generateFinalPreview()
                    }
                )
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Reset button
            if viewModel.editState.adjustments.hasChanges {
                Button(action: { viewModel.resetAdjustments() }) {
                    Text("Reset All Adjustments")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
    }

    private func hasChanges(for type: AdjustmentType) -> Bool {
        let value = type.getValue(from: viewModel.editState.adjustments)
        return value != type.defaultValue
    }

    private func formatValue(_ value: Double, for type: AdjustmentType) -> String {
        switch type {
        case .contrast, .saturation:
            // Show as percentage from default (100%)
            let percentage = (value - 1.0) * 100
            return String(format: "%+.1f", percentage)
        case .exposure:
            return String(format: "%+.1f EV", value)
        default:
            let percentage = value * 100
            return String(format: "%+.1f", percentage)
        }
    }
}

// MARK: - Adjustment Type Button

/// Button for selecting an adjustment type
struct AdjustmentTypeButton: View {
    let type: AdjustmentType
    let isSelected: Bool
    let hasChanges: Bool
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        // Indicator dot for modified adjustments
                        if hasChanges && !isSelected {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 6, height: 6)
                                .offset(x: 2, y: -2)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        // Lock badge for premium adjustments
                        if isLocked {
                            PremiumLockBadge()
                                .offset(x: 4, y: -4)
                        }
                    }

                Text(type.rawValue)
                    .font(AppTheme.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : (hasChanges ? AppTheme.Colors.primary : .gray))
            .opacity(isLocked ? 0.6 : 1.0)
            .frame(width: 65)
        }
    }
}

// MARK: - Adjustment Slider

/// Custom slider for adjustments with center indicator
struct AdjustmentSlider: View {
    @Binding var value: Double
    let type: AdjustmentType
    let onEditingChanged: (Bool) -> Void
    var onDragStarted: (() -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                // Center indicator (for adjustments with 0 default)
                if type.defaultValue == 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: 12)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }

                // Fill from center or from left
                let progress = (value - type.minValue) / (type.maxValue - type.minValue)
                let thumbX = max(12, min(progress * geometry.size.width, geometry.size.width - 12))

                // Value fill indicator
                if type.defaultValue == 0 {
                    // Fill from center for zero-based adjustments
                    let defaultProgress = (0 - type.minValue) / (type.maxValue - type.minValue)
                    let centerX = defaultProgress * geometry.size.width
                    let fillWidth = abs(thumbX - centerX)
                    let fillX = min(thumbX, centerX) + fillWidth / 2

                    Rectangle()
                        .fill(AppTheme.Colors.primary.opacity(0.5))
                        .frame(width: fillWidth, height: 4)
                        .position(x: fillX, y: geometry.size.height / 2)
                }

                // Thumb
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                    .position(x: thumbX, y: geometry.size.height / 2)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onDragStarted?()
                        }
                        let progress = min(max(gesture.location.x / geometry.size.width, 0), 1)
                        var newValue = type.minValue + progress * (type.maxValue - type.minValue)
                        // Snap to 0.001 intervals (displays as 0.1 increments)
                        newValue = (newValue * 1000).rounded() / 1000
                        value = newValue
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded?()
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 44)
    }
}

// MARK: - Crop Overlay View

/// Interactive crop overlay for selecting crop region
struct CropOverlayView: View {
    let image: UIImage
    @Binding var cropRect: CGRect
    let aspectRatio: AspectRatioPreset
    var onDragStarted: (() -> Void)? = nil

    // Scale and offset state for pinch-to-zoom
    @State private var imageScale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0  // Cannot zoom out past fit
    private let maxScale: CGFloat = 3.0  // Maximum zoom in

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let baseImageRect = calculateImageRect(containerSize: containerSize)

            ZStack {
                Color.black
                imageLayerView(baseImageRect: baseImageRect, containerSize: containerSize)
                cropOverlayView(baseImageRect: baseImageRect)
            }
        }
    }

    // MARK: - Image Layer

    private func imageLayerView(baseImageRect: CGRect, containerSize: CGSize) -> some View {
        let currentScale = imageScale * gestureScale
        let currentOffsetWidth = imageOffset.width + gestureOffset.width
        let currentOffsetHeight = imageOffset.height + gestureOffset.height

        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(currentScale)
            .offset(x: currentOffsetWidth, y: currentOffsetHeight)
            .gesture(magnificationGesture(baseImageRect: baseImageRect, containerSize: containerSize))
            .simultaneousGesture(panGesture(baseImageRect: baseImageRect, containerSize: containerSize))
    }

    private func magnificationGesture(baseImageRect: CGRect, containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                let newScale = min(max(imageScale * value, minScale), maxScale)
                imageScale = newScale
                gestureScale = 1.0
                imageOffset = clampOffset(imageOffset, scale: imageScale, baseImageRect: baseImageRect, containerSize: containerSize)
                updateCropRectForScale(baseImageRect: baseImageRect)
            }
    }

    private func panGesture(baseImageRect: CGRect, containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                gestureOffset = value.translation
            }
            .onEnded { value in
                let newOffset = CGSize(
                    width: imageOffset.width + value.translation.width,
                    height: imageOffset.height + value.translation.height
                )
                imageOffset = clampOffset(newOffset, scale: imageScale, baseImageRect: baseImageRect, containerSize: containerSize)
                gestureOffset = .zero
                updateCropRectForScale(baseImageRect: baseImageRect)
            }
    }

    // MARK: - Crop Overlay

    private func cropOverlayView(baseImageRect: CGRect) -> some View {
        let currentScale = imageScale * gestureScale
        let currentOffsetWidth = imageOffset.width + gestureOffset.width
        let currentOffsetHeight = imageOffset.height + gestureOffset.height

        // Calculate scaled image rect for crop overlay positioning
        let scaledImageRect = CGRect(
            x: baseImageRect.origin.x - (baseImageRect.width * (currentScale - 1) / 2) + currentOffsetWidth,
            y: baseImageRect.origin.y - (baseImageRect.height * (currentScale - 1) / 2) + currentOffsetHeight,
            width: baseImageRect.width * currentScale,
            height: baseImageRect.height * currentScale
        )

        return CropRectangleOverlay(
            cropRect: $cropRect,
            imageRect: scaledImageRect,
            aspectRatio: aspectRatio.ratio(originalAspect: image.size.width / image.size.height),
            onDragStarted: onDragStarted,
            imageScale: currentScale,
            imageOffset: CGSize(width: currentOffsetWidth, height: currentOffsetHeight)
        )
    }

    /// Clamp offset to keep crop area within image bounds
    private func clampOffset(_ newOffset: CGSize, scale: CGFloat, baseImageRect: CGRect, containerSize: CGSize) -> CGSize {
        let scaledWidth = baseImageRect.width * scale
        let scaledHeight = baseImageRect.height * scale

        // How much the image extends beyond its original bounds on each side
        let extraWidth = (scaledWidth - baseImageRect.width) / 2
        let extraHeight = (scaledHeight - baseImageRect.height) / 2

        // Clamp so image always covers the original image area
        let maxOffsetX = extraWidth
        let minOffsetX = -extraWidth
        let maxOffsetY = extraHeight
        let minOffsetY = -extraHeight

        return CGSize(
            width: max(minOffsetX, min(newOffset.width, maxOffsetX)),
            height: max(minOffsetY, min(newOffset.height, maxOffsetY))
        )
    }

    /// Update crop rect when scale/offset changes to maintain visual crop position
    private func updateCropRectForScale(baseImageRect: CGRect) {
        // The crop rect is in normalized coordinates (0-1) relative to the full image
        // When zoomed, we need to adjust the crop rect so it represents the visible portion
        // This keeps the visual crop box position consistent
    }

    /// Calculate the actual image rect within the container based on aspect ratio
    private func calculateImageRect(containerSize: CGSize) -> CGRect {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        var imageWidth: CGFloat
        var imageHeight: CGFloat

        if imageAspect > containerAspect {
            // Image is wider than container - fit by width
            imageWidth = containerSize.width
            imageHeight = containerSize.width / imageAspect
        } else {
            // Image is taller than container - fit by height
            imageHeight = containerSize.height
            imageWidth = containerSize.height * imageAspect
        }

        let x = (containerSize.width - imageWidth) / 2
        let y = (containerSize.height - imageHeight) / 2

        return CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
    }
}

// MARK: - Crop Rectangle Overlay

/// Draggable crop rectangle overlay
struct CropRectangleOverlay: View {
    @Binding var cropRect: CGRect
    let imageRect: CGRect  // Actual image bounds within container (already accounts for scale/offset)
    let aspectRatio: CGFloat?
    var onDragStarted: (() -> Void)? = nil
    var imageScale: CGFloat = 1.0  // Current zoom level of the image
    var imageOffset: CGSize = .zero  // Current pan offset of the image

    @State private var isDragging = false
    @State private var dragStartRect: CGRect = .zero
    @State private var hasStartedHandleDrag: Bool = false

    private let handleSize: CGFloat = 30
    private let minCropSize: CGFloat = 50

    var body: some View {
        ZStack {
            // Dimmed overlay outside crop area (only covers image area)
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .mask(
                    Rectangle()
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)
                        .overlay(
                            Rectangle()
                                .frame(
                                    width: cropRect.width * imageRect.width,
                                    height: cropRect.height * imageRect.height
                                )
                                .position(
                                    x: imageRect.origin.x + (cropRect.origin.x + cropRect.width / 2) * imageRect.width,
                                    y: imageRect.origin.y + (cropRect.origin.y + cropRect.height / 2) * imageRect.height
                                )
                                .blendMode(.destinationOut)
                        )
                )

            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(
                    width: cropRect.width * imageRect.width,
                    height: cropRect.height * imageRect.height
                )
                .position(
                    x: imageRect.origin.x + (cropRect.origin.x + cropRect.width / 2) * imageRect.width,
                    y: imageRect.origin.y + (cropRect.origin.y + cropRect.height / 2) * imageRect.height
                )

            // Grid lines
            GridLinesView(
                rect: CGRect(
                    x: imageRect.origin.x + cropRect.origin.x * imageRect.width,
                    y: imageRect.origin.y + cropRect.origin.y * imageRect.height,
                    width: cropRect.width * imageRect.width,
                    height: cropRect.height * imageRect.height
                )
            )

            // Corner handles
            ForEach(CropHandle.allCases) { handle in
                CropHandleView(handle: handle)
                    .position(handlePosition(for: handle))
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // Capture start state on first change, not on appear
                                if !hasStartedHandleDrag {
                                    hasStartedHandleDrag = true
                                    dragStartRect = cropRect
                                }
                                onDragStarted?()
                                handleDrag(handle: handle, translation: value.translation)
                            }
                            .onEnded { _ in
                                hasStartedHandleDrag = false
                                dragStartRect = .zero
                            }
                    )
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartRect = cropRect
                        onDragStarted?()
                    }
                    moveCropRect(by: value.translation)
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartRect = .zero
                }
        )
    }

    private func handlePosition(for handle: CropHandle) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch handle {
        case .topLeft:
            x = imageRect.origin.x + cropRect.origin.x * imageRect.width
            y = imageRect.origin.y + cropRect.origin.y * imageRect.height
        case .topRight:
            x = imageRect.origin.x + (cropRect.origin.x + cropRect.width) * imageRect.width
            y = imageRect.origin.y + cropRect.origin.y * imageRect.height
        case .bottomLeft:
            x = imageRect.origin.x + cropRect.origin.x * imageRect.width
            y = imageRect.origin.y + (cropRect.origin.y + cropRect.height) * imageRect.height
        case .bottomRight:
            x = imageRect.origin.x + (cropRect.origin.x + cropRect.width) * imageRect.width
            y = imageRect.origin.y + (cropRect.origin.y + cropRect.height) * imageRect.height
        }

        return CGPoint(x: x, y: y)
    }

    private func handleDrag(handle: CropHandle, translation: CGSize) {
        // dragStartRect is now properly initialized on first drag change
        let dx = translation.width / imageRect.width
        let dy = translation.height / imageRect.height

        var newRect = dragStartRect

        switch handle {
        case .topLeft:
            newRect.origin.x = min(dragStartRect.origin.x + dx, dragStartRect.maxX - minCropSize / imageRect.width)
            newRect.origin.y = min(dragStartRect.origin.y + dy, dragStartRect.maxY - minCropSize / imageRect.height)
            newRect.size.width = dragStartRect.maxX - newRect.origin.x
            newRect.size.height = dragStartRect.maxY - newRect.origin.y
        case .topRight:
            newRect.origin.y = min(dragStartRect.origin.y + dy, dragStartRect.maxY - minCropSize / imageRect.height)
            newRect.size.width = max(dragStartRect.width + dx, minCropSize / imageRect.width)
            newRect.size.height = dragStartRect.maxY - newRect.origin.y
        case .bottomLeft:
            newRect.origin.x = min(dragStartRect.origin.x + dx, dragStartRect.maxX - minCropSize / imageRect.width)
            newRect.size.width = dragStartRect.maxX - newRect.origin.x
            newRect.size.height = max(dragStartRect.height + dy, minCropSize / imageRect.height)
        case .bottomRight:
            newRect.size.width = max(dragStartRect.width + dx, minCropSize / imageRect.width)
            newRect.size.height = max(dragStartRect.height + dy, minCropSize / imageRect.height)
        }

        // Apply aspect ratio constraint if set
        if let ratio = aspectRatio {
            let currentRatio = newRect.width / newRect.height
            if currentRatio > ratio {
                newRect.size.width = newRect.height * ratio
            } else {
                newRect.size.height = newRect.width / ratio
            }
        }

        // Clamp all edges to image bounds (normalized 0-1)
        let clampedMinX = max(0, newRect.origin.x)
        let clampedMinY = max(0, newRect.origin.y)
        let clampedMaxX = min(1, newRect.origin.x + newRect.size.width)
        let clampedMaxY = min(1, newRect.origin.y + newRect.size.height)

        newRect = CGRect(
            x: clampedMinX,
            y: clampedMinY,
            width: max(clampedMaxX - clampedMinX, minCropSize / imageRect.width),
            height: max(clampedMaxY - clampedMinY, minCropSize / imageRect.height)
        )

        cropRect = newRect
    }

    private func moveCropRect(by translation: CGSize) {
        let dx = translation.width / imageRect.width
        let dy = translation.height / imageRect.height

        var newOrigin = CGPoint(
            x: dragStartRect.origin.x + dx,
            y: dragStartRect.origin.y + dy
        )

        // Clamp to bounds
        newOrigin.x = max(0, min(newOrigin.x, 1 - cropRect.width))
        newOrigin.y = max(0, min(newOrigin.y, 1 - cropRect.height))

        cropRect.origin = newOrigin
    }
}

// MARK: - Crop Handle

enum CropHandle: CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight

    var id: Self { self }
}

// MARK: - Crop Handle View

struct CropHandleView: View {
    let handle: CropHandle

    var body: some View {
        ZStack {
            // Visual handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Grid Lines View

struct GridLinesView: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            // Vertical lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 0.5, height: rect.height)
                    .position(
                        x: rect.origin.x + rect.width * CGFloat(i) / 3,
                        y: rect.origin.y + rect.height / 2
                    )
            }

            // Horizontal lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: rect.width, height: 0.5)
                    .position(
                        x: rect.origin.x + rect.width / 2,
                        y: rect.origin.y + rect.height * CGFloat(i) / 3
                    )
            }
        }
    }
}

// MARK: - Zoomable Crop View

/// View for repositioning the image under a fixed crop box
/// Shows the full image that can be scaled and panned, with a fixed crop box overlay
/// Updates cropRect in real-time as user zooms/pans
/// Corner handles can be dragged to resize the crop box
struct ZoomableCropView: View {
    let image: UIImage
    let initialCropRect: CGRect  // The original crop rect in normalized coords
    @Binding var cropRect: CGRect  // Updated crop rect based on zoom/pan
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    // Gesture state for image pan/zoom
    @State private var gestureScale: CGFloat = 1.0
    @State private var gestureOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    // State for crop box resizing
    @State private var cropBoxOffset: CGSize = .zero  // Offset from center
    @State private var cropBoxSizeAdjustment: CGSize = .zero  // Size delta from initial
    @GestureState private var isDraggingHandle: Bool = false  // Auto-resets when gesture ends
    @State private var hasStartedDrag: Bool = false  // Track drag start since @GestureState can't capture complex state
    @State private var dragStartCropBoxOffset: CGSize = .zero
    @State private var dragStartCropBoxSizeAdjustment: CGSize = .zero

    // Initialization flag to prevent gesture handling before state is ready
    @State private var isInitialized: Bool = false

    // Minimum and maximum scale bounds (relative to initial "crop fills box" state)
    private let minScale: CGFloat = 0.5   // Can zoom out to see more
    private let maxScale: CGFloat = 3.0   // Can zoom in
    private let minCropSize: CGFloat = 50  // Minimum crop box dimension

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let baseCropBoxSize = calculateBaseCropBoxSize(containerSize: containerSize)
            let currentCropBoxSize = CGSize(
                width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
            )
            let cropBoxCenter = CGPoint(
                x: containerSize.width / 2 + cropBoxOffset.width,
                y: containerSize.height / 2 + cropBoxOffset.height
            )

            ZStack {
                Color.black

                // The image layer - uses scaleEffect and offset for transforms
                imageLayer(containerSize: containerSize, cropBoxSize: currentCropBoxSize, cropBoxCenter: cropBoxCenter)

                // Dimmed overlay with crop box cutout
                dimmingOverlay(cropBoxSize: currentCropBoxSize, cropBoxCenter: cropBoxCenter, containerSize: containerSize)

                // Crop box border and grid
                cropBoxOverlay(containerSize: containerSize, cropBoxSize: currentCropBoxSize, cropBoxCenter: cropBoxCenter)
            }
            .clipped()
            .onAppear {
                // Explicitly reset all transient crop box state for fresh start
                cropBoxOffset = .zero
                cropBoxSizeAdjustment = .zero
                hasStartedDrag = false
                dragStartCropBoxOffset = .zero
                dragStartCropBoxSizeAdjustment = .zero
                isInitialized = false

                // Initialize transforms for this crop session
                initializeTransforms(containerSize: containerSize, cropBoxSize: baseCropBoxSize)

                // Mark as initialized after state is set up
                // Use async to ensure layout is complete before enabling gestures
                DispatchQueue.main.async {
                    isInitialized = true
                }
            }
            .onDisappear {
                // Reset initialization flag for clean state on next appearance
                isInitialized = false
            }
        }
    }

    // MARK: - Image Layer

    private func imageLayer(containerSize: CGSize, cropBoxSize: CGSize, cropBoxCenter: CGPoint) -> some View {
        let baseCropBoxSize = calculateBaseCropBoxSize(containerSize: containerSize)
        let baseImageSize = calculateBaseImageSize(containerSize: containerSize, cropBoxSize: baseCropBoxSize)

        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: baseImageSize.width, height: baseImageSize.height)
            .scaleEffect(scale * gestureScale)
            .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard isInitialized, !isDraggingHandle else { return }
                        // Compute fresh crop box values for real-time clamping
                        let freshCropBoxSize = CGSize(
                            width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                            height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
                        )
                        let freshCropBoxCenter = CGPoint(
                            x: containerSize.width / 2 + cropBoxOffset.width,
                            y: containerSize.height / 2 + cropBoxOffset.height
                        )
                        // Calculate potential new offset and clamp it in real-time
                        let potentialOffset = CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        )
                        let clampedOffset = clampOffset(potentialOffset, scale: scale, baseImageSize: baseImageSize, cropBoxSize: freshCropBoxSize, cropBoxCenter: freshCropBoxCenter, containerSize: containerSize)
                        // Set gestureOffset to the clamped difference from current offset
                        gestureOffset = CGSize(
                            width: clampedOffset.width - offset.width,
                            height: clampedOffset.height - offset.height
                        )
                    }
                    .onEnded { value in
                        guard isInitialized, !isDraggingHandle else { return }
                        // Compute fresh crop box values
                        let freshCropBoxSize = CGSize(
                            width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                            height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
                        )
                        let freshCropBoxCenter = CGPoint(
                            x: containerSize.width / 2 + cropBoxOffset.width,
                            y: containerSize.height / 2 + cropBoxOffset.height
                        )
                        // Commit the clamped offset (already clamped during drag)
                        offset = CGSize(
                            width: offset.width + gestureOffset.width,
                            height: offset.height + gestureOffset.height
                        )
                        gestureOffset = .zero
                        lastOffset = offset
                        updateCropRect(baseImageSize: baseImageSize, cropBoxSize: freshCropBoxSize, cropBoxCenter: freshCropBoxCenter)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        guard isInitialized, !isDraggingHandle else { return }
                        // Clamp scale in real-time to prevent crop exceeding image
                        let freshCropBoxSize = CGSize(
                            width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                            height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
                        )
                        // Calculate minimum scale that keeps crop within image bounds
                        let minScaleForCrop = max(
                            freshCropBoxSize.width / baseImageSize.width,
                            freshCropBoxSize.height / baseImageSize.height
                        )
                        let effectiveMinScale = max(minScale, minScaleForCrop)
                        let clampedGestureScale = min(max(value, effectiveMinScale / scale), maxScale / scale)
                        gestureScale = clampedGestureScale
                    }
                    .onEnded { value in
                        guard isInitialized, !isDraggingHandle else { return }
                        // Compute fresh crop box values
                        let freshCropBoxSize = CGSize(
                            width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                            height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
                        )
                        let freshCropBoxCenter = CGPoint(
                            x: containerSize.width / 2 + cropBoxOffset.width,
                            y: containerSize.height / 2 + cropBoxOffset.height
                        )
                        // Calculate minimum scale that keeps crop within image bounds
                        let minScaleForCrop = max(
                            freshCropBoxSize.width / baseImageSize.width,
                            freshCropBoxSize.height / baseImageSize.height
                        )
                        let effectiveMinScale = max(minScale, minScaleForCrop)
                        let newScale = min(max(scale * value, effectiveMinScale), maxScale)
                        scale = newScale
                        gestureScale = 1.0
                        lastScale = scale

                        // Clamp offset for new scale (scale change may affect valid bounds)
                        offset = clampOffset(offset, scale: scale, baseImageSize: baseImageSize, cropBoxSize: freshCropBoxSize, cropBoxCenter: freshCropBoxCenter, containerSize: containerSize)
                        lastOffset = offset
                        updateCropRect(baseImageSize: baseImageSize, cropBoxSize: freshCropBoxSize, cropBoxCenter: freshCropBoxCenter)
                    }
            )
    }

    // MARK: - Overlays

    private func dimmingOverlay(cropBoxSize: CGSize, cropBoxCenter: CGPoint, containerSize: CGSize) -> some View {
        Color.black.opacity(0.6)
            .mask(
                Rectangle()
                    .overlay(
                        Rectangle()
                            .frame(width: cropBoxSize.width, height: cropBoxSize.height)
                            .position(cropBoxCenter)
                            .blendMode(.destinationOut)
                    )
            )
            .allowsHitTesting(false)
    }

    private func cropBoxOverlay(containerSize: CGSize, cropBoxSize: CGSize, cropBoxCenter: CGPoint) -> some View {
        let baseCropBoxSize = calculateBaseCropBoxSize(containerSize: containerSize)
        let baseImageSize = calculateBaseImageSize(containerSize: containerSize, cropBoxSize: baseCropBoxSize)

        return ZStack {
            // Border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropBoxSize.width, height: cropBoxSize.height)
                .position(cropBoxCenter)
                .allowsHitTesting(false)

            // Grid lines
            GridLinesView(
                rect: CGRect(
                    x: cropBoxCenter.x - cropBoxSize.width / 2,
                    y: cropBoxCenter.y - cropBoxSize.height / 2,
                    width: cropBoxSize.width,
                    height: cropBoxSize.height
                )
            )
            .allowsHitTesting(false)

            // Corner handles - interactive for resizing
            ForEach(CropHandle.allCases) { handle in
                CropHandleView(handle: handle)
                    .position(handlePosition(for: handle, cropBoxSize: cropBoxSize, cropBoxCenter: cropBoxCenter))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1)
                            .updating($isDraggingHandle) { _, state, _ in
                                state = true  // Auto-resets when gesture ends
                            }
                            .onChanged { value in
                                // Capture start state on first change
                                if !hasStartedDrag {
                                    hasStartedDrag = true
                                    dragStartCropBoxOffset = cropBoxOffset
                                    dragStartCropBoxSizeAdjustment = cropBoxSizeAdjustment
                                }
                                handleHandleDrag(handle: handle, translation: value.translation, containerSize: containerSize, baseCropBoxSize: baseCropBoxSize, baseImageSize: baseImageSize)
                            }
                            .onEnded { _ in
                                hasStartedDrag = false
                                // isDraggingHandle auto-resets via @GestureState
                                // Compute fresh crop box values for updateCropRect
                                let freshCropBoxSize = CGSize(
                                    width: max(minCropSize, baseCropBoxSize.width + cropBoxSizeAdjustment.width),
                                    height: max(minCropSize, baseCropBoxSize.height + cropBoxSizeAdjustment.height)
                                )
                                let freshCropBoxCenter = CGPoint(
                                    x: containerSize.width / 2 + cropBoxOffset.width,
                                    y: containerSize.height / 2 + cropBoxOffset.height
                                )
                                updateCropRect(baseImageSize: baseImageSize, cropBoxSize: freshCropBoxSize, cropBoxCenter: freshCropBoxCenter)
                            }
                    )
            }
        }
    }

    // MARK: - Handle Drag Logic

    private func handleHandleDrag(handle: CropHandle, translation: CGSize, containerSize: CGSize, baseCropBoxSize: CGSize, baseImageSize: CGSize) {
        let dx = translation.width
        let dy = translation.height

        var newSizeAdj = dragStartCropBoxSizeAdjustment
        var newOffset = dragStartCropBoxOffset

        switch handle {
        case .topLeft:
            // Shrink from top-left: decrease width/height, move center down-right
            newSizeAdj.width = dragStartCropBoxSizeAdjustment.width - dx
            newSizeAdj.height = dragStartCropBoxSizeAdjustment.height - dy
            newOffset.width = dragStartCropBoxOffset.width + dx / 2
            newOffset.height = dragStartCropBoxOffset.height + dy / 2
        case .topRight:
            // Expand right, shrink top
            newSizeAdj.width = dragStartCropBoxSizeAdjustment.width + dx
            newSizeAdj.height = dragStartCropBoxSizeAdjustment.height - dy
            newOffset.width = dragStartCropBoxOffset.width + dx / 2
            newOffset.height = dragStartCropBoxOffset.height + dy / 2
        case .bottomLeft:
            // Shrink left, expand bottom
            newSizeAdj.width = dragStartCropBoxSizeAdjustment.width - dx
            newSizeAdj.height = dragStartCropBoxSizeAdjustment.height + dy
            newOffset.width = dragStartCropBoxOffset.width + dx / 2
            newOffset.height = dragStartCropBoxOffset.height + dy / 2
        case .bottomRight:
            // Expand both
            newSizeAdj.width = dragStartCropBoxSizeAdjustment.width + dx
            newSizeAdj.height = dragStartCropBoxSizeAdjustment.height + dy
            newOffset.width = dragStartCropBoxOffset.width + dx / 2
            newOffset.height = dragStartCropBoxOffset.height + dy / 2
        }

        // Clamp to ensure minimum size
        let newWidth = baseCropBoxSize.width + newSizeAdj.width
        let newHeight = baseCropBoxSize.height + newSizeAdj.height
        if newWidth < minCropSize {
            newSizeAdj.width = minCropSize - baseCropBoxSize.width
        }
        if newHeight < minCropSize {
            newSizeAdj.height = minCropSize - baseCropBoxSize.height
        }

        // Calculate current scaled image bounds
        let scaledImageWidth = baseImageSize.width * scale
        let scaledImageHeight = baseImageSize.height * scale
        let imageCenterX = containerSize.width / 2 + offset.width
        let imageCenterY = containerSize.height / 2 + offset.height
        let imageLeft = imageCenterX - scaledImageWidth / 2
        let imageRight = imageCenterX + scaledImageWidth / 2
        let imageTop = imageCenterY - scaledImageHeight / 2
        let imageBottom = imageCenterY + scaledImageHeight / 2

        // Clamp crop box size to not exceed image bounds
        let maxCropWidth = scaledImageWidth - 4  // Small margin
        let maxCropHeight = scaledImageHeight - 4
        if baseCropBoxSize.width + newSizeAdj.width > maxCropWidth {
            newSizeAdj.width = maxCropWidth - baseCropBoxSize.width
        }
        if baseCropBoxSize.height + newSizeAdj.height > maxCropHeight {
            newSizeAdj.height = maxCropHeight - baseCropBoxSize.height
        }

        // Calculate proposed crop box
        let proposedCropBoxSize = CGSize(
            width: max(minCropSize, baseCropBoxSize.width + newSizeAdj.width),
            height: max(minCropSize, baseCropBoxSize.height + newSizeAdj.height)
        )
        let proposedCenterX = containerSize.width / 2 + newOffset.width
        let proposedCenterY = containerSize.height / 2 + newOffset.height

        // Calculate proposed crop box edges
        var cropLeft = proposedCenterX - proposedCropBoxSize.width / 2
        var cropRight = proposedCenterX + proposedCropBoxSize.width / 2
        var cropTop = proposedCenterY - proposedCropBoxSize.height / 2
        var cropBottom = proposedCenterY + proposedCropBoxSize.height / 2

        // Clamp each edge independently to image bounds
        if cropLeft < imageLeft {
            cropLeft = imageLeft
        }
        if cropRight > imageRight {
            cropRight = imageRight
        }
        if cropTop < imageTop {
            cropTop = imageTop
        }
        if cropBottom > imageBottom {
            cropBottom = imageBottom
        }

        // Ensure minimum size after edge clamping
        // If clamping made the box too small, expand from the unclamped edge
        if cropRight - cropLeft < minCropSize {
            if cropLeft == imageLeft {
                cropRight = min(imageRight, cropLeft + minCropSize)
            } else {
                cropLeft = max(imageLeft, cropRight - minCropSize)
            }
        }
        if cropBottom - cropTop < minCropSize {
            if cropTop == imageTop {
                cropBottom = min(imageBottom, cropTop + minCropSize)
            } else {
                cropTop = max(imageTop, cropBottom - minCropSize)
            }
        }

        // Also constrain to container bounds with padding
        let containerPadding: CGFloat = 20
        let containerMinX = containerPadding
        let containerMaxX = containerSize.width - containerPadding
        let containerMinY = containerPadding
        let containerMaxY = containerSize.height - containerPadding

        if cropLeft < containerMinX {
            cropLeft = containerMinX
        }
        if cropRight > containerMaxX {
            cropRight = containerMaxX
        }
        if cropTop < containerMinY {
            cropTop = containerMinY
        }
        if cropBottom > containerMaxY {
            cropBottom = containerMaxY
        }

        // Calculate final size and center from clamped edges
        let finalWidth = max(minCropSize, cropRight - cropLeft)
        let finalHeight = max(minCropSize, cropBottom - cropTop)
        let clampedCenterX = (cropLeft + cropRight) / 2
        let clampedCenterY = (cropTop + cropBottom) / 2

        // Update size adjustment and offset based on clamped values
        newSizeAdj.width = finalWidth - baseCropBoxSize.width
        newSizeAdj.height = finalHeight - baseCropBoxSize.height
        newOffset.width = clampedCenterX - containerSize.width / 2
        newOffset.height = clampedCenterY - containerSize.height / 2

        cropBoxSizeAdjustment = newSizeAdj
        cropBoxOffset = newOffset
    }

    // MARK: - Calculations

    /// Calculate the base crop box size (centered in container, maintains crop aspect ratio)
    private func calculateBaseCropBoxSize(containerSize: CGSize) -> CGSize {
        let cropAspectRatio = (initialCropRect.width * image.size.width) /
                              (initialCropRect.height * image.size.height)
        let containerAspect = containerSize.width / containerSize.height
        let padding: CGFloat = 40

        var boxWidth: CGFloat
        var boxHeight: CGFloat

        if cropAspectRatio > containerAspect {
            boxWidth = containerSize.width - padding * 2
            boxHeight = boxWidth / cropAspectRatio
        } else {
            boxHeight = containerSize.height - padding * 2
            boxWidth = boxHeight * cropAspectRatio
        }

        return CGSize(width: max(boxWidth, 50), height: max(boxHeight, 50))
    }

    /// Calculate base image size so that at scale=1.0, the crop portion fills the crop box
    private func calculateBaseImageSize(containerSize: CGSize, cropBoxSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height

        // The image needs to be sized so that cropRect portion = cropBox size
        // So image.width * cropRect.width = cropBox.width at scale 1.0
        // Therefore: image.width = cropBox.width / cropRect.width

        let targetWidth = cropBoxSize.width / initialCropRect.width
        let targetHeight = cropBoxSize.height / initialCropRect.height

        // Use the size that maintains aspect ratio and covers the crop
        var width: CGFloat
        var height: CGFloat

        if targetWidth / imageAspect >= targetHeight {
            width = targetWidth
            height = targetWidth / imageAspect
        } else {
            height = targetHeight
            width = targetHeight * imageAspect
        }

        return CGSize(width: width, height: height)
    }

    /// Initialize scale and offset so the current crop fills the crop box
    private func initializeTransforms(containerSize: CGSize, cropBoxSize: CGSize) {
        let baseImageSize = calculateBaseImageSize(containerSize: containerSize, cropBoxSize: cropBoxSize)

        // Start at scale 1.0 (crop fills box)
        scale = 1.0
        lastScale = 1.0
        gestureScale = 1.0

        // Reset crop box adjustments
        cropBoxOffset = .zero
        cropBoxSizeAdjustment = .zero

        // Calculate offset to center the crop region in the view
        // The crop center in normalized coords (0-1)
        let cropCenterX = initialCropRect.midX
        let cropCenterY = initialCropRect.midY

        // Convert to offset: if crop center is at 0.5,0.5 (image center), offset should be 0
        // If crop is at 0.25,0.25, we need to shift image so that point is centered
        let initialOffset = CGSize(
            width: (0.5 - cropCenterX) * baseImageSize.width,
            height: (0.5 - cropCenterY) * baseImageSize.height
        )

        let cropBoxCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        offset = clampOffset(initialOffset, scale: scale, baseImageSize: baseImageSize, cropBoxSize: cropBoxSize, cropBoxCenter: cropBoxCenter, containerSize: containerSize)
        lastOffset = offset
        gestureOffset = .zero
    }

    /// Clamp offset to keep crop box within image bounds
    private func clampOffset(_ newOffset: CGSize, scale: CGFloat, baseImageSize: CGSize, cropBoxSize: CGSize, cropBoxCenter: CGPoint, containerSize: CGSize) -> CGSize {
        let scaledWidth = baseImageSize.width * scale
        let scaledHeight = baseImageSize.height * scale

        // The crop box can be offset from center, so we need to account for that
        // Image is centered at container center + offset
        // Crop box is at cropBoxCenter
        // We need to ensure the crop box stays within the image

        // Calculate how much the crop box is offset from container center
        let cropBoxOffsetFromCenter = CGSize(
            width: cropBoxCenter.x - containerSize.width / 2,
            height: cropBoxCenter.y - containerSize.height / 2
        )

        // Maximum offset considering crop box position
        let maxOffsetX = max(0, (scaledWidth - cropBoxSize.width) / 2) - cropBoxOffsetFromCenter.width
        let minOffsetX = -max(0, (scaledWidth - cropBoxSize.width) / 2) - cropBoxOffsetFromCenter.width

        let maxOffsetY = max(0, (scaledHeight - cropBoxSize.height) / 2) - cropBoxOffsetFromCenter.height
        let minOffsetY = -max(0, (scaledHeight - cropBoxSize.height) / 2) - cropBoxOffsetFromCenter.height

        return CGSize(
            width: max(minOffsetX, min(newOffset.width, maxOffsetX)),
            height: max(minOffsetY, min(newOffset.height, maxOffsetY))
        )
    }

    /// Update cropRect based on current scale, offset, and crop box position/size
    private func updateCropRect(baseImageSize: CGSize, cropBoxSize: CGSize, cropBoxCenter: CGPoint) {
        let scaledWidth = baseImageSize.width * scale
        let scaledHeight = baseImageSize.height * scale

        // Calculate crop box position in normalized image coordinates
        // Image is centered with offset applied, crop box is at cropBoxOffset from center
        let cropBoxOffsetX = cropBoxOffset.width
        let cropBoxOffsetY = cropBoxOffset.height

        let cropInImageX = (scaledWidth / 2 - offset.width + cropBoxOffsetX - cropBoxSize.width / 2) / scaledWidth
        let cropInImageY = (scaledHeight / 2 - offset.height + cropBoxOffsetY - cropBoxSize.height / 2) / scaledHeight
        let cropWidthNorm = cropBoxSize.width / scaledWidth
        let cropHeightNorm = cropBoxSize.height / scaledHeight

        let newRect = CGRect(
            x: max(0, min(cropInImageX, 1 - cropWidthNorm)),
            y: max(0, min(cropInImageY, 1 - cropHeightNorm)),
            width: min(cropWidthNorm, 1),
            height: min(cropHeightNorm, 1)
        )

        cropRect = newRect
    }

    private func handlePosition(for handle: CropHandle, cropBoxSize: CGSize, cropBoxCenter: CGPoint) -> CGPoint {
        let centerX = cropBoxCenter.x
        let centerY = cropBoxCenter.y
        let halfW = cropBoxSize.width / 2
        let halfH = cropBoxSize.height / 2

        switch handle {
        case .topLeft: return CGPoint(x: centerX - halfW, y: centerY - halfH)
        case .topRight: return CGPoint(x: centerX + halfW, y: centerY - halfH)
        case .bottomLeft: return CGPoint(x: centerX - halfW, y: centerY + halfH)
        case .bottomRight: return CGPoint(x: centerX + halfW, y: centerY + halfH)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PhotoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoEditorView(
            photoId: UUID(),
            isPresented: .constant(true)
        )
    }
}
#endif
