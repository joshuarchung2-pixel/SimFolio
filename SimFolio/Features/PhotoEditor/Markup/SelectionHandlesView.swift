// SelectionHandlesView.swift
// Selection UI for markup elements
//
// Shows a dashed bounding box around the selected element with draggable handles.
// Corner handles for text boxes and freeform lines allow resizing.
// Endpoint handles for measurement lines allow repositioning endpoints.

import SwiftUI

// MARK: - Draggable Handle View

/// A single draggable handle dot for resizing or repositioning elements
struct DraggableHandle: View {
    let position: CGPoint
    let handleType: HandleType
    var onDrag: ((HandleType, CGSize) -> Void)?
    var onDragEnd: ((HandleType) -> Void)?

    private let handleSize: CGFloat = 14
    private let hitAreaSize: CGFloat = 44  // Apple's recommended minimum touch target
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        ZStack {
            // Invisible hit area for easier touch targeting
            Circle()
                .fill(Color.clear)
                .frame(width: hitAreaSize, height: hitAreaSize)

            // Visual handle
            Circle()
                .fill(Color.white)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.primary, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .contentShape(Circle())
        .position(position)
        .highPriorityGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let incrementalDelta = CGSize(
                        width: value.translation.width - lastDragTranslation.width,
                        height: value.translation.height - lastDragTranslation.height
                    )
                    lastDragTranslation = value.translation
                    onDrag?(handleType, incrementalDelta)
                }
                .onEnded { _ in
                    lastDragTranslation = .zero
                    onDragEnd?(handleType)
                }
        )
    }
}

// MARK: - Rotation Draggable Handle

/// A handle for rotating elements by dragging around the element center
struct RotationDraggableHandle: View {
    let position: CGPoint
    let elementCenter: CGPoint
    let handleSize: CGFloat
    var onRotation: ((Double) -> Void)?
    var onRotationEnd: (() -> Void)?

    private let hitAreaSize: CGFloat = 44  // Apple's recommended minimum touch target
    @State private var lastAngle: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Invisible hit area for easier touch targeting
            Circle()
                .fill(Color.clear)
                .frame(width: hitAreaSize, height: hitAreaSize)

            // Visual handle
            Circle()
                .fill(Color.white)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    // Rotation icon
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: handleSize * 0.5, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.primary)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .contentShape(Circle())
        .position(position)
        .highPriorityGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    // Calculate angle from element center to current drag position
                    let currentPosition = value.location
                    let currentAngle = atan2(
                        currentPosition.y - elementCenter.y,
                        currentPosition.x - elementCenter.x
                    ) * 180 / .pi

                    if !isDragging {
                        // First drag event - store initial angle
                        isDragging = true
                        lastAngle = currentAngle
                    } else {
                        // Calculate angle delta
                        var deltaAngle = currentAngle - lastAngle

                        // Handle angle wrap-around (e.g., 179 to -179)
                        if deltaAngle > 180 {
                            deltaAngle -= 360
                        } else if deltaAngle < -180 {
                            deltaAngle += 360
                        }

                        lastAngle = currentAngle
                        onRotation?(deltaAngle)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    lastAngle = 0
                    onRotationEnd?()
                }
        )
    }
}

// MARK: - Selection Handles View

/// View that renders a selection box around a selected element with draggable handles
/// Move is handled via single-finger drag on the element
/// Resize is handled via corner handles (one-finger drag with unlocked aspect ratio)
/// Rotation is handled via a rotation handle (stick extending from bottom center)
struct SelectionHandlesView: View {
    let element: MarkupElement
    let canvasSize: CGSize

    // Callbacks for move interactions
    var onDragMove: ((CGSize) -> Void)?
    var onDragEnd: (() -> Void)?

    // Callbacks for handle interactions
    var onHandleDrag: ((HandleType, CGSize) -> Void)?
    var onHandleDragEnd: ((HandleType) -> Void)?

    // Callback for rotation
    var onRotationDrag: ((Double) -> Void)?
    var onRotationDragEnd: (() -> Void)?

    // Drag state - track last translation for incremental movement
    @State private var lastDragTranslation: CGSize = .zero

    // Rotation stick length
    private let rotationStickLength: CGFloat = 40
    private let rotationHandleSize: CGFloat = 20

    var body: some View {
        let rect = boundingRectInCanvas
        let rotation = elementRotationDegrees
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)

