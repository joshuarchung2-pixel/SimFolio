// PortfolioPhotosTab.swift
// Dental Portfolio - Portfolio Photos Tab
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
import Photos

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
    @ObservedObject var library = PhotoLibraryManager.shared

    @State private var groupBy: PhotosGroupBy = .byRequirement
    @State private var selectedAsset: PHAsset? = nil
    @State private var showPhotoDetail: Bool = false

    // MARK: - Computed Properties

    /// All assets that match any requirement in this portfolio
    var matchingAssets: [PHAsset] {
        library.assets.filter { asset in
            guard let metadata = metadataManager.getMetadata(for: asset.localIdentifier) else {
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

    /// Assets grouped by requirement (procedure)
    var assetsByRequirement: [(requirement: PortfolioRequirement, assets: [PHAsset])] {
        portfolio.requirements.compactMap { requirement in
            let assets = matchingAssets.filter { asset in
                guard let metadata = metadataManager.getMetadata(for: asset.localIdentifier) else {
                    return false
                }
                return metadata.procedure == requirement.procedure
            }

            if assets.isEmpty {
                return nil
            }
            return (requirement, assets)
        }
    }

    /// Assets grouped by date
    var assetsByDate: [(date: Date, assets: [PHAsset])] {
        let calendar = Calendar.current

        // Group assets by day
        let grouped = Dictionary(grouping: matchingAssets) { asset in
            calendar.startOfDay(for: asset.creationDate ?? Date())
        }

        // Sort by date descending (newest first)
        return grouped
            .map { (date: $0.key, assets: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var photoCount: Int {
        matchingAssets.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Group by picker
            groupByPicker

            // Content
            if matchingAssets.isEmpty {
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
            if let asset = selectedAsset {
                PortfolioPhotoDetailSheet(
                    asset: asset,
                    allAssets: matchingAssets,
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
                    HapticsManager.shared.selectionChanged()
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
                    .foregroundColor(
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
                .foregroundColor(AppTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.Colors.textTertiary)

            Text("No Photos Yet")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("Photos matching this portfolio's requirements will appear here.")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Grouped Content

    var requirementGroupedContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ForEach(assetsByRequirement, id: \.requirement.id) { group in
                RequirementPhotoSection(
                    requirement: group.requirement,
                    assets: group.assets,
                    onPhotoTapped: { asset in
                        selectedAsset = asset
                        showPhotoDetail = true
                    }
                )
            }
        }
    }

    var dateGroupedContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ForEach(assetsByDate, id: \.date) { group in
                DatePhotoSection(
                    date: group.date,
                    assets: group.assets,
                    onPhotoTapped: { asset in
                        selectedAsset = asset
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
    let assets: [PHAsset]
    let onPhotoTapped: (PHAsset) -> Void

    @ObservedObject var metadataManager = MetadataManager.shared

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
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("(\(assets.count))")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            PortfolioPhotoGrid(
                assets: assets,
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
    let assets: [PHAsset]
    let onPhotoTapped: (PHAsset) -> Void

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
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("(\(assets.count))")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            PortfolioPhotoGrid(
                assets: assets,
                onPhotoTapped: onPhotoTapped
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - PortfolioPhotoGrid

/// Grid layout for portfolio photos
struct PortfolioPhotoGrid: View {
    let assets: [PHAsset]
    let onPhotoTapped: (PHAsset) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(assets, id: \.localIdentifier) { asset in
                PortfolioPhotoThumbnail(
                    asset: asset,
                    onTap: {
                        onPhotoTapped(asset)
                    }
                )
            }
        }
    }
}

// MARK: - PortfolioPhotoThumbnail

/// Thumbnail view for a portfolio photo with metadata badge
struct PortfolioPhotoThumbnail: View {
    let asset: PHAsset
    let onTap: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var image: UIImage? = nil
    @State private var isPressed: Bool = false

    var metadata: PhotoMetadata? {
        metadataManager.getMetadata(for: asset.localIdentifier)
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
            let abbrev = angleAbbreviation(angle)
            parts.append(abbrev)
        }

        return parts.isEmpty ? nil : parts.joined(separator: "·")
    }

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
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

        let targetSize = CGSize(width: 200, height: 200)

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

    private func angleAbbreviation(_ angle: String) -> String {
        switch angle.lowercased() {
        case "occlusal": return "O"
        case "buccal", "buccal/facial": return "B"
        case "lingual": return "L"
        case "mesial": return "M"
        case "distal": return "D"
        case "facial": return "F"
        case "incisal": return "I"
        case "proximal": return "P"
        default: return String(angle.prefix(1)).uppercased()
        }
    }
}

// MARK: - PortfolioPhotoDetailSheet

/// Full-screen photo detail view with swipe navigation
struct PortfolioPhotoDetailSheet: View {
    let asset: PHAsset
    let allAssets: [PHAsset]
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var currentIndex: Int = 0

    var currentAsset: PHAsset {
        allAssets[currentIndex]
    }

    var metadata: PhotoMetadata? {
        metadataManager.getMetadata(for: currentAsset.localIdentifier)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                // Swipeable photo viewer
                TabView(selection: $currentIndex) {
                    ForEach(Array(allAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        PortfolioPhotoDetailImage(asset: asset)
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
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("\(currentIndex + 1) / \(allAssets.count)")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(.white)

                        Spacer()

                        // Share button
                        Button(action: sharePhoto) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
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
            // Set initial index to the selected asset
            if let index = allAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
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
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= rating ? .yellow : .gray)
                        }
                    }
                }

                Spacer()

                if let date = currentAsset.creationDate {
                    Text(formatDate(date))
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
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
        // Load full image and share
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        manager.requestImage(
            for: currentAsset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .default,
            options: options
        ) { image, _ in
            guard let image = image else { return }

            DispatchQueue.main.async {
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
    }
}

// MARK: - PortfolioPhotoDetailImage

/// Full-screen photo view with pinch-to-zoom and double-tap zoom
struct PortfolioPhotoDetailImage: View {
    let asset: PHAsset

    @State private var image: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }

    private func loadFullImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
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
                        .foregroundColor(
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
