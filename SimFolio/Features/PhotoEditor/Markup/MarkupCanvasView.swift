// MarkupCanvasView.swift
// Main canvas for markup rendering and interaction
//
// Features:
// - Renders all markup elements sorted by zIndex
// - Routes gestures based on current sub-mode
// - Handles drawing, measurement, text placement, and selection
// - Shows selection handles for selected elements

import SwiftUI

// MARK: - Markup Canvas View

/// Main canvas for rendering and interacting with markup elements
struct MarkupCanvasView: View {
    @Binding var markupState: MarkupState
    let subMode: MarkupSubMode
    let isEditable: Bool

    // Current tool settings
    let selectedColor: MarkupColor
    let selectedLineWidth: LineWidth
    let selectedFontSize: FontSize
    let selectedFillColor: MarkupColor?

    // Drawing state
    @Binding var currentDrawingPoints: [CGPoint]
    @Binding var isDrawing: Bool

    // Measurement state
    @Binding var measurementStartPoint: CGPoint?
    @Binding var measurementEndPoint: CGPoint?

    // Inline text editing state
    @Binding var isEditingText: Bool
    @Binding var pendingTextPosition: CGPoint?
    @Binding var pendingTextContent: String

    // Callbacks
    var onDrawingComplete: (([CGPoint]) -> Void)?
    var onMeasurementComplete: ((CGPoint, CGPoint) -> Void)?
    var onTextCommit: ((CGPoint, String, CGSize) -> Void)?  // position, text, canvasSize
    var onElementSelected: ((UUID?) -> Void)?
    var onElementMoved: ((CGSize) -> Void)?
    var onElementMoveComplete: (() -> Void)?
    var onElementRotated: ((Double) -> Void)?
    var onElementRotateComplete: (() -> Void)?
    var onElementScaled: ((CGFloat) -> Void)?
    var onElementScaleComplete: (() -> Void)?
    var onHandleDrag: ((HandleType, CGSize) -> Void)?
    var onHandleDragEnd: ((HandleType) -> Void)?
    var onAutoSwitchToSelectMode: (() -> Void)?

    // Internal state
    @State private var canvasSize: CGSize = .zero
    @State private var dragStartState: MarkupState?
    @FocusState private var isTextFieldFocused: Bool

    // State for tap-to-place measurement workflow
    @State private var pendingMeasurementStart: CGPoint? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Existing elements
                ForEach(markupState.sortedElements) { element in
                    MarkupElementView(element: element, canvasSize: geometry.size)
                }

                // Preview for current drawing
                if isDrawing && !currentDrawingPoints.isEmpty {
                    PreviewDrawingLineView(
                        points: currentDrawingPoints,
                        color: selectedColor,
                        lineWidth: selectedLineWidth,
                        canvasSize: geometry.size
                    )
                }

                // Preview for current measurement
                if let start = measurementStartPoint, let end = measurementEndPoint {
                    PreviewMeasurementLineView(
                        startPoint: start,
                        endPoint: end,
                        color: selectedColor,
                        lineWidth: selectedLineWidth,
                        capLength: 0.03,
                        canvasSize: geometry.size
                    )
                }

                // Pending measurement start indicator (tap-to-place workflow)
                if let pendingStart = pendingMeasurementStart,
                   subMode == .measurement,
                   measurementStartPoint == measurementEndPoint || measurementStartPoint == nil {
                    PendingMeasurementIndicatorView(
                        position: pendingStart,
                        color: selectedColor,
                        canvasSize: geometry.size
                    )
                }

                // Gesture overlay (only when editable and not editing text)
                // This must come BEFORE selection handles so handles can receive drag events
                if isEditable && !isEditingText {
                    gestureOverlay(geometry: geometry)
                }

                // Selection handles for selected element (on top of gesture overlay)
                if let selectedElement = markupState.selectedElement, isEditable {
                    selectionHandlesView(for: selectedElement, canvasSize: geometry.size)
                }

