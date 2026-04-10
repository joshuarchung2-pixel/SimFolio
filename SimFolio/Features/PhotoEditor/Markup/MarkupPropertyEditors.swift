// MarkupPropertyEditors.swift
// Property editors for markup customization
//
// Contains:
// - ColorPickerView: 8 preset color selection
// - LineWidthPickerView: 5 line width options
// - FontSizePickerView: 4 font size options
// - FillColorPickerView: Fill color with none option

import SwiftUI

// MARK: - Color Picker View

/// Horizontal row of 8 preset colors for markup
struct MarkupColorPickerView: View {
    @Binding var selectedColor: MarkupColor
    var onColorSelected: ((MarkupColor) -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(MarkupColor.presets, id: \.self) { color in
                ColorSwatchView(
                    color: color,
                    isSelected: selectedColor == color
                )
                .onTapGesture {
                    selectedColor = color
                    onColorSelected?(color)
                }
            }
        }
    }
}

// MARK: - Color Swatch View

/// Individual color swatch in the picker
struct ColorSwatchView: View {
    let color: MarkupColor
    let isSelected: Bool

    private let swatchSize: CGFloat = 32

    var body: some View {
        ZStack {
            // Checkerboard background for transparency indication
            if color.alpha < 1.0 {
                CheckerboardPattern()
                    .frame(width: swatchSize, height: swatchSize)
                    .clipShape(Circle())
            }

            // Color circle
            Circle()
                .fill(color.color)
                .frame(width: swatchSize, height: swatchSize)

            // Border for light colors
            if isLightColor {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: swatchSize, height: swatchSize)
            }

            // Selection indicator
            if isSelected {
                Circle()
                    .stroke(AppTheme.Colors.primary, lineWidth: 3)
                    .frame(width: swatchSize + 6, height: swatchSize + 6)
            }
        }
        .frame(width: swatchSize + 8, height: swatchSize + 8)
    }

    private var isLightColor: Bool {
        // Check if color is light (high luminance)
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.8
    }
}

// MARK: - Checkerboard Pattern

/// Pattern for showing transparency
struct CheckerboardPattern: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let tileSize: CGFloat = 4

            Canvas { context, _ in
                for row in 0..<Int(ceil(size.height / tileSize)) {
                    for col in 0..<Int(ceil(size.width / tileSize)) {
                        let isLight = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isLight ? .white : .gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Line Width Picker View

/// Picker for 5 line width options
struct LineWidthPickerView: View {
    @Binding var selectedWidth: LineWidth
    var onWidthSelected: ((LineWidth) -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ForEach(LineWidth.allCases) { width in
                LineWidthOptionView(
                    width: width,
                    isSelected: selectedWidth == width
                )
                .onTapGesture {
                    selectedWidth = width
                    onWidthSelected?(width)
                }
            }
        }
    }
}

// MARK: - Line Width Option View

/// Individual line width option
struct LineWidthOptionView: View {
    let width: LineWidth
    let isSelected: Bool

    private let optionSize: CGFloat = 44

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.2) : Color.white.opacity(0.1))
                .frame(width: optionSize, height: optionSize)

            // Line preview
            RoundedRectangle(cornerRadius: width.pointWidth / 2)
                .fill(isSelected ? AppTheme.Colors.primary : .white)
                .frame(width: optionSize - 16, height: width.pointWidth)

            // Selection border
            if isSelected {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(AppTheme.Colors.primary, lineWidth: 2)
                    .frame(width: optionSize, height: optionSize)
            }
        }
    }
}

// MARK: - Font Size Picker View

/// Picker for 4 font size options
struct FontSizePickerView: View {
    @Binding var selectedSize: FontSize
    var onSizeSelected: ((FontSize) -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(FontSize.allCases) { size in
                FontSizeOptionView(
                    size: size,
                    isSelected: selectedSize == size
                )
                .onTapGesture {
                    selectedSize = size
                    onSizeSelected?(size)
                }
            }
        }
    }
}

// MARK: - Font Size Option View

/// Individual font size option
struct FontSizeOptionView: View {
    let size: FontSize
    let isSelected: Bool

    var body: some View {
        Text("Aa")
            .font(.system(size: size.pointSize * 0.8))
            .foregroundStyle(isSelected ? .white : .gray)
            .frame(width: 50, height: 40)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
            )
    }
}

// MARK: - Fill Color Picker View

/// Picker for fill color with "None" option
struct FillColorPickerView: View {
    @Binding var selectedFillColor: MarkupColor?
    var onFillColorSelected: ((MarkupColor?) -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // None option
            NoneColorOptionView(isSelected: selectedFillColor == nil)
                .onTapGesture {
                    selectedFillColor = nil
                    onFillColorSelected?(nil)
                }

            // Color options
            ForEach(MarkupColor.presets, id: \.self) { color in
                ColorSwatchView(
                    color: color,
                    isSelected: selectedFillColor == color
                )
                .onTapGesture {
                    selectedFillColor = color
                    onFillColorSelected?(color)
                }
            }
        }
    }
}

// MARK: - None Color Option View

/// Option for "no fill"
struct NoneColorOptionView: View {
    let isSelected: Bool

    private let swatchSize: CGFloat = 32

    var body: some View {
        ZStack {
            // Strikethrough circle
            Circle()
                .stroke(Color.gray, lineWidth: 1)
                .frame(width: swatchSize, height: swatchSize)

            // Diagonal line
            Path { path in
                path.move(to: CGPoint(x: swatchSize * 0.2, y: swatchSize * 0.8))
                path.addLine(to: CGPoint(x: swatchSize * 0.8, y: swatchSize * 0.2))
            }
            .stroke(Color.gray, lineWidth: 1)
            .frame(width: swatchSize, height: swatchSize)

            // Selection indicator
            if isSelected {
                Circle()
                    .stroke(AppTheme.Colors.primary, lineWidth: 3)
                    .frame(width: swatchSize + 6, height: swatchSize + 6)
            }
        }
        .frame(width: swatchSize + 8, height: swatchSize + 8)
    }
}

// MARK: - Property Editor Section View

/// Section wrapper for property editors with label
struct PropertyEditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "8E8E93"))

            content()
        }
    }
}
