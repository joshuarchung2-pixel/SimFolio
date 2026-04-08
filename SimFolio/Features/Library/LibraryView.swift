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
import Combine
import UniformTypeIdentifiers

// MARK: - LibraryViewModel

/// View model for LibraryView managing view state, selection, filtering, and sorting
class LibraryViewModel: ObservableObject {

    // MARK: - View Mode

    /// Current view mode for the library
    enum ViewMode: Equatable, Hashable {
        /// Top-level list of procedure folders
        case procedures
        /// Photos for a specific procedure
        case procedureDetail(String)
        /// Flat grid of all photos
        case allPhotos
    }

    // MARK: - Display Mode

    /// Display mode for photo grids (grid vs list)
    enum DisplayMode {
        case grid
        case list
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

    /// Display mode (grid vs list)
    @Published var displayMode: DisplayMode = .grid

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Empty init - no search setup needed
    }

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
                guard let m = metadata.getMetadata(for: asset.localIdentifier),
                      let procedure = m.procedure else { return false }
                return filter.procedures.contains(procedure)
            }
        }

        // Filter by stage
        if !filter.stages.isEmpty {
            result = result.filter { asset in
                guard let m = metadata.getMetadata(for: asset.localIdentifier),
                      let stage = m.stage else { return false }
                return filter.stages.contains(stage)
            }
        }

        // Filter by angle
        if !filter.angles.isEmpty {
            result = result.filter { asset in
                guard let m = metadata.getMetadata(for: asset.localIdentifier),
                      let angle = m.angle else { return false }
                return filter.angles.contains(angle)
            }
        }

        // Filter by minimum rating
        if let minRating = filter.minimumRating {
            result = result.filter { asset in
                (metadata.getRating(for: asset.localIdentifier) ?? 0) >= minRating
            }
        }

        // Filter by favorites only
        if filter.favoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // Filter by date range
        if let dateRange = filter.dateRange {
            let now = Date()
            let calendar = Calendar.current

            switch dateRange {
            case .lastWeek:
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                result = result.filter { ($0.creationDate ?? now) >= weekAgo }

            case .lastMonth:
                let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                result = result.filter { ($0.creationDate ?? now) >= monthAgo }

            case .last3Months:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                result = result.filter { ($0.creationDate ?? now) >= threeMonthsAgo }

            case .lastYear:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                result = result.filter { ($0.creationDate ?? now) >= yearAgo }

            case .custom(let start, let end):
                result = result.filter { asset in
                    guard let date = asset.creationDate else { return false }
                    return date >= start && date <= end
                }
            }
        }

        // Filter by portfolio (assets matching portfolio requirements)
        if let portfolioId = filter.portfolioId {
            if let portfolio = metadata.portfolios.first(where: { $0.id == portfolioId }) {
                let proceduresInPortfolio = Set(portfolio.requirements.map { $0.procedure })
                result = result.filter { asset in
                    guard let m = metadata.getMetadata(for: asset.localIdentifier),
                          let procedure = m.procedure else { return false }
                    return proceduresInPortfolio.contains(procedure)
                }
            }
        }

        // Sort
        switch sortOrder {
        case .dateNewest:
            result.sort { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
        case .dateOldest:
            result.sort { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
        case .procedure:
            result.sort { asset1, asset2 in
                let p1 = metadata.getMetadata(for: asset1.localIdentifier)?.procedure ?? ""
                let p2 = metadata.getMetadata(for: asset2.localIdentifier)?.procedure ?? ""
                return p1 < p2
            }
        case .rating:
            result.sort { asset1, asset2 in
                let r1 = metadata.getRating(for: asset1.localIdentifier) ?? 0
                let r2 = metadata.getRating(for: asset2.localIdentifier) ?? 0
                return r1 > r2
            }
        }

        return result
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

// MARK: - Library Navigation Destination
/// Enum for library navigation destinations
enum LibraryDestination: Hashable {
    case procedureDetail(String)
    case allPhotos
}

/// Main library view with procedure folders, filters, and photo organization
struct LibraryView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var showFilterSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showBatchPaywall = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Root view - Procedures List
            ScrollView {
                VStack(spacing: 0) {
                    // Filter chips bar (only if filters active)
                    if !router.libraryFilter.isEmpty {
                        FilterChipsBar(filter: $router.libraryFilter)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Procedures list content
                    ProceduresListView(
                        viewModel: viewModel,
                        onProcedureTap: { procedure in
                            navigationPath.append(LibraryDestination.procedureDetail(procedure))
                        },
                        onAllPhotosTap: {
                            navigationPath.append(LibraryDestination.allPhotos)
                        }
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .procedureDetail(let procedure):
                    LibraryProcedureDetailWrapper(
                        procedure: procedure,
                        viewModel: viewModel,
                        showFilterSheet: $showFilterSheet,
                        showDeleteConfirmation: $showDeleteConfirmation,
                        showBatchPaywall: $showBatchPaywall,
                        onDelete: handleDeleteSelected,
                        onShare: handleShareSelected,
                        onFavorite: handleFavoriteSelected
                    )
                case .allPhotos:
                    LibraryAllPhotosWrapper(
                        viewModel: viewModel,
                        showFilterSheet: $showFilterSheet,
                        showDeleteConfirmation: $showDeleteConfirmation,
                        showBatchPaywall: $showBatchPaywall,
                        onDelete: handleDeleteSelected,
                        onShare: handleShareSelected,
                        onFavorite: handleFavoriteSelected
                    )
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                LibraryFilterSheet(filter: $router.libraryFilter)
            }
            .alert("Delete \(viewModel.selectedAssetIds.count) Photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDeleteSelected()
                }
            } message: {
                Text("This will permanently remove \(viewModel.selectedAssetIds.count) photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s") from your library.")
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                library.fetchAssets()
            }
        }
    }

    // MARK: - Action Handlers

    /// Handle deletion of selected assets
    func handleDeleteSelected() {
        let selectedIds = Array(viewModel.selectedAssetIds)
        let assetsToDelete = library.assets.filter { selectedIds.contains($0.localIdentifier) }

        guard !assetsToDelete.isEmpty else { return }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    for id in selectedIds {
                        MetadataManager.shared.deleteMetadata(for: id)
                        PhotoEditPersistenceService.shared.deleteEditState(for: id)
                    }
                    viewModel.exitSelectionMode()
                    library.fetchAssets()
                }
            }
        }
    }

    /// Handle sharing of selected assets
    func handleShareSelected() {
        let ids = Array(viewModel.selectedAssetIds)
        router.presentSheet(.shareSheet(photoIds: ids))
    }

    /// Handle favoriting selected assets
    func handleFavoriteSelected() {
        let selectedIds = Array(viewModel.selectedAssetIds)
        let assetsToFavorite = library.assets.filter { selectedIds.contains($0.localIdentifier) }

        guard !assetsToFavorite.isEmpty else { return }

        // Store the asset IDs before the async operation
        let assetIds = assetsToFavorite.map { $0.localIdentifier }

        PHPhotoLibrary.shared().performChanges {
            for asset in assetsToFavorite {
                let request = PHAssetChangeRequest(for: asset)
                request.isFavorite = true
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    // Post notification for each favorited asset for immediate thumbnail update
                    for assetId in assetIds {
                        NotificationCenter.default.post(
                            name: .photoFavoriteChanged,
                            object: nil,
                            userInfo: ["assetId": assetId, "isFavorite": true]
                        )
                    }
                    viewModel.exitSelectionMode()
                }
            }
        }
    }
}

// MARK: - FilterChipsBar

/// Horizontal bar displaying active filter chips that can be removed
struct FilterChipsBar: View {
    @Binding var filter: LibraryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                // Procedure chips
                ForEach(Array(filter.procedures), id: \.self) { procedure in
                    FilterChip(
                        text: procedure,
                        color: AppTheme.procedureColor(for: procedure),
                        onRemove: {
                            filter.procedures.remove(procedure)
                        }
                    )
                }

                // Stage chips
                ForEach(Array(filter.stages), id: \.self) { stage in
                    FilterChip(
                        text: stage,
                        color: AppTheme.stageColor(for: stage),
                        onRemove: {
                            filter.stages.remove(stage)
                        }
                    )
                }

                // Angle chips
                ForEach(Array(filter.angles), id: \.self) { angle in
                    FilterChip(
                        text: angle,
                        color: AppTheme.angleColor(for: angle),
                        onRemove: {
                            filter.angles.remove(angle)
                        }
                    )
                }

                // Rating chip
                if let minRating = filter.minimumRating {
                    FilterChip(
                        text: "\(minRating)+ Stars",
                        color: .yellow,
                        onRemove: {
                            filter.minimumRating = nil
                        }
                    )
                }

                // Favorites chip
                if filter.favoritesOnly {
                    FilterChip(
                        text: "Favorites",
                        color: .yellow,
                        onRemove: {
                            filter.favoritesOnly = false
                        }
                    )
                }

