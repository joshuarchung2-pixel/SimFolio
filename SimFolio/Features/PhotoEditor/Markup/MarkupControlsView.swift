// MarkupControlsView.swift
// Toolbar controls for markup mode
//
// Contains:
// - Sub-mode picker (Select, Draw, Measure, Text)
// - Property editors for current mode
// - Action buttons (Delete, Bring Front, Send Back)

import SwiftUI

// MARK: - Markup Controls View

/// Main controls view for markup mode
struct MarkupControlsView: View {
    @Binding var subMode: MarkupSubMode
    @Binding var selectedColor: MarkupColor
    @Binding var selectedLineWidth: LineWidth
    @Binding var selectedFontSize: FontSize
    @Binding var selectedFillColor: MarkupColor?

    let hasSelection: Bool
    let selectedElementType: MarkupElementType?
    let isMarkupEmpty: Bool

    // Undo state
    var canUndo: Bool = false

    // Action callbacks
    var onUndo: (() -> Void)?
    var onDelete: (() -> Void)?
    var onBringToFront: (() -> Void)?
    var onSendToBack: (() -> Void)?
    var onColorChanged: ((MarkupColor) -> Void)?
    var onLineWidthChanged: ((LineWidth) -> Void)?
    var onFontSizeChanged: ((FontSize) -> Void)?
    var onFillColorChanged: ((MarkupColor?) -> Void)?
    var onClearAll: (() -> Void)?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            // Sub-mode picker with undo button - no top padding to stay close to mode picker
            subModePicker

            // Property editors container with action buttons overlay
            ZStack(alignment: .bottom) {
                // Scrollable property editors - fills remaining space
                ScrollView(.vertical, showsIndicators: false) {
                    propertyEditors
                        .padding(.bottom, hasSelection ? 60 : AppTheme.Spacing.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: -2)

                // Action buttons overlay when element is selected
                if hasSelection {
                    actionButtons
                        .padding(.bottom, AppTheme.Spacing.sm)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Sub-Mode Picker

    private var subModePicker: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Undo button
            Button(action: {
                onUndo?()
            }) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                    Text("Undo")
                        .font(AppTheme.Typography.caption2)
                }
                .foregroundStyle(canUndo ? .white : .gray.opacity(0.4))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .disabled(!canUndo)

            Spacer()

            // Sub-mode buttons
            ForEach(MarkupSubMode.allCases) { mode in
                SubModeButton(
                    mode: mode,
                    isSelected: subMode == mode
                ) {
                    subMode = mode
                }
            }
        }
    }

    // MARK: - Property Editors

    @ViewBuilder
    private var propertyEditors: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                // Mode-specific controls
                switch subMode {
                case .select:
                    // Only show property editors when an element is selected
                    if hasSelection {
                        PropertyEditorSection(title: "Color") {
                            MarkupColorPickerView(
                                selectedColor: $selectedColor,
                                onColorSelected: { color in
                                    onColorChanged?(color)
                                }
                            )
                        }
                        selectedElementPropertyEditors
                    }

                case .freeform, .measurement:
                    PropertyEditorSection(title: "Color") {
                        MarkupColorPickerView(
                            selectedColor: $selectedColor,
                            onColorSelected: { color in
                                onColorChanged?(color)
                            }
                        )
                    }
                    PropertyEditorSection(title: "Line Width") {
                        LineWidthPickerView(
                            selectedWidth: $selectedLineWidth,
                            onWidthSelected: { width in
                                onLineWidthChanged?(width)
                            }
                        )
                    }

                case .text:
                    PropertyEditorSection(title: "Color") {
                        MarkupColorPickerView(
                            selectedColor: $selectedColor,
                            onColorSelected: { color in
                                onColorChanged?(color)
                            }
                        )
                    }
                    PropertyEditorSection(title: "Font Size") {
                        FontSizePickerView(
                            selectedSize: $selectedFontSize,
                            onSizeSelected: { size in
                                onFontSizeChanged?(size)
                            }
                        )
                    }

                    PropertyEditorSection(title: "Fill Color") {
                        FillColorPickerView(
                            selectedFillColor: $selectedFillColor,
                            onFillColorSelected: { color in
                                onFillColorChanged?(color)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xs)
        }
    }

    // MARK: - Selected Element Property Editors

    @ViewBuilder
    private var selectedElementPropertyEditors: some View {
        switch selectedElementType {
        case .freeformLine, .measurementLine:
            PropertyEditorSection(title: "Line Width") {
                LineWidthPickerView(
                    selectedWidth: $selectedLineWidth,
                    onWidthSelected: { width in
                        onLineWidthChanged?(width)
                    }
                )
            }

        case .textBox:
            PropertyEditorSection(title: "Font Size") {
                FontSizePickerView(
                    selectedSize: $selectedFontSize,
                    onSizeSelected: { size in
                        onFontSizeChanged?(size)
                    }
                )
            }

            PropertyEditorSection(title: "Fill Color") {
                FillColorPickerView(
                    selectedFillColor: $selectedFillColor,
                    onFillColorSelected: { color in
                        onFillColorChanged?(color)
                    }
                )
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Delete button
            ActionButton(
                title: "Delete",
                icon: "trash",
                style: .destructive
            ) {
                onDelete?()
            }

            // Bring to front
            ActionButton(
                title: "Front",
                icon: "square.3.layers.3d.top.filled",
                style: .secondary
            ) {
                onBringToFront?()
            }

            // Send to back
            ActionButton(
                title: "Back",
                icon: "square.3.layers.3d.bottom.filled",
                style: .secondary
            ) {
                onSendToBack?()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(Color(uiColor: .systemGray5))
        )
    }
}

// MARK: - Markup Element Type

/// Simple enum to identify element type for property editors
enum MarkupElementType {
    case freeformLine
    case measurementLine
    case textBox
}

// MARK: - Sub-Mode Button

/// Button for selecting a sub-mode
struct SubModeButton: View {
    let mode: MarkupSubMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18))
                Text(mode.rawValue)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(isSelected ? AppTheme.Colors.primary : Color(hex: "C7C7CC"))
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Action Button

/// Styled action button for markup actions
struct ActionButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return AppTheme.Colors.primary
        case .secondary:
            return Color(hex: "C7C7CC")
        case .destructive:
            return AppTheme.Colors.error
        }
    }
}

// MARK: - Text Input Sheet View

/// Sheet for entering text when placing a text box
struct TextInputSheetView: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.md) {
                TextField("Enter text", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
            }
            .padding(.top, AppTheme.Spacing.md)
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onConfirm(text)
                        }
                        isPresented = false
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Markup Empty State View

/// Context-aware empty state for Select sub-mode when nothing is selected.
/// Shows different copy depending on whether the photo has any markup elements.
struct MarkupEmptyStateView: View {
    let isMarkupEmpty: Bool

    private var iconName: String {
        isMarkupEmpty ? "scribble.variable" : "hand.point.up"
    }

    private var title: String {
        isMarkupEmpty ? "No marks yet" : "Nothing selected"
    }

    private var hint: String {
        isMarkupEmpty
            ? "Switch to Draw, Measure, or Text to annotate your photo."
            : "Tap a mark on the photo to edit its color or size."
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "48484A"))
                .accessibilityHidden(true)

            Text(title)
                .font(AppTheme.Typography.sectionLabel)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "8E8E93"))

            Text(hint)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
    }
}
