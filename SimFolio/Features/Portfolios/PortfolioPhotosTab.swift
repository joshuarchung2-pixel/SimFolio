// PortfolioPhotosTab.swift
// SimFolio - Portfolio Photos Tab
//
// This tab shows all photos that match the portfolio's requirements.
// Photos can be grouped by requirement (procedure) or by date.
//
// Features:
// - Group by picker (By Requirement / By Date)
// - Photo grid with 3 columns
// - Thumbnail badges showing stage and angle
// - Photo detail sheet with swipe navigation
// - Pinch to zoom and double-tap zoom
// - Share functionality

import SwiftUI

// MARK: - PhotosGroupBy

/// Enum for photo grouping options
enum PhotosGroupBy: String, CaseIterable, Identifiable {
    case byRequirement = "By Requirement"
    case byDate = "By Date"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .byRequirement: return "folder"
        case .byDate: return "calendar"
        }
    }
}

// MARK: - PortfolioPhotosTab

/// Tab showing all photos matching portfolio requirements
struct PortfolioPhotosTab: View {
    let portfolio: Portfolio

    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var photoStorage = PhotoStorageService.shared

    @State private var groupBy: PhotosGroupBy = .byRequirement
    @State private var selectedRecord: PhotoRecord? = nil
    @State private var showPhotoDetail: Bool = false

    // MARK: - Computed Properties

    /// All records that match any requirement in this portfolio
    var matchingRecords: [PhotoRecord] {
        photoStorage.records.filter { record in
            guard let metadata = metadataManager.getMetadata(for: record.id.uuidString) else {
                return false
            }

            // Check if this photo matches any requirement
            for requirement in portfolio.requirements {
                if metadata.procedure == requirement.procedure {
                    // Check if stage matches (if metadata has stage)
                    if let stage = metadata.stage, !requirement.stages.contains(stage) {
                        continue
                    }
                    // Check if angle matches (if metadata has angle)
                    if let angle = metadata.angle, !requirement.angles.contains(angle) {
                        continue
                    }
                    return true
                }
            }
            return false
        }
    }

    /// Records grouped by requirement (procedure)
    var recordsByRequirement: [(requirement: PortfolioRequirement, records: [PhotoRecord])] {
        portfolio.requirements.compactMap { requirement in
            let records = matchingRecords.filter { record in
                guard let metadata = metadataManager.getMetadata(for: record.id.uuidString) else {
                    return false
                }
                return metadata.procedure == requirement.procedure
            }

            if records.isEmpty {
                return nil
            }
            return (requirement, records)
        }
    }

    /// Records grouped by date
    var recordsByDate: [(date: Date, records: [PhotoRecord])] {
        let calendar = Calendar.current

        // Group records by day
        let grouped = Dictionary(grouping: matchingRecords) { record in
            calendar.startOfDay(for: record.createdDate)
        }

        // Sort by date descending (newest first)
        return grouped
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var photoCount: Int {
        matchingRecords.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Group by picker
            groupByPicker

            // Content
            if matchingRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Photo count header
                        photoCountHeader

                        // Grouped content
                        switch groupBy {
                        case .byRequirement:
                            requirementGroupedContent
                        case .byDate:
                            dateGroupedContent
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(.top, AppTheme.Spacing.md)
                }
            }
        }
        .sheet(isPresented: $showPhotoDetail) {
            if let record = selectedRecord {
                PortfolioPhotoDetailSheet(
                    record: record,
                    allRecords: matchingRecords,
                    isPresented: $showPhotoDetail
                )
            }
        }
    }

    // MARK: - Subviews

    var groupByPicker: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(PhotosGroupBy.allCases) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        groupBy = option
                    }
                }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12))
                        Text(option.rawValue)
                            .font(AppTheme.Typography.caption)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .background(
                        groupBy == option
                            ? AppTheme.Colors.primary
                            : AppTheme.Colors.surfaceSecondary
                    )
                    .foregroundStyle(
                        groupBy == option
                            ? .white
                            : AppTheme.Colors.textSecondary
                    )
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
    }

    var photoCountHeader: some View {
        HStack {
            Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            Text("No Photos Yet")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Photos matching this portfolio's requirements will appear here.")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Grouped Content

    var requirementGroupedContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ForEach(recordsByRequirement, id: \.requirement.id) { group in
                RequirementPhotoSection(
                    requirement: group.requirement,
                    records: group.records,
                    onPhotoTapped: { record in
                        selectedRecord = record
                        showPhotoDetail = true
                    }
                )
            }
        }
    }

    var dateGroupedContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ForEach(recordsByDate, id: \.date) { group in
                DatePhotoSection(
                    date: group.date,
                    records: group.records,
                    onPhotoTapped: { record in
                        selectedRecord = record
                        showPhotoDetail = true
                    }
                )
            }
        }
    }
}

// MARK: - RequirementPhotoSection

/// Section showing photos for a specific requirement/procedure
struct RequirementPhotoSection: View {
    let requirement: PortfolioRequirement
    let records: [PhotoRecord]
    let onPhotoTapped: (PhotoRecord) -> Void