                // Date range chip
                if let dateRange = filter.dateRange {
                    FilterChip(
                        text: dateRangeText(dateRange),
                        color: AppTheme.Colors.primary,
                        onRemove: {
                            filter.dateRange = nil
                        }
                    )
                }

                // Portfolio chip
                if filter.portfolioId != nil {
                    FilterChip(
                        text: "Portfolio",
                        color: AppTheme.Colors.primary,
                        onRemove: {
                            filter.portfolioId = nil
                        }
                    )
                }

                // Clear all button (if multiple filters)
                if filter.activeFilterCount > 1 {
                    Button(action: {
                        filter.reset()
                    }) {
                        Text("Clear All")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
    }

    func dateRangeText(_ range: LibraryFilter.DateRange) -> String {
        switch range {
        case .lastWeek:
            return "Last 7 Days"
        case .lastMonth:
            return "Last 30 Days"
        case .last3Months:
            return "Last 3 Months"
        case .lastYear:
            return "Last Year"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

// MARK: - FilterChip

/// Individual filter chip with colored dot and remove button
struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: AppTheme.IconSize.xs, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(color.opacity(AppTheme.Opacity.light))
        .cornerRadius(AppTheme.CornerRadius.full)
    }
}

// MARK: - Procedure Sort Order

/// Sort options for procedure folders
enum ProcedureSortOrder: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case mostRecent = "Most Recent"
    case countDescending = "Most Photos"
    case countAscending = "Fewest Photos"

    var icon: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .mostRecent: return "clock"
        case .countDescending: return "arrow.down.circle"
        case .countAscending: return "arrow.up.circle"
        }
    }
}

// MARK: - Library Procedure Detail Wrapper

/// Wrapper view for procedure detail with its own navigation context
struct LibraryProcedureDetailWrapper: View {
    let procedure: String
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var showFilterSheet: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var showBatchPaywall: Bool
    let onDelete: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void

    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        ScrollView {
            ProcedureDetailView(procedure: procedure, viewModel: viewModel)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .navigationTitle(procedure)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isSelectionMode {
                SelectionActionBar(
                    selectedCount: viewModel.selectedAssetIds.count,
                    onDelete: { showDeleteConfirmation = true },
                    onShare: onShare,
                    onFavorite: onFavorite
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    // Filter button
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: router.libraryFilter.isEmpty
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    // View mode toggle (grid/list)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.displayMode = viewModel.displayMode == .grid ? .list : .grid
                        }
                    }) {
                        Image(systemName: viewModel.displayMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    // Selection mode toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.isSelectionMode {
                                viewModel.exitSelectionMode()
                            } else {
                                requirePremium(.batchOperations, showPaywall: $showBatchPaywall) {
                                    viewModel.isSelectionMode = true
                                }
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: viewModel.isSelectionMode) { isSelecting in
            withAnimation(.easeInOut(duration: 0.25)) {
                router.isTabBarVisible = !isSelecting
            }
        }
        .onDisappear {
            router.isTabBarVisible = true
            router.libraryFilter.reset()
        }
        .alert("Delete \(viewModel.selectedAssetIds.count) Photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will permanently remove \(viewModel.selectedAssetIds.count) photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s") from your library.")
        }
        .premiumGate(for: .batchOperations, showPaywall: $showBatchPaywall)
    }
}

// MARK: - Library All Photos Wrapper

/// Wrapper view for all photos with its own navigation context
struct LibraryAllPhotosWrapper: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var showFilterSheet: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var showBatchPaywall: Bool
    let onDelete: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void

    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        ScrollView {
            AllPhotosGridView(viewModel: viewModel)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .navigationTitle("All Photos")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isSelectionMode {
                SelectionActionBar(
                    selectedCount: viewModel.selectedAssetIds.count,
                    onDelete: { showDeleteConfirmation = true },
                    onShare: onShare,
                    onFavorite: onFavorite
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    // Filter button
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: router.libraryFilter.isEmpty
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    // View mode toggle (grid/list)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.displayMode = viewModel.displayMode == .grid ? .list : .grid
                        }
                    }) {
                        Image(systemName: viewModel.displayMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    // Selection mode toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.isSelectionMode {
                                viewModel.exitSelectionMode()
                            } else {
                                requirePremium(.batchOperations, showPaywall: $showBatchPaywall) {
                                    viewModel.isSelectionMode = true
                                }
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: viewModel.isSelectionMode) { isSelecting in
            withAnimation(.easeInOut(duration: 0.25)) {
                router.isTabBarVisible = !isSelecting
            }
        }
        .onDisappear {
            router.isTabBarVisible = true
            router.libraryFilter.reset()
        }
        .alert("Delete \(viewModel.selectedAssetIds.count) Photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will permanently remove \(viewModel.selectedAssetIds.count) photo\(viewModel.selectedAssetIds.count == 1 ? "" : "s") from your library.")
        }
        .premiumGate(for: .batchOperations, showPaywall: $showBatchPaywall)
    }
}

// MARK: - ProceduresListView

