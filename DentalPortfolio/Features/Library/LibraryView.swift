// LibraryView.swift
// Photo library with filters and organization
//
// Phase 4 - Library Redesign
// A cleaner, filter-based library view that shows:
// - Top-level procedure folders with photo counts and stats
// - Filter chips bar for active filters
// - Procedure detail view with photos grouped by tooth and stage
// - Improved photo detail view with metadata editing

import SwiftUI
import Photos

// MARK: - LibraryViewModel

/// View model for LibraryView managing view state, selection, filtering, and sorting
class LibraryViewModel: ObservableObject {

    // MARK: - View Mode

    /// Current view mode for the library
    enum ViewMode: Equatable {
        /// Top-level list of procedure folders
        case procedures
        /// Photos for a specific procedure
        case procedureDetail(String)
        /// Flat grid of all photos
        case allPhotos
    }

    // MARK: - Sort Order

    /// Sort order options for photos
    enum SortOrder: String, CaseIterable {
        case dateNewest = "Newest First"
        case dateOldest = "Oldest First"
        case procedure = "By Procedure"
        case rating = "By Rating"

        /// SF Symbol icon for the sort order
        var icon: String {
            switch self {
            case .dateNewest: return "arrow.down"
            case .dateOldest: return "arrow.up"
            case .procedure: return "folder"
            case .rating: return "star"
            }
        }
    }

    // MARK: - Published Properties

    /// Current view mode
    @Published var viewMode: ViewMode = .procedures

    /// Whether selection mode is active
    @Published var isSelectionMode: Bool = false

    /// Set of selected asset identifiers
    @Published var selectedAssetIds: Set<String> = []

    /// Current sort order
    @Published var sortOrder: SortOrder = .dateNewest

    /// Loading state
    @Published var isLoading: Bool = false

    /// Search text for filtering
    @Published var searchText: String = ""

    // MARK: - Filtering Methods