    var procedureColor: Color {
        AppTheme.procedureColor(for: requirement.procedure)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Section header
            HStack(spacing: AppTheme.Spacing.sm) {
                Circle()
                    .fill(procedureColor)
                    .frame(width: 12, height: 12)

                Text(requirement.procedure)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("(\(records.count))")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            PortfolioPhotoGrid(
                records: records,
                onPhotoTapped: onPhotoTapped
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - DatePhotoSection

/// Section showing photos for a specific date
struct DatePhotoSection: View {
    let date: Date
    let records: [PhotoRecord]
    let onPhotoTapped: (PhotoRecord) -> Void

    var formattedDate: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Section header
            HStack {
                Text(formattedDate)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("(\(records.count))")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            PortfolioPhotoGrid(
                records: records,
                onPhotoTapped: onPhotoTapped
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - PortfolioPhotoGrid

/// Grid layout for portfolio photos
struct PortfolioPhotoGrid: View {
    let records: [PhotoRecord]
    let onPhotoTapped: (PhotoRecord) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.xxs),
        GridItem(.flexible(), spacing: AppTheme.Spacing.xxs),
        GridItem(.flexible(), spacing: AppTheme.Spacing.xxs)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.xxs) {
            ForEach(records, id: \.id) { record in
                PortfolioPhotoThumbnail(
                    record: record,
                    onTap: {
                        onPhotoTapped(record)
                    }
                )
            }
        }
    }
}

// MARK: - PortfolioPhotoThumbnail

/// Thumbnail view for a portfolio photo with metadata badge
struct PortfolioPhotoThumbnail: View {
    let record: PhotoRecord
    let onTap: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var image: UIImage? = nil

    var metadata: PhotoMetadata? {
        metadataManager.getMetadata(for: record.id.uuidString)
    }

    /// Short label showing stage initial and angle abbreviation
    var metadataLabel: String? {
        guard let metadata = metadata else { return nil }

        var parts: [String] = []

        // Stage initial (P for Preparation, R for Restoration)
        if let stage = metadata.stage {
            let initial = String(stage.prefix(1)).uppercased()
            parts.append(initial)
        }

        // Angle abbreviation
        if let angle = metadata.angle {
            let abbrev = PhotoMetadata.angleAbbreviation(for: angle)
            parts.append(abbrev)
        }

        return parts.isEmpty ? nil : parts.joined(separator: "·")
    }

    var body: some View {
        Button(action: {
            onTap()
        }) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    // Thumbnail image
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(AppTheme.Colors.surfaceSecondary)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }

                    // Metadata overlay badge
                    if let label = metadataLabel {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                            .padding(.vertical, AppTheme.Spacing.xxs)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(AppTheme.CornerRadius.xs)
                            .padding(AppTheme.Spacing.xs)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PhotoThumbnailButtonStyle())
        .onAppear {
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this record was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == record.id.uuidString {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadEditedThumbnail(id: record.id)
    }

}

// MARK: - Photo Thumbnail Button Style

/// A button style for photo thumbnails that scales on press
struct PhotoThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - PortfolioPhotoDetailSheet

/// Full-screen photo detail view with swipe navigation
struct PortfolioPhotoDetailSheet: View {
    let record: PhotoRecord
    let allRecords: [PhotoRecord]
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var currentIndex: Int = 0

    var currentRecord: PhotoRecord {
        allRecords[currentIndex]
    }

    var metadata: PhotoMetadata? {
        metadataManager.getMetadata(for: currentRecord.id.uuidString)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                // Swipeable photo viewer
                TabView(selection: $currentIndex) {
                    ForEach(Array(allRecords.enumerated()), id: \.element.id) { index, rec in
                        ZoomablePhotoView(record: rec)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("\(currentIndex + 1) / \(allRecords.count)")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.white)

                        Spacer()

                        // Share button
                        Button(action: sharePhoto) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)

                    Spacer()

                    // Bottom metadata card
                    if let metadata = metadata {
                        metadataCard(metadata)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Set initial index to the selected record
            if let index = allRecords.firstIndex(where: { $0.id == record.id }) {
                currentIndex = index
            }
        }
    }

    func metadataCard(_ metadata: PhotoMetadata) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Tags row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if let procedure = metadata.procedure {
                        DPTagPill(
                            procedure,
                            color: AppTheme.procedureColor(for: procedure),
                            size: .medium
                        )
                    }

                    if let stage = metadata.stage {
                        DPTagPill(
                            stage,
                            color: stage.lowercased().contains("prep") ? AppTheme.Colors.warning : AppTheme.Colors.success,
                            size: .medium
                        )
                    }

                    if let angle = metadata.angle {
                        DPTagPill(
                            angle,
                            color: .purple,
                            size: .medium
                        )
                    }

                    if let toothNumber = metadata.toothNumber {
                        DPTagPill(
                            "Tooth #\(toothNumber)",
                            color: AppTheme.Colors.primary,
                            size: .medium
                        )
                    }
                }
            }

            // Rating and date row
            HStack {
                if let rating = metadata.rating, rating > 0 {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(star <= rating ? AppTheme.Colors.warning : .gray)
                        }
                    }
                }

                Spacer()

                Text(formatDate(currentRecord.createdDate))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(Color.white)
        )
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func sharePhoto() {
        // Load full image (with persisted edits applied) and share
        guard let image = PhotoStorageService.shared.loadEditedImage(id: currentRecord.id) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}


// MARK: - Preview Provider

#if DEBUG
struct PortfolioPhotosTab_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PortfolioPhotosTab(
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
                            angles: ["Occlusal", "Proximal"]
                        )
                    ]
                )
            )
            .navigationTitle("Photos")
        }
    }
}

struct PhotosGroupByPicker_Previews: PreviewProvider {
    @State static var groupBy: PhotosGroupBy = .byRequirement

    static var previews: some View {
        VStack {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(PhotosGroupBy.allCases) { option in
                    Button(action: {
                        groupBy = option
                    }) {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: option.icon)
                                .font(.system(size: 12))
                            Text(option.rawValue)
                                .font(AppTheme.Typography.caption)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            groupBy == option
                                ? AppTheme.Colors.primary
                                : AppTheme.Colors.surfaceSecondary
                        )
                        .foregroundStyle(
                            groupBy == option
                                ? .white
                                : AppTheme.Colors.textSecondary
                        )
                        .cornerRadius(AppTheme.CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