/// List view showing procedure folders with photo counts and stats
struct ProceduresListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    // Navigation callbacks
    var onProcedureTap: ((String) -> Void)?
    var onAllPhotosTap: (() -> Void)?

    // Procedure sort order stored in UserDefaults
    @AppStorage("procedureSortOrder") private var procedureSortOrder: ProcedureSortOrder = .alphabetical

    var procedureStats: [(procedure: String, count: Int, prepCount: Int, restoCount: Int, mostRecentDate: Date?)] {
        var stats: [(String, Int, Int, Int, Date?)] = []
        let grouped = viewModel.assetsByProcedure(from: library.assets, metadata: metadataManager)

        for procedure in metadataManager.procedures {
            let assets = grouped[procedure] ?? []
            let prepCount = assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Preparation"
            }.count
            let restoCount = assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Restoration"
            }.count
            let mostRecentDate = assets.compactMap { $0.creationDate }.max()

            if assets.count > 0 {
                stats.append((procedure, assets.count, prepCount, restoCount, mostRecentDate))
            }
        }

        // Add untagged if any
        let untaggedAssets = grouped["Untagged"] ?? []
        if untaggedAssets.count > 0 {
            let mostRecentDate = untaggedAssets.compactMap { $0.creationDate }.max()
            stats.append(("Untagged", untaggedAssets.count, 0, 0, mostRecentDate))
        }

        return stats
    }

    // Sorted procedure stats based on selected sort order
    var sortedProcedureStats: [(procedure: String, count: Int, prepCount: Int, restoCount: Int, mostRecentDate: Date?)] {
        let stats = procedureStats

        switch procedureSortOrder {
        case .alphabetical:
            return stats.sorted { $0.procedure.localizedCaseInsensitiveCompare($1.procedure) == .orderedAscending }
        case .mostRecent:
            return stats.sorted { ($0.mostRecentDate ?? .distantPast) > ($1.mostRecentDate ?? .distantPast) }
        case .countDescending:
            return stats.sorted { $0.count > $1.count }
        case .countAscending:
            return stats.sorted { $0.count < $1.count }
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Quick access cards
            quickAccessSection

            // Procedure folders
            procedureFoldersSection

            Spacer(minLength: 100)
        }
    }

    // MARK: - Quick Access Section
    var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Compact grid that fits on screen (no scrolling needed)
            HStack(spacing: AppTheme.Spacing.sm) {
                // All Photos
                CompactAccessCard(
                    icon: "photo.on.rectangle",
                    title: "All",
                    count: library.assets.count,
                    color: AppTheme.Colors.primary
                ) {
                    onAllPhotosTap?()
                }

                // Favorites (was Starred)
                CompactAccessCard(
                    icon: "heart.fill",
                    title: "Favorites",
                    count: starredCount,
                    color: .pink
                ) {
                    router.libraryFilter.favoritesOnly = true
                    onAllPhotosTap?()
                }

                // Recent (last 7 days)
                CompactAccessCard(
                    icon: "clock.fill",
                    title: "Recent",
                    count: recentCount,
                    color: AppTheme.Colors.success
                ) {
                    router.libraryFilter.dateRange = .lastWeek
                    onAllPhotosTap?()
                }

                // Untagged (only if exists)
                if untaggedCount > 0 {
                    CompactAccessCard(
                        icon: "tag.slash",
                        title: "Untagged",
                        count: untaggedCount,
                        color: AppTheme.Colors.textSecondary
                    ) {
                        onProcedureTap?("Untagged")
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Procedure Folders Section
    var procedureFoldersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                DPSectionHeader(
                    "Procedures",
                    subtitle: "\(procedureStats.count) with photos"
                )

                Spacer()

                // Sort menu
                Menu {
                    Picker("Sort Order", selection: $procedureSortOrder) {
                        ForEach(ProcedureSortOrder.allCases, id: \.self) { order in
                            Label(order.rawValue, systemImage: order.icon)
                                .tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if procedureStats.isEmpty {
                DPEmptyState(
                    icon: "folder",
                    title: "No Photos Yet",
                    message: "Captured photos will be organized here by procedure.",
                    actionTitle: "Start Capturing"
                ) {
                    router.selectedTab = .capture
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                // Procedure rows
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(sortedProcedureStats, id: \.procedure) { stat in
                        ProcedureFolderRow(
                            procedure: stat.procedure,
                            totalCount: stat.count,
                            isSelectionMode: viewModel.isSelectionMode
                        ) {
                            if viewModel.isSelectionMode {
                                // Select all in this procedure
                                let assets = viewModel.assetsByProcedure(from: library.assets, metadata: metadataManager)[stat.procedure] ?? []
                                for asset in assets {
                                    viewModel.selectedAssetIds.insert(asset.localIdentifier)
                                }
                            } else {
                                onProcedureTap?(stat.procedure)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .animation(.easeInOut(duration: 0.2), value: procedureSortOrder)
            }
        }
    }

    // MARK: - Computed Properties

    var starredCount: Int {
        library.assets.filter { $0.isFavorite }.count
    }

    var recentCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return library.assets.filter { $0.creationDate ?? Date() > weekAgo }.count
    }

    var untaggedCount: Int {
        library.assets.filter { asset in
            metadataManager.getMetadata(for: asset.localIdentifier)?.procedure == nil
        }.count
    }
}

// MARK: - Quick Access Card

/// Card for quick access shortcuts (All Photos, Starred, Recent, etc.)
struct QuickAccessCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(AppTheme.Opacity.light))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: AppTheme.IconSize.md))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("\(count)")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            .frame(width: 120)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Compact Access Card

/// Smaller quick access card that fits multiple cards on screen without scrolling
struct CompactAccessCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.IconSize.sm))
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(title)
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Procedure Folder Row

/// Row displaying a procedure folder
struct ProcedureFolderRow: View {
    let procedure: String
    let totalCount: Int
    let isSelectionMode: Bool
    let action: () -> Void

    var color: Color {
        procedure == "Untagged" ? AppTheme.Colors.textSecondary : AppTheme.procedureColor(for: procedure)
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Color indicator
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                // Procedure name and count
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(procedure)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("\(totalCount) photo\(totalCount == 1 ? "" : "s")")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Chevron or selection indicator
                if isSelectionMode {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppTheme.Colors.primary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Stage Breakdown Bar

/// Mini progress bar showing prep/resto ratio
struct StageBreakdownBar: View {
    let prepCount: Int
    let restoCount: Int
    let totalCount: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                // Prep portion
                if prepCount > 0 {
                    Rectangle()
                        .fill(AppTheme.Colors.warning)
                        .frame(width: geo.size.width * CGFloat(prepCount) / CGFloat(totalCount))
                }

                // Resto portion
                if restoCount > 0 {
                    Rectangle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: geo.size.width * CGFloat(restoCount) / CGFloat(totalCount))
                }

                // Unassigned portion
                let unassigned = totalCount - prepCount - restoCount
                if unassigned > 0 {
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceSecondary)
                        .frame(width: geo.size.width * CGFloat(unassigned) / CGFloat(totalCount))
                }
            }
            .cornerRadius(AppTheme.CornerRadius.xxs)
        }
        .frame(height: 6)
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
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == asset.localIdentifier {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestEditedThumbnail(for: asset, size: CGSize(width: 100, height: 100)) { loadedImage in
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

    @State private var viewStyle: ViewStyle = .grouped
    @State private var expandedTeeth: Set<Int> = []
    @State private var selectedPhotoId: String? = nil

    enum ViewStyle {
        case grouped  // Grouped by tooth
        case grid     // Flat grid
    }

    var isUntagged: Bool {
        procedure == "Untagged"
    }

    var procedureAssets: [PHAsset] {
        if procedure == "Untagged" {
            return library.assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.procedure == nil
            }
        } else {
            return library.assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.procedure == procedure
            }
        }
    }

    var assetsByTooth: [Int: [PHAsset]] {
        var grouped: [Int: [PHAsset]] = [:]

        for asset in procedureAssets {
            let toothNumber = metadataManager.getMetadata(for: asset.localIdentifier)?.toothNumber ?? 0
            grouped[toothNumber, default: []].append(asset)
        }

        return grouped
    }

    var sortedToothNumbers: [Int] {
        assetsByTooth.keys.sorted()
    }

    /// Group procedure assets by stage
    var stageAssetCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for asset in procedureAssets {
            let stage = metadataManager.getMetadata(for: asset.localIdentifier)?.stage ?? "Unknown"
            counts[stage, default: 0] += 1
        }
        return counts
    }

    /// Sorted list of stages present in this procedure
    var sortedProcedureStages: [String] {
        let stages = Set(stageAssetCounts.keys)
        let enabledStages = metadataManager.getEnabledStages()
        return stages.sorted { stage1, stage2 in
            let order1 = enabledStages.first { $0.name == stage1 }?.sortOrder ?? 999
            let order2 = enabledStages.first { $0.name == stage2 }?.sortOrder ?? 999
            return order1 < order2
        }
    }

    var body: some View {
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
            VStack(spacing: AppTheme.Spacing.lg) {
                // Stats header
                statsHeader

                // View style toggle (hidden for untagged)
                if !isUntagged {
                    viewStyleToggle
                }

                // Content (force grid view for untagged)
                if viewStyle == .grouped && !isUntagged {
                    groupedContent
                } else {
                    gridContent
                }

                Spacer(minLength: 100)
            }
            .padding(.top, AppTheme.Spacing.sm)
            .sheet(item: $selectedPhotoId) { photoId in
                PhotoDetailSheet(
                    photoId: photoId,
                    allAssets: procedureAssets,
                    onDismiss: { selectedPhotoId = nil },
                    onPhotoTagged: { _ in
                        selectedPhotoId = nil
                        // Photo will appear in its new procedure folder
                    }
                )
            }
        }
    }

    // MARK: - Stats Header
    var statsHeader: some View {
        DPCard {
            if isUntagged {
                // Simplified stats for untagged photos
                StatItem(
                    value: "\(procedureAssets.count)",
                    label: "Photos",
                    color: AppTheme.procedureColor(for: procedure)
                )
                .frame(maxWidth: .infinity)
            } else {
                // Full stats for regular procedures
                HStack(spacing: AppTheme.Spacing.lg) {
                    StatItem(
                        value: "\(procedureAssets.count)",
                        label: "Photos",
                        color: AppTheme.procedureColor(for: procedure)
                    )

                    Divider()
                        .frame(height: 40)

                    StatItem(
                        value: "\(assetsByTooth.count)",
                        label: "Teeth",
                        color: AppTheme.Colors.success
                    )

                    // Dynamic stage counts (show up to 3 stages)
                    ForEach(sortedProcedureStages.prefix(3), id: \.self) { stage in
                        if let count = stageAssetCounts[stage], count > 0 {
                            Divider()
                                .frame(height: 40)

                            StatItem(
                                value: "\(count)",
                                label: PhotoMetadata.stageAbbreviation(for: stage),
                                color: metadataManager.stageColor(for: stage)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - View Style Toggle
    var viewStyleToggle: some View {
        HStack {
            Spacer()

            Picker("View Style", selection: $viewStyle) {
                Image(systemName: "list.bullet").tag(ViewStyle.grouped)
                Image(systemName: "square.grid.2x2").tag(ViewStyle.grid)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 100)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Grouped Content
    var groupedContent: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(sortedToothNumbers, id: \.self) { toothNumber in
                ToothGroupSection(
                    toothNumber: toothNumber,
                    assets: assetsByTooth[toothNumber] ?? [],
                    isExpanded: expandedTeeth.contains(toothNumber),
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedIds: viewModel.selectedAssetIds,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedTeeth.contains(toothNumber) {
                                expandedTeeth.remove(toothNumber)
                            } else {
                                expandedTeeth.insert(toothNumber)
                            }
                        }
                    },
                    onSelectAsset: { assetId in
                        if viewModel.isSelectionMode {
                            viewModel.toggleSelection(for: assetId)
                        } else {
                            selectedPhotoId = assetId
                        }
                    },
                    metadataManager: metadataManager
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Grid Content
    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var gridContent: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Results count
            HStack {
                Text("\(procedureAssets.count) photo\(procedureAssets.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(procedureAssets, id: \.localIdentifier) { asset in
                    PhotoGridCell(
                        asset: asset,
                        metadata: metadataManager.getMetadata(for: asset.localIdentifier),
                        isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                        isSelectionMode: viewModel.isSelectionMode,
                        onTap: {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(for: asset.localIdentifier)
                            } else {
                                selectedPhotoId = asset.localIdentifier
                            }
                        },
                        metadataManager: metadataManager
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
        }
    }
}

// MARK: - Stat Item

/// Individual stat display for the procedure header
struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .foregroundStyle(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Tooth Group Section

/// Expandable section showing photos grouped by tooth number
struct ToothGroupSection: View {
    let toothNumber: Int
    let assets: [PHAsset]
    let isExpanded: Bool
    let isSelectionMode: Bool
    let selectedIds: Set<String>
    let onToggleExpand: () -> Void
    let onSelectAsset: (String) -> Void
    @ObservedObject var metadataManager: MetadataManager

    var toothLabel: String {
        toothNumber == 0 ? "No Tooth Assigned" : "Tooth #\(toothNumber)"
    }

    /// Group assets by their stage name
    var assetsByStage: [String: [PHAsset]] {
        var grouped: [String: [PHAsset]] = [:]
        for asset in assets {
            let stage = metadataManager.getMetadata(for: asset.localIdentifier)?.stage ?? "Unknown"
            grouped[stage, default: []].append(asset)
        }
        return grouped
    }

    /// Get distinct stages in this tooth group, sorted by StageConfig.sortOrder
    var sortedStages: [String] {
        let stages = Set(assetsByStage.keys)
        let enabledStages = metadataManager.getEnabledStages()
        return stages.sorted { stage1, stage2 in
            let order1 = enabledStages.first { $0.name == stage1 }?.sortOrder ?? 999
            let order2 = enabledStages.first { $0.name == stage2 }?.sortOrder ?? 999
            return order1 < order2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack {
                    // Tooth icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.surfaceSecondary)
                            .frame(width: 36, height: 36)

                        Text(toothNumber == 0 ? "?" : "\(toothNumber)")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    // Tooth label and count
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(toothLabel)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(sortedStages.prefix(3), id: \.self) { stage in
                                if let count = assetsByStage[stage]?.count, count > 0 {
                                    Text("\(count) \(PhotoMetadata.stageAbbreviation(for: stage))")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(metadataManager.stageColor(for: stage))
                                }
                            }
                        }
                    }

                    Spacer()

                    // Thumbnail preview (when collapsed)
                    if !isExpanded {
                        HStack(spacing: -8) {
                            ForEach(assets.prefix(3), id: \.localIdentifier) { asset in
                                AsyncThumbnailView(asset: asset, size: 32)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(AppTheme.Colors.surface, lineWidth: 2)
                                    )
                            }
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                .padding(AppTheme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(sortedStages, id: \.self) { stage in
                        if let stageAssets = assetsByStage[stage], !stageAssets.isEmpty {
                            StagePhotoGrid(
                                stage: stage,
                                assets: stageAssets,
                                isSelectionMode: isSelectionMode,
                                selectedIds: selectedIds,
                                onSelectAsset: onSelectAsset,
                                metadataManager: metadataManager
                            )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Stage Photo Grid

/// Grid of photos for a specific stage (Preparation or Restoration)
struct StagePhotoGrid: View {
    let stage: String
    let assets: [PHAsset]
    let isSelectionMode: Bool
    let selectedIds: Set<String>
    let onSelectAsset: (String) -> Void
    @ObservedObject var metadataManager: MetadataManager

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Stage label
            HStack {
                Circle()
                    .fill(metadataManager.stageColor(for: stage))
                    .frame(width: 8, height: 8)

                Text(stage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Photo grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    LibraryPhotoThumbnail(
                        asset: asset,
                        isSelected: selectedIds.contains(asset.localIdentifier),
                        isSelectionMode: isSelectionMode
                    ) {
                        onSelectAsset(asset.localIdentifier)
                    }
                    .aspectRatio(1, contentMode: .fill)
                }
            }
        }
    }
}

// MARK: - Library Photo Thumbnail

/// Photo thumbnail with selection overlay and rating badge
struct LibraryPhotoThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var isFavorite: Bool = false
    @State private var showFavoritePulse: Bool = false
    @ObservedObject var metadataManager = MetadataManager.shared

    var rating: Int {
        metadataManager.getRating(for: asset.localIdentifier) ?? 0
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Thumbnail
                    Group {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else {
                            Rectangle()
                                .fill(AppTheme.Colors.surfaceSecondary)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

                    // Selection indicator
                    if isSelectionMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(AppTheme.Opacity.strong))
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: AppTheme.IconSize.xs, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(AppTheme.Spacing.xs)
                    }

                    // Rating stars (bottom left)
                    if !isSelectionMode && rating > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "star.fill")
                                .font(.system(size: AppTheme.IconSize.xs - 4))
                            Text("\(rating)")
                                .font(AppTheme.Typography.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.xs)
                        .padding(.vertical, AppTheme.Spacing.xxs)
                        .background(Color.black.opacity(AppTheme.Opacity.prominent))
                        .cornerRadius(AppTheme.CornerRadius.xs)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(AppTheme.Spacing.xs)
                    }

                    // Favorite heart (bottom right) - shows even in selection mode when pulsing
                    if isFavorite || showFavoritePulse {
                        Image(systemName: "heart.fill")
                            .font(.system(size: AppTheme.IconSize.xs))
                            .foregroundStyle(.red)
                            .padding(AppTheme.Spacing.xs)
                            .background(Color.black.opacity(AppTheme.Opacity.prominent))
                            .cornerRadius(AppTheme.CornerRadius.xs)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(AppTheme.Spacing.xs)
                            .scaleEffect(showFavoritePulse ? 1.3 : 1.0)
                            .opacity(showFavoritePulse ? 1.0 : (isSelectionMode ? 0.0 : 1.0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFavoritePulse)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            isFavorite = asset.isFavorite
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == asset.localIdentifier {
                loadThumbnail()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoFavoriteChanged)) { notification in
            // Update favorite status if this asset's favorite changed
            if let assetId = notification.userInfo?["assetId"] as? String,
               assetId == asset.localIdentifier,
               let newFavorite = notification.userInfo?["isFavorite"] as? Bool {
                let wasNotFavorite = !isFavorite
                isFavorite = newFavorite

                // Trigger pulse animation when favorited
                if newFavorite && wasNotFavorite {
                    withAnimation {
                        showFavoritePulse = true
                    }
                    // Reset after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation {
                            showFavoritePulse = false
                        }
                    }
                }
            }
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestEditedThumbnail(for: asset, size: CGSize(width: 150, height: 150)) { loadedImage in
            self.image = loadedImage
        }
    }
}

// MARK: - PhotoGridCell

/// Grid cell showing photo thumbnail with metadata below
struct PhotoGridCell: View {
    let asset: PHAsset
    let metadata: PhotoMetadata?
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    @ObservedObject var metadataManager: MetadataManager

    @State private var image: UIImage?
    @State private var isFavorite: Bool = false
    @State private var showFavoritePulse: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Photo thumbnail
                ZStack(alignment: .topTrailing) {
                    // Image
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
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(AppTheme.CornerRadius.small)

                    // Selection indicator
                    if isSelectionMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(AppTheme.Opacity.strong))
                                .frame(width: 22, height: 22)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: AppTheme.IconSize.xs - 1, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(6)
                    }

                    // Favorite indicator (bottom right) - shows even in selection mode when pulsing
                    if isFavorite || showFavoritePulse {
                        Image(systemName: "heart.fill")
                            .font(.system(size: AppTheme.IconSize.xs))
                            .foregroundStyle(.red)
                            .padding(AppTheme.Spacing.xs)
                            .background(Color.black.opacity(AppTheme.Opacity.prominent))
                            .cornerRadius(AppTheme.CornerRadius.xs)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(AppTheme.Spacing.xs)
                            .scaleEffect(showFavoritePulse ? 1.3 : 1.0)
                            .opacity(showFavoritePulse ? 1.0 : (isSelectionMode ? 0.0 : 1.0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFavoritePulse)
                    }
                }

                // Metadata container with fixed height for consistent grid alignment
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    // Tags row
                    if let metadata = metadata, (metadata.procedure != nil || metadata.stage != nil || metadata.angle != nil) {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            if let procedure = metadata.procedure {
                                Text(procedure)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, AppTheme.Spacing.xs)
                                    .padding(.vertical, AppTheme.Spacing.xxs)
                                    .background(AppTheme.procedureColor(for: procedure))
                                    .cornerRadius(AppTheme.CornerRadius.xs)
                            }

                            if let stage = metadata.stage {
                                Text(PhotoMetadata.stageAbbreviation(for: stage))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(metadataManager.stageColor(for: stage))
                            }

                            if let angle = metadata.angle {
                                Text(PhotoMetadata.angleAbbreviation(for: angle))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                        .lineLimit(1)
                    } else {
                        // Placeholder for consistent height
                        Color.clear.frame(height: 16)
                    }

                    // Rating row
                    if let rating = metadata?.rating, rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: AppTheme.IconSize.xs - 4))
                                    .foregroundStyle(.yellow)
                            }
                            ForEach(0..<(5 - rating), id: \.self) { _ in
                                Image(systemName: "star")
                                    .font(.system(size: AppTheme.IconSize.xs - 4))
                                    .foregroundStyle(AppTheme.Colors.textTertiary.opacity(AppTheme.Opacity.medium))
                            }
                        }
                    } else {
                        // Placeholder for consistent height
                        Color.clear.frame(height: 10)
                    }
                }
                .frame(height: 30, alignment: .top)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            isFavorite = asset.isFavorite
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == asset.localIdentifier {
                // Force reload by clearing and reloading
                loadThumbnailForce()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoFavoriteChanged)) { notification in
            // Update favorite status if this asset's favorite changed
            if let assetId = notification.userInfo?["assetId"] as? String,
               assetId == asset.localIdentifier,
               let newFavorite = notification.userInfo?["isFavorite"] as? Bool {
                let wasNotFavorite = !isFavorite
                isFavorite = newFavorite

                // Trigger pulse animation when favorited
                if newFavorite && wasNotFavorite {
                    withAnimation {
                        showFavoritePulse = true
                    }
                    // Reset after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation {
                            showFavoritePulse = false
                        }
                    }
                }
            }
        }
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        loadThumbnailForce()
    }

    private func loadThumbnailForce() {
        PhotoLibraryManager.shared.requestEditedThumbnail(for: asset, size: CGSize(width: 200, height: 200)) { loadedImage in
            self.image = loadedImage
        }
    }
}

