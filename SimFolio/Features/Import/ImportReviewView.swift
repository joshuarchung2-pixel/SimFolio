// ImportReviewView.swift
// SimFolio - Review screen for the Photos-library import flow
//
// Mirrors CaptureReviewView (Features/Capture/CaptureFlowView.swift:1092). Reuses
// ReviewPhotoCard and ReviewTagEditorSheet unchanged so visual behavior matches
// the post-capture flow.

import SwiftUI

struct ImportReviewView: View {
    @ObservedObject var importState: ImportFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    var onCancel: () -> Void
    var onStartImport: () -> Void

    @State private var showTagEditor = false

    // MARK: Derived

    private var candidatesToImport: [ImportCandidate] {
        importState.candidatesToImport
    }

    // MARK: Body

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tagSummaryBar
                ScrollView {
                    photoGrid
                        .padding(AppTheme.Spacing.md)
                }
                portfolioMatchIndicator
                bottomActions
            }
        }
        .sheet(isPresented: $showTagEditor) {
            ImportTagEditorSheet(importState: importState)
                .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.primary)
            }

            Spacer()

            Text("Review \(importState.candidates.count) Photo\(importState.candidates.count == 1 ? "" : "s")")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Button("Import") {
                onStartImport()
            }
            .font(AppTheme.Typography.headline)
            .foregroundStyle(candidatesToImport.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
            .disabled(candidatesToImport.isEmpty)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
    }

    // MARK: Tag Summary

    private var tagSummaryBar: some View {
        Button(action: { showTagEditor = true }) {
            HStack {
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

    // MARK: Grid

    private var photoGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.md
        ) {
            ForEach(Array(importState.candidates.enumerated()), id: \.element.id) { index, candidate in
                ImportCandidateCard(
                    candidate: candidate,
                    index: index,
                    onToggleKeep: { importState.toggleKeep(id: candidate.id) },
                    onRatingChange: { rating in importState.setRating(rating, for: candidate.id) }
                )
            }
        }
    }

    // MARK: Portfolio Match

    @ViewBuilder
    private var portfolioMatchIndicator: some View {
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

    // MARK: Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            DPButton(
                "Import \(candidatesToImport.count) Photo\(candidatesToImport.count == 1 ? "" : "s")",
                icon: "square.and.arrow.down",
                style: .primary,
                isFullWidth: true,
                isDisabled: candidatesToImport.isEmpty
            ) {
                onStartImport()
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
    }

    // MARK: Helpers

    private var currentTagPills: [(text: String, color: Color)] {
        var pills: [(String, Color)] = []
        if let p = importState.selectedProcedure {
            pills.append((p, AppTheme.procedureColor(for: p)))
        }
        if let t = importState.selectedToothNumber {
            pills.append(("#\(t)", AppTheme.Colors.info))
        }
        if let s = importState.selectedStage {
            pills.append((PhotoMetadata.stageAbbreviation(for: s), metadataManager.stageColor(for: s)))
        }
        if let a = importState.selectedAngle {
            pills.append((a, AppTheme.angleColor(for: a)))
        }
        return pills
    }

    private func findPortfolioMatch() -> String? {
        guard let procedure = importState.selectedProcedure,
              let stage = importState.selectedStage,
              let angle = importState.selectedAngle else { return nil }

        for portfolio in metadataManager.portfolios {
            for requirement in portfolio.requirements {
                if requirement.procedure == procedure &&
                   requirement.stages.contains(stage) &&
                   requirement.angles.contains(angle) {
                    let currentCount = metadataManager.getPhotoCount(
                        for: requirement, stage: stage, angle: angle
                    )
                    let needed = requirement.angleCounts[angle] ?? 1
                    let willAdd = candidatesToImport.count

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
}

// MARK: - ImportCandidateCard

/// Card for a single import candidate in the review grid. Modeled after ReviewPhotoCard
/// but local to the Import feature so the two flows stay independent.
struct ImportCandidateCard: View {
    let candidate: ImportCandidate
    let index: Int
    let onToggleKeep: () -> Void
    let onRatingChange: (Int) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                photoContent

                Button(action: onToggleKeep) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(candidate.shouldKeep ? AppTheme.Colors.textTertiary.opacity(0.5) : AppTheme.Colors.error)
                        .background(Color.white.clipShape(Circle()))
                }
                .padding(AppTheme.Spacing.sm)
            }

            if candidate.loadError != nil {
                Text("Couldn't load")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.error)
            } else if candidate.shouldKeep {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { onRatingChange(star) }) {
                            Image(systemName: star <= candidate.rating ? "star.fill" : "star")
                                .font(.system(size: 20))
                                .foregroundStyle(star <= candidate.rating ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary)
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

    @ViewBuilder
    private var photoContent: some View {
        if let image = candidate.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .clipped()
                .cornerRadius(AppTheme.CornerRadius.medium)
                .opacity(candidate.shouldKeep ? 1.0 : 0.4)
        } else {
            ZStack {
                Rectangle()
                    .fill(AppTheme.Colors.surfaceSecondary)
                if candidate.loadError != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.Colors.error)
                } else {
                    ProgressView()
                }
            }
            .frame(height: 150)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
    }
}

// MARK: - ImportTagEditorSheet

/// Simplified tag editor for imports. Keeps the review screen independent of CaptureFlowView's
/// ReviewTagEditorSheet so the two flows can evolve separately.
struct ImportTagEditorSheet: View {
    @ObservedObject var importState: ImportFlowState
    @ObservedObject var metadataManager = MetadataManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    procedureSection
                    toothSection
                    stageSection
                    angleSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var procedureSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("PROCEDURE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledProcedureNames(), id: \.self) { procedure in
                        DPTagPill(
                            procedure,
                            color: AppTheme.procedureColor(for: procedure),
                            isSelected: importState.selectedProcedure == procedure
                        ) {
                            importState.selectedProcedure = procedure
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toothSection: some View {
        if importState.selectedProcedure != nil {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("TOOTH")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Picker("Tooth Number", selection: Binding(
                    get: { importState.selectedToothNumber },
                    set: { importState.selectedToothNumber = $0 }
                )) {
                    Text("—").tag(Int?.none)
                    ForEach(1...32, id: \.self) { number in
                        Text("\(number)").tag(Int?.some(number))
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                .clipped()
            }
        }
    }

    private var stageSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("STAGE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledStages()) { stage in
                        DPTagPill(
                            stage.name,
                            color: stage.color,
                            isSelected: importState.selectedStage == stage.name
                        ) {
                            importState.selectedStage = stage.name
                        }
                    }
                }
            }
        }
    }

    private var angleSection: some View {
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
                            isSelected: importState.selectedAngle == angle
                        ) {
                            importState.selectedAngle = angle
                        }
                    }
                }
            }
        }
    }
}