                // Inline text editor overlay
                if isEditingText, let position = pendingTextPosition {
                    inlineTextEditor(position: position, canvasSize: geometry.size)
                }
            }
            .contentShape(Rectangle())
            // Tap gesture for selection/deselection in select mode
            .onTapGesture { location in
                guard subMode == .select, isEditable, !isEditingText else { return }
                let normalizedLocation = CGPoint(
                    x: location.x / geometry.size.width,
                    y: location.y / geometry.size.height
                )
                // Hit test to find if an element was tapped
                var tappedElement: MarkupElement? = nil
                for element in markupState.sortedElements.reversed() {
                    let rect = element.boundingRect
                    let expandedRect = rect.insetBy(dx: -0.02, dy: -0.02)
                    if expandedRect.contains(normalizedLocation) {
                        tappedElement = element
                        break
                    }
                }
                // Select tapped element, or deselect if tapping empty space
                onElementSelected?(tappedElement?.id)
            }
            .onAppear {
                canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                canvasSize = newSize
            }
            .onChange(of: isEditingText) { newValue in
                if newValue {
                    // Auto-focus the text field when editing starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
            }
            .onChange(of: subMode) { newMode in
                // Cancel pending measurement when switching modes
                if newMode != .measurement {
                    cancelPendingMeasurement()
                }
            }
        }
    }

    // MARK: - Selection Handles

    @ViewBuilder
    private func selectionHandlesView(for element: MarkupElement, canvasSize: CGSize) -> some View {
        // Shows dashed bounding box with move capability and draggable corner/endpoint handles
        // Also includes rotation handle for text boxes and freeform lines
        SelectionHandlesView(
            element: element,
            canvasSize: canvasSize,
            onDragMove: { delta in
                onElementMoved?(delta)
            },
            onDragEnd: {
                onElementMoveComplete?()
            },
            onHandleDrag: { handleType, delta in
                onHandleDrag?(handleType, delta)
            },
            onHandleDragEnd: { handleType in
                onHandleDragEnd?(handleType)
            },
            onRotationDrag: { degrees in
                onElementRotated?(degrees)
            },
            onRotationDragEnd: {
                onElementRotateComplete?()
            }
        )
    }

    // MARK: - Gesture Overlay

    @ViewBuilder
    private func gestureOverlay(geometry: GeometryProxy) -> some View {
        switch subMode {
        case .select:
            selectGestureOverlay(geometry: geometry)

        case .freeform:
            drawingGestureOverlay(geometry: geometry)

        case .measurement:
            measurementGestureOverlay(geometry: geometry)

        case .text:
            textPlacementGestureOverlay(geometry: geometry)
        }
    }

    // MARK: - Select Mode

    private func selectGestureOverlay(geometry: GeometryProxy) -> some View {
        // Tap handling is done at the ZStack level with contentShape(Rectangle())
        // This overlay is kept for consistency but doesn't need its own tap gesture
        Color.clear
            .contentShape(Rectangle())
    }

    // MARK: - Drawing Mode

    private func drawingGestureOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { location in
                // Check if tapping on an existing element - auto-select it
                let normalizedLocation = normalizePoint(location, in: geometry.size)
                if let element = hitTest(at: normalizedLocation) {
                    onElementSelected?(element.id)
                    onAutoSwitchToSelectMode?()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDrawing {
                            isDrawing = true
                            currentDrawingPoints = []
                        }

                        let normalizedPoint = normalizePoint(value.location, in: geometry.size)
                        currentDrawingPoints.append(normalizedPoint)
                    }
                    .onEnded { _ in
                        if currentDrawingPoints.count > 1 {
                            onDrawingComplete?(currentDrawingPoints)
                        }
                        isDrawing = false
                        currentDrawingPoints = []
                    }
            )
    }

    // MARK: - Measurement Mode

    private func measurementGestureOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { location in
                let normalizedLocation = normalizePoint(location, in: geometry.size)

                // Check if tapping on an existing element - auto-select it
                if let element = hitTest(at: normalizedLocation) {
                    // Cancel any pending measurement and select the element
                    cancelPendingMeasurement()
                    onElementSelected?(element.id)
                    onAutoSwitchToSelectMode?()
                    return
                }

                // Tap-to-place workflow
                if let pendingStart = pendingMeasurementStart {
                    // Second tap - complete the measurement
                    let distance = sqrt(
                        pow(normalizedLocation.x - pendingStart.x, 2) +
                        pow(normalizedLocation.y - pendingStart.y, 2)
                    )

                    // If tapped very close to start point, cancel the measurement
                    if distance < 0.015 {
                        cancelPendingMeasurement()
                        return
                    }

                    // If distance is sufficient, create the measurement
                    if distance > 0.02 {
                        onMeasurementComplete?(pendingStart, normalizedLocation)
                    }

                    // Reset pending state
                    cancelPendingMeasurement()
                } else {
                    // First tap - set the start point
                    pendingMeasurementStart = normalizedLocation
                    measurementStartPoint = normalizedLocation
                    measurementEndPoint = normalizedLocation
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Use pending start if available, otherwise use drag start
                        let startNormalized = pendingMeasurementStart ?? normalizePoint(value.startLocation, in: geometry.size)
                        let endNormalized = normalizePoint(value.location, in: geometry.size)

                        measurementStartPoint = startNormalized
                        measurementEndPoint = endNormalized
                    }
                    .onEnded { value in
                        if let start = measurementStartPoint, let end = measurementEndPoint {
                            let distance = sqrt(
                                pow(end.x - start.x, 2) +
                                pow(end.y - start.y, 2)
                            )
                            // Only commit if line is long enough
                            if distance > 0.02 {
                                onMeasurementComplete?(start, end)
                            }
                        }
                        // Reset all state including pending
                        cancelPendingMeasurement()
                    }
            )
    }

    // MARK: - Text Placement Mode

    private func textPlacementGestureOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { location in
                let normalizedLocation = normalizePoint(location, in: geometry.size)

                // Check if tapping on an existing element - auto-select it
                if let element = hitTest(at: normalizedLocation) {
                    onElementSelected?(element.id)
                    onAutoSwitchToSelectMode?()
                } else {
                    // Start inline text editing at the tapped location
                    pendingTextPosition = normalizedLocation
                    pendingTextContent = ""
                    isEditingText = true
                }
            }
    }

    // MARK: - Inline Text Editor

    private func inlineTextEditor(position: CGPoint, canvasSize: CGSize) -> some View {
        let pixelPosition = CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )

        return ZStack {
            // Clear background that dismisses on tap (no dimming for true preview)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    commitInlineText()
                }

            // The text editor positioned at the tap location - matches TextBoxView exactly
            InlineTextEditorView(
                text: $pendingTextContent,
                fontSize: selectedFontSize,
                fontColor: selectedColor,
                fillColor: selectedFillColor,
                isFocused: $isTextFieldFocused,
                onCommit: {
                    commitInlineText()
                },
                onCancel: {
                    cancelInlineText()
                }
            )
            .position(x: pixelPosition.x, y: pixelPosition.y)
        }
        .ignoresSafeArea(.keyboard)
    }

    private func commitInlineText() {
        let trimmedText = pendingTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty, let position = pendingTextPosition {
            onTextCommit?(position, trimmedText, canvasSize)
        }
        isEditingText = false
        pendingTextPosition = nil
        pendingTextContent = ""
        isTextFieldFocused = false
    }

    private func cancelInlineText() {
        isEditingText = false
        pendingTextPosition = nil
        pendingTextContent = ""
        isTextFieldFocused = false
    }

    // MARK: - Hit Testing

    /// Find element at the given normalized point (reverse zIndex order for proper hit testing)
    private func hitTest(at point: CGPoint) -> MarkupElement? {
        // Check in reverse order (top to bottom)
        for element in markupState.sortedElements.reversed() {
            let rect = element.boundingRect
            // Expand hit area slightly for easier selection
            let expandedRect = rect.insetBy(dx: -0.02, dy: -0.02)

            if expandedRect.contains(point) {
                return element
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func normalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x / size.width,
            y: point.y / size.height
        )
    }

    /// Cancels any pending tap-to-place measurement workflow
    private func cancelPendingMeasurement() {
        pendingMeasurementStart = nil
        measurementStartPoint = nil
        measurementEndPoint = nil
    }
}