// MARK: - Photo Detail Sheet

/// Sheet wrapper for photo detail view - presents PhotoDetailView in fullscreen
struct PhotoDetailSheet: View {
    let photoId: String
    let allAssets: [PHAsset]
    let onDismiss: () -> Void
    var onPhotoTagged: ((String) -> Void)?

    @State private var isPresented = true

    var body: some View {
        if let asset = allAssets.first(where: { $0.localIdentifier == photoId }) {
            PhotoDetailView(
                asset: asset,
                allAssets: allAssets,
                isPresented: $isPresented,
                onPhotoTagged: { procedure in
                    onPhotoTagged?(procedure)
                }
            )
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    onDismiss()
                }
            }
        } else {
            // Asset was tagged and moved - dismiss gracefully
            Color.clear
                .onAppear {
                    onDismiss()
                }
        }
    }
}

// MARK: - Photo Detail View

/// Full-screen photo viewer with swipe navigation and metadata editing
struct PhotoDetailView: View {
    let asset: PHAsset
    let allAssets: [PHAsset]
    @Binding var isPresented: Bool
    var onPhotoTagged: ((String) -> Void)?

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var currentIndex: Int = 0
    @State private var image: UIImage?
    @State private var isImmersiveMode = false
    @State private var showMetadataEditor = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showAddToPortfolio = false
    @State private var showPhotoEditor = false
    @State private var dragOffset: CGSize = .zero
    /// Edited image from photo editor (for immediate display)
    @State private var editedImage: UIImage?
    /// Counter to trigger refresh in ZoomablePhotoView
    @State private var imageRefreshTrigger: Int = 0
    /// Local state to track favorite status (PHAsset.isFavorite doesn't trigger SwiftUI updates)
    @State private var isFavorite: Bool = false
    /// Animation state for heart pulse effect
    @State private var heartPulse: Bool = false
    /// Track if current photo is zoomed (disables page swiping when zoomed)
    @State private var isPhotoZoomed: Bool = false

