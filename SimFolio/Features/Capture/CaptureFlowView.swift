// CaptureFlowView.swift
// SimFolio - Multi-step Capture Flow
//
// A redesigned capture experience with clear flow stages:
// 1. Setup Stage: Pre-select procedure, tooth, stage, angle
// 2. Camera Stage: Full-screen camera with minimal controls
// 3. Review Stage: Review captured photos with ratings
//
// Key features:
// - Tag BEFORE shooting (optionally)
// - Batch capture multiple photos with same tags
// - Review all photos before saving
// - Cleaner camera UI with fewer visible controls

import SwiftUI
import AVFoundation
import Photos
import Combine

// MARK: - Portfolio Requirement Info

/// Information about missing portfolio requirements for a tag combination
struct RequirementInfo: Identifiable, Equatable {
    let id = UUID()
    let portfolioId: String
    let portfolioName: String
    let procedure: String
    let stage: String
    let angle: String
    let required: Int
    let current: Int

    var missing: Int {
        max(0, required - current)
    }

    var isSatisfied: Bool {
        current >= required
    }
}

// MARK: - Capture Flow State

/// Observable state manager for the capture flow
/// Tracks current step, tag selections, and captured photos
class CaptureFlowState: ObservableObject {

    // MARK: - Flow Steps

    enum Step: Equatable {
        case setup      // Pre-capture tagging
        case camera     // Active camera
        case review     // Review captured photos
    }

    @Published var currentStep: Step = .setup

    // MARK: - Tag Selections

    @Published var selectedProcedure: String?
    @Published var selectedToothNumber: Int?
    @Published var selectedToothDate: Date = Date()
    @Published var selectedStage: String?
    @Published var selectedAngle: String?

    // MARK: - Captured Photos

    /// Photos captured in this session
    @Published var capturedPhotos: [CapturedPhoto] = []

    /// Number of captures in-flight (shutter tapped but photo not yet delivered)
    @Published var pendingCaptureCount: Int = 0

    /// Total count including pending captures, for immediate UI feedback
    var displayPhotoCount: Int {
        capturedPhotos.count + pendingCaptureCount
    }

    // MARK: - Context State

    /// Whether we came from a specific requirement (pre-filled tags)
    @Published var isFromRequirement: Bool = false

    /// Source portfolio ID if navigating from a requirement
    @Published var sourcePortfolioId: String?

    // MARK: - Computed Properties

    /// Returns true if any tag is selected
    var hasAnyTags: Bool {
        selectedProcedure != nil
    }

    /// Returns true if all required tags are selected
    var hasAllTags: Bool {
        selectedProcedure != nil &&
        selectedToothNumber != nil &&
        selectedStage != nil &&
        selectedAngle != nil
    }

    /// Human-readable summary of selected tags
    var tagSummary: String {
        var parts: [String] = []
        if let p = selectedProcedure { parts.append(p) }
        if let t = selectedToothNumber { parts.append("#\(t)") }
        if let s = selectedStage { parts.append(stageAbbreviation(for: s)) }
        if let a = selectedAngle { parts.append(a) }

        if parts.isEmpty {
            return "Tap to add tags"
        }
        return parts.joined(separator: " • ")
    }

    /// Get abbreviated stage name for display
    private func stageAbbreviation(for stage: String) -> String {
        switch stage.lowercased() {
        case "pre-op":
            return "Pre"
        case "preparation":
            return "Prep"
        case "restoration":
            return "Resto"
        default:
            // Custom stages show their full name (truncated if too long)
            return stage.count > 8 ? String(stage.prefix(6)) + "..." : stage
        }
    }

    /// Photos marked to keep (not discarded)
    var photosToKeep: [CapturedPhoto] {
        capturedPhotos.filter { $0.shouldKeep }
    }

    // MARK: - Methods

    /// Pre-fill tags from external navigation (e.g., from requirement card)
    /// - Parameters:
    ///   - procedure: Pre-selected procedure type
    ///   - stage: Pre-selected stage
    ///   - angle: Pre-selected angle
    ///   - toothNumber: Pre-selected tooth number
    ///   - portfolioId: Source portfolio ID
    ///   - skipToCamera: Whether to skip directly to camera (only when all tags are pre-filled from a portfolio requirement)
    func prefill(procedure: String?, stage: String?, angle: String?, toothNumber: Int?, portfolioId: String?, skipToCamera: Bool = false) {
        self.selectedProcedure = procedure
        self.selectedStage = stage
        self.selectedAngle = angle
        self.selectedToothNumber = toothNumber
        self.sourcePortfolioId = portfolioId
        self.isFromRequirement = procedure != nil

        // Only skip to camera if explicitly requested (e.g., from portfolio requirement with all tags)
        if skipToCamera && hasAllTags {
            currentStep = .camera
        }
        // Otherwise stay on setup screen with pre-filled values
    }

