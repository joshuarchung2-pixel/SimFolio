// PortfolioChecklistTab.swift
// Dental Portfolio - Portfolio Checklist Tab
//
// This tab shows an expandable checklist of all requirements, organized by procedure.
// Each requirement can be expanded to show stages and angles with completion status.
//
// Features:
// - Expandable requirement cards with progress indicators
// - Stage sections with colored headers
// - Angle rows with status icons and thumbnail stacks
// - Quick capture buttons for incomplete items
// - Auto-expand first incomplete requirement on appear

import SwiftUI
import Photos

// MARK: - PortfolioChecklistTab

/// Checklist tab showing expandable requirements with completion status
struct PortfolioChecklistTab: View {
    let portfolio: Portfolio

    @EnvironmentObject var router: NavigationRouter
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared

    // Track which requirements are expanded
    @State private var expandedRequirements: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Summary header
                checklistSummaryHeader

                // Requirement cards
                if portfolio.requirements.isEmpty {
                    emptyState
                } else {
                    ForEach(portfolio.requirements) { requirement in
                        RequirementChecklistCard(
                            requirement: requirement,
                            isExpanded: expandedRequirements.contains(requirement.id),
                            onToggleExpand: {
                                toggleExpansion(for: requirement.id)
                            },
                            onCapturePressed: { stage, angle in
                                navigateToCapture(requirement: requirement, stage: stage, angle: angle)
                            }
                        )
                    }
                }

                Spacer(minLength: 50)
            }
            .padding(.top, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .onAppear {
            // Auto-expand first incomplete requirement
            if expandedRequirements.isEmpty {
                if let firstIncomplete = findFirstIncompleteRequirement() {
                    expandedRequirements.insert(firstIncomplete)
                }
            }
        }
    }

    // MARK: - Summary Header

    var checklistSummaryHeader: some View {
        let stats = metadataManager.getPortfolioStats(portfolio)
        let completeCount = portfolio.requirements.filter { req in
            isRequirementComplete(req)
        }.count

        return HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("\(completeCount) of \(portfolio.requirements.count) requirements complete")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("\(stats.fulfilled) of \(stats.total) photos captured")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            // Expand/Collapse all button
            Button(action: toggleAllExpansion) {
                Text(expandedRequirements.count == portfolio.requirements.count ? "Collapse All" : "Expand All")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }

    var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.textTertiary)

            Text("No Requirements")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("This portfolio doesn't have any requirements yet.")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Helper Functions

    func toggleExpansion(for requirementId: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedRequirements.contains(requirementId) {
                expandedRequirements.remove(requirementId)
            } else {
                expandedRequirements.insert(requirementId)
            }
        }
        HapticsManager.shared.selectionChanged()
    }

    func toggleAllExpansion() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedRequirements.count == portfolio.requirements.count {
                expandedRequirements.removeAll()
            } else {
                expandedRequirements = Set(portfolio.requirements.map { $0.id })
            }
        }
        HapticsManager.shared.selectionChanged()
    }

    func findFirstIncompleteRequirement() -> String? {
        for requirement in portfolio.requirements {
            if !isRequirementComplete(requirement) {
                return requirement.id
            }
        }
        return nil
    }

    func isRequirementComplete(_ requirement: PortfolioRequirement) -> Bool {
        for stage in requirement.stages {
            for angle in requirement.angles {
                let count = metadataManager.getMatchingPhotoCount(
                    procedure: requirement.procedure,
                    stage: stage,
                    angle: angle
                )
                let needed = requirement.angleCounts[angle] ?? 1
                if count < needed {
                    return false
                }
            }
        }
        return true
    }

    func navigateToCapture(requirement: PortfolioRequirement, stage: String, angle: String) {
        dismiss()
        router.navigateToCapture(
            procedure: requirement.procedure,
            stage: stage,
            angle: angle,
            toothNumber: nil,
            forPortfolioId: portfolio.id
        )
    }
}