    var currentAsset: PHAsset {
        allAssets.indices.contains(currentIndex) ? allAssets[currentIndex] : asset
    }

    var currentMetadata: PhotoMetadata? {
        metadataManager.getMetadata(for: currentAsset.localIdentifier)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Main content layout
                VStack(spacing: 0) {
                    // Top bar overlay
                    if !isImmersiveMode {
                        topBar
                            .transition(.opacity)
                    } else {
                        // Reserve space for safe area when immersive
                        Color.clear.frame(height: geometry.safeAreaInsets.top + 60)
                    }

                    // Photo with gestures - takes available space
                    photoView(geometry: geometry)
                        .frame(maxHeight: isImmersiveMode ? .infinity : geometry.size.height - 180)

                    // Bottom metadata card (non-overlapping)
                    if !isImmersiveMode {
                        metadataCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .statusBar(hidden: isImmersiveMode)
        .onAppear {
            currentIndex = allAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0
            isFavorite = currentAsset.isFavorite
            loadFullImage()
        }
        .onChange(of: currentIndex) { _ in
            isFavorite = currentAsset.isFavorite
            loadFullImage()
        }
        .sheet(isPresented: $showMetadataEditor) {
            PhotoMetadataEditSheet(
                asset: currentAsset,
                isPresented: $showMetadataEditor,
                onPhotoTagged: { procedure in
                    // Show success toast via notification
                    NotificationCenter.default.post(
                        name: .showGlobalToast,
                        object: nil,
                        userInfo: ["message": "Photo tagged as \(procedure)", "type": "success"]
                    )

                    // Dismiss after brief delay and notify parent
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPresented = false
                        onPhotoTagged?(procedure)
                    }
                }
            )
        }
        .alert("Delete Photo?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCurrentPhoto()
            }
        } message: {
            Text("This will permanently delete the photo from your library.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = image {
                ShareSheet(activityItems: [image])
            }
        }
        .fullScreenCover(isPresented: $showPhotoEditor) {
            PhotoEditorView(
                asset: currentAsset,
                isPresented: $showPhotoEditor,
                onSave: { processedImage in
                    // Immediately display the edited image
                    self.editedImage = processedImage
                    self.image = processedImage
                    // Also increment refresh trigger to update any cached views
                    self.imageRefreshTrigger += 1
                    // Post notification for thumbnail refresh
                    NotificationCenter.default.post(
                        name: .photoEditSaved,
                        object: nil,
                        userInfo: ["assetId": currentAsset.localIdentifier]
                    )
                }
            )
        }
    }

    // MARK: - Photo View

