// PortfolioChecklistTab.swift
// SimFolio - Requirement Checklist Components
//
// Reusable expandable requirement card and its child components. Driven by the
// portfolio Overview tab (see `PortfolioDetailView.swift`), which owns expansion
// state and capture navigation.

import SwiftUI

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
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
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
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                // Fraction text
                Text("\(stats.fulfilled)/\(stats.total)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                    .frame(width: 45, alignment: .trailing)

                // Chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
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
                    .foregroundStyle(stageColor)

                Text(stage)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(stageColor)
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
    @ObservedObject var photoStorage = PhotoStorageService.shared

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

    var matchingRecords: [PhotoRecord] {
        // Get records that match this procedure/stage/angle
        photoStorage.records.filter { record in
            if let metadata = metadataManager.getMetadata(for: record.id.uuidString) {
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
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)

            // Angle name
            Text(angle)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(isComplete ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                .strikethrough(isComplete, color: AppTheme.Colors.textSecondary)

            Spacer()

            // Thumbnail stack (if photos exist)
            if !matchingRecords.isEmpty {
                ThumbnailStack(records: matchingRecords)
            }

            // Count text
            Text("\(currentCount)/\(neededCount)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                .frame(width: 35, alignment: .trailing)

            // Camera button (if incomplete)
            if !isComplete {
                Button(action: {
                    onCapturePressed()
                }) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
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
    let records: [PhotoRecord]

    private let thumbnailSize: CGFloat = 28
    private let overlap: CGFloat = 10

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                AsyncThumbnailView(assetId: record.id.uuidString, size: thumbnailSize)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.surface, lineWidth: 2)
                    )
                    .zIndex(Double(records.count - index)) // Stack order
            }
        }
    }
}

// MARK: - AsyncThumbnailView

/// Asynchronously loads and displays a photo thumbnail
struct AsyncThumbnailView: View {
    let assetId: String
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
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == assetId {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        if let uuid = UUID(uuidString: assetId) {
            image = PhotoStorageService.shared.loadEditedThumbnail(id: uuid)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
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