// MARK: - Inline Text Editor View

/// Inline text editor that appears on the canvas for direct text entry
/// Styled to match TextBoxView exactly for true WYSIWYG preview
struct InlineTextEditorView: View {
    @Binding var text: String
    let fontSize: FontSize
    let fontColor: MarkupColor
    let fillColor: MarkupColor?
    @FocusState.Binding var isFocused: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void

    private var isTextEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Text field styled to match final TextBoxView rendering
            textField
            // Floating action buttons below the text
            actionButtons
        }
    }

    private var textField: some View {
        TextField("Type here...", text: $text, axis: .vertical)
            .font(.system(size: fontSize.pointSize, weight: .medium))
            .foregroundStyle(fontColor.color)
            .multilineTextAlignment(.center)
            .lineLimit(nil)  // No line limit - allow text to extend naturally
            .fixedSize(horizontal: false, vertical: true)  // Grow vertically as needed
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(textBackground)
            .focused($isFocused)
            .frame(minWidth: 60)  // Minimum width for tapping
            .onSubmit { onCommit() }
    }

    @ViewBuilder
    private var textBackground: some View {
        if let fill = fillColor {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs)
                .fill(fill.color.opacity(0.8))
        } else {
            // No background when no fill color - matches TextBoxView
            Color.clear
        }
    }

    private var actionButtons: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            cancelButton
            doneButton
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var doneButton: some View {
        Button(action: onCommit) {
            Text("Done")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isTextEmpty ? .white.opacity(0.4) : AppTheme.Colors.primary)
        }
        .disabled(isTextEmpty)
    }
}

// MARK: - Markup Canvas Overlay View

/// A simpler overlay version for display-only (non-editable) markup
struct MarkupCanvasOverlayView: View {
    let markupState: MarkupState

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(markupState.sortedElements) { element in
                    MarkupElementView(element: element, canvasSize: geometry.size)
                }
            }
        }
    }
}