    func photoView(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allAssets.enumerated()), id: \.element.localIdentifier) { index, photoAsset in
                ZoomablePhotoView(
                    asset: photoAsset,
                    preloadedImage: index == currentIndex ? editedImage : nil,
                    refreshTrigger: index == currentIndex ? imageRefreshTrigger : 0,
                    isZoomed: index == currentIndex ? $isPhotoZoomed : nil
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .offset(y: dragOffset.height)
        .simultaneousGesture(
            // Vertical drag to dismiss - only when not zoomed
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only handle vertical drags when not zoomed
                    if !isPhotoZoomed && abs(value.translation.height) > abs(value.translation.width) * 1.5 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if !isPhotoZoomed && abs(value.translation.height) > 100 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isImmersiveMode.toggle()
            }
        }
        // Reset zoom when changing photos
        .onChange(of: currentIndex) { _ in
            isPhotoZoomed = false
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack {
            // Close button
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: AppTheme.IconSize.md - 2, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(AppTheme.Opacity.heavy))
                    .clipShape(Circle())
            }

            Spacer()

            // Photo counter
            Text("\(currentIndex + 1) / \(allAssets.count)")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(Color.black.opacity(AppTheme.Opacity.heavy))
                .cornerRadius(AppTheme.CornerRadius.full)

            Spacer()

            // Edit Photo button (dedicated button for quick access)
            Button(action: {
                showPhotoEditor = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: AppTheme.IconSize.md - 2, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(AppTheme.Opacity.heavy))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Edit Photo")

            // Actions menu
            Menu {
                // Edit Photo
                Button(action: {
                    showPhotoEditor = true
                }) {
                    Label("Edit Photo", systemImage: "slider.horizontal.3")
                }

                // Favorite toggle
                Button(action: { toggleFavorite() }) {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorite ? "heart.slash" : "heart"
                    )
                }

                // Edit metadata
                Button(action: { showMetadataEditor = true }) {
                    Label("Edit Details", systemImage: "pencil")
                }

                Divider()

                // Share
                Button(action: { showShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                // Add to Portfolio
                Button(action: { showAddToPortfolio = true }) {
                    Label("Add to Portfolio", systemImage: "folder.badge.plus")
                }

                Divider()

                // Delete
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label("Delete Photo", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: AppTheme.IconSize.md - 2, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(AppTheme.Opacity.heavy))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
    }

    // MARK: - Metadata Card

    var metadataCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Drag handle indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AppTheme.Colors.textTertiary.opacity(AppTheme.Opacity.heavy))
                .frame(width: 36, height: 5)
                .padding(.top, AppTheme.Spacing.xs)

            // Tags row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if let metadata = currentMetadata {
                        if let procedure = metadata.procedure {
                            DetailTagChip(text: procedure, color: AppTheme.procedureColor(for: procedure))
                        }

                        if let toothNumber = metadata.toothNumber {
                            DetailTagChip(text: "#\(toothNumber)", color: AppTheme.Colors.success)
                        }

                        if let stage = metadata.stage {
                            DetailTagChip(
                                text: PhotoMetadata.stageAbbreviation(for: stage),
                                color: metadataManager.stageColor(for: stage)
                            )
                        }

                        if let angle = metadata.angle {
                            DetailTagChip(text: angle, color: AppTheme.angleColor(for: angle))
                        }
                    }

                    // Show "No tags" if nothing is set
                    if currentMetadata == nil ||
                       (currentMetadata?.procedure == nil &&
                        currentMetadata?.toothNumber == nil &&
                        currentMetadata?.stage == nil &&
                        currentMetadata?.angle == nil) {
                        Text("No tags")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }

                    // Edit tags button
                    Button(action: { showMetadataEditor = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.primary.opacity(0.15))
                        .cornerRadius(AppTheme.CornerRadius.full)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xs)
            }

            // Rating and favorite row
            HStack {
                RatingStarsView(
                    rating: Binding(
                        get: { currentMetadata?.rating ?? 0 },
                        set: { newRating in
                            metadataManager.setRating(newRating, for: currentAsset.localIdentifier)
                        }
                    ),
                    starSize: 28,
                    spacing: 4
                )

                Spacer()

                // Favorite heart button
                Button(action: {
                    toggleFavorite()
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: AppTheme.IconSize.xl - 4))
                        .foregroundStyle(isFavorite ? .red : .white.opacity(AppTheme.Opacity.medium))
                        .scaleEffect(heartPulse ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: heartPulse)
                        .frame(width: 44, height: 44)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }

            // Date
            if let date = currentAsset.creationDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: AppTheme.IconSize.xs))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    Text(date, style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("at")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    Text(date, style: .time)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
        .background(
            Color(UIColor.systemBackground)
                .cornerRadius(20, corners: [.topLeft, .topRight])
        )
    }

    // MARK: - Methods

    func loadFullImage() {
        PhotoLibraryManager.shared.requestEditedImage(for: currentAsset) { loadedImage in
            self.image = loadedImage
        }
    }

    func toggleFavorite() {
        let newValue = !isFavorite
        let assetId = currentAsset.localIdentifier
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: self.currentAsset)
            request.isFavorite = newValue
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.isFavorite = newValue
                    // Trigger pulse animation when favoriting
                    if newValue {
                        self.heartPulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.heartPulse = false
                        }
                    }
                    // Post notification for thumbnail refresh
                    NotificationCenter.default.post(
                        name: .photoFavoriteChanged,
                        object: nil,
                        userInfo: ["assetId": assetId, "isFavorite": newValue]
                    )
                }
            }
        }
    }

    func deleteCurrentPhoto() {
        let assetId = currentAsset.localIdentifier
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([self.currentAsset] as NSFastEnumeration)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    MetadataManager.shared.deleteMetadata(for: assetId)
                    PhotoEditPersistenceService.shared.deleteEditState(for: assetId)

                    if allAssets.count == 1 {
                        isPresented = false
                    } else if currentIndex >= allAssets.count - 1 {
                        currentIndex = max(0, currentIndex - 1)
                    }
                }
            }
        }
    }
}

// MARK: - Zoomable Photo View

/// Photo view with pinch-to-zoom and double-tap zoom support using UIScrollView
struct ZoomablePhotoView: UIViewRepresentable {
    let asset: PHAsset
    var preloadedImage: UIImage?
    var refreshTrigger: Int = 0
    var isZoomed: Binding<Bool>?

    func makeCoordinator() -> Coordinator {
        Coordinator(isZoomed: isZoomed)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isScrollEnabled = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor)
        ])

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.activityIndicator = spinner

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        if let preloaded = preloadedImage {
            context.coordinator.updateImage(preloaded)
        } else {
            spinner.startAnimating()
            context.coordinator.loadImage(for: asset)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isZoomed = isZoomed

        if let preloaded = preloadedImage, preloaded !== coordinator.currentImage {
            coordinator.updateImage(preloaded)
        }

        if refreshTrigger != coordinator.lastRefreshTrigger {
            coordinator.lastRefreshTrigger = refreshTrigger
            coordinator.loadImage(for: asset)
        }

        if isZoomed == nil && scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: false)
        }

        coordinator.layoutImageIfNeeded()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        var imageView: UIImageView?
        var activityIndicator: UIActivityIndicatorView?
        var isZoomed: Binding<Bool>?
        var currentImage: UIImage?
        var lastRefreshTrigger: Int = 0
        private var lastBounds: CGRect = .zero

        init(isZoomed: Binding<Bool>?) {
            self.isZoomed = isZoomed
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageInScrollView()
            let zoomed = scrollView.zoomScale > 1.01
            scrollView.isScrollEnabled = zoomed
            isZoomed?.wrappedValue = zoomed
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            isZoomed?.wrappedValue = scale > 1.01
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }

            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let location = gesture.location(in: imageView)
                let zoomScale: CGFloat = 2.0
                let width = scrollView.bounds.width / zoomScale
                let height = scrollView.bounds.height / zoomScale
                let rect = CGRect(
                    x: location.x - width / 2,
                    y: location.y - height / 2,
                    width: width,
                    height: height
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }

        func centerImageInScrollView() {
            guard let scrollView = scrollView, let imageView = imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }

        func updateImage(_ image: UIImage) {
            currentImage = image
            imageView?.image = image
            activityIndicator?.stopAnimating()

            guard let scrollView = scrollView, let imageView = imageView else { return }

            scrollView.setZoomScale(1.0, animated: false)
            scrollView.isScrollEnabled = false
            isZoomed?.wrappedValue = false

            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0 && boundsSize.height > 0 else { return }

            let imageSize = image.size
            let widthRatio = boundsSize.width / imageSize.width
            let heightRatio = boundsSize.height / imageSize.height
            let fitRatio = min(widthRatio, heightRatio)

            let fitSize = CGSize(
                width: imageSize.width * fitRatio,
                height: imageSize.height * fitRatio
            )

            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize

            centerImageInScrollView()
            lastBounds = scrollView.bounds
        }

        func layoutImageIfNeeded() {
            guard let scrollView = scrollView, let imageView = imageView,
                  let image = currentImage else { return }
            let bounds = scrollView.bounds
            guard bounds != lastBounds, bounds.width > 0, bounds.height > 0 else { return }
            lastBounds = bounds

            let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let fitSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            centerImageInScrollView()
        }

        func loadImage(for asset: PHAsset) {
            PhotoLibraryManager.shared.requestEditedImage(for: asset) { [weak self] loadedImage in
                if let image = loadedImage {
                    self?.updateImage(image)
                }
            }
        }
    }
}

// MARK: - Rating Stars View

/// Interactive star rating component
struct RatingStarsView: View {
    @Binding var rating: Int
    var starSize: CGFloat = 24
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    if rating == star {
                        rating = 0
                    } else {
                        rating = star
                    }
                }) {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: starSize))
                        .foregroundStyle(star <= rating ? .yellow : .white.opacity(AppTheme.Opacity.medium))
                }
            }
        }
    }
}

// MARK: - Detail Tag Chip

/// Tag chip for photo detail view with colored background
struct DetailTagChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.sm + AppTheme.Spacing.xxs)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Rounded Corner Extension

/// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

/// Shape for rounded corners on specific edges
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Photo Metadata Edit Sheet

/// Sheet for editing all photo metadata with change tracking
struct PhotoMetadataEditSheet: View {
    let asset: PHAsset
    @Binding var isPresented: Bool
    var onPhotoTagged: ((String) -> Void)?  // Called with procedure name when untagged photo is tagged

    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var selectedProcedure: String?
    @State private var selectedToothNumber: Int?
    @State private var selectedToothDate: Date = Date()
    @State private var selectedStage: String?
    @State private var selectedAngle: String?
    @State private var selectedRating: Int = 0

    @State private var hasChanges = false
    @State private var showAddStageSheet = false
    @State private var showAddProcedureSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    // Procedure selection
                    selectionSection(title: "PROCEDURE") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(metadataManager.procedures, id: \.self) { procedure in
                                FilterToggleChip(
                                    text: procedure,
                                    color: AppTheme.procedureColor(for: procedure),
                                    isSelected: selectedProcedure == procedure
                                ) {
                                    if selectedProcedure == procedure {
                                        selectedProcedure = nil
                                    } else {
                                        selectedProcedure = procedure
                                    }
                                    hasChanges = true
                                }
                            }