    /// Transition from setup to camera
    func startCapturing() {
        currentStep = .camera
    }

    /// Add a newly captured photo to the session
    /// - Parameter image: The captured UIImage
    func addPhoto(image: UIImage) {
        let photo = CapturedPhoto(image: image)
        capturedPhotos.append(photo)
        pendingCaptureCount = max(0, pendingCaptureCount - 1)
    }

    /// Remove a photo at the specified index
    /// - Parameter index: Index of the photo to remove
    func removePhoto(at index: Int) {
        // Use safe removal to prevent out-of-bounds crash
        capturedPhotos.safeRemove(at: index)
    }

    /// Toggle whether a photo should be kept
    /// - Parameter id: UUID of the photo
    func togglePhotoKeep(id: UUID) {
        if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
            capturedPhotos[index].shouldKeep.toggle()
        }
    }

    /// Set the rating for a photo
    /// - Parameters:
    ///   - rating: Star rating (0-5)
    ///   - id: UUID of the photo
    func setRating(_ rating: Int, for id: UUID) {
        if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
            capturedPhotos[index].rating = rating
        }
    }

    /// Transition from camera to review
    func finishCapturing() {
        if !capturedPhotos.isEmpty {
            currentStep = .review
        }
    }

    /// Reset all state to initial values
    func reset() {
        currentStep = .setup
        selectedProcedure = nil
        selectedToothNumber = nil
        selectedToothDate = Date()
        selectedStage = nil
        selectedAngle = nil
        capturedPhotos = []
        pendingCaptureCount = 0
        isFromRequirement = false
        sourcePortfolioId = nil
    }

    // MARK: - Portfolio Requirement Helpers

    /// Get all missing requirements for a given procedure
    /// - Parameter procedure: The procedure type to check
    /// - Returns: Array of requirement info for missing requirements
    func getMissingRequirements(for procedure: String) -> [RequirementInfo] {
        let metadataManager = MetadataManager.shared
        var missing: [RequirementInfo] = []

        for portfolio in metadataManager.portfolios {
            for requirement in portfolio.requirements where requirement.procedure == procedure {
                for stage in requirement.stages {
                    for angle in requirement.angles {
                        let required = requirement.angleCounts[angle] ?? 1
                        let current = metadataManager.getMatchingPhotoCount(
                            procedure: procedure,
                            stage: stage,
                            angle: angle
                        )

                        if current < required {
                            missing.append(RequirementInfo(
                                portfolioId: portfolio.id,
                                portfolioName: portfolio.name,
                                procedure: procedure,
                                stage: stage,
                                angle: angle,
                                required: required,
                                current: current
                            ))
                        }
                    }
                }
            }
        }

        return missing
    }

    /// Get missing requirement count for a specific stage (given current procedure selection)
    /// - Parameter stage: The stage to check
    /// - Returns: Total number of missing photos for this stage
    func getMissingCount(for stage: String) -> Int {
        guard let procedure = selectedProcedure else { return 0 }
        return getMissingRequirements(for: procedure)
            .filter { $0.stage == stage }
            .reduce(0) { $0 + $1.missing }
    }

    /// Get missing requirement count for a specific angle (given current procedure and stage selection)
    /// - Parameter angle: The angle to check
    /// - Returns: Total number of missing photos for this angle
    func getMissingCount(for angle: String, stage: String? = nil) -> Int {
        guard let procedure = selectedProcedure else { return 0 }
        let stageFilter = stage ?? selectedStage
        return getMissingRequirements(for: procedure)
            .filter { stageFilter == nil || $0.stage == stageFilter }
            .filter { $0.angle == angle }
            .reduce(0) { $0 + $1.missing }
    }

    /// Get the current requirement info for the selected tag combination
    /// - Returns: Requirement info if the current selection matches a portfolio requirement
    func getCurrentRequirementInfo() -> RequirementInfo? {
        guard let procedure = selectedProcedure,
              let stage = selectedStage,
              let angle = selectedAngle else { return nil }

        let metadataManager = MetadataManager.shared

        for portfolio in metadataManager.portfolios {
            for requirement in portfolio.requirements where requirement.procedure == procedure {
                if requirement.stages.contains(stage) && requirement.angles.contains(angle) {
                    let required = requirement.angleCounts[angle] ?? 1
                    let current = metadataManager.getMatchingPhotoCount(
                        procedure: procedure,
                        stage: stage,
                        angle: angle
                    )

                    return RequirementInfo(
                        portfolioId: portfolio.id,
                        portfolioName: portfolio.name,
                        procedure: procedure,
                        stage: stage,
                        angle: angle,
                        required: required,
                        current: current
                    )
                }
            }
        }

        return nil
    }
}

