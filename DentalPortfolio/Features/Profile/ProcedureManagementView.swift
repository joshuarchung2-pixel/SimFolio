// ProcedureManagementView.swift
// Dental Portfolio - Procedure Management
//
// This view allows users to manage their procedure list including
// reordering, customizing colors, adding custom procedures, and toggling visibility.
//
// Features:
// - View enabled/disabled procedures in separate sections
// - Reorder procedures via drag and drop
// - Add custom procedures with color selection
// - Edit procedure names and colors
// - Toggle procedure visibility
// - Delete custom procedures (defaults can only be disabled)
// - Reset to default procedures
//
// Contents:
// - ProcedureManagementView: Main procedure management screen
// - ProcedureRow: Individual procedure row with toggle and edit
// - ProcedureEditorSheet: Add/edit procedure form
// - ColorOption: Color selection circle

import SwiftUI

// MARK: - ProcedureManagementView

/// Main view for managing procedure configurations
struct ProcedureManagementView: View {
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - State

    @State private var editMode: EditMode = .inactive
    @State private var showAddProcedure: Bool = false
    @State private var showResetConfirmation: Bool = false
    @State private var editingProcedure: ProcedureConfig? = nil

    // MARK: - Computed Properties

    var enabledProcedures: [ProcedureConfig] {
        metadataManager.procedureConfigs
            .filter { $0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var disabledProcedures: [ProcedureConfig] {
        metadataManager.procedureConfigs
            .filter { !$0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var enabledCount: Int {
        enabledProcedures.count
    }

    var totalCount: Int {
        metadataManager.procedureConfigs.count
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info header
                infoHeader

                // Procedure list
                List {
                    // Enabled procedures section
                    Section {
                        ForEach(enabledProcedures) { procedure in
                            ProcedureRow(
                                procedure: procedure,
                                photoCount: getPhotoCount(for: procedure.name),
                                onToggle: { toggleProcedure(procedure) },
                                onEdit: { editingProcedure = procedure },
                                editMode: editMode
                            )
                        }
                        .onMove(perform: moveProcedures)
                        .onDelete(perform: deleteEnabledProcedures)
                    } header: {
                        Text("ENABLED (\(enabledCount))")
                    } footer: {
                        Text("Drag to reorder. Enabled procedures appear in capture and tagging.")
                    }

                    // Disabled procedures section
                    if !disabledProcedures.isEmpty {
                        Section {
                            ForEach(disabledProcedures) { procedure in
                                ProcedureRow(
                                    procedure: procedure,
                                    photoCount: getPhotoCount(for: procedure.name),
                                    onToggle: { toggleProcedure(procedure) },
                                    onEdit: { editingProcedure = procedure },
                                    editMode: editMode
                                )
                            }
                            .onDelete(perform: deleteDisabledProcedures)
                        } header: {
                            Text("DISABLED")
                        } footer: {
                            Text("Disabled procedures won't appear in capture but existing photos keep their tags.")
                        }
                    }

                    // Add custom procedure
                    Section {
                        Button(action: { showAddProcedure = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text("Add Custom Procedure")
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }

                    // Reset section
                    Section {
                        Button(action: { showResetConfirmation = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(AppTheme.Colors.error)
                                Text("Reset to Defaults")
                                    .foregroundColor(AppTheme.Colors.error)
                            }
                        }
                    } footer: {
                        Text("This will restore the default procedure list and colors.")
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.editMode, $editMode)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Procedures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddProcedure) {
                ProcedureEditorSheet(
                    isPresented: $showAddProcedure,
                    procedure: nil,
                    onSave: { procedure in
                        metadataManager.addProcedure(procedure)
                    }
                )
            }
            .sheet(item: $editingProcedure) { procedure in
                ProcedureEditorSheet(
                    isPresented: Binding(
                        get: { editingProcedure != nil },
                        set: { if !$0 { editingProcedure = nil } }
                    ),
                    procedure: procedure,
                    onSave: { updatedProcedure in
                        metadataManager.updateProcedure(updatedProcedure)
                    }
                )
            }
            .alert("Reset to Defaults?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    metadataManager.resetToDefaults()
                    HapticsManager.shared.success()
                }
            } message: {
                Text("This will replace your custom procedures with the default list. Your photos will keep their existing tags.")
            }
        }
        .onAppear {
            metadataManager.loadProcedures()
        }
    }

    // MARK: - Info Header

    var infoHeader: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "info.circle")
                .foregroundColor(AppTheme.Colors.primary)

            Text("Customize which procedures appear when tagging photos. Tap Edit to reorder or delete.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.primary.opacity(0.08))
    }

    // MARK: - Helper Functions

    func getPhotoCount(for procedureName: String) -> Int {
        metadataManager.assetMetadata.values.filter { $0.procedure == procedureName }.count
    }

    func toggleProcedure(_ procedure: ProcedureConfig) {
        var updated = procedure
        updated.isEnabled.toggle()
        metadataManager.updateProcedure(updated)
        HapticsManager.shared.selectionChanged()
    }

    func moveProcedures(from source: IndexSet, to destination: Int) {
        // Get only enabled procedures for reordering
        var enabled = enabledProcedures

        enabled.move(fromOffsets: source, toOffset: destination)

        // Update sort orders for enabled procedures
        for (index, procedure) in enabled.enumerated() {
            if let mainIndex = metadataManager.procedureConfigs.firstIndex(where: { $0.id == procedure.id }) {
                metadataManager.procedureConfigs[mainIndex].sortOrder = index
            }
        }

        metadataManager.saveProcedures()
        HapticsManager.shared.selectionChanged()
    }

    func deleteEnabledProcedures(at offsets: IndexSet) {
        let enabled = enabledProcedures
        for index in offsets {
            let procedure = enabled[index]
            if !procedure.isDefault {
                metadataManager.deleteProcedure(procedure.id)
            }
        }
        HapticsManager.shared.lightTap()
    }

    func deleteDisabledProcedures(at offsets: IndexSet) {
        let disabled = disabledProcedures
        for index in offsets {
            let procedure = disabled[index]
            if !procedure.isDefault {
                metadataManager.deleteProcedure(procedure.id)
            }
        }
        HapticsManager.shared.lightTap()
    }
}

// MARK: - ProcedureRow

/// Row displaying a single procedure with toggle and edit options
struct ProcedureRow: View {
    let procedure: ProcedureConfig
    let photoCount: Int
    let onToggle: () -> Void
    let onEdit: () -> Void
    let editMode: EditMode

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Color indicator
            Circle()
                .fill(procedure.color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: procedure.color.opacity(0.4), radius: 2, x: 0, y: 1)

            // Procedure info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(procedure.name)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(procedure.isEnabled ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)

                    if procedure.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.surfaceSecondary)
                            .cornerRadius(4)
                    }
                }

