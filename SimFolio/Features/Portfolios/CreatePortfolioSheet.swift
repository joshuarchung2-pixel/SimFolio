// CreatePortfolioSheet.swift
// SimFolio - Create and Edit Portfolio Sheets
//
// This file contains views for creating new portfolios and editing existing ones.
// Users can set portfolio name, due date, and define photo requirements.
//
// Contents:
// - CreatePortfolioSheet: Form for creating new portfolios
// - EditPortfolioSheet: Form for editing existing portfolios
// - RequirementPreviewRow: Displays a requirement in the list
// - RequirementEditorSheet: Form for adding/editing requirements
// - Chip components: ProcedureChip, StageChip, AngleChip
// - FlowLayout: Custom layout for wrapping chip components

import SwiftUI

// MARK: - CreatePortfolioSheet

/// Sheet for creating a new portfolio with name, due date, and requirements
struct CreatePortfolioSheet: View {
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Form State

    @State private var name: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var requirements: [PortfolioRequirement] = []

    // MARK: - Sheet State

    @State private var showRequirementEditor: Bool = false
    @State private var editingRequirementIndex: Int? = nil

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Portfolio name section
                    nameSection

                    // Due date section
                    dueDateSection

                    // Requirements section
                    requirementsSection

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPortfolio()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showRequirementEditor) {
                RequirementEditorSheet(
                    isPresented: $showRequirementEditor,
                    existingRequirement: editingRequirementIndex != nil ? requirements[editingRequirementIndex!] : nil,
                    onSave: { requirement in
                        if let index = editingRequirementIndex {
                            requirements[index] = requirement
                        } else {
                            requirements.append(requirement)
                        }
                        editingRequirementIndex = nil
                    }
                )
            }
        }
    }

    // MARK: - Name Section

    var nameSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Portfolio Name")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            TextField("e.g., Fall 2024 Operative Exam", text: $name)
                .font(AppTheme.Typography.body)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .stroke(AppTheme.Colors.primary.opacity(name.isEmpty ? 0 : 0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Due Date Section

    var dueDateSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Due Date")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            DPCard(padding: AppTheme.Spacing.md) {
                VStack(spacing: AppTheme.Spacing.md) {
                    Toggle(isOn: $hasDueDate) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text("Set Due Date")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("Get reminders as the deadline approaches")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .tint(AppTheme.Colors.primary)

                    if hasDueDate {
                        Divider()

                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .tint(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Requirements Section

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Requirements")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                if !requirements.isEmpty {
                    Text("\(requirements.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(10)
                }
            }

            Text("Define what photos are needed for this portfolio")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            VStack(spacing: AppTheme.Spacing.sm) {
                // Existing requirements
                ForEach(requirements.indices, id: \.self) { index in
                    RequirementPreviewRow(
                        requirement: requirements[index],
                        onEdit: {
                            editingRequirementIndex = index
                            showRequirementEditor = true
                        },
                        onDelete: {
                            withAnimation {
                                _ = requirements.remove(at: index)
                            }
                        }
                    )
                }

                // Add requirement button
                Button(action: {
                    editingRequirementIndex = nil
                    showRequirementEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))

                        Text("Add Requirement")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            if requirements.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    Text("You can add requirements now or later")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Actions

    func createPortfolio() {
        let portfolio = Portfolio(
            id: UUID().uuidString,
            name: trimmedName,
            createdDate: Date(),
            dueDate: hasDueDate ? dueDate : nil,
            requirements: requirements
        )

        metadataManager.addPortfolio(portfolio)

        // Track analytics
        AnalyticsService.logPortfolioCreated(
            name: trimmedName,
            requirementCount: requirements.count,
            hasDueDate: hasDueDate
        )

        isPresented = false
    }
}

// MARK: - EditPortfolioSheet

/// Sheet for editing an existing portfolio's name and due date
struct EditPortfolioSheet: View {
    let portfolio: Portfolio
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Form State

    @State private var name: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var requirements: [PortfolioRequirement] = []
    @State private var showRequirementEditor = false
    @State private var editingRequirementIndex: Int? = nil
    @State private var requirementToDeleteIndex: Int? = nil
    @State private var showDeleteRequirementAlert = false
    @State private var matchingPhotoCount: Int = 0

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !requirements.isEmpty
    }

    var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName != portfolio.name {
            return true
        }

        if hasDueDate != (portfolio.dueDate != nil) {
            return true
        }

        if hasDueDate, let originalDueDate = portfolio.dueDate {
            let calendar = Calendar.current
            if !calendar.isDate(dueDate, inSameDayAs: originalDueDate) {
                return true
            }
        }

        if requirements != portfolio.requirements {
            return true
        }

        return false
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Portfolio name section
                    nameSection

                    // Due date section
                    dueDateSection

                    // Requirements section
                    requirementsSection

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || !hasChanges)
                }
            }
            .onAppear {
                loadPortfolio()
            }
            .sheet(isPresented: $showRequirementEditor) {
                RequirementEditorSheet(
                    isPresented: $showRequirementEditor,
                    existingRequirement: editingRequirementIndex != nil ? requirements[editingRequirementIndex!] : nil,
                    onSave: { requirement in
                        if let index = editingRequirementIndex {
                            requirements[index] = requirement
                        } else {
                            requirements.append(requirement)
                        }
                        editingRequirementIndex = nil
                    }
                )
            }
            .alert("Remove Requirement?", isPresented: $showDeleteRequirementAlert) {
                Button("Cancel", role: .cancel) {
                    requirementToDeleteIndex = nil
                }
                Button("Remove", role: .destructive) {
                    if let index = requirementToDeleteIndex {
                        requirements.remove(at: index)
                        requirementToDeleteIndex = nil
                    }
                }
            } message: {
                if matchingPhotoCount > 0 {
                    Text("This requirement has \(matchingPhotoCount) matching photo\(matchingPhotoCount == 1 ? "" : "s"). The photos will remain in your library but will no longer count toward this portfolio.")
                } else {
                    Text("This requirement will be removed from the portfolio.")
                }
            }
        }
    }

    // MARK: - Name Section

    var nameSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Portfolio Name")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            TextField("Portfolio name", text: $name)
                .font(AppTheme.Typography.body)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Due Date Section

    var dueDateSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Due Date")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            DPCard(padding: AppTheme.Spacing.md) {
                VStack(spacing: AppTheme.Spacing.md) {
                    Toggle(isOn: $hasDueDate) {
                        Text("Set Due Date")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .tint(AppTheme.Colors.primary)

                    if hasDueDate {
                        Divider()

                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .tint(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Requirements Section

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Requirements")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(requirements.enumerated()), id: \.element.id) { index, requirement in
                    RequirementPreviewRow(
                        requirement: requirement,
                        onEdit: {
                            editingRequirementIndex = index
                            showRequirementEditor = true
                        },
                        onDelete: {
                            prepareDeleteRequirement(at: index)
                        }
                    )
                }

                // Add Requirement button
                Button(action: {
                    editingRequirementIndex = nil
                    showRequirementEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                        Text("Add Requirement")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Actions

    func loadPortfolio() {
        name = portfolio.name
        hasDueDate = portfolio.dueDate != nil
        dueDate = portfolio.dueDate ?? Date()
        requirements = portfolio.requirements
    }

    func saveChanges() {
        let updatedPortfolio = Portfolio(
            id: portfolio.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdDate: portfolio.createdDate,
            dueDate: hasDueDate ? dueDate : nil,
            requirements: requirements
        )

        metadataManager.updatePortfolio(updatedPortfolio)
        isPresented = false
    }

    func prepareDeleteRequirement(at index: Int) {
        requirementToDeleteIndex = index
        let requirement = requirements[index]

        matchingPhotoCount = metadataManager.assetMetadata.values.filter { metadata in
            metadata.procedure == requirement.procedure
                && requirement.stages.contains(metadata.stage ?? "")
                && requirement.angles.contains(metadata.angle ?? "")
        }.count

        showDeleteRequirementAlert = true
    }
}

// MARK: - RequirementPreviewRow

/// Row displaying a requirement summary with edit and delete actions
struct RequirementPreviewRow: View {
    let requirement: PortfolioRequirement
    let onEdit: () -> Void
    let onDelete: () -> Void

    var procedureColor: Color {
        AppTheme.procedureColor(for: requirement.procedure)
    }

    var summary: String {
        var parts: [String] = []

        // Stages
        if requirement.stages.count == 2 {
            parts.append("Both stages")
        } else if let stage = requirement.stages.first {
            parts.append(stage)
        }

        // Angles
        parts.append("\(requirement.angles.count) angle\(requirement.angles.count == 1 ? "" : "s")")

        // Photos per angle - check if any have more than 1
        let maxCount = requirement.angleCounts.values.max() ?? 1
        if maxCount > 1 {
            parts.append("\(maxCount) each")
        }

        return parts.joined(separator: " · ")
    }

    var totalPhotos: Int {
        requirement.totalRequired
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Procedure color indicator
            Circle()
                .fill(procedureColor)
                .frame(width: 12, height: 12)

            // Content
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(requirement.procedure)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            // Photo count badge
            Text("\(totalPhotos) photo\(totalPhotos == 1 ? "" : "s")")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.surfaceSecondary)
                .cornerRadius(AppTheme.CornerRadius.small)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - RequirementEditorSheet

/// Sheet for adding or editing a portfolio requirement
struct RequirementEditorSheet: View {
    @Binding var isPresented: Bool
    let existingRequirement: PortfolioRequirement?
    let onSave: (PortfolioRequirement) -> Void

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Form State

    @State private var selectedProcedure: String = ""
    @State private var selectedStages: Set<String> = []
    @State private var selectedAngles: Set<String> = []
    @State private var photosPerAngle: Int = 1

    // MARK: - Sheet State

    @State private var showAddProcedureSheet = false
    @State private var showAddStageSheet = false

    // MARK: - Dynamic Options from MetadataManager

    var availableProcedures: [String] {
        metadataManager.getEnabledProcedureNames()
    }

    var availableStages: [String] {
        metadataManager.getEnabledStageNames()
    }

    var availableAngles: [String] {
        MetadataManager.angles
    }

    // MARK: - Validation

    var isValid: Bool {
        !selectedProcedure.isEmpty &&
        !selectedStages.isEmpty &&
        !selectedAngles.isEmpty
    }

    var totalPhotos: Int {
        selectedStages.count * selectedAngles.count * photosPerAngle
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Procedure selection
                    procedureSection

                    // Stages selection
                    stagesSection

                    // Angles selection
                    anglesSection

                    // Photos per angle
                    photosPerAngleSection

                    // Summary
                    if isValid {
                        summarySection
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(existingRequirement != nil ? "Edit Requirement" : "Add Requirement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(existingRequirement != nil ? "Save" : "Add") {
                        saveRequirement()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingRequirement()
            }
            .sheet(isPresented: $showAddProcedureSheet) {
                ProcedureEditorSheet(
                    isPresented: $showAddProcedureSheet,
                    procedure: nil,
                    onSave: { newProcedure in
                        metadataManager.addProcedure(newProcedure)
                        // Auto-select the new procedure
                        selectedProcedure = newProcedure.name
                    }
                )
            }
            .sheet(isPresented: $showAddStageSheet) {
                AddStageSheet(
                    isPresented: $showAddStageSheet,
                    onStageAdded: { newStage in
                        // Auto-select the new stage
                        selectedStages.insert(newStage.name)
                    }
                )
            }
        }
    }

    // MARK: - Procedure Section

    var procedureSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Procedure")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            PortfolioFlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(availableProcedures, id: \.self) { procedure in
                    ProcedureChip(
                        procedure: procedure,
                        isSelected: selectedProcedure == procedure,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedProcedure = procedure
                            }
                        }
                    )
                }

                // Add procedure button
                Button(action: { showAddProcedureSheet = true }) {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add")
                            .font(AppTheme.Typography.subheadline.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(AppTheme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Stages Section

    var stagesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Stages")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Button(action: {
                    withAnimation {
                        if selectedStages.count == availableStages.count {
                            selectedStages.removeAll()
                        } else {
                            selectedStages = Set(availableStages)
                        }
                    }
                }) {
                    Text(selectedStages.count == availableStages.count ? "Deselect All" : "Select All")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(availableStages, id: \.self) { stage in
                    StageChip(
                        stage: stage,
                        isSelected: selectedStages.contains(stage),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedStages.contains(stage) {
                                    selectedStages.remove(stage)
                                } else {
                                    selectedStages.insert(stage)
                                }
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
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Angles Section

    var anglesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Angles")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Button(action: {
                    withAnimation {
                        if selectedAngles.count == availableAngles.count {
                            selectedAngles.removeAll()
                        } else {
                            selectedAngles = Set(availableAngles)
                        }
                    }
                }) {
                    Text(selectedAngles.count == availableAngles.count ? "Deselect All" : "Select All")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            PortfolioFlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(availableAngles, id: \.self) { angle in
                    AngleChip(
                        angle: angle,
                        isSelected: selectedAngles.contains(angle),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedAngles.contains(angle) {
                                    selectedAngles.remove(angle)
                                } else {
                                    selectedAngles.insert(angle)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Photos Per Angle Section

    var photosPerAngleSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Photos Per Angle")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            DPCard(padding: AppTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("Required photos")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("Per stage/angle combination")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: AppTheme.Spacing.md) {
                        Button(action: {
                            if photosPerAngle > 1 {
                                photosPerAngle -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(photosPerAngle > 1 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        }
                        .disabled(photosPerAngle <= 1)

                        Text("\(photosPerAngle)")
                            .font(AppTheme.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .frame(minWidth: 30)

                        Button(action: {
                            if photosPerAngle < 10 {
                                photosPerAngle += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(photosPerAngle < 10 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        }
                        .disabled(photosPerAngle >= 10)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Summary Section

    var summarySection: some View {
        DPCard(padding: AppTheme.Spacing.md) {
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text("Requirement Summary")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Spacer()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        SummaryRow(label: "Procedure:", value: selectedProcedure)
                        SummaryRow(label: "Stages:", value: selectedStages.sorted().joined(separator: ", "))
                        SummaryRow(label: "Angles:", value: "\(selectedAngles.count) selected")
                        SummaryRow(label: "Photos per combo:", value: "\(photosPerAngle)")
                    }

                    Spacer()

                    VStack {
                        Text("\(totalPhotos)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        Text("total photos")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Actions

    func loadExistingRequirement() {
        guard let existing = existingRequirement else { return }

        selectedProcedure = existing.procedure
        selectedStages = Set(existing.stages)
        selectedAngles = Set(existing.angles)
        // Get the max count from angleCounts, or default to 1
        photosPerAngle = existing.angleCounts.values.max() ?? 1
    }

    func saveRequirement() {
        // Build angleCounts dictionary with uniform count
        var angleCounts: [String: Int] = [:]
        for angle in selectedAngles {
            angleCounts[angle] = photosPerAngle
        }

        let requirement = PortfolioRequirement(
            id: existingRequirement?.id ?? UUID().uuidString,
            procedure: selectedProcedure,
            stages: Array(selectedStages).sorted(),
            angles: Array(selectedAngles).sorted(),
            angleCounts: angleCounts
        )

        onSave(requirement)
        isPresented = false
    }
}

// MARK: - SummaryRow

/// Helper view for displaying label-value pairs in the summary
private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text(value)
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - ProcedureChip

/// Selectable chip for procedure selection with procedure color
struct ProcedureChip: View {
    let procedure: String
    let isSelected: Bool
    let onTap: () -> Void

    var procedureColor: Color {
        MetadataManager.shared.procedureColor(for: procedure)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Circle()
                    .fill(procedureColor)
                    .frame(width: 12, height: 12)

                Text(procedure)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? procedureColor : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(isSelected ? procedureColor.opacity(0.15) : AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(isSelected ? procedureColor : AppTheme.Colors.surfaceSecondary, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - StageChip

/// Selectable chip for stage selection with stage-specific styling
struct StageChip: View {
    let stage: String
    let isSelected: Bool
    let onTap: () -> Void

    var stageColor: Color {
        AppTheme.stageColor(for: stage)
    }

    var stageIcon: String {
        AppTheme.stageIcon(for: stage)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: stageIcon)
                    .font(.system(size: 14))

                Text(stage)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? stageColor : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(isSelected ? stageColor.opacity(0.15) : AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(isSelected ? stageColor : AppTheme.Colors.surfaceSecondary, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AngleChip

/// Selectable chip for angle selection with directional icons
struct AngleChip: View {
    let angle: String
    let isSelected: Bool
    let onTap: () -> Void

    var angleColor: Color {
        AppTheme.angleColor(for: angle)
    }

    var angleIcon: String {
        switch angle.lowercased() {
        case "occlusal", "incisal", "occlusal/incisal": return "arrow.down"
        case "buccal", "buccal/facial": return "arrow.left"
        case "lingual": return "arrow.right"
        case "mesial": return "arrow.up.left"
        case "distal": return "arrow.up.right"
        case "proximal": return "arrow.left.and.right"
        case "facial": return "arrow.left"
        default: return "camera"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: angleIcon)
                    .font(.system(size: 12))

                Text(angle)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? angleColor : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .fill(isSelected ? angleColor.opacity(0.15) : AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(isSelected ? angleColor : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PortfolioFlowLayout

/// Custom layout that wraps content to next line when it exceeds available width
struct PortfolioFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Move to next line if needed
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (
            size: CGSize(width: totalWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CreatePortfolioSheet_Previews: PreviewProvider {
    static var previews: some View {
        CreatePortfolioSheet(isPresented: .constant(true))
    }
}

struct EditPortfolioSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditPortfolioSheet(
            portfolio: Portfolio(
                name: "Test Portfolio",
                createdDate: Date(),
                dueDate: Date().addingTimeInterval(86400 * 7),
                requirements: [
                    PortfolioRequirement(
                        procedure: "Class 1",
                        stages: ["Preparation", "Restoration"],
                        angles: ["Occlusal/Incisal", "Buccal/Facial"]
                    )
                ]
            ),
            isPresented: .constant(true)
        )
    }
}

struct RequirementEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        RequirementEditorSheet(
            isPresented: .constant(true),
            existingRequirement: nil,
            onSave: { _ in }
        )
    }
}
#endif