                            // Add procedure button
                            Button(action: { showAddProcedureSheet = true }) {
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

                            // Clear button
                            if selectedProcedure != nil {
                                Button(action: {
                                    selectedProcedure = nil
                                    hasChanges = true
                                }) {
                                    Text("Clear")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.error)
                                }
                            }
                        }
                    }

                    // Tooth selection
                    selectionSection(title: "TOOTH NUMBER") {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            InlineToothPicker(
                                selectedToothNumber: $selectedToothNumber,
                                selectedDate: $selectedToothDate,
                                autoSelectOnAppear: false,
                                onChanged: { hasChanges = true }
                            )

                            if selectedToothNumber != nil {
                                Button(action: {
                                    selectedToothNumber = nil
                                    hasChanges = true
                                }) {
                                    HStack(spacing: AppTheme.Spacing.xs) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Remove tooth")
                                    }
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                    }

                    // Stage selection
                    selectionSection(title: "STAGE") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(metadataManager.getEnabledStages()) { stageConfig in
                                    StageChipWithDelete(
                                        stageConfig: stageConfig,
                                        isSelected: selectedStage == stageConfig.name,
                                        onSelect: {
                                            if selectedStage == stageConfig.name {
                                                selectedStage = nil
                                            } else {
                                                selectedStage = stageConfig.name
                                            }
                                            hasChanges = true
                                        },
                                        onDelete: stageConfig.isDefault ? nil : {
                                            if selectedStage == stageConfig.name {
                                                selectedStage = nil
                                            }
                                            metadataManager.deleteStage(stageConfig.id)
                                            hasChanges = true
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

                                Spacer()

                                if selectedStage != nil {
                                    Button(action: {
                                        selectedStage = nil
                                        hasChanges = true
                                    }) {
                                        Text("Clear")
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(AppTheme.Colors.error)
                                    }
                                }
                            }
                        }
                    }

                    // Angle selection
                    selectionSection(title: "ANGLE") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(MetadataManager.angles, id: \.self) { angle in
                                FilterToggleChip(
                                    text: angle,
                                    color: AppTheme.angleColor(for: angle),
                                    isSelected: selectedAngle == angle
                                ) {
                                    if selectedAngle == angle {
                                        selectedAngle = nil
                                    } else {
                                        selectedAngle = angle
                                    }
                                    hasChanges = true
                                }
                            }

                            if selectedAngle != nil {
                                Button(action: {
                                    selectedAngle = nil
                                    hasChanges = true
                                }) {
                                    Text("Clear")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.error)
                                }
                            }
                        }
                    }

                    // Rating
                    selectionSection(title: "RATING") {
                        HStack {
                            RatingStarsView(
                                rating: Binding(
                                    get: { selectedRating },
                                    set: { newValue in
                                        selectedRating = newValue
                                        hasChanges = true
                                    }
                                ),
                                starSize: 32,
                                spacing: 8
                            )

                            Spacer()

                            if selectedRating > 0 {
                                Button(action: {
                                    selectedRating = 0
                                    hasChanges = true
                                }) {
                                    Text("Clear")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(AppTheme.Colors.error)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Metadata")
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
                    .disabled(!hasChanges)
                }
            }
            .onAppear {
                loadCurrentMetadata()
            }
            .sheet(isPresented: $showAddStageSheet) {
                AddStageSheet(isPresented: $showAddStageSheet)
            }
            .sheet(isPresented: $showAddProcedureSheet) {
                ProcedureEditorSheet(
                    isPresented: $showAddProcedureSheet,
                    procedure: nil,
                    onSave: { newProcedure in
                        metadataManager.addProcedure(newProcedure)
                        // Auto-select the new procedure
                        selectedProcedure = newProcedure.name
                        hasChanges = true
                    }
                )
            }
        }
    }

    func selectionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            content()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    func loadCurrentMetadata() {
        if let metadata = metadataManager.getMetadata(for: asset.localIdentifier) {
            selectedProcedure = metadata.procedure
            selectedToothNumber = metadata.toothNumber
            selectedToothDate = metadata.toothDate ?? Date()
            selectedStage = metadata.stage
            selectedAngle = metadata.angle
            selectedRating = metadata.rating ?? 0
        }
    }

    func saveChanges() {
        // Check if this was previously untagged
        let previousMetadata = metadataManager.getMetadata(for: asset.localIdentifier)
        let wasUntagged = previousMetadata?.procedure == nil

        let metadata = PhotoMetadata(
            procedure: selectedProcedure,
            toothNumber: selectedToothNumber,
            toothDate: selectedToothDate,
            stage: selectedStage,
            angle: selectedAngle,
            rating: selectedRating > 0 ? selectedRating : nil
        )

        metadataManager.assignMetadata(metadata, to: asset.localIdentifier)

        // If was untagged and now has a procedure, notify parent
        if wasUntagged, let procedure = selectedProcedure {
            onPhotoTagged?(procedure)
        }

        isPresented = false
    }
}

// MARK: - Stage Chip With Delete

/// A chip-style button for stage selection in library editing with optional delete functionality
struct StageChipWithDelete: View {
    let stageConfig: StageConfig
    let isSelected: Bool
    let onSelect: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Button(action: onSelect) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    StageIconView(
                        stageConfig: stageConfig,
                        size: 14,
                        foregroundColor: isSelected ? .white : stageConfig.color
                    )

                    Text(stageConfig.name)
                        .font(AppTheme.Typography.subheadline.weight(.medium))
                        .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                }
                .padding(.leading, AppTheme.Spacing.sm)
                .padding(.trailing, onDelete != nil ? AppTheme.Spacing.xxs : AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            .buttonStyle(PlainButtonStyle())

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: AppTheme.IconSize.xs - 2, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(AppTheme.Opacity.prominent) : AppTheme.Colors.textTertiary)
                        .padding(.trailing, AppTheme.Spacing.xs)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(isSelected ? stageConfig.color : AppTheme.Colors.surfaceSecondary)
        .cornerRadius(AppTheme.CornerRadius.full)
    }
}

// MARK: - Metadata Row

/// Simple row for displaying metadata key-value pairs
struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
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

    @State private var selectedPhotoId: String? = nil

    var filteredAssets: [PHAsset] {
        viewModel.filteredAssets(
            from: library.assets,
            metadata: metadataManager,
            filter: router.libraryFilter
        )
    }

    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        Group {
            if filteredAssets.isEmpty {
                emptyState
            } else {
                if viewModel.displayMode == .grid {
                    photoGrid
                } else {
                    photoList
                }
            }
        }
        .padding(.top, AppTheme.Spacing.sm)
        .sheet(item: $selectedPhotoId) { photoId in
            PhotoDetailSheet(
                photoId: photoId,
                allAssets: filteredAssets,
                onDismiss: { selectedPhotoId = nil },
                onPhotoTagged: { _ in
                    selectedPhotoId = nil
                    // Photo stays in All Photos view, just now tagged
                }
            )
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack {
            Spacer()

            if router.libraryFilter.isEmpty {
                DPEmptyState(
                    icon: "photo.on.rectangle",
                    title: "No Photos",
                    message: "Your captured photos will appear here.",
                    actionTitle: "Start Capturing"
                ) {
                    router.selectedTab = .capture
                }
            } else {
                DPEmptyState(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matches",
                    message: "No photos match your current filters.",
                    actionTitle: "Clear Filters"
                ) {
                    router.libraryFilter.reset()
                }
            }

            Spacer()
        }
    }

    // MARK: - Photo Grid
    var photoGrid: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Results count
            HStack {
                Text("\(filteredAssets.count) photo\(filteredAssets.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid with metadata cells
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredAssets, id: \.localIdentifier) { asset in
                    PhotoGridCell(
                        asset: asset,
                        metadata: metadataManager.getMetadata(for: asset.localIdentifier),
                        isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                        isSelectionMode: viewModel.isSelectionMode,
                        onTap: {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(for: asset.localIdentifier)
                            } else {
                                selectedPhotoId = asset.localIdentifier
                            }
                        },
                        metadataManager: metadataManager
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)

            Spacer(minLength: 100)
        }
    }

    // MARK: - Photo List
    var photoList: some View {
        LazyVStack(spacing: AppTheme.Spacing.sm) {
            // Results count
            HStack {
                Text("\(filteredAssets.count) photo\(filteredAssets.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo list
            ForEach(filteredAssets, id: \.localIdentifier) { asset in
                PhotoListRow(
                    asset: asset,
                    metadata: metadataManager.getMetadata(for: asset.localIdentifier),
                    isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                    isSelectionMode: viewModel.isSelectionMode
                ) {
                    if viewModel.isSelectionMode {
                        viewModel.toggleSelection(for: asset.localIdentifier)
                    } else {
                        selectedPhotoId = asset.localIdentifier
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }

            Spacer(minLength: 100)
        }
    }
}

// MARK: - PhotoListRow

/// List row for displaying photo with metadata
struct PhotoListRow: View {
    let asset: PHAsset
    let metadata: PhotoMetadata?
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @ObservedObject var metadataManager = MetadataManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Selection indicator
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .font(.title2)
                }

                // Thumbnail
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(AppTheme.Colors.surfaceSecondary)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

                // Metadata
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    // Tags
                    HStack(spacing: AppTheme.Spacing.xs) {
                        if let procedure = metadata?.procedure {
                            Text(procedure)
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        if let stage = metadata?.stage {
                            Text("• \(PhotoMetadata.stageAbbreviation(for: stage))")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    // Date
                    if let date = asset.creationDate {
                        Text(date, style: .date)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    // Rating
                    if let rating = metadata?.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: AppTheme.IconSize.xs - 2))
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }

                Spacer()

                // Chevron
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, AppTheme.Spacing.md)
        .onAppear {
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == asset.localIdentifier {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestEditedThumbnail(for: asset, size: CGSize(width: 120, height: 120)) { loadedImage in
            self.image = loadedImage
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
                                .fill(isSelected ? AppTheme.Colors.primary : Color.white.opacity(AppTheme.Opacity.strong))
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: AppTheme.IconSize.xs, weight: .bold))
                                    .foregroundStyle(.white)
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
                                            .font(.system(size: AppTheme.IconSize.xs - 4))
                                            .foregroundStyle(AppTheme.Colors.warning)
                                    }
                                }
                                .padding(.horizontal, AppTheme.Spacing.xs)
                                .padding(.vertical, AppTheme.Spacing.xxs)
                                .background(Color.black.opacity(AppTheme.Opacity.heavy))
                                .cornerRadius(AppTheme.CornerRadius.xs)
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
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this asset was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == asset.localIdentifier {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestEditedThumbnail(for: asset, size: CGSize(width: 200, height: 200)) { loadedImage in
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
    let onFavorite: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Selection count header
            if selectedCount > 0 {
                Text("\(selectedCount) photo\(selectedCount == 1 ? "" : "s") selected")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.sm)
            }

            Divider()
                .padding(.top, AppTheme.Spacing.sm)

            HStack(spacing: AppTheme.Spacing.lg) {
                // Share button
                ActionBarButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    isDisabled: selectedCount == 0,
                    action: onShare
                )

                // Favorite button
                ActionBarButton(
                    icon: "heart",
                    label: "Favorite",
                    isDisabled: selectedCount == 0,
                    action: onFavorite
                )

                // Delete button
                ActionBarButton(
                    icon: "trash",
                    label: "Delete",
                    isDisabled: selectedCount == 0,
                    isDestructive: true,
                    action: onDelete
                )
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.surface)
        }
    }
}