    /// Filter assets based on current LibraryFilter
    /// - Parameters:
    ///   - assets: All assets to filter
    ///   - metadata: MetadataManager instance
    ///   - filter: Current filter configuration
    /// - Returns: Filtered array of assets
    func filteredAssets(
        from assets: [PHAsset],
        metadata: MetadataManager,
        filter: LibraryFilter
    ) -> [PHAsset] {
        var result = assets

        // Filter by procedure
        if !filter.procedures.isEmpty {
            result = result.filter { asset in
                guard let meta = metadata.getMetadata(for: asset.localIdentifier),
                      let procedure = meta.procedure else {
                    return false
                }
                return filter.procedures.contains(procedure)
            }
        }

        // Filter by stage
        if !filter.stages.isEmpty {
            result = result.filter { asset in
                guard let meta = metadata.getMetadata(for: asset.localIdentifier),
                      let stage = meta.stage else {
                    return false
                }
                return filter.stages.contains(stage)
            }
        }

        // Filter by angle
        if !filter.angles.isEmpty {
            result = result.filter { asset in
                guard let meta = metadata.getMetadata(for: asset.localIdentifier),
                      let angle = meta.angle else {
                    return false
                }
                return filter.angles.contains(angle)
            }
        }

        // Filter by minimum rating
        if let minRating = filter.minimumRating {
            result = result.filter { asset in
                guard let rating = metadata.getRating(for: asset.localIdentifier) else {
                    return false
                }
                return rating >= minRating
            }
        }

        // Filter by date range
        if let dateRange = filter.dateRange {
            let dates = dateRange.dates
            result = result.filter { asset in
                guard let creationDate = asset.creationDate else {
                    return false
                }
                return creationDate >= dates.start && creationDate <= dates.end
            }
        }

        // Filter by portfolio (assets matching portfolio requirements)
        if let portfolioId = filter.portfolioId {
            // Get portfolio and filter assets that match its requirements
            if let portfolio = metadata.portfolios.first(where: { $0.id == portfolioId }) {
                let proceduresInPortfolio = Set(portfolio.requirements.map { $0.procedure })
                result = result.filter { asset in
                    guard let meta = metadata.getMetadata(for: asset.localIdentifier),
                          let procedure = meta.procedure else {
                        return false
                    }
                    return proceduresInPortfolio.contains(procedure)
                }
            }
        }

        // Apply search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { asset in
                guard let meta = metadata.getMetadata(for: asset.localIdentifier) else {
                    return false
                }
                // Search in procedure, stage, angle, and tooth number
                if let procedure = meta.procedure, procedure.lowercased().contains(searchLower) {
                    return true
                }
                if let stage = meta.stage, stage.lowercased().contains(searchLower) {
                    return true
                }
                if let angle = meta.angle, angle.lowercased().contains(searchLower) {
                    return true
                }
                if let toothNumber = meta.toothNumber, "\(toothNumber)".contains(searchLower) {
                    return true
                }
                return false
            }
        }

        // Apply sort order
        result = sortAssets(result, metadata: metadata)

        return result
    }

    /// Sort assets based on current sort order
    private func sortAssets(_ assets: [PHAsset], metadata: MetadataManager) -> [PHAsset] {
        switch sortOrder {
        case .dateNewest:
            return assets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .dateOldest:
            return assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .procedure:
            return assets.sorted { asset1, asset2 in
                let proc1 = metadata.getMetadata(for: asset1.localIdentifier)?.procedure ?? ""
                let proc2 = metadata.getMetadata(for: asset2.localIdentifier)?.procedure ?? ""
                if proc1 == proc2 {
                    return (asset1.creationDate ?? .distantPast) > (asset2.creationDate ?? .distantPast)
                }
                return proc1 < proc2
            }
        case .rating:
            return assets.sorted { asset1, asset2 in
                let rating1 = metadata.getRating(for: asset1.localIdentifier) ?? 0
                let rating2 = metadata.getRating(for: asset2.localIdentifier) ?? 0
                if rating1 == rating2 {
                    return (asset1.creationDate ?? .distantPast) > (asset2.creationDate ?? .distantPast)
                }
                return rating1 > rating2
            }
        }
    }

    // MARK: - Grouping Methods

    /// Group assets by procedure type
    /// - Parameters:
    ///   - assets: Assets to group
    ///   - metadata: MetadataManager instance
    /// - Returns: Dictionary of procedure name to assets
    func assetsByProcedure(
        from assets: [PHAsset],
        metadata: MetadataManager
    ) -> [String: [PHAsset]] {
        var grouped: [String: [PHAsset]] = [:]

        for asset in assets {
            let procedure: String
            if let meta = metadata.getMetadata(for: asset.localIdentifier),
               let proc = meta.procedure {
                procedure = proc
            } else {
                procedure = "Untagged"
            }

            if grouped[procedure] == nil {
                grouped[procedure] = []
            }
            grouped[procedure]?.append(asset)
        }

        return grouped
    }

    /// Get sorted list of procedure names for display
    /// - Parameters:
    ///   - assets: Assets to analyze
    ///   - metadata: MetadataManager instance
    /// - Returns: Sorted array of procedure names
    func sortedProcedureNames(
        from assets: [PHAsset],
        metadata: MetadataManager
    ) -> [String] {
        let grouped = assetsByProcedure(from: assets, metadata: metadata)
        var names = Array(grouped.keys)

        // Sort with base procedures first, then alphabetically, with Untagged last
        names.sort { name1, name2 in
            if name1 == "Untagged" { return false }
            if name2 == "Untagged" { return true }

            let baseProcs = MetadataManager.baseProcedures
            let isBase1 = baseProcs.contains(name1)
            let isBase2 = baseProcs.contains(name2)

            if isBase1 && !isBase2 { return true }
            if !isBase1 && isBase2 { return false }

            return name1 < name2
        }

        return names
    }

    // MARK: - Selection Methods

    /// Toggle selection state for an asset
    /// - Parameter assetId: The asset's local identifier
    func toggleSelection(for assetId: String) {
        if selectedAssetIds.contains(assetId) {
            selectedAssetIds.remove(assetId)
        } else {
            selectedAssetIds.insert(assetId)
        }
    }

    /// Select all provided assets
    /// - Parameter assets: Assets to select
    func selectAll(assets: [PHAsset]) {
        selectedAssetIds = Set(assets.map { $0.localIdentifier })
    }

    /// Clear all selections
    func clearSelection() {
        selectedAssetIds.removeAll()
    }

    /// Exit selection mode and clear selections
    func exitSelectionMode() {
        isSelectionMode = false
        selectedAssetIds.removeAll()
    }

    // MARK: - Navigation Methods

    /// Navigate to procedure detail view
    /// - Parameter procedure: The procedure name to show
    func showProcedure(_ procedure: String) {
        viewMode = .procedureDetail(procedure)
    }

    /// Navigate to all photos grid view
    func showAllPhotos() {
        viewMode = .allPhotos
    }

    /// Go back to procedures list
    func goBack() {
        viewMode = .procedures
        exitSelectionMode()
    }
}

