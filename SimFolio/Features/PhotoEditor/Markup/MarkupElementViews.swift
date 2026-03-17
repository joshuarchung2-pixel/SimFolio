// MarkupElementViews.swift
// Views for rendering individual markup elements
//
// Contains:
// - FreeformLineShape: Path from points array
// - MeasurementLineShape: Line with perpendicular caps
// - TextBoxView: Text with optional background

import SwiftUI

// MARK: - Freeform Line Shape

/// A shape that draws a freeform line from an array of points
struct FreeformLineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard points.count > 1 else {
            if let first = points.first {
                // Single point - draw a small circle
                let pointRect = CGRect(
                    x: first.x * rect.width - 2,
                    y: first.y * rect.height - 2,
                    width: 4,
                    height: 4
                )
                path.addEllipse(in: pointRect)
            }
            return path
        }

        // Convert normalized points to actual coordinates
        let scaledPoints = points.map { point in
            CGPoint(x: point.x * rect.width, y: point.y * rect.height)
        }

        path.move(to: scaledPoints[0])

        // Use quadratic curves for smooth lines
        if scaledPoints.count == 2 {
            path.addLine(to: scaledPoints[1])
        } else {
            for i in 1..<scaledPoints.count {
                let current = scaledPoints[i]
                let previous = scaledPoints[i - 1]

                // Midpoint for smooth curve
                let midPoint = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2
                )

                if i == 1 {
                    path.addLine(to: midPoint)
                } else {
                    path.addQuadCurve(to: midPoint, control: previous)
                }

                if i == scaledPoints.count - 1 {
                    path.addLine(to: current)
                }
            }
        }

        return path
    }
}

// MARK: - Freeform Line View

/// View that renders a freeform line element
struct FreeformLineView: View {
    let line: FreeformLine
    let canvasSize: CGSize

    var body: some View {
        FreeformLineShape(points: line.points.map { $0.cgPoint })
            .stroke(
                line.color.color,
                style: StrokeStyle(
                    lineWidth: line.lineWidth.pointWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Measurement Line Shape

/// A shape that draws an I-shaped measurement line
struct MeasurementLineShape: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let capLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Convert normalized points to actual coordinates
        let start = CGPoint(
            x: startPoint.x * rect.width,
            y: startPoint.y * rect.height
        )
        let end = CGPoint(
            x: endPoint.x * rect.width,
            y: endPoint.y * rect.height
        )

        // Main line
        path.move(to: start)
        path.addLine(to: end)

        // Calculate perpendicular direction for caps
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0 else { return path }

        // Perpendicular unit vector
        let perpX = -dy / length
        let perpY = dx / length

        // Cap size in actual coordinates (use average dimension for scaling)
        let capSize = capLength * min(rect.width, rect.height)

        // Start cap (I-shaped)
        let startCapTop = CGPoint(
            x: start.x + perpX * capSize,
            y: start.y + perpY * capSize
        )
        let startCapBottom = CGPoint(
            x: start.x - perpX * capSize,
            y: start.y - perpY * capSize
        )
        path.move(to: startCapTop)
        path.addLine(to: startCapBottom)

        // End cap (I-shaped)
        let endCapTop = CGPoint(
            x: end.x + perpX * capSize,
            y: end.y + perpY * capSize
        )
        let endCapBottom = CGPoint(
            x: end.x - perpX * capSize,
            y: end.y - perpY * capSize
        )
        path.move(to: endCapTop)
        path.addLine(to: endCapBottom)

        return path
    }
}

// MARK: - Measurement Line View

/// View that renders a measurement line element
struct MeasurementLineView: View {
    let line: MeasurementLine
    let canvasSize: CGSize

    var body: some View {
        MeasurementLineShape(
            startPoint: line.startPoint.cgPoint,
            endPoint: line.endPoint.cgPoint,
            capLength: line.capLength
        )
        .stroke(
            line.color.color,
            style: StrokeStyle(
                lineWidth: line.lineWidth.pointWidth,
                lineCap: .square,
                lineJoin: .miter
            )
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Text Box View

/// View that renders a text box element
struct TextBoxView: View {
    let textBox: TextBox
    let canvasSize: CGSize

    var body: some View {
        let position = CGPoint(
            x: textBox.position.x * canvasSize.width,
            y: textBox.position.y * canvasSize.height
        )

        let size = CGSize(
            width: textBox.size.width * canvasSize.width,
            height: textBox.size.height * canvasSize.height
        )

        Text(textBox.text)
            .font(.system(size: textBox.fontSize.pointSize))
            .foregroundStyle(textBox.fontColor.color)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .padding(4)
            .frame(width: max(size.width, 50), height: max(size.height, 24))
            .background(
                Group {
                    if let fillColor = textBox.fillColor {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fillColor.color)
                    }
                }
            )
            .rotationEffect(.degrees(textBox.rotation))
            .position(position)
    }
}

// MARK: - Markup Element View

/// Unified view that renders any markup element
struct MarkupElementView: View {
    let element: MarkupElement
    let canvasSize: CGSize

    var body: some View {
        switch element {
        case .freeformLine(let line):
            FreeformLineView(line: line, canvasSize: canvasSize)
        case .measurementLine(let line):
            MeasurementLineView(line: line, canvasSize: canvasSize)
        case .textBox(let box):
            TextBoxView(textBox: box, canvasSize: canvasSize)
        }
    }
}

// MARK: - Preview Drawing Line View

/// View for showing the current drawing in progress
struct PreviewDrawingLineView: View {
    let points: [CGPoint]
    let color: MarkupColor
    let lineWidth: LineWidth
    let canvasSize: CGSize

    var body: some View {
        if points.count > 0 {
            FreeformLineShape(points: points)
                .stroke(
                    color.color,
                    style: StrokeStyle(
                        lineWidth: lineWidth.pointWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }
}

// MARK: - Preview Measurement Line View

/// View for showing a measurement line in progress
struct PreviewMeasurementLineView: View {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: MarkupColor
    let lineWidth: LineWidth
    let capLength: CGFloat
    let canvasSize: CGSize

    var body: some View {
        MeasurementLineShape(
            startPoint: startPoint,
            endPoint: endPoint,
            capLength: capLength
        )
        .stroke(
            color.color,
            style: StrokeStyle(
                lineWidth: lineWidth.pointWidth,
                lineCap: .square,
                lineJoin: .miter
            )
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Pending Measurement Indicator View

/// Pulsing indicator showing where the first tap was placed for tap-to-place measurement
struct PendingMeasurementIndicatorView: View {
    let position: CGPoint
    let color: MarkupColor
    let canvasSize: CGSize

    @State private var isPulsing = false

    private let outerRingSize: CGFloat = 32
    private let innerCircleSize: CGFloat = 16
    private let centerDotSize: CGFloat = 6

    var body: some View {
        let pixelPosition = CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )

        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(color.color.opacity(isPulsing ? 0 : 0.6), lineWidth: 2)
                .frame(width: outerRingSize * (isPulsing ? 1.5 : 1.0),
                       height: outerRingSize * (isPulsing ? 1.5 : 1.0))

            // Inner solid circle
            Circle()
                .fill(color.color.opacity(0.3))
                .frame(width: innerCircleSize, height: innerCircleSize)

            Circle()
                .stroke(color.color, lineWidth: 2)
                .frame(width: innerCircleSize, height: innerCircleSize)

            // Center white dot for precise positioning
            Circle()
                .fill(Color.white)
                .frame(width: centerDotSize, height: centerDotSize)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .position(pixelPosition)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}