// MARK: - ActionBarButton

/// Individual button for the selection action bar
struct ActionBarButton: View {
    let icon: String
    let label: String
    var isDisabled: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var foregroundColor: Color {
        if isDisabled {
            return AppTheme.Colors.textTertiary
        } else if isDestructive {
            return AppTheme.Colors.error
        } else {
            return AppTheme.Colors.primary
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.IconSize.lg - 2))

                Text(label)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(foregroundColor)
        }
        .disabled(isDisabled)
    }
}

// MARK: - LibraryFilterSheet

/// Sheet for configuring library filters with multiple filter categories
struct LibraryFilterSheet: View {
    @Binding var filter: LibraryFilter
    @Environment(\.dismiss) var dismiss
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var tempFilter: LibraryFilter = LibraryFilter()
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    // Procedures section
                    filterSection(title: "PROCEDURES") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(metadataManager.procedures, id: \.self) { procedure in
                                FilterToggleChip(
                                    text: procedure,
                                    color: AppTheme.procedureColor(for: procedure),
                                    isSelected: tempFilter.procedures.contains(procedure)
                                ) {
                                    toggleProcedure(procedure)
                                }
                            }
                        }
                    }

                    // Stages section
                    filterSection(title: "STAGES") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(metadataManager.getEnabledStages()) { stageConfig in
                                    FilterToggleChip(
                                        text: stageConfig.name,
                                        color: stageConfig.color,
                                        isSelected: tempFilter.stages.contains(stageConfig.name)
                                    ) {
                                        toggleStage(stageConfig.name)
                                    }
                                }
                            }
                        }
                    }

                    // Angles section
                    filterSection(title: "ANGLES") {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(MetadataManager.angles, id: \.self) { angle in
                                FilterToggleChip(
                                    text: angle,
                                    color: AppTheme.angleColor(for: angle),
                                    isSelected: tempFilter.angles.contains(angle)
                                ) {
                                    toggleAngle(angle)
                                }
                            }
                        }
                    }

                    // Rating section
                    filterSection(title: "MINIMUM RATING") {
                        HStack(spacing: AppTheme.Spacing.md) {
                            ForEach([1, 2, 3, 4, 5], id: \.self) { rating in
                                RatingFilterButton(
                                    rating: rating,
                                    isSelected: tempFilter.minimumRating == rating
                                ) {
                                    if tempFilter.minimumRating == rating {
                                        tempFilter.minimumRating = nil
                                    } else {
                                        tempFilter.minimumRating = rating
                                    }
                                }
                            }
                        }
                    }

                    // Date range section
                    filterSection(title: "DATE RANGE") {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                DateRangeButton(
                                    text: "Last 7 Days",
                                    isSelected: tempFilter.dateRange == .lastWeek
                                ) {
                                    tempFilter.dateRange = tempFilter.dateRange == .lastWeek ? nil : .lastWeek
                                }

                                DateRangeButton(
                                    text: "Last 30 Days",
                                    isSelected: tempFilter.dateRange == .lastMonth
                                ) {
                                    tempFilter.dateRange = tempFilter.dateRange == .lastMonth ? nil : .lastMonth
                                }
                            }

                            HStack(spacing: AppTheme.Spacing.sm) {
                                DateRangeButton(
                                    text: "Last 3 Months",
                                    isSelected: tempFilter.dateRange == .last3Months
                                ) {
                                    tempFilter.dateRange = tempFilter.dateRange == .last3Months ? nil : .last3Months
                                }

                                DateRangeButton(
                                    text: "Last Year",
                                    isSelected: tempFilter.dateRange == .lastYear
                                ) {
                                    tempFilter.dateRange = tempFilter.dateRange == .lastYear ? nil : .lastYear
                                }
                            }

                            // Custom date range
                            DisclosureGroup("Custom Range") {
                                VStack(spacing: AppTheme.Spacing.sm) {
                                    DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                                    DatePicker("To", selection: $customEndDate, displayedComponents: .date)

                                    Button("Apply Custom Range") {
                                        tempFilter.dateRange = .custom(start: customStartDate, end: customEndDate)
                                    }
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundStyle(AppTheme.Colors.primary)
                                }
                                .padding(.top, AppTheme.Spacing.sm)
                            }
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    // Active filter count
                    if tempFilter.activeFilterCount > 0 {
                        HStack {
                            Text("\(tempFilter.activeFilterCount) filter\(tempFilter.activeFilterCount == 1 ? "" : "s") active")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            Spacer()

                            Button("Reset All") {
                                tempFilter.reset()
                            }
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Filter Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filter = tempFilter
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempFilter = filter

                // Set custom date picker values if custom range exists
                if case .custom(let start, let end) = filter.dateRange {
                    customStartDate = start
                    customEndDate = end
                }
            }
        }
    }

    // MARK: - Helper Views

    func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            content()
                .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Toggle Methods

    func toggleProcedure(_ procedure: String) {
        if tempFilter.procedures.contains(procedure) {
            tempFilter.procedures.remove(procedure)
        } else {
            tempFilter.procedures.insert(procedure)
        }
    }

    func toggleStage(_ stage: String) {
        if tempFilter.stages.contains(stage) {
            tempFilter.stages.remove(stage)
        } else {
            tempFilter.stages.insert(stage)
        }
    }

    func toggleAngle(_ angle: String) {
        if tempFilter.angles.contains(angle) {
            tempFilter.angles.remove(angle)
        } else {
            tempFilter.angles.insert(angle)
        }
    }
}

// MARK: - Filter Toggle Chip

/// Toggleable chip for filter selection with colored dot and checkmark
struct FilterToggleChip: View {
    let text: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(text)
                    .font(AppTheme.Typography.subheadline)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: AppTheme.IconSize.xs, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? color : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                    .stroke(isSelected ? color : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Rating Filter Button

/// Button for selecting minimum rating filter
struct RatingFilterButton: View {
    let rating: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 2) {
                Text("\(rating)")
                    .font(AppTheme.Typography.subheadline)
                Image(systemName: "star.fill")
                    .font(.system(size: AppTheme.IconSize.xs))
                Text("+")
                    .font(AppTheme.Typography.caption)
            }
            .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? Color.yellow : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                    .stroke(isSelected ? Color.yellow : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Range Button

/// Button for selecting preset date ranges
struct DateRangeButton: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                        .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
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