// MARK: - LibraryView

/// Main library view with procedure folders, filters, and photo organization
struct LibraryView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var showFilterSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter chips bar (only if filters active)
                    if !router.libraryFilter.isEmpty {
                        FilterChipsBar(filter: $router.libraryFilter)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Content based on view mode
                    Group {
                        switch viewModel.viewMode {
                        case .procedures:
                            ProceduresListView(viewModel: viewModel)
                        case .procedureDetail(let procedure):
                            ProcedureDetailView(procedure: procedure, viewModel: viewModel)
                        case .allPhotos:
                            AllPhotosGridView(viewModel: viewModel)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.viewMode)

                    // Selection action bar (only in selection mode)
                    if viewModel.isSelectionMode {
                        SelectionActionBar(
                            selectedCount: viewModel.selectedAssetIds.count,
                            onDelete: handleDeleteSelected,
                            onShare: handleShareSelected,
                            onAddToPortfolio: handleAddToPortfolio
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.viewMode != .procedures {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.goBack()
                            }
                        }) {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: "chevron.left")
                                Text("Library")
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        // Filter button
                        Button(action: { showFilterSheet = true }) {
                            Image(systemName: router.libraryFilter.isEmpty
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                                .foregroundColor(AppTheme.Colors.primary)
                        }

                        // Sort menu
                        Menu {
                            ForEach(LibraryViewModel.SortOrder.allCases, id: \.self) { order in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.sortOrder = order
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: order.icon)
                                        Text(order.rawValue)
                                        if viewModel.sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(AppTheme.Colors.primary)
                        }

                        // Selection mode toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if viewModel.isSelectionMode {
                                    viewModel.exitSelectionMode()
                                } else {
                                    viewModel.isSelectionMode = true
                                }
                            }
                        }) {
                            Text(viewModel.isSelectionMode ? "Done" : "Select")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                LibraryFilterSheet(filter: $router.libraryFilter)
            }
            .onAppear {
                library.fetchAssets()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Computed Properties

    /// Navigation title based on current view mode
    var navigationTitle: String {
        switch viewModel.viewMode {
        case .procedures:
            return "Library"
        case .procedureDetail(let procedure):
            return procedure
        case .allPhotos:
            return "All Photos"
        }
    }

    // MARK: - Action Handlers

    /// Handle deletion of selected assets
    func handleDeleteSelected() {
        // TODO: Implement delete confirmation and action
        print("Delete \(viewModel.selectedAssetIds.count) selected photos")
    }

    /// Handle sharing of selected assets
    func handleShareSelected() {
        // TODO: Implement share sheet
        let ids = Array(viewModel.selectedAssetIds)
        router.presentSheet(.shareSheet(photoIds: ids))
    }

    /// Handle adding selected assets to a portfolio
    func handleAddToPortfolio() {
        // TODO: Implement portfolio selection sheet
        print("Add \(viewModel.selectedAssetIds.count) photos to portfolio")
    }
}

// MARK: - FilterChipsBar

