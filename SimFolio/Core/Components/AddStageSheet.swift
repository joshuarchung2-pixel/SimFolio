// AddStageSheet.swift
// SimFolio
//
// Reusable sheet for adding custom stages to the stage list.
// Provides validation and consistent UX across the app.

import SwiftUI

// MARK: - Add Stage Sheet

/// Sheet for adding a new custom stage
/// Provides text input with validation for unique stage names
struct AddStageSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var metadataManager = MetadataManager.shared

    /// Callback when a stage is successfully added
    var onStageAdded: ((StageConfig) -> Void)?

    @State private var stageName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    /// Validation error message (if any)
    private var validationError: String? {
        let trimmed = stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil  // Don't show error for empty field
        }
        if metadataManager.stageExists(name: trimmed) {
            return "A stage with this name already exists"
        }
        if trimmed.count > 30 {
            return "Stage name is too long (max 30 characters)"
        }
        return nil
    }

    /// Whether the Add button should be enabled
    private var canAdd: Bool {
        let trimmed = stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && validationError == nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Text field section
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("STAGE NAME")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    TextField("Enter stage name", text: $stageName)
                        .font(AppTheme.Typography.body)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                                .stroke(
                                    validationError != nil ? AppTheme.Colors.error : AppTheme.Colors.divider,
                                    lineWidth: 1
                                )
                        )
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    // Validation error
                    if let error = validationError {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Info text
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    Text("Custom stages appear after the default stages (Pre-Op, Preparation, Restoration)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
            }
            .padding(.top, AppTheme.Spacing.md)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStage()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func addStage() {
        let trimmed = stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, validationError == nil else { return }

        let newStage = metadataManager.addCustomStage(name: trimmed)
        onStageAdded?(newStage)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    AddStageSheet(isPresented: .constant(true))
        .environmentObject(MetadataManager.shared)
}