// MARK: - Captured Photo Model

/// Represents a photo captured during this session
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    var rating: Int = 0
    var shouldKeep: Bool = true
    let capturedAt: Date = Date()
}

// MARK: - Capture Flow Container View

/// Main container view for the capture flow
/// Routes between setup, camera, and review stages
struct CaptureFlowView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var captureState = CaptureFlowState()
    @ObservedObject var cameraService: CameraService

    @State private var showCancelConfirmation = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Content based on current step
            Group {
                switch captureState.currentStep {
                case .setup:
                    CaptureSetupView(captureState: captureState)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                case .camera:
                    CameraCaptureView(captureState: captureState, cameraService: cameraService)
                        .transition(.opacity)

                case .review:
                    CaptureReviewView(captureState: captureState)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: captureState.currentStep)
        }
        .onAppear {
            // Apply pre-filled values from router
            // Only skip to camera if coming from a portfolio requirement with all tags filled
            let hasAllTagsFromPortfolio = router.captureFromPortfolioId != nil &&
                router.capturePrefilledProcedure != nil &&
                router.capturePrefilledStage != nil &&
                router.capturePrefilledAngle != nil &&
                router.capturePrefilledToothNumber != nil

            captureState.prefill(
                procedure: router.capturePrefilledProcedure,
                stage: router.capturePrefilledStage,
                angle: router.capturePrefilledAngle,
                toothNumber: router.capturePrefilledToothNumber,
                portfolioId: router.captureFromPortfolioId,
                skipToCamera: hasAllTagsFromPortfolio
            )
        }
        .alert("Discard Photos?", isPresented: $showCancelConfirmation) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                captureState.reset()
                router.resetCaptureState()
                router.selectedTab = .home
            }
        } message: {
            Text("You have \(captureState.capturedPhotos.count) unsaved photo(s). Discard them?")
        }
    }

    /// Handle cancel action with confirmation if photos exist
    func handleCancel() {
        if captureState.capturedPhotos.isEmpty {
            captureState.reset()
            router.resetCaptureState()
            router.selectedTab = .home
        } else {
            showCancelConfirmation = true
        }
    }
}

// MARK: - Capture Setup View