/// Horizontal bar displaying active filter chips that can be removed
struct FilterChipsBar: View {
    @Binding var filter: LibraryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Procedure filters
                ForEach(Array(filter.procedures), id: \.self) { procedure in
                    DPTagPill(
                        procedure,
                        color: AppTheme.procedureColor(for: procedure),
                        size: .small,
                        showRemoveButton: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.procedures.remove(procedure)
                            }
                        }
                    )
                }

                // Stage filters
                ForEach(Array(filter.stages), id: \.self) { stage in
                    DPTagPill(
                        stage,
                        color: AppTheme.Colors.secondary,
                        size: .small,
                        showRemoveButton: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.stages.remove(stage)
                            }
                        }
                    )
                }

                // Angle filters
                ForEach(Array(filter.angles), id: \.self) { angle in
                    DPTagPill(
                        angle,
                        color: AppTheme.Colors.secondary,
                        size: .small,
                        showRemoveButton: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.angles.remove(angle)
                            }
                        }
                    )
                }

                // Rating filter
                if let rating = filter.minimumRating {
                    DPTagPill(
                        "\(rating)+ Stars",
                        color: AppTheme.Colors.warning,
                        size: .small,
                        showRemoveButton: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.minimumRating = nil
                            }
                        }
                    )
                }

                // Date range filter
                if let dateRange = filter.dateRange {
                    DPTagPill(
                        dateRange.displayName,
                        color: AppTheme.Colors.primary,
                        size: .small,
                        showRemoveButton: true,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter.dateRange = nil
                            }
                        }
                    )
                }

                // Clear all button (if multiple filters active)
                if filter.activeFilterCount > 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filter.reset()
                        }
                    }) {
                        Text("Clear All")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.error)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 2)
    }
}

// MARK: - ProceduresListView

/// List view showing procedure folders with photo counts and stats
struct ProceduresListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        let filteredAssets = viewModel.filteredAssets(
            from: library.assets,
            metadata: metadataManager,
            filter: router.libraryFilter
        )
        let procedureNames = viewModel.sortedProcedureNames(
            from: filteredAssets,
            metadata: metadataManager
        )
        let groupedAssets = viewModel.assetsByProcedure(
            from: filteredAssets,
            metadata: metadataManager
        )

        if procedureNames.isEmpty {
            DPEmptyState(
                icon: "photo.on.rectangle.angled",
                title: "No Photos Yet",
                message: "Start capturing your dental work to build your library.",
                actionTitle: "Take Photo"
            ) {
                router.navigateToCapture()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.sm) {
                    // All Photos row
                    AllPhotosRow(
                        photoCount: filteredAssets.count,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showAllPhotos()
                            }
                        }
                    )
                    .padding(.horizontal, AppTheme.Spacing.md)

                    Divider()
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.xs)

                    // Procedure folders
                    ForEach(procedureNames, id: \.self) { procedure in
                        let assets = groupedAssets[procedure] ?? []
                        ProcedureFolderRow(
                            procedure: procedure,
                            photoCount: assets.count,
                            assets: assets,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.showProcedure(procedure)
                                }
                            }
                        )
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - AllPhotosRow

/// Row showing "All Photos" option with count
struct AllPhotosRow: View {
    let photoCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            DPCard(padding: AppTheme.Spacing.md, shadowStyle: .small) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }

                    // Text
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("All Photos")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("\(photoCount) photos")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ProcedureFolderRow

/// Row displaying a procedure folder with photo count and preview thumbnails
struct ProcedureFolderRow: View {
    let procedure: String
    let photoCount: Int
    let assets: [PHAsset]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            DPCard(padding: AppTheme.Spacing.md, shadowStyle: .small) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Procedure color indicator
                    ZStack {
                        Circle()
                            .fill(AppTheme.procedureColor(for: procedure).opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "folder.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.procedureColor(for: procedure))
                    }

                    // Text info
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(procedure)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("\(photoCount) \(photoCount == 1 ? "photo" : "photos")")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Preview thumbnails (up to 3)
                    HStack(spacing: -8) {
                        ForEach(0..<min(3, assets.count), id: \.self) { index in
                            ThumbnailView(asset: assets[index])
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppTheme.Colors.surface, lineWidth: 2)
                                )
                                .zIndex(Double(3 - index))
                        }
                    }

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ThumbnailView

/// Async thumbnail loader for PHAsset
struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

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
        PhotoLibraryManager.shared.requestThumbnail(for: asset, size: CGSize(width: 100, height: 100)) { loadedImage in
            self.image = loadedImage
        }
    }
}

