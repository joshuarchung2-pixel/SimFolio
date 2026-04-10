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
import Combine
import UniformTypeIdentifiers
import UIKit

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

    /// Set of selected photo record IDs
    @Published var selectedAssetIds: Set<UUID> = []

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

    /// Filter records based on current LibraryFilter
    /// - Parameters:
    ///   - records: All records to filter
    ///   - metadata: MetadataManager instance
    ///   - filter: Current filter configuration
    /// - Returns: Filtered array of records
    func filteredRecords(
        from records: [PhotoRecord],
        metadata: MetadataManager,
        filter: LibraryFilter
    ) -> [PhotoRecord] {
        var result = records

        // Filter by procedure
        if !filter.procedures.isEmpty {
            result = result.filter { record in
                guard let m = metadata.getMetadata(for: record.id.uuidString),
                      let procedure = m.procedure else { return false }
                return filter.procedures.contains(procedure)
            }
        }

        // Filter by stage
        if !filter.stages.isEmpty {
            result = result.filter { record in
                guard let m = metadata.getMetadata(for: record.id.uuidString),
                      let stage = m.stage else { return false }
                return filter.stages.contains(stage)
            }
        }

        // Filter by angle
        if !filter.angles.isEmpty {
            result = result.filter { record in
                guard let m = metadata.getMetadata(for: record.id.uuidString),
                      let angle = m.angle else { return false }
                return filter.angles.contains(angle)
            }
        }

        // Filter by minimum rating
        if let minRating = filter.minimumRating {
            result = result.filter { record in
                (metadata.getRating(for: record.id.uuidString) ?? 0) >= minRating
            }
        }

        // Filter by favorites only
        if filter.favoritesOnly {
            result = result.filter { record in
                metadata.getMetadata(for: record.id.uuidString)?.isFavorite == true
            }
        }

        // Filter by date range
        if let dateRange = filter.dateRange {
            let now = Date()
            let calendar = Calendar.current

            switch dateRange {
            case .lastWeek:
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                result = result.filter { $0.createdDate >= weekAgo }

            case .lastMonth:
                let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                result = result.filter { $0.createdDate >= monthAgo }

            case .last3Months:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                result = result.filter { $0.createdDate >= threeMonthsAgo }

            case .lastYear:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                result = result.filter { $0.createdDate >= yearAgo }

            case .custom(let start, let end):
                result = result.filter { record in
                    return record.createdDate >= start && record.createdDate <= end
                }
            }
        }

        // Filter by portfolio (records matching portfolio requirements)
        if let portfolioId = filter.portfolioId {
            if let portfolio = metadata.portfolios.first(where: { $0.id == portfolioId }) {
                let proceduresInPortfolio = Set(portfolio.requirements.map { $0.procedure })
                result = result.filter { record in
                    guard let m = metadata.getMetadata(for: record.id.uuidString),
                          let procedure = m.procedure else { return false }
                    return proceduresInPortfolio.contains(procedure)
                }
            }
        }

        // Sort
        switch sortOrder {
        case .dateNewest:
            result.sort { $0.createdDate > $1.createdDate }
        case .dateOldest:
            result.sort { $0.createdDate < $1.createdDate }
        case .procedure:
            result.sort { record1, record2 in
                let p1 = metadata.getMetadata(for: record1.id.uuidString)?.procedure ?? ""
                let p2 = metadata.getMetadata(for: record2.id.uuidString)?.procedure ?? ""
                return p1 < p2
            }
        case .rating:
            result.sort { record1, record2 in
                let r1 = metadata.getRating(for: record1.id.uuidString) ?? 0
                let r2 = metadata.getRating(for: record2.id.uuidString) ?? 0
                return r1 > r2
            }
        }

        return result
    }

    // MARK: - Grouping Methods

    /// Group records by procedure type
    /// - Parameters:
    ///   - records: Records to group
    ///   - metadata: MetadataManager instance
    /// - Returns: Dictionary of procedure name to records
    func recordsByProcedure(
        from records: [PhotoRecord],
        metadata: MetadataManager
    ) -> [String: [PhotoRecord]] {
        var grouped: [String: [PhotoRecord]] = [:]

        for record in records {
            let procedure: String
            if let meta = metadata.getMetadata(for: record.id.uuidString),
               let proc = meta.procedure {
                procedure = proc
            } else {
                procedure = "Untagged"
            }

            if grouped[procedure] == nil {
                grouped[procedure] = []
            }
            grouped[procedure]?.append(record)
        }

        return grouped
    }

    /// Get sorted list of procedure names for display
    /// - Parameters:
    ///   - records: Records to analyze
    ///   - metadata: MetadataManager instance
    /// - Returns: Sorted array of procedure names
    func sortedProcedureNames(
        from records: [PhotoRecord],
        metadata: MetadataManager
    ) -> [String] {
        let grouped = recordsByProcedure(from: records, metadata: metadata)
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

    /// Toggle selection state for a record
    /// - Parameter recordId: The record's UUID
    func toggleSelection(for recordId: UUID) {
        if selectedAssetIds.contains(recordId) {
            selectedAssetIds.remove(recordId)
        } else {
            selectedAssetIds.insert(recordId)
        }
    }

    /// Select all provided records
    /// - Parameter records: Records to select
    func selectAll(records: [PhotoRecord]) {
        selectedAssetIds = Set(records.map { $0.id })
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
    @ObservedObject var photoStorage = PhotoStorageService.shared
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
        }
    }

    // MARK: - Action Handlers

    /// Handle deletion of selected photos
    func handleDeleteSelected() {
        let idsToDelete = Array(viewModel.selectedAssetIds)
        guard !idsToDelete.isEmpty else { return }

        // Remove metadata
        for id in idsToDelete {
            MetadataManager.shared.deleteMetadata(for: id.uuidString)
            PhotoEditPersistenceService.shared.deleteEditState(for: id.uuidString)
        }

        // Delete files from disk
        PhotoStorageService.shared.deletePhotos(ids: idsToDelete)

        viewModel.exitSelectionMode()
    }

    /// Handle sharing of selected photos
    func handleShareSelected() {
        let ids = Array(viewModel.selectedAssetIds).map { $0.uuidString }
        router.presentSheet(.shareSheet(photoIds: ids))
    }

    /// Handle favoriting selected photos
    func handleFavoriteSelected() {
        let selectedIds = Array(viewModel.selectedAssetIds)
        guard !selectedIds.isEmpty else { return }

        for id in selectedIds {
            let key = id.uuidString
            var meta = metadataManager.getMetadata(for: key) ?? PhotoMetadata()
            meta.isFavorite = true
            metadataManager.assignMetadata(meta, to: key)
            NotificationCenter.default.post(
                name: .photoFavoriteChanged,
                object: nil,
                userInfo: ["assetId": key, "isFavorite": true]
            )
        }
        viewModel.exitSelectionMode()
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
                        color: AppTheme.Colors.warning,
                        onRemove: {
                            filter.minimumRating = nil
                        }
                    )
                }

                // Favorites chip
                if filter.favoritesOnly {
                    FilterChip(
                        text: "Favorites",
                        color: AppTheme.Colors.warning,
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
    @ObservedObject var photoStorage = PhotoStorageService.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    // Navigation callbacks
    var onProcedureTap: ((String) -> Void)?
    var onAllPhotosTap: (() -> Void)?

    // Procedure sort order stored in UserDefaults
    @AppStorage("procedureSortOrder") private var procedureSortOrder: ProcedureSortOrder = .alphabetical

    var procedureStats: [(procedure: String, count: Int, prepCount: Int, restoCount: Int, mostRecentDate: Date?)] {
        var stats: [(String, Int, Int, Int, Date?)] = []
        let grouped = viewModel.recordsByProcedure(from: photoStorage.records, metadata: metadataManager)

        for procedure in metadataManager.procedures {
            let records = grouped[procedure] ?? []
            let prepCount = records.filter { record in
                metadataManager.getMetadata(for: record.id.uuidString)?.stage == "Preparation"
            }.count
            let restoCount = records.filter { record in
                metadataManager.getMetadata(for: record.id.uuidString)?.stage == "Restoration"
            }.count
            let mostRecentDate = records.map { $0.createdDate }.max()

            if records.count > 0 {
                stats.append((procedure, records.count, prepCount, restoCount, mostRecentDate))
            }
        }

        // Add untagged if any
        let untaggedRecords = grouped["Untagged"] ?? []
        if untaggedRecords.count > 0 {
            let mostRecentDate = untaggedRecords.map { $0.createdDate }.max()
            stats.append(("Untagged", untaggedRecords.count, 0, 0, mostRecentDate))
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
                    count: photoStorage.records.count,
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
                                let records = viewModel.recordsByProcedure(from: photoStorage.records, metadata: metadataManager)[stat.procedure] ?? []
                                for record in records {
                                    viewModel.selectedAssetIds.insert(record.id)
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
        photoStorage.records.filter { record in
            metadataManager.getMetadata(for: record.id.uuidString)?.isFavorite == true
        }.count
    }

    var recentCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return photoStorage.records.filter { $0.createdDate > weekAgo }.count
    }

    var untaggedCount: Int {
        photoStorage.records.filter { record in
            metadataManager.getMetadata(for: record.id.uuidString)?.procedure == nil
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
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
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

/// Async thumbnail loader for PhotoRecord
struct ThumbnailView: View {
    let record: PhotoRecord
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
            // Refresh if this record was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == record.id.uuidString {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}

// MARK: - RecordThumbnailView

/// Small thumbnail view for PhotoRecord (used in collapsed tooth group previews)
struct RecordThumbnailView: View {
    let record: PhotoRecord
    let size: CGFloat

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
            }
        }
        .onAppear {
            image = PhotoStorageService.shared.loadThumbnail(id: record.id)
        }
    }
}

// MARK: - ProcedureDetailView

/// Detail view showing photos for a specific procedure, grouped by tooth and stage
struct ProcedureDetailView: View {
    let procedure: String
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var photoStorage = PhotoStorageService.shared
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

    var procedureRecords: [PhotoRecord] {
        if procedure == "Untagged" {
            return photoStorage.records.filter { record in
                metadataManager.getMetadata(for: record.id.uuidString)?.procedure == nil
            }
        } else {
            return photoStorage.records.filter { record in
                metadataManager.getMetadata(for: record.id.uuidString)?.procedure == procedure
            }
        }
    }

    var recordsByTooth: [Int: [PhotoRecord]] {
        var grouped: [Int: [PhotoRecord]] = [:]

        for record in procedureRecords {
            let toothNumber = metadataManager.getMetadata(for: record.id.uuidString)?.toothNumber ?? 0
            grouped[toothNumber, default: []].append(record)
        }

        return grouped
    }

    var sortedToothNumbers: [Int] {
        recordsByTooth.keys.sorted()
    }

    /// Group procedure records by stage
    var stageAssetCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for record in procedureRecords {
            let stage = metadataManager.getMetadata(for: record.id.uuidString)?.stage ?? "Unknown"
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
        if procedureRecords.isEmpty {
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
                    allRecords: procedureRecords,
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
                    value: "\(procedureRecords.count)",
                    label: "Photos",
                    color: AppTheme.procedureColor(for: procedure)
                )
                .frame(maxWidth: .infinity)
            } else {
                // Full stats for regular procedures
                HStack(spacing: AppTheme.Spacing.lg) {
                    StatItem(
                        value: "\(procedureRecords.count)",
                        label: "Photos",
                        color: AppTheme.procedureColor(for: procedure)
                    )

                    Divider()
                        .frame(height: 40)

                    StatItem(
                        value: "\(recordsByTooth.count)",
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
                    records: recordsByTooth[toothNumber] ?? [],
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
                    onSelectRecord: { recordId in
                        if viewModel.isSelectionMode {
                            viewModel.toggleSelection(for: recordId)
                        } else {
                            selectedPhotoId = recordId.uuidString
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
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm)
    ]

    var gridContent: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Results count
            HStack {
                Text("\(procedureRecords.count) photo\(procedureRecords.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(procedureRecords) { record in
                    PhotoGridCell(
                        record: record,
                        metadata: metadataManager.getMetadata(for: record.id.uuidString),
                        isSelected: viewModel.selectedAssetIds.contains(record.id),
                        isSelectionMode: viewModel.isSelectionMode,
                        onTap: {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(for: record.id)
                            } else {
                                selectedPhotoId = record.id.uuidString
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
    let records: [PhotoRecord]
    let isExpanded: Bool
    let isSelectionMode: Bool
    let selectedIds: Set<UUID>
    let onToggleExpand: () -> Void
    let onSelectRecord: (UUID) -> Void
    @ObservedObject var metadataManager: MetadataManager

    var toothLabel: String {
        toothNumber == 0 ? "No Tooth Assigned" : "Tooth #\(toothNumber)"
    }

    /// Group records by their stage name
    var recordsByStage: [String: [PhotoRecord]] {
        var grouped: [String: [PhotoRecord]] = [:]
        for record in records {
            let stage = metadataManager.getMetadata(for: record.id.uuidString)?.stage ?? "Unknown"
            grouped[stage, default: []].append(record)
        }
        return grouped
    }

    /// Get distinct stages in this tooth group, sorted by StageConfig.sortOrder
    var sortedStages: [String] {
        let stages = Set(recordsByStage.keys)
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
                                if let count = recordsByStage[stage]?.count, count > 0 {
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
                            ForEach(records.prefix(3)) { record in
                                RecordThumbnailView(record: record, size: 32)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xs)
                                            .stroke(AppTheme.Colors.surface, lineWidth: 1)
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
                        if let stageRecords = recordsByStage[stage], !stageRecords.isEmpty {
                            StagePhotoGrid(
                                stage: stage,
                                records: stageRecords,
                                isSelectionMode: isSelectionMode,
                                selectedIds: selectedIds,
                                onSelectRecord: onSelectRecord,
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
    let records: [PhotoRecord]
    let isSelectionMode: Bool
    let selectedIds: Set<UUID>
    let onSelectRecord: (UUID) -> Void
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
                ForEach(records) { record in
                    LibraryPhotoThumbnail(
                        record: record,
                        isSelected: selectedIds.contains(record.id),
                        isSelectionMode: isSelectionMode
                    ) {
                        onSelectRecord(record.id)
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
    let record: PhotoRecord
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var isFavorite: Bool = false
    @State private var showFavoritePulse: Bool = false
    @ObservedObject var metadataManager = MetadataManager.shared

    var rating: Int {
        metadataManager.getRating(for: record.id.uuidString) ?? 0
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
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1)
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
            isFavorite = metadataManager.getMetadata(for: record.id.uuidString)?.isFavorite == true
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this record was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == record.id.uuidString {
                loadThumbnail()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoFavoriteChanged)) { notification in
            // Update favorite status if this record's favorite changed
            if let assetId = notification.userInfo?["assetId"] as? String,
               assetId == record.id.uuidString,
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
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}

// MARK: - PhotoGridCell

/// Grid cell showing photo thumbnail with metadata below
struct PhotoGridCell: View {
    let record: PhotoRecord
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
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1)
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
                                    .foregroundStyle(AppTheme.Colors.warning)
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
            isFavorite = metadataManager.getMetadata(for: record.id.uuidString)?.isFavorite == true
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoEditSaved)) { notification in
            // Refresh if this record was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == record.id.uuidString {
                // Force reload by clearing and reloading
                loadThumbnailForce()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoFavoriteChanged)) { notification in
            // Update favorite status if this record's favorite changed
            if let assetId = notification.userInfo?["assetId"] as? String,
               assetId == record.id.uuidString,
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
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}

// MARK: - Photo Detail Sheet

/// Sheet wrapper for photo detail view - presents PhotoDetailView in fullscreen
struct PhotoDetailSheet: View {
    let photoId: String
    let allRecords: [PhotoRecord]
    let onDismiss: () -> Void
    var onPhotoTagged: ((String) -> Void)?

    @State private var isPresented = true

    var body: some View {
        if let record = allRecords.first(where: { $0.id.uuidString == photoId }) {
            PhotoDetailView(
                record: record,
                allRecords: allRecords,
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
            // Record was tagged and moved - dismiss gracefully
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
    let record: PhotoRecord
    let allRecords: [PhotoRecord]
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
    /// Local state to track favorite status
    @State private var isFavorite: Bool = false
    /// Animation state for heart pulse effect
    @State private var heartPulse: Bool = false
    /// Track if current photo is zoomed (disables page swiping when zoomed)
    @State private var isPhotoZoomed: Bool = false

    var currentRecord: PhotoRecord {
        allRecords.indices.contains(currentIndex) ? allRecords[currentIndex] : record
    }

    var currentMetadata: PhotoMetadata? {
        metadataManager.getMetadata(for: currentRecord.id.uuidString)
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
            currentIndex = allRecords.firstIndex(where: { $0.id == record.id }) ?? 0
            isFavorite = metadataManager.getMetadata(for: currentRecord.id.uuidString)?.isFavorite == true
            loadFullImage()
        }
        .onChange(of: currentIndex) { _ in
            isFavorite = metadataManager.getMetadata(for: currentRecord.id.uuidString)?.isFavorite == true
            loadFullImage()
        }
        .sheet(isPresented: $showMetadataEditor) {
            PhotoMetadataEditSheet(
                recordId: currentRecord.id.uuidString,
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
                photoId: currentRecord.id,
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
                        userInfo: ["assetId": currentRecord.id.uuidString]
                    )
                }
            )
        }
    }

    // MARK: - Photo View

    func photoView(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allRecords.enumerated()), id: \.element.id) { index, photoRecord in
                ZoomablePhotoView(
                    record: photoRecord,
                    preloadedImage: index == currentIndex ? editedImage : nil,
                    refreshTrigger: index == currentIndex ? imageRefreshTrigger : 0,
                    isZoomed: index == currentIndex ? $isPhotoZoomed : nil
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
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
            Text("\(currentIndex + 1) / \(allRecords.count)")
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
                            metadataManager.setRating(newRating, for: currentRecord.id.uuidString)
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
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: AppTheme.IconSize.xs))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                Text(currentRecord.createdDate, style: .date)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("at")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                Text(currentRecord.createdDate, style: .time)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.xl, corners: [.topLeft, .topRight])
        .padding(.bottom, -AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface.ignoresSafeArea(.all, edges: .bottom))
    }

    // MARK: - Methods

    func loadFullImage() {
        image = PhotoStorageService.shared.loadImage(id: currentRecord.id)
    }

    func toggleFavorite() {
        let newValue = !isFavorite
        let assetId = currentRecord.id.uuidString

        var meta = metadataManager.getMetadata(for: assetId) ?? PhotoMetadata()
        meta.isFavorite = newValue
        metadataManager.assignMetadata(meta, to: assetId)

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

    func deleteCurrentPhoto() {
        let recordId = currentRecord.id
        let assetId = recordId.uuidString

        MetadataManager.shared.deleteMetadata(for: assetId)
        PhotoEditPersistenceService.shared.deleteEditState(for: assetId)
        PhotoStorageService.shared.deletePhoto(id: recordId)

        if allRecords.count == 1 {
            isPresented = false
        } else if currentIndex >= allRecords.count - 1 {
            currentIndex = max(0, currentIndex - 1)
        }
    }
}

// MARK: - Zoomable Photo View

/// Photo view with pinch-to-zoom and double-tap zoom support using UIScrollView
/// UIScrollView subclass that notifies on layout so the image can be
/// sized once the view has real bounds (fixes black-image-on-appear).
class LayoutAwareScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

struct ZoomablePhotoView: UIViewRepresentable {
    /// PhotoRecord for app-owned photos
    let record: PhotoRecord
    var preloadedImage: UIImage?
    var refreshTrigger: Int = 0
    var isZoomed: Binding<Bool>?

    init(record: PhotoRecord, preloadedImage: UIImage? = nil, refreshTrigger: Int = 0, isZoomed: Binding<Bool>? = nil) {
        self.record = record
        self.preloadedImage = preloadedImage
        self.refreshTrigger = refreshTrigger
        self.isZoomed = isZoomed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isZoomed: isZoomed)
    }

    func makeUIView(context: Context) -> LayoutAwareScrollView {
        let scrollView = LayoutAwareScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isScrollEnabled = true
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        let coordinator = context.coordinator
        scrollView.onLayout = { [weak coordinator] in
            coordinator?.layoutImageIfNeeded()
        }

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
            context.coordinator.loadImage(for: record)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: LayoutAwareScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isZoomed = isZoomed

        if let preloaded = preloadedImage, preloaded !== coordinator.currentImage {
            coordinator.updateImage(preloaded)
        }

        if refreshTrigger != coordinator.lastRefreshTrigger {
            coordinator.lastRefreshTrigger = refreshTrigger
            coordinator.loadImage(for: record)
        }

        if isZoomed == nil && scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: false)
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        var imageView: UIImageView?
        var activityIndicator: UIActivityIndicatorView?
        var isZoomed: Binding<Bool>?
        var currentImage: UIImage?
        var lastRefreshTrigger: Int = 0
        private static let zoomedThreshold: CGFloat = 1.01
        private var lastBoundsSize: CGSize = .zero

        init(isZoomed: Binding<Bool>?) {
            self.isZoomed = isZoomed
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageInScrollView()
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            scrollView.panGestureRecognizer.isEnabled = true
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            let zoomed = scale > Self.zoomedThreshold
            scrollView.panGestureRecognizer.isEnabled = zoomed
            isZoomed?.wrappedValue = zoomed
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }

            if scrollView.zoomScale > Self.zoomedThreshold {
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
            scrollView.panGestureRecognizer.isEnabled = false
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
            lastBoundsSize = scrollView.bounds.size
        }

        func layoutImageIfNeeded() {
            guard let scrollView = scrollView, let imageView = imageView,
                  let image = currentImage else { return }
            let bounds = scrollView.bounds
            // Compare size only — during zoom, bounds.origin (contentOffset) changes
            // but frame size stays the same. Also skip while actively zoomed.
            guard bounds.size != lastBoundsSize, bounds.width > 0, bounds.height > 0 else { return }
            guard scrollView.zoomScale <= Self.zoomedThreshold else { return }
            lastBoundsSize = bounds.size

            let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let fitSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            centerImageInScrollView()
        }

        func loadImage(for record: PhotoRecord) {
            if let loadedImage = PhotoStorageService.shared.loadImage(id: record.id) {
                self.updateImage(loadedImage)
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
                        .foregroundStyle(star <= rating ? AppTheme.Colors.warning : .white.opacity(AppTheme.Opacity.medium))
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
    let recordId: String
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
                                spacing: AppTheme.Spacing.sm
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
        if let metadata = metadataManager.getMetadata(for: recordId) {
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
        let previousMetadata = metadataManager.getMetadata(for: recordId)
        let wasUntagged = previousMetadata?.procedure == nil

        // Preserve existing favorite status
        let existingFavorite = previousMetadata?.isFavorite

        let metadata = PhotoMetadata(
            procedure: selectedProcedure,
            toothNumber: selectedToothNumber,
            toothDate: selectedToothDate,
            stage: selectedStage,
            angle: selectedAngle,
            rating: selectedRating > 0 ? selectedRating : nil,
            isFavorite: existingFavorite
        )

        metadataManager.assignMetadata(metadata, to: recordId)

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
    @ObservedObject var photoStorage = PhotoStorageService.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    @State private var selectedPhotoId: String? = nil

    var filteredRecords: [PhotoRecord] {
        viewModel.filteredRecords(
            from: photoStorage.records,
            metadata: metadataManager,
            filter: router.libraryFilter
        )
    }

    let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
        GridItem(.flexible(), spacing: AppTheme.Spacing.sm)
    ]

    var body: some View {
        Group {
            if filteredRecords.isEmpty {
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
                allRecords: filteredRecords,
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
                Text("\(filteredRecords.count) photo\(filteredRecords.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo grid with metadata cells
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredRecords) { record in
                    PhotoGridCell(
                        record: record,
                        metadata: metadataManager.getMetadata(for: record.id.uuidString),
                        isSelected: viewModel.selectedAssetIds.contains(record.id),
                        isSelectionMode: viewModel.isSelectionMode,
                        onTap: {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(for: record.id)
                            } else {
                                selectedPhotoId = record.id.uuidString
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
                Text("\(filteredRecords.count) photo\(filteredRecords.count == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Photo list
            ForEach(filteredRecords) { record in
                PhotoListRow(
                    record: record,
                    metadata: metadataManager.getMetadata(for: record.id.uuidString),
                    isSelected: viewModel.selectedAssetIds.contains(record.id),
                    isSelectionMode: viewModel.isSelectionMode
                ) {
                    if viewModel.isSelectionMode {
                        viewModel.toggleSelection(for: record.id)
                    } else {
                        selectedPhotoId = record.id.uuidString
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
    let record: PhotoRecord
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
                    Text(record.createdDate, style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    // Rating
                    if let rating = metadata?.rating, rating > 0 {
                        HStack(spacing: AppTheme.Spacing.xxs) {
                            ForEach(0..<rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: AppTheme.IconSize.xs - 2))
                                    .foregroundStyle(AppTheme.Colors.warning)
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
            // Refresh if this record was edited
            if let editedAssetId = notification.userInfo?["assetId"] as? String,
               editedAssetId == record.id.uuidString {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
    }
}

// MARK: - PhotoGridItem

/// Individual photo cell in the grid with selection support
struct PhotoGridItem: View {
    let record: PhotoRecord
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
                                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(AppTheme.Spacing.xs)
                    }

                    // Rating stars (bottom left)
                    if let rating = metadataManager.getRating(for: record.id.uuidString), rating > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: AppTheme.Spacing.xxs) {
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
                        .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 1)
                )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
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
        image = PhotoStorageService.shared.loadThumbnail(id: record.id)
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
            HStack(spacing: AppTheme.Spacing.xxs) {
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
            .background(isSelected ? AppTheme.Colors.warning : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                    .stroke(isSelected ? AppTheme.Colors.warning : AppTheme.Colors.surfaceSecondary, lineWidth: 1)
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