// MARK: - RequirementChecklistCard

/// Expandable card showing a single requirement with stages and angles
struct RequirementChecklistCard: View {
    let requirement: PortfolioRequirement
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCapturePressed: (String, String) -> Void // (stage, angle)

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Computed Properties

    var stats: (fulfilled: Int, total: Int) {
        var fulfilled = 0
        var total = 0

        for stage in requirement.stages {
            for angle in requirement.angles {
                let count = metadataManager.getMatchingPhotoCount(
                    procedure: requirement.procedure,
                    stage: stage,
                    angle: angle
                )
                let needed = requirement.angleCounts[angle] ?? 1
                fulfilled += min(count, needed)
                total += needed
            }
        }

        return (fulfilled, total)
    }

    var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    var isComplete: Bool {
        stats.fulfilled >= stats.total
    }

    var procedureColor: Color {
        AppTheme.procedureColor(for: requirement.procedure)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible header
            headerRow

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, AppTheme.Spacing.md)

                expandedContent
            }
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    // MARK: - Header Row

    var headerRow: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Procedure color indicator
                Circle()
                    .fill(procedureColor)
                    .frame(width: 16, height: 16)

                // Procedure name
                Text(requirement.procedure)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                // Progress ring
                DPProgressRing(
                    progress: progress,
                    size: 36,
                    lineWidth: 4,
                    foregroundColor: isComplete ? AppTheme.Colors.success : nil,
                    showLabel: false
                )

                // Fraction text
                Text("\(stats.fulfilled)/\(stats.total)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                    .frame(width: 45, alignment: .trailing)

                // Chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Expanded Content

    var expandedContent: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(requirement.stages, id: \.self) { stage in
                StageChecklistSection(
                    stage: stage,
                    requirement: requirement,
                    onCapturePressed: { angle in
                        onCapturePressed(stage, angle)
                    }
                )
            }
        }
        .padding(AppTheme.Spacing.md)
    }
}

// MARK: - StageChecklistSection

/// Section showing a stage header and its angle rows
struct StageChecklistSection: View {
    let stage: String
    let requirement: PortfolioRequirement
    let onCapturePressed: (String) -> Void // (angle)

    @ObservedObject var metadataManager = MetadataManager.shared

    var stageColor: Color {
        switch stage.lowercased() {
        case "preparation", "prep":
            return AppTheme.Colors.warning
        case "restoration", "resto":
            return AppTheme.Colors.success
        default:
            return AppTheme.Colors.textSecondary
        }
    }

    var stageIcon: String {
        switch stage.lowercased() {
        case "preparation", "prep":
            return "wrench.and.screwdriver"
        case "restoration", "resto":
            return "checkmark.seal"
        default:
            return "circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Stage header
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: stageIcon)
                    .font(.system(size: 14))
                    .foregroundColor(stageColor)

                Text(stage)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(stageColor)
            }
            .padding(.leading, AppTheme.Spacing.xs)