// MARK: - ProcedureDetailView

/// Detail view showing photos for a specific procedure, grouped by tooth and stage
struct ProcedureDetailView: View {
    let procedure: String
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        let allFiltered = viewModel.filteredAssets(
            from: library.assets,
            metadata: metadataManager,
            filter: router.libraryFilter
        )
        let procedureAssets = allFiltered.filter { asset in
            let meta = metadataManager.getMetadata(for: asset.localIdentifier)
            return meta?.procedure == procedure || (procedure == "Untagged" && meta?.procedure == nil)
        }

        if procedureAssets.isEmpty {
            DPEmptyState(
                icon: "folder",
                title: "No Photos",
                message: "No photos found for \(procedure).",
                actionTitle: "Take Photo"
            ) {
                router.navigateToCapture(procedure: procedure)
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs),
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs),
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs)
                    ],
                    spacing: AppTheme.Spacing.xs
                ) {
                    ForEach(procedureAssets, id: \.localIdentifier) { asset in
                        PhotoGridItem(
                            asset: asset,
                            isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                            isSelectionMode: viewModel.isSelectionMode,
                            onTap: {
                                if viewModel.isSelectionMode {
                                    viewModel.toggleSelection(for: asset.localIdentifier)
                                } else {
                                    router.navigateToPhotoDetail(id: asset.localIdentifier)
                                }
                            }
                        )
                    }
                }
                .padding(AppTheme.Spacing.sm)
            }
        }
    }
}

// MARK: - AllPhotosGridView

/// Grid view showing all photos in the library
struct AllPhotosGridView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        let filteredAssets = viewModel.filteredAssets(
            from: library.assets,
            metadata: metadataManager,
            filter: router.libraryFilter
        )

        if filteredAssets.isEmpty {
            DPEmptyState(
                icon: "photo.on.rectangle.angled",
                title: "No Photos",
                message: "No photos match the current filters.",
                actionTitle: "Clear Filters"
            ) {
                router.libraryFilter.reset()
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs),
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs),
                        GridItem(.flexible(), spacing: AppTheme.Spacing.xs)
                    ],
                    spacing: AppTheme.Spacing.xs
                ) {
                    ForEach(filteredAssets, id: \.localIdentifier) { asset in
                        PhotoGridItem(
                            asset: asset,
                            isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                            isSelectionMode: viewModel.isSelectionMode,
                            onTap: {
                                if viewModel.isSelectionMode {
                                    viewModel.toggleSelection(for: asset.localIdentifier)
                                } else {
                                    router.navigateToPhotoDetail(id: asset.localIdentifier)
                                }
                            }
                        )
                    }
                }
                .padding(AppTheme.Spacing.sm)
            }
        }
    }
}

// MARK: - PhotoGridItem

/// Individual photo cell in the grid with selection support
struct PhotoGridItem: View {
    let asset: PHAsset
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @ObservedObject var metadataManager = MetadataManager.shared

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Thumbnail
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
                                    .scaleEffect(0.8)
                            )
                    }

                    // Selection indicator
                    if isSelectionMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(0.8))
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(AppTheme.Spacing.xs)
                    }

                    // Rating stars (bottom left)
                    if let rating = metadataManager.getRating(for: asset.localIdentifier), rating > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 2) {
                                    ForEach(0..<rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(AppTheme.Colors.warning)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                                .padding(AppTheme.Spacing.xs)

                                Spacer()
                            }
                        }
                    }
                }
                .cornerRadius(AppTheme.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 3)
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestThumbnail(for: asset, size: CGSize(width: 200, height: 200)) { loadedImage in
            self.image = loadedImage
        }
    }
}

// MARK: - SelectionActionBar