/// Pre-capture tagging screen
/// Allows user to select procedure, tooth number, stage, and angle before capturing
struct CaptureSetupView: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    @State private var showToothPicker = false

    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        router.selectedTab = .home
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Button(action: {
                        captureState.startCapturing()
                    }) {
                        Text("Skip, tag later")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                        // Title
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("What are you capturing?")
                                .font(AppTheme.Typography.title)
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("Tag now for automatic organization")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)

                        // Procedure Selection
                        ProcedureSelectionGrid(
                            selectedProcedure: $captureState.selectedProcedure,
                            procedures: metadataManager.procedures,
                            captureState: captureState
                        )

                        // Tooth Selection (only if procedure selected)
                        if captureState.selectedProcedure != nil {
                            ToothSelectionSection(
                                selectedToothNumber: $captureState.selectedToothNumber,
                                selectedDate: $captureState.selectedToothDate,
                                procedure: captureState.selectedProcedure ?? "",
                                metadataManager: metadataManager
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Stage Selection (only if tooth selected)
                        if captureState.selectedToothNumber != nil {
                            StageSelectionSection(
                                selectedStage: $captureState.selectedStage,
                                captureState: captureState
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Angle Selection (only if stage selected)
                        if captureState.selectedStage != nil {
                            AngleSelectionSection(
                                selectedAngle: $captureState.selectedAngle,
                                angles: MetadataManager.angles,
                                captureState: captureState
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                    .animation(.easeInOut(duration: 0.3), value: captureState.selectedProcedure != nil)
                    .animation(.easeInOut(duration: 0.3), value: captureState.selectedToothNumber != nil)
                    .animation(.easeInOut(duration: 0.3), value: captureState.selectedStage != nil)
                }

                // Bottom CTA
                VStack(spacing: AppTheme.Spacing.md) {
                    if captureState.hasAnyTags {
                        Text(captureState.tagSummary)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    DPButton(
                        "Start Capturing",
                        icon: "camera.fill",
                        style: .primary,
                        isFullWidth: true,
                        isDisabled: captureState.selectedProcedure == nil
                    ) {
                        captureState.startCapturing()
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
            }
        }
    }
}

// MARK: - Procedure Selection Grid

/// Grid of procedure type buttons for selection
struct ProcedureSelectionGrid: View {
    @Binding var selectedProcedure: String?
    let procedures: [String]
    @ObservedObject var captureState: CaptureFlowState
    @State private var showAddProcedure = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("PROCEDURE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
                ForEach(procedures, id: \.self) { procedure in
                    let missingRequirements = captureState.getMissingRequirements(for: procedure)
                    let totalMissing = missingRequirements.reduce(0) { $0 + $1.missing }

                    ProcedureSelectionButton(
                        procedure: procedure,
                        color: AppTheme.procedureColor(for: procedure),
                        isSelected: selectedProcedure == procedure,
                        missingCount: totalMissing
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedProcedure == procedure {
                                selectedProcedure = nil
                            } else {
                                selectedProcedure = procedure
                            }
                        }
                    }
                }

                // Add new procedure button (as grid item)
                Button(action: { showAddProcedure = true }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add New")
                            .font(AppTheme.Typography.subheadline.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                            .stroke(AppTheme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .sheet(isPresented: $showAddProcedure) {
            ProcedureEditorSheet(
                isPresented: $showAddProcedure,
                procedure: nil,
                onSave: { newProcedure in
                    MetadataManager.shared.addProcedure(newProcedure)
                    // Auto-select the new procedure
                    selectedProcedure = newProcedure.name
                }
            )
        }
    }
}

// MARK: - Procedure Selection Button

/// Individual procedure button with color indicator and selection state
struct ProcedureSelectionButton: View {
    let procedure: String
    let color: Color
    let isSelected: Bool
    var missingCount: Int = 0
    let onTap: () -> Void

    /// Whether this procedure has missing portfolio requirements
    var hasRequirement: Bool {
        missingCount > 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: hasRequirement ? AppTheme.Spacing.xs : 0) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)

                    Text(procedure)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(isSelected ? AppTheme.procedureColor(for: procedure) : AppTheme.Colors.textPrimary)

                    Spacer()

                    if hasRequirement {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.error.opacity(0.8))
                    }
                }

                if hasRequirement {
                    Text("\(missingCount) photo\(missingCount == 1 ? "" : "s") required")
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(AppTheme.Colors.error.opacity(0.9))
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                isSelected
                    ? AppTheme.procedureBackgroundColor(for: procedure)
                    : (hasRequirement ? AppTheme.Colors.error.opacity(0.06) : AppTheme.Colors.surface)
            )
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(
                        isSelected
                            ? AppTheme.procedureBorderColor(for: procedure)
                            : (hasRequirement ? AppTheme.Colors.error.opacity(0.4) : AppTheme.Colors.divider),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tooth Selection Section

/// Section for selecting tooth number with inline picker
struct ToothSelectionSection: View {
    @Binding var selectedToothNumber: Int?
    @Binding var selectedDate: Date
    let procedure: String
    @ObservedObject var metadataManager: MetadataManager

    /// Get existing tooth entries for this procedure
    var existingTeeth: [ToothEntry] {
        metadataManager.getToothEntries(for: procedure)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("TOOTH")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            // Inline tooth picker
            InlineToothPicker(
                selectedToothNumber: $selectedToothNumber,
                selectedDate: $selectedDate,
                autoSelectOnAppear: false
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Inline Tooth Picker

/// Inline picker for tooth selection with number and name display
struct InlineToothPicker: View {
    @Binding var selectedToothNumber: Int?
    @Binding var selectedDate: Date
    var autoSelectOnAppear: Bool = true
    var onChanged: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Tooth picker row
            HStack(spacing: AppTheme.Spacing.lg) {
                // Label
                Text("Tooth #")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Number picker
                Picker("Tooth Number", selection: Binding(
                    get: { selectedToothNumber },
                    set: { newValue in
                        selectedToothNumber = newValue
                        selectedDate = Date()
                        onChanged?()
                    }
                )) {
                    Text("—").tag(Int?.none)
                    ForEach(1...32, id: \.self) { number in
                        Text("\(number)").tag(Int?.some(number))
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 100)
                .clipped()

                // Tooth name display
                if let tooth = selectedToothNumber {
                    Text(ToothUtility.name(for: tooth))
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.success)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.success.opacity(0.1))
                        .cornerRadius(AppTheme.CornerRadius.small)
                } else {
                    Text("Select a tooth")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .onAppear {
            // Set default selection if none
            if autoSelectOnAppear && selectedToothNumber == nil {
                selectedToothNumber = 1
                selectedDate = Date()
            }
        }
    }
}

// MARK: - Quick Tooth Button

/// Button for quickly selecting a recently used tooth
struct QuickToothButton: View {
    let toothNumber: Int
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.xxs) {
                Text("#\(toothNumber)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)

                Text(date, style: .date)
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? AppTheme.Colors.success : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(isSelected ? AppTheme.Colors.success : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stage Selection Section

/// Section for selecting preparation or restoration stage
struct StageSelectionSection: View {
    @Binding var selectedStage: String?
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var showAddStageSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("STAGE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledStages()) { stageConfig in
                        let missingCount = captureState.getMissingCount(for: stageConfig.name)

                        StageButton(
                            stageConfig: stageConfig,
                            isSelected: selectedStage == stageConfig.name,
                            missingCount: missingCount,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStage = stageConfig.name
                                }
                            },
                            onDelete: stageConfig.isDefault ? nil : {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedStage == stageConfig.name {
                                        selectedStage = nil
                                    }
                                    metadataManager.deleteStage(stageConfig.id)
                                }
                            }
                        )
                    }

                    // Add Stage Button
                    AddStageButton {
                        showAddStageSheet = true
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showAddStageSheet) {
            AddStageSheet(isPresented: $showAddStageSheet)
        }
    }
}

// MARK: - Stage Button

/// Button for selecting a stage
struct StageButton: View {
    let stageConfig: StageConfig
    let isSelected: Bool
    var missingCount: Int = 0
    let onTap: () -> Void
    var onDelete: (() -> Void)?

    /// Whether this stage has missing portfolio requirements
    var hasRequirement: Bool {
        missingCount > 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? stageConfig.color : stageConfig.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    StageIconView(
                        stageConfig: stageConfig,
                        size: 24,
                        foregroundColor: isSelected ? .white : stageConfig.color
                    )

                    // Requirement badge
                    if hasRequirement {
                        Circle()
                            .fill(AppTheme.Colors.error)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 20, y: -20)
                    }

                    // Delete button for custom stages
                    if let onDelete = onDelete, !isSelected {
                        Button(action: onDelete) {
                            Circle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                )
                        }
                        .offset(x: -20, y: -20)
                    }
                }

                Text(stageConfig.name)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 100)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                isSelected
                    ? stageConfig.color.opacity(0.1)
                    : (hasRequirement ? AppTheme.Colors.error.opacity(0.06) : AppTheme.Colors.surface)
            )
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(
                        isSelected
                            ? stageConfig.color
                            : (hasRequirement ? AppTheme.Colors.error.opacity(0.4) : AppTheme.Colors.surfaceSecondary),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Stage Button

/// Button for adding a new custom stage
struct AddStageButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Circle()
                    .strokeBorder(AppTheme.Colors.divider, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    )

                Text("Add")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .frame(width: 100)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppTheme.Colors.divider, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Angle Selection Section

/// Section for selecting photo angle
struct AngleSelectionSection: View {
    @Binding var selectedAngle: String?
    let angles: [String]
    @ObservedObject var captureState: CaptureFlowState

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("ANGLE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
                ForEach(angles, id: \.self) { angle in
                    let missingCount = captureState.getMissingCount(for: angle, stage: captureState.selectedStage)

                    AngleButton(
                        angle: angle,
                        isSelected: selectedAngle == angle,
                        missingCount: missingCount
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAngle = angle
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Angle Button

/// Button for selecting a photo angle
struct AngleButton: View {
    let angle: String
    let isSelected: Bool
    var missingCount: Int = 0
    let onTap: () -> Void

    var icon: String {
        switch angle {
        case "Occlusal", "Incisal", "Occlusal/Incisal": return "arrow.down"
        case "Buccal/Facial": return "arrow.left"
        case "Lingual": return "arrow.right"
        case "Proximal": return "arrow.left.arrow.right"
        case "Mesial": return "arrow.up.left"
        case "Distal": return "arrow.up.right"
        default: return "questionmark"
        }
    }

    /// Whether this angle has missing portfolio requirements
    var hasRequirement: Bool {
        missingCount > 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: hasRequirement ? AppTheme.Spacing.xs : 0) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: AppTheme.IconSize.sm))
                        .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.angleColor(for: angle))
                        .frame(width: 24)

                    Text(angle)
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if hasRequirement {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: AppTheme.IconSize.sm - 2))
                            .foregroundStyle(AppTheme.Colors.error.opacity(AppTheme.Opacity.strong))
                    }
                }

                if hasRequirement {
                    Text("\(missingCount) photo\(missingCount == 1 ? "" : "s") required")
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(AppTheme.Colors.error.opacity(0.9))
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                isSelected
                    ? AppTheme.Colors.accentLight
                    : (hasRequirement ? AppTheme.Colors.error.opacity(0.06) : AppTheme.Colors.surface)
            )
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(
                        isSelected
                            ? AppTheme.Colors.primary
                            : (hasRequirement ? AppTheme.Colors.error.opacity(0.4) : AppTheme.Colors.divider),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Capture Review View

/// Post-capture review screen
/// Shows all captured photos with rating and keep/discard options
struct CaptureReviewView: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    @AppStorage("saveToCameraRoll") private var saveToCameraRoll = false

    @State private var showTagEditor = false
    @State private var selectedPhotoIndex: Int? = nil
    @State private var isSaving = false

    var photosToSave: [CapturedPhoto] {
        captureState.photosToKeep
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Tag summary
                tagSummaryBar

                // Photo grid
                ScrollView {
                    photoGrid
                        .padding(AppTheme.Spacing.md)
                }

                // Portfolio match indicator
                portfolioMatchIndicator

                // Bottom actions
                bottomActions
            }

            // Loading overlay
            if isSaving {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Saving...")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showTagEditor) {
            ReviewTagEditorSheet(captureState: captureState)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    var header: some View {
        HStack {
            Button(action: { captureState.currentStep = .camera }) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.primary)
            }

            Spacer()

            Text("Review \(captureState.capturedPhotos.count) Photos")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Button("Done") {
                savePhotos()
            }
            .font(AppTheme.Typography.headline)
            .foregroundStyle(photosToSave.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
            .disabled(photosToSave.isEmpty)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Tag Summary Bar

    var tagSummaryBar: some View {
        Button(action: { showTagEditor = true }) {
            HStack {
                // Tag pills
                ForEach(currentTagPills, id: \.text) { pill in
                    DPTagPill(pill.text, color: pill.color, size: .small)
                }

                if currentTagPills.isEmpty {
                    Text("No tags")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }

                Spacer()

                Text("Edit")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.primary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfaceSecondary)
        }
    }

    // MARK: - Photo Grid

    var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
            ForEach(Array(captureState.capturedPhotos.enumerated()), id: \.element.id) { index, photo in
                ReviewPhotoCard(
                    photo: photo,
                    index: index,
                    onToggleKeep: {
                        captureState.togglePhotoKeep(id: photo.id)
                    },
                    onRatingChange: { rating in
                        captureState.setRating(rating, for: photo.id)
                    },
                    onTap: {
                        selectedPhotoIndex = index
                    }
                )
            }
        }
    }

    // MARK: - Portfolio Match Indicator

    @ViewBuilder
    var portfolioMatchIndicator: some View {
        if let match = findPortfolioMatch() {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.success)

                Text(match)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.success.opacity(0.1))
        }
    }

    // MARK: - Bottom Actions

    var bottomActions: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            DPButton(
                "Save \(photosToSave.count) Photo\(photosToSave.count == 1 ? "" : "s")",
                icon: "checkmark.circle.fill",
                style: .primary,
                isFullWidth: true,
                isDisabled: photosToSave.isEmpty
            ) {
                savePhotos()
            }

            HStack(spacing: AppTheme.Spacing.md) {
                DPButton(
                    "Capture More",
                    icon: "camera",
                    style: .secondary
                ) {
                    captureState.currentStep = .camera
                }

                Button(action: {
                    captureState.capturedPhotos.removeAll()
                    captureState.currentStep = .camera
                }) {
                    Text("Discard All")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.error)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Helper Methods

    var currentTagPills: [(text: String, color: Color)] {
        var pills: [(String, Color)] = []
        if let p = captureState.selectedProcedure {
            pills.append((p, AppTheme.procedureColor(for: p)))
        }
        if let t = captureState.selectedToothNumber {
            pills.append(("#\(t)", AppTheme.Colors.info))
        }
        if let s = captureState.selectedStage {
            pills.append((PhotoMetadata.stageAbbreviation(for: s), metadataManager.stageColor(for: s)))
        }
        if let a = captureState.selectedAngle {
            pills.append((a, AppTheme.angleColor(for: a)))
        }
        return pills
    }

    func findPortfolioMatch() -> String? {
        // Check if current tags match any portfolio requirement
        guard let procedure = captureState.selectedProcedure,
              let stage = captureState.selectedStage,
              let angle = captureState.selectedAngle else {
            return nil
        }

        for portfolio in metadataManager.portfolios {
            for requirement in portfolio.requirements {
                if requirement.procedure == procedure &&
                   requirement.stages.contains(stage) &&
                   requirement.angles.contains(angle) {
                    let currentCount = metadataManager.getPhotoCount(for: requirement, stage: stage, angle: angle)
                    let needed = requirement.angleCounts[angle] ?? 1
                    let willAdd = photosToSave.count

                    if currentCount + willAdd >= needed {
                        return "Completes \(angle) for \(portfolio.name)!"
                    } else {
                        return "\(currentCount + willAdd)/\(needed) \(angle) for \(portfolio.name)"
                    }
                }
            }
        }

        return nil
    }

    /// Returns just the portfolio name if current tags match a portfolio requirement
    func findPortfolioMatchName() -> String? {
        guard let procedure = captureState.selectedProcedure,
              let stage = captureState.selectedStage,
              let angle = captureState.selectedAngle else {
            return nil
        }

        for portfolio in metadataManager.portfolios {
            for requirement in portfolio.requirements {
                if requirement.procedure == procedure &&
                   requirement.stages.contains(stage) &&
                   requirement.angles.contains(angle) {
                    return portfolio.name
                }
            }
        }

        return nil
    }

    func savePhotos() {
        isSaving = true

        let baseMetadata = PhotoMetadata(
            procedure: captureState.selectedProcedure,
            toothNumber: captureState.selectedToothNumber,
            toothDate: captureState.selectedToothDate,
            stage: captureState.selectedStage,
            angle: captureState.selectedAngle,
            rating: nil
        )

        let photoCount = photosToSave.count

        for photo in photosToSave {
            var photoMetadata = baseMetadata
            photoMetadata.rating = photo.rating > 0 ? photo.rating : nil

            // Save to app storage
            let record = PhotoStorageService.shared.savePhoto(photo.image)

            // Store metadata keyed by new UUID
            MetadataManager.shared.assignMetadata(photoMetadata, to: record.id.uuidString)

            // Add tooth entry
            if let entry = photoMetadata.toothEntry {
                MetadataManager.shared.addToothEntry(entry)
            }

            // Optionally save to camera roll
            if saveToCameraRoll {
                PhotoLibraryManager.shared.saveImageToCameraRoll(photo.image)
            }

            // Analytics
            AnalyticsService.logPhotoCaptured(
                procedure: photoMetadata.procedure,
                stage: photoMetadata.stage,
                toothNumber: photoMetadata.toothNumber
            )
        }

        // Log batch capture completion
        AnalyticsService.logCustomEvent("batch_capture_completed", parameters: [
            "photo_count": photoCount
        ])

        // Prompt review after first photo capture
        ReviewPromptService.requestIfEligible(for: .firstPhotoCaptured)

        // Determine toast message based on portfolio match
        let toastMessage: String
        if let portfolioMatch = findPortfolioMatchName() {
            toastMessage = "\(photoCount) photo\(photoCount == 1 ? "" : "s") added to \(portfolioMatch)"
        } else {
            toastMessage = "\(photoCount) photo\(photoCount == 1 ? "" : "s") saved to library"
        }

        isSaving = false

        // Reset and go home
        captureState.reset()
        router.resetCaptureState()
        router.selectedTab = .home

        // Show toast after navigation (small delay for smooth UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .showGlobalToast,
                object: nil,
                userInfo: ["message": toastMessage, "type": "success"]
            )
        }
    }
}

// MARK: - Review Photo Card

/// Card displaying a captured photo with keep/discard toggle and rating
struct ReviewPhotoCard: View {
    let photo: CapturedPhoto
    let index: Int
    let onToggleKeep: () -> Void
    let onRatingChange: (Int) -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Photo with keep/delete overlay
            ZStack(alignment: .topTrailing) {
                Button(action: onTap) {
                    Image(uiImage: photo.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .opacity(photo.shouldKeep ? 1.0 : 0.4)
                }

                // Keep/Delete toggle
                Button(action: onToggleKeep) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(photo.shouldKeep ? AppTheme.Colors.textTertiary.opacity(0.5) : AppTheme.Colors.error)
                        .background(Color.white.clipShape(Circle()))
                }
                .padding(AppTheme.Spacing.sm)
            }

            // Rating stars or discard message
            if photo.shouldKeep {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { onRatingChange(star) }) {
                            Image(systemName: star <= photo.rating ? "star.fill" : "star")
                                .font(.system(size: 20))
                                .foregroundStyle(star <= photo.rating ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary)
                        }
                    }
                }
            } else {
                Text("Will be discarded")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Review Tag Editor Sheet

/// Tag editor sheet for the review screen
struct ReviewTagEditorSheet: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showToothChart = false
    @State private var showAddStageSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Procedure selection
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("PROCEDURE")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(MetadataManager.baseProcedures, id: \.self) { procedure in
                                    DPTagPill(
                                        procedure,
                                        color: AppTheme.procedureColor(for: procedure),
                                        isSelected: captureState.selectedProcedure == procedure
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            captureState.selectedProcedure = procedure
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Tooth selection
                    if let procedure = captureState.selectedProcedure {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("TOOTH")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    let recentTeeth = metadataManager.getToothEntries(for: procedure).prefix(5)
                                    ForEach(recentTeeth.map { $0 }, id: \.id) { entry in
                                        Button(action: {
                                            captureState.selectedToothNumber = entry.toothNumber
                                            captureState.selectedToothDate = entry.date
                                        }) {
                                            Text("#\(entry.toothNumber)")
                                                .font(AppTheme.Typography.subheadline.weight(.semibold))
                                                .padding(.horizontal, AppTheme.Spacing.sm)
                                                .padding(.vertical, AppTheme.Spacing.xs)
                                                .background(
                                                    captureState.selectedToothNumber == entry.toothNumber
                                                        ? AppTheme.Colors.info
                                                        : AppTheme.Colors.surfaceSecondary
                                                )
                                                .foregroundStyle(
                                                    captureState.selectedToothNumber == entry.toothNumber
                                                        ? .white
                                                        : AppTheme.Colors.textPrimary
                                                )
                                                .cornerRadius(AppTheme.CornerRadius.small)
                                        }
                                    }

                                    Button(action: { showToothChart = true }) {
                                        HStack(spacing: AppTheme.Spacing.xxs) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("New")
                                                .font(AppTheme.Typography.subheadline.weight(.medium))
                                        }
                                        .padding(.horizontal, AppTheme.Spacing.sm)
                                        .padding(.vertical, AppTheme.Spacing.xs)
                                        .background(AppTheme.Colors.primary.opacity(0.15))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                        .cornerRadius(AppTheme.CornerRadius.small)
                                    }
                                }
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
                                            captureState.selectedStage = stageConfig.name
                                        },
                                        onDelete: stageConfig.isDefault ? nil : {
                                            if captureState.selectedStage == stageConfig.name {
                                                captureState.selectedStage = nil
                                            }
                                            metadataManager.deleteStage(stageConfig.id)
                                        }
                                    )
                                }

                                // Add stage button
                                Button(action: { showAddStageSheet = true }) {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Add")
                                            .font(AppTheme.Typography.subheadline.weight(.medium))
                                    }
                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(AppTheme.Colors.surfaceSecondary)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .cornerRadius(AppTheme.CornerRadius.full)
                                }
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
                                    DPTagPill(
                                        angle,
                                        color: AppTheme.angleColor(for: angle),
                                        isSelected: captureState.selectedAngle == angle
                                    ) {
                                        captureState.selectedAngle = angle
                                    }
                                }
                            }
                        }
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
            ToothPickerSheet(
                selectedTooth: $captureState.selectedToothNumber,
                selectedDate: $captureState.selectedToothDate,
                isPresented: $showToothChart,
                recentTeeth: captureState.selectedProcedure != nil
                    ? Array(metadataManager.getToothEntries(for: captureState.selectedProcedure!).prefix(5))
                    : [],
                showDatePicker: false,
                onConfirm: { tooth, date in
                    // Add tooth entry when confirmed
                    if let procedure = captureState.selectedProcedure {
                        let entry = ToothEntry(
                            procedure: procedure,
                            toothNumber: tooth,
                            date: date
                        )
                        metadataManager.addToothEntry(entry)
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddStageSheet) {
            AddStageSheet(isPresented: $showAddStageSheet)
        }
    }
}

// MARK: - Stage Pill With Delete

/// A pill-style button for stage selection with optional delete functionality
struct StagePillWithDelete: View {
    let stageConfig: StageConfig
    let isSelected: Bool
    let onSelect: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Button(action: onSelect) {
                Text(stageConfig.name)
                    .font(AppTheme.Typography.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                    .padding(.leading, AppTheme.Spacing.sm)
                    .padding(.trailing, onDelete != nil ? AppTheme.Spacing.xxs : AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
            }
            .buttonStyle(PlainButtonStyle())

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : AppTheme.Colors.textTertiary)
                        .padding(.trailing, AppTheme.Spacing.xs)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(isSelected ? stageConfig.color : AppTheme.Colors.surfaceSecondary)
        .cornerRadius(AppTheme.CornerRadius.full)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CaptureFlowView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureFlowPreviewContainer()
    }
}

struct CaptureFlowPreviewContainer: View {
    @StateObject private var router = NavigationRouter()
    @StateObject private var cameraService = CameraService()

    var body: some View {
        CaptureFlowView(cameraService: cameraService)
            .environmentObject(router)
    }
}
#endif