        ZStack {
            // Dashed bounding box
            Rectangle()
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [5, 3]
                    )
                )
                .foregroundStyle(.white)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

            // Move gesture overlay (covers the whole bounding box)
            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // Calculate incremental delta (difference from last translation)
                            let incrementalDelta = CGSize(
                                width: (value.translation.width - lastDragTranslation.width) / canvasSize.width,
                                height: (value.translation.height - lastDragTranslation.height) / canvasSize.height
                            )
                            lastDragTranslation = value.translation
                            onDragMove?(incrementalDelta)
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                            onDragEnd?()
                        }
                )

            // Draggable handles based on element type
            handleViews(for: rect)

            // Rotation handle (stick with circular handle at bottom)
            rotationHandle(for: rect)
        }
        .rotationEffect(
            Angle(degrees: rotation),
            anchor: UnitPoint(
                x: centerPoint.x / canvasSize.width,
                y: centerPoint.y / canvasSize.height
            )
        )
    }

    // MARK: - Element Rotation

    /// Get the current rotation of the element in degrees
    /// Note: Only TextBox tracks rotation as a property. FreeformLine rotation is baked into points.
    private var elementRotationDegrees: Double {
        switch element {
        case .textBox(let box):
            return box.rotation
        case .freeformLine:
            // Freeform lines don't track rotation - it's baked into the points
            return 0
        case .measurementLine:
            return 0
        }
    }

    // MARK: - Handle Views

    @ViewBuilder
    private func handleViews(for rect: CGRect) -> some View {
        switch element {
        case .textBox, .freeformLine:
            // Corner handles for resizing
            cornerHandles(for: rect)

        case .measurementLine(let line):
            // Endpoint handles for measurement lines
            endpointHandles(for: line)
        }
    }

    private func cornerHandles(for rect: CGRect) -> some View {
        Group {
            // Top-left
            DraggableHandle(
                position: CGPoint(x: rect.minX, y: rect.minY),
                handleType: .topLeft,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )

            // Top-right
            DraggableHandle(
                position: CGPoint(x: rect.maxX, y: rect.minY),
                handleType: .topRight,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )

            // Bottom-left
            DraggableHandle(
                position: CGPoint(x: rect.minX, y: rect.maxY),
                handleType: .bottomLeft,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )

            // Bottom-right
            DraggableHandle(
                position: CGPoint(x: rect.maxX, y: rect.maxY),
                handleType: .bottomRight,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )
        }
    }

    // MARK: - Rotation Handle

    @ViewBuilder
    private func rotationHandle(for rect: CGRect) -> some View {
        let centerX = rect.midX
        let bottomY = rect.maxY
        let handleY = bottomY + rotationStickLength

        // Only show rotation handle for text boxes and freeform lines
        switch element {
        case .textBox, .freeformLine:
            ZStack {
                // Rotation stick (line from bottom center to handle)
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: bottomY))
                    path.addLine(to: CGPoint(x: centerX, y: handleY))
                }
                .stroke(Color.white, lineWidth: 2)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Rotation handle (circular with rotation icon)
                RotationDraggableHandle(
                    position: CGPoint(x: centerX, y: handleY),
                    elementCenter: CGPoint(x: rect.midX, y: rect.midY),
                    handleSize: rotationHandleSize,
                    onRotation: { degrees in
                        onRotationDrag?(degrees)
                    },
                    onRotationEnd: {
                        onRotationDragEnd?()
                    }
                )
            }

        case .measurementLine:
            EmptyView()
        }
    }

    private func endpointHandles(for line: MeasurementLine) -> some View {
        let startPixel = CGPoint(
            x: line.startPoint.x * Double(canvasSize.width),
            y: line.startPoint.y * Double(canvasSize.height)
        )
        let endPixel = CGPoint(
            x: line.endPoint.x * Double(canvasSize.width),
            y: line.endPoint.y * Double(canvasSize.height)
        )

        return Group {
            DraggableHandle(
                position: startPixel,
                handleType: .startPoint,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )

            DraggableHandle(
                position: endPixel,
                handleType: .endPoint,
                onDrag: handleDrag,
                onDragEnd: handleDragEnd
            )
        }
    }

    // MARK: - Handle Callbacks

    private func handleDrag(handleType: HandleType, delta: CGSize) {
        // Convert pixel delta to normalized delta
        let normalizedDelta = CGSize(
            width: delta.width / canvasSize.width,
            height: delta.height / canvasSize.height
        )
        onHandleDrag?(handleType, normalizedDelta)
    }

    private func handleDragEnd(handleType: HandleType) {
        onHandleDragEnd?(handleType)
    }

    // MARK: - Computed Properties

    private var boundingRectInCanvas: CGRect {
        let normalizedRect = element.boundingRect

        // Add some padding
        let padding: CGFloat = 8

        return CGRect(
            x: normalizedRect.origin.x * canvasSize.width - padding,
            y: normalizedRect.origin.y * canvasSize.height - padding,
            width: normalizedRect.width * canvasSize.width + padding * 2,
            height: normalizedRect.height * canvasSize.height + padding * 2
        )
    }
}

// MARK: - Simple Selection Box View

/// A simpler selection view for elements that don't support resize/rotate
struct SimpleSelectionBoxView: View {
    let element: MarkupElement
    let canvasSize: CGSize

    var onDragMove: ((CGSize) -> Void)?
    var onDragEnd: (() -> Void)?

    // Drag state - track last translation for incremental movement
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        let rect = boundingRectInCanvas

        ZStack {
            // Dashed bounding box
            Rectangle()
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [5, 3]
                    )
                )
                .foregroundStyle(.white)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

            // Move gesture overlay
            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // Calculate incremental delta (difference from last translation)
                            let incrementalDelta = CGSize(
                                width: (value.translation.width - lastDragTranslation.width) / canvasSize.width,
                                height: (value.translation.height - lastDragTranslation.height) / canvasSize.height
                            )
                            lastDragTranslation = value.translation
                            onDragMove?(incrementalDelta)
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                            onDragEnd?()
                        }
                )
        }
    }

    private var boundingRectInCanvas: CGRect {
        let normalizedRect = element.boundingRect
        let padding: CGFloat = 8

        return CGRect(
            x: normalizedRect.origin.x * canvasSize.width - padding,
            y: normalizedRect.origin.y * canvasSize.height - padding,
            width: normalizedRect.width * canvasSize.width + padding * 2,
            height: normalizedRect.height * canvasSize.height + padding * 2
        )
    }
}