/// Bottom action bar for selection mode operations
struct SelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onShare: () -> Void
    let onAddToPortfolio: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: AppTheme.Spacing.xl) {
                // Share button
                Button(action: onShare) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                        Text("Share")
                            .font(AppTheme.Typography.caption)
                    }
                }
                .foregroundColor(selectedCount > 0 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .disabled(selectedCount == 0)

                // Add to Portfolio button
                Button(action: onAddToPortfolio) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20, weight: .medium))
                        Text("Portfolio")
                            .font(AppTheme.Typography.caption)
                    }
                }
                .foregroundColor(selectedCount > 0 ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .disabled(selectedCount == 0)

                // Delete button
                Button(action: onDelete) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .medium))
                        Text("Delete")
                            .font(AppTheme.Typography.caption)
                    }
                }
                .foregroundColor(selectedCount > 0 ? AppTheme.Colors.error : AppTheme.Colors.textTertiary)
                .disabled(selectedCount == 0)
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.surface)
        }
    }
}

// MARK: - LibraryFilterSheet

/// Sheet for configuring library filters
struct LibraryFilterSheet: View {
    @Binding var filter: LibraryFilter
    @Environment(\.dismiss) var dismiss
    @ObservedObject var metadataManager = MetadataManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Procedures Section
                    FilterSection(title: "Procedures") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(metadataManager.procedures, id: \.self) { procedure in
                                let isSelected = filter.procedures.contains(procedure)
                                DPTagPill(
                                    procedure,
                                    color: AppTheme.procedureColor(for: procedure),
                                    size: .medium,
                                    isSelected: isSelected,
                                    onTap: {
                                        if isSelected {
                                            filter.procedures.remove(procedure)
                                        } else {
                                            filter.procedures.insert(procedure)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Stages Section
                    FilterSection(title: "Stages") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(MetadataManager.stages, id: \.self) { stage in
                                let isSelected = filter.stages.contains(stage)
                                DPTagPill(
                                    stage,
                                    color: AppTheme.Colors.secondary,
                                    size: .medium,
                                    isSelected: isSelected,
                                    onTap: {
                                        if isSelected {
                                            filter.stages.remove(stage)
                                        } else {
                                            filter.stages.insert(stage)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Angles Section
                    FilterSection(title: "Angles") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(MetadataManager.angles, id: \.self) { angle in
                                let isSelected = filter.angles.contains(angle)
                                DPTagPill(
                                    angle,
                                    color: AppTheme.Colors.secondary,
                                    size: .medium,
                                    isSelected: isSelected,
                                    onTap: {
                                        if isSelected {
                                            filter.angles.remove(angle)
                                        } else {
                                            filter.angles.insert(angle)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Rating Section
                    FilterSection(title: "Minimum Rating") {
                        HStack(spacing: AppTheme.Spacing.md) {
                            ForEach(1...5, id: \.self) { rating in
                                let isSelected = filter.minimumRating == rating
                                Button(action: {
                                    filter.minimumRating = isSelected ? nil : rating
                                }) {
                                    HStack(spacing: 2) {
                                        ForEach(0..<rating, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 12))
                                        }
                                    }
                                    .foregroundColor(isSelected ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary)
                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(isSelected ? AppTheme.Colors.warning.opacity(0.15) : AppTheme.Colors.surfaceSecondary)
                                    .cornerRadius(AppTheme.CornerRadius.small)
                                }
                            }
                        }
                    }

                    // Date Range Section
                    FilterSection(title: "Date Range") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach([
                                LibraryFilter.DateRange.lastWeek,
                                LibraryFilter.DateRange.lastMonth,
                                LibraryFilter.DateRange.last3Months,
                                LibraryFilter.DateRange.lastYear
                            ], id: \.displayName) { range in
                                let isSelected = filter.dateRange?.displayName == range.displayName
                                DPTagPill(
                                    range.displayName,
                                    color: AppTheme.Colors.primary,
                                    size: .medium,
                                    isSelected: isSelected,
                                    onTap: {
                                        filter.dateRange = isSelected ? nil : range
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filter.reset()
                    }
                    .foregroundColor(AppTheme.Colors.error)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - FilterSection

/// Section container for filter options
struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            content
        }
    }
}

// MARK: - FlowLayout

/// A layout that wraps content to new lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if rowWidth + size.width > containerWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        height += rowHeight

        return CGSize(width: containerWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
            .environmentObject(NavigationRouter())
    }
}
#endif