                if photoCount > 0 {
                    Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            // Edit button (when not in edit mode)
            if editMode == .inactive {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Toggle
            Toggle("", isOn: Binding(
                get: { procedure.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(AppTheme.Colors.primary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .opacity(procedure.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - ProcedureEditorSheet

/// Sheet for adding or editing a procedure
struct ProcedureEditorSheet: View {
    @Binding var isPresented: Bool
    let procedure: ProcedureConfig?
    let onSave: (ProcedureConfig) -> Void

    // MARK: - State

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var showDeleteConfirmation: Bool = false

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Predefined Colors

    let colorOptions: [String] = [
        "#3B82F6", // Blue
        "#10B981", // Green
        "#8B5CF6", // Purple
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#EC4899", // Pink
        "#06B6D4", // Cyan
        "#84CC16", // Lime
        "#F97316", // Orange
        "#6366F1", // Indigo
        "#14B8A6", // Teal
        "#DC2626", // Red Dark
        "#7C3AED", // Violet
        "#059669", // Emerald
        "#D97706", // Yellow Dark
        "#BE185D"  // Pink Dark
    ]

    var isEditing: Bool {
        procedure != nil
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isDuplicate: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return metadataManager.procedureConfigs.contains {
            $0.name.lowercased() == trimmedName && $0.id != procedure?.id
        }
    }

    var canDelete: Bool {
        guard let procedure = procedure else { return false }
        return !procedure.isDefault
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Preview
                    previewSection

                    // Name field
                    nameSection

                    // Color picker
                    colorPickerSection

                    // Delete button (for existing custom procedures)
                    if isEditing && canDelete {
                        deleteSection
                    }

                    Spacer(minLength: 50)
                }
                .padding(.top, AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Procedure" : "New Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProcedure()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isDuplicate)
                }
            }
            .alert("Delete Procedure?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProcedure()
                }
            } message: {
                Text("This procedure will be removed. Photos with this tag will keep the tag name but won't match any procedure.")
            }
            .onAppear {
                loadProcedure()
            }
        }
    }

    // MARK: - Preview Section

    var previewSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Large preview
            HStack(spacing: AppTheme.Spacing.md) {
                Circle()
                    .fill(Color(hex: selectedColorHex))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: Color(hex: selectedColorHex).opacity(0.4), radius: 4, x: 0, y: 2)

                Text(name.isEmpty ? "Procedure Name" : name)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(name.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
            }

            // Tag preview
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Preview:")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                DPTagPill(
                    name.isEmpty ? "Procedure" : name,
                    color: Color(hex: selectedColorHex)
                )
            }
        }
        .padding(.vertical, AppTheme.Spacing.lg)
    }

    // MARK: - Name Section

    var nameSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("PROCEDURE NAME")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            TextField("Enter procedure name", text: $name)
                .font(AppTheme.Typography.body)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .padding(.horizontal, AppTheme.Spacing.md)

            if isDuplicate {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.Colors.warning)
                    Text("A procedure with this name already exists")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.warning)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }

    // MARK: - Color Picker Section

    var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("COLOR")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppTheme.Spacing.sm) {
                ForEach(colorOptions, id: \.self) { colorHex in
                    ColorOption(
                        colorHex: colorHex,
                        isSelected: selectedColorHex == colorHex,
                        onSelect: {
                            selectedColorHex = colorHex
                            HapticsManager.shared.selectionChanged()
                        }
                    )
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Delete Section

    var deleteSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Divider()
                .padding(.horizontal, AppTheme.Spacing.md)

            Button(action: { showDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Procedure")
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.error.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            Text("Default procedures cannot be deleted, only disabled.")
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textTertiary)
                .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Actions

    func loadProcedure() {
        guard let procedure = procedure else { return }
        name = procedure.name
        selectedColorHex = procedure.colorHex
    }

    func saveProcedure() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingProcedure = procedure {
            // Update existing
            var updated = existingProcedure
            updated.name = trimmedName
            updated.colorHex = selectedColorHex
            onSave(updated)
        } else {
            // Create new
            let newProcedure = ProcedureConfig(
                name: trimmedName,
                colorHex: selectedColorHex,
                isDefault: false,
                isEnabled: true
            )
            onSave(newProcedure)
        }

        HapticsManager.shared.success()
        isPresented = false
    }

    func deleteProcedure() {
        guard let procedure = procedure else { return }
        metadataManager.deleteProcedure(procedure.id)
        HapticsManager.shared.success()
        isPresented = false
    }
}

// MARK: - ColorOption

/// Color selection circle with checkmark when selected
struct ColorOption: View {
    let colorHex: String
    let isSelected: Bool
    let onSelect: () -> Void

    var color: Color {
        Color(hex: colorHex)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 42, height: 42)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ProcedureManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ProcedureManagementView(isPresented: .constant(true))
    }
}

struct ProcedureEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        ProcedureEditorSheet(
            isPresented: .constant(true),
            procedure: nil,
            onSave: { _ in }
        )
    }
}

struct ProcedureRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ProcedureRow(
                procedure: ProcedureConfig(
                    name: "Class 1",
                    colorHex: "#3B82F6",
                    isDefault: true,
                    isEnabled: true
                ),
                photoCount: 12,
                onToggle: { },
                onEdit: { },
                editMode: .inactive
            )

            ProcedureRow(
                procedure: ProcedureConfig(
                    name: "Custom Procedure",
                    colorHex: "#EC4899",
                    isDefault: false,
                    isEnabled: false
                ),
                photoCount: 0,
                onToggle: { },
                onEdit: { },
                editMode: .inactive
            )
        }
        .padding()
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}

struct ColorOption_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ColorOption(colorHex: "#3B82F6", isSelected: true, onSelect: { })
            ColorOption(colorHex: "#10B981", isSelected: false, onSelect: { })
            ColorOption(colorHex: "#EF4444", isSelected: false, onSelect: { })
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .previewLayout(.sizeThatFits)
    }
}
#endif