            // Angle rows
            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(requirement.angles, id: \.self) { angle in
                    AngleChecklistRow(
                        angle: angle,
                        stage: stage,
                        requirement: requirement,
                        onCapturePressed: {
                            onCapturePressed(angle)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - AngleChecklistRow

/// Row showing an angle with completion status, thumbnails, and capture button
struct AngleChecklistRow: View {
    let angle: String
    let stage: String
    let requirement: PortfolioRequirement
    let onCapturePressed: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared

    var currentCount: Int {
        metadataManager.getMatchingPhotoCount(
            procedure: requirement.procedure,
            stage: stage,
            angle: angle
        )
    }

    var neededCount: Int {
        requirement.angleCounts[angle] ?? 1
    }

    var isComplete: Bool {
        currentCount >= neededCount
    }

    var matchingAssets: [PHAsset] {
        // Get assets that match this procedure/stage/angle
        library.assets.filter { asset in
            if let metadata = metadataManager.getMetadata(for: asset.localIdentifier) {
                return metadata.procedure == requirement.procedure &&
                       metadata.stage == stage &&
                       metadata.angle == angle
            }
            return false
        }
        .prefix(3) // Only show up to 3 thumbnails
        .map { $0 }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Status icon
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)

            // Angle name
            Text(angle)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(isComplete ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                .strikethrough(isComplete, color: AppTheme.Colors.textSecondary)

            Spacer()

            // Thumbnail stack (if photos exist)
            if !matchingAssets.isEmpty {
                ThumbnailStack(assets: matchingAssets)
            }

            // Count text
            Text("\(currentCount)/\(neededCount)")
                .font(AppTheme.Typography.caption)
                .foregroundColor(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                .frame(width: 35, alignment: .trailing)

            // Camera button (if incomplete)
            if !isComplete {
                Button(action: {
                    HapticsManager.shared.lightTap()
                    onCapturePressed()
                }) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Spacer to maintain alignment when button is hidden
                Color.clear
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .background(
            isComplete
                ? AppTheme.Colors.success.opacity(0.05)
                : AppTheme.Colors.surfaceSecondary
        )
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - ThumbnailStack

/// Overlapping stack of photo thumbnails
struct ThumbnailStack: View {
    let assets: [PHAsset]

    private let thumbnailSize: CGFloat = 28
    private let overlap: CGFloat = 10

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                AsyncThumbnailView(asset: asset, size: thumbnailSize)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.surface, lineWidth: 2)
                    )
                    .zIndex(Double(assets.count - index)) // Stack order
            }
        }
    }
}

// MARK: - AsyncThumbnailView

/// Asynchronously loads and displays a photo thumbnail
struct AsyncThumbnailView: View {
    let asset: PHAsset
    let size: CGFloat

    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.surfaceSecondary)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: size * 2, height: size * 2) // 2x for retina

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PortfolioChecklistTab_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioChecklistTabPreviewContainer()
    }
}

struct PortfolioChecklistTabPreviewContainer: View {
    @StateObject private var router = NavigationRouter()

    var body: some View {
        NavigationView {
            PortfolioChecklistTab(
                portfolio: Portfolio(
                    name: "Restorative Dentistry Final",
                    createdDate: Date().addingTimeInterval(-86400 * 7),
                    dueDate: Date().addingTimeInterval(86400 * 5),
                    requirements: [
                        PortfolioRequirement(
                            procedure: "Class 1",
                            stages: ["Preparation", "Restoration"],
                            angles: ["Occlusal", "Buccal/Facial"]
                        ),
                        PortfolioRequirement(
                            procedure: "Class 2",
                            stages: ["Preparation", "Restoration"],
                            angles: ["Occlusal", "Proximal", "Buccal/Facial"]
                        ),
                        PortfolioRequirement(
                            procedure: "Crown",
                            stages: ["Preparation"],
                            angles: ["Buccal/Facial", "Lingual", "Occlusal", "Mesial", "Distal"]
                        )
                    ]
                )
            )
            .environmentObject(router)
            .navigationTitle("Checklist")
        }
    }
}

struct RequirementChecklistCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            RequirementChecklistCard(
                requirement: PortfolioRequirement(
                    procedure: "Class 1",
                    stages: ["Preparation", "Restoration"],
                    angles: ["Occlusal", "Buccal/Facial"]
                ),
                isExpanded: true,
                onToggleExpand: { },
                onCapturePressed: { _, _ in }
            )

            RequirementChecklistCard(
                requirement: PortfolioRequirement(
                    procedure: "Crown",
                    stages: ["Preparation"],
                    angles: ["Occlusal", "Buccal/Facial", "Lingual"]
                ),
                isExpanded: false,
                onToggleExpand: { },
                onCapturePressed: { _, _ in }
            )
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
