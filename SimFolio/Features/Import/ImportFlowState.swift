// ImportFlowState.swift
// SimFolio - State for the Photos-library import flow
//
// Mirrors CaptureFlowState (Features/Capture/CaptureFlowView.swift) so the import
// pipeline (picker → review → saving) stays independently testable from live capture.

import SwiftUI
import PhotosUI
import Combine

// MARK: - ImportCandidate

/// A single photo selected from the system Photos library that is a candidate to import.
/// Image data is loaded lazily from the PhotosPicker item; pHAssetId is used for dedupe and
/// originalCapturedDate preserves the real capture time for Library date ordering.
struct ImportCandidate: Identifiable {
    let id = UUID()
    let pickerItemId: String?
    var image: UIImage?
    let pHAssetId: String?
    let originalCapturedDate: Date?
    var rating: Int = 0
    var shouldKeep: Bool = true
    var loadError: Error?
}

// MARK: - ImportProgress

/// Snapshot of progress during a running import batch.
struct ImportProgress: Equatable {
    var completed: Int = 0
    var total: Int = 0
    var skipped: Int = 0
    var failed: Int = 0
}

// MARK: - ImportResult

/// Final counts returned when an import batch finishes (either naturally or via cancel).
struct ImportResult: Equatable {
    var imported: Int
    var skipped: Int
    var failed: Int
}

// MARK: - Import Flow Steps

/// Discrete phases of the import flow.
enum ImportFlowStep: Equatable {
    case picker
    case review
    case importing
}

// MARK: - Import Flow State

/// Observable state driving the Import flow. Mirrors the shape of CaptureFlowState.
@MainActor
final class ImportFlowState: ObservableObject {

    // MARK: Step

    @Published var currentStep: ImportFlowStep = .picker

    // MARK: Picker Selection

    /// Raw items produced by PhotosPicker, waiting to be resolved into ImportCandidates.
    @Published var selectedItems: [PhotosPickerItem] = []

    /// Resolved candidates ready for review.
    @Published var candidates: [ImportCandidate] = []

    // MARK: Tagging

    @Published var selectedProcedure: String?
    @Published var selectedToothNumber: Int?
    @Published var selectedToothDate: Date = Date()
    @Published var selectedStage: String?
    @Published var selectedAngle: String?

    // MARK: Progress

    @Published var progress = ImportProgress()
    @Published var isImporting: Bool = false
    @Published var isCancelled: Bool = false

    // MARK: Portfolio Context

    /// Portfolio ID if the flow was launched from a specific portfolio requirement.
    @Published var sourcePortfolioId: String?

    // MARK: Derived

    /// True when this import flow was launched with a prefilled portfolio/procedure context
    /// (e.g., from a portfolio requirement's "Add Photos" CTA). False for Library-inbox
    /// backfill imports.
    var isFromPortfolio: Bool {
        sourcePortfolioId != nil
    }

    var candidatesToImport: [ImportCandidate] {
        candidates.filter { $0.shouldKeep && $0.loadError == nil }
    }

    var hasAnyTags: Bool {
        selectedProcedure != nil
    }

    var hasAllTags: Bool {
        selectedProcedure != nil &&
        selectedToothNumber != nil &&
        selectedStage != nil &&
        selectedAngle != nil
    }

    /// Human-readable summary of selected tags (matches CaptureFlowState.tagSummary).
    var tagSummary: String {
        var parts: [String] = []
        if let p = selectedProcedure { parts.append(p) }
        if let t = selectedToothNumber { parts.append("#\(t)") }
        if let s = selectedStage { parts.append(PhotoMetadata.stageAbbreviation(for: s)) }
        if let a = selectedAngle { parts.append(a) }
        return parts.isEmpty ? "Tap to add tags" : parts.joined(separator: " • ")
    }

    // MARK: Prefill

    func prefill(
        procedure: String? = nil,
        stage: String? = nil,
        angle: String? = nil,
        toothNumber: Int? = nil,
        portfolioId: String? = nil
    ) {
        selectedProcedure = procedure
        selectedStage = stage
        selectedAngle = angle
        selectedToothNumber = toothNumber
        sourcePortfolioId = portfolioId
    }

    // MARK: Candidate Mutation

    func toggleKeep(id: UUID) {
        if let index = candidates.firstIndex(where: { $0.id == id }) {
            candidates[index].shouldKeep.toggle()
        }
    }

    func setRating(_ rating: Int, for id: UUID) {
        if let index = candidates.firstIndex(where: { $0.id == id }) {
            candidates[index].rating = rating
        }
    }

    // MARK: Portfolio Requirement Matching

    /// Mirrors CaptureFlowState.getCurrentRequirementInfo() so the import review screen can
    /// show the same "this completes X for Y" indicator.
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

    // MARK: Reset

    func reset() {
        currentStep = .picker
        selectedItems = []
        candidates = []
        selectedProcedure = nil
        selectedToothNumber = nil
        selectedToothDate = Date()
        selectedStage = nil
        selectedAngle = nil
        progress = ImportProgress()
        isImporting = false
        isCancelled = false
        sourcePortfolioId = nil
    }
}
