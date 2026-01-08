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
                // Procedure chips
                ForEach(Array(filter.procedures), id: \.self) { procedure in
                    FilterChip(
                        text: procedure,
                        color: AppTheme.procedureColor(for: procedure),
                        onRemove: {
                            filter.procedures.remove(procedure)
                            HapticsManager.shared.lightTap()
                        }
                    )
                }

                // Stage chips
                ForEach(Array(filter.stages), id: \.self) { stage in
                    FilterChip(
                        text: stage,
                        color: stage == "Preparation" ? AppTheme.Colors.warning : AppTheme.Colors.success,
                        onRemove: {
                            filter.stages.remove(stage)
                            HapticsManager.shared.lightTap()
                        }
                    )
                }

                // Angle chips
                ForEach(Array(filter.angles), id: \.self) { angle in
                    FilterChip(
                        text: angle,
                        color: .purple,
                        onRemove: {
                            filter.angles.remove(angle)
                            HapticsManager.shared.lightTap()
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
                            HapticsManager.shared.lightTap()
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
                            HapticsManager.shared.lightTap()
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
                            HapticsManager.shared.lightTap()
                        }
                    )
                }

                // Clear all button (if multiple filters)
                if filter.activeFilterCount > 1 {
                    Button(action: {
                        filter.reset()
                        HapticsManager.shared.lightTap()
                    }) {
                        Text("Clear All")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.error)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.surface)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
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
                .foregroundColor(AppTheme.Colors.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(color.opacity(0.15))
        .cornerRadius(AppTheme.CornerRadius.full)
    }
}

// MARK: - ProceduresListView

/// List view showing procedure folders with photo counts and stats
struct ProceduresListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var library = PhotoLibraryManager.shared
    @ObservedObject var metadataManager = MetadataManager.shared
    @EnvironmentObject var router: NavigationRouter

    var procedureStats: [(procedure: String, count: Int, prepCount: Int, restoCount: Int)] {
        var stats: [(String, Int, Int, Int)] = []
        let grouped = viewModel.assetsByProcedure(from: library.assets, metadata: metadataManager)

        for procedure in metadataManager.procedures {
            let assets = grouped[procedure] ?? []
            let prepCount = assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Preparation"
            }.count
            let restoCount = assets.filter { asset in
                metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Restoration"
            }.count

            if assets.count > 0 {
                stats.append((procedure, assets.count, prepCount, restoCount))
            }
        }

        // Add untagged if any
        let untaggedCount = grouped["Untagged"]?.count ?? 0
        if untaggedCount > 0 {
            stats.append(("Untagged", untaggedCount, 0, 0))
        }

        return stats
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Quick access cards
                quickAccessSection

                // Procedure folders
                procedureFoldersSection

                Spacer(minLength: 100)
            }
            .padding(.top, AppTheme.Spacing.md)
        }
    }

    // MARK: - Quick Access Section
    var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader("Quick Access")
                .padding(.horizontal, AppTheme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // All Photos
                    QuickAccessCard(
                        icon: "photo.on.rectangle",
                        title: "All Photos",
                        count: library.assets.count,
                        color: AppTheme.Colors.primary
                    ) {
                        viewModel.showAllPhotos()
                    }

                    // Starred
                    QuickAccessCard(
                        icon: "star.fill",
                        title: "Starred",
                        count: starredCount,
                        color: .yellow
                    ) {
                        router.libraryFilter.minimumRating = 4
                        viewModel.showAllPhotos()
                    }

                    // Recent (last 7 days)
                    QuickAccessCard(
                        icon: "clock.fill",
                        title: "Recent",
                        count: recentCount,
                        color: AppTheme.Colors.success
                    ) {
                        router.libraryFilter.dateRange = .lastWeek
                        viewModel.showAllPhotos()
                    }

                    // Untagged
                    if untaggedCount > 0 {
                        QuickAccessCard(
                            icon: "tag.slash",
                            title: "Untagged",
                            count: untaggedCount,
                            color: AppTheme.Colors.textSecondary
                        ) {
                            viewModel.showProcedure("Untagged")
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }

    // MARK: - Procedure Folders Section
    var procedureFoldersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Procedures",
                subtitle: "\(procedureStats.count) with photos"
            )
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
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(procedureStats, id: \.procedure) { stat in
                        ProcedureFolderRow(
                            procedure: stat.procedure,
                            totalCount: stat.count,
                            prepCount: stat.prepCount,
                            restoCount: stat.restoCount,
                            isSelectionMode: viewModel.isSelectionMode
                        ) {
                            if viewModel.isSelectionMode {
                                // Select all in this procedure
                                let assets = viewModel.assetsByProcedure(from: library.assets, metadata: metadataManager)[stat.procedure] ?? []
                                for asset in assets {
                                    viewModel.selectedAssetIds.insert(asset.localIdentifier)
                                }
                            } else {
                                viewModel.showProcedure(stat.procedure)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }

    // MARK: - Computed Properties

    var starredCount: Int {
        library.assets.filter { asset in
            (metadataManager.getRating(for: asset.localIdentifier) ?? 0) >= 4
        }.count
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

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("\(count)")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(width: 120)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEffect(isPressed: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Procedure Folder Row

/// Row displaying a procedure folder with stage breakdown
struct ProcedureFolderRow: View {
    let procedure: String
    let totalCount: Int
    let prepCount: Int
    let restoCount: Int
    let isSelectionMode: Bool
    let action: () -> Void

    @State private var isPressed = false

    var color: Color {
        procedure == "Untagged" ? AppTheme.Colors.textSecondary : AppTheme.procedureColor(for: procedure)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Color indicator
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                // Procedure name and count
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(procedure)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("\(totalCount) photo\(totalCount == 1 ? "" : "s")")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Stage breakdown (mini progress bar)
                if procedure != "Untagged" && totalCount > 0 {
                    StageBreakdownBar(
                        prepCount: prepCount,
                        restoCount: restoCount,
                        totalCount: totalCount
                    )
                    .frame(width: 60)
                }

                // Chevron or selection indicator
                if isSelectionMode {
                    Image(systemName: "plus.circle")
                        .foregroundColor(AppTheme.Colors.primary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEffect(isPressed: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
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
            .cornerRadius(2)
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

    @State private var viewStyle: ViewStyle = .grouped
    @State private var expandedTeeth: Set<Int> = []
    @State private var selectedPhotoId: String? = nil

    enum ViewStyle {
        case grouped  // Grouped by tooth
        case grid     // Flat grid
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

    var prepCount: Int {
        procedureAssets.filter { asset in
            metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Preparation"
        }.count
    }

    var restoCount: Int {
        procedureAssets.filter { asset in
            metadataManager.getMetadata(for: asset.localIdentifier)?.stage == "Restoration"
        }.count
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
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Stats header
                    statsHeader

                    // View style toggle
                    viewStyleToggle

                    // Content
                    if viewStyle == .grouped {
                        groupedContent
                    } else {
                        gridContent
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .sheet(item: $selectedPhotoId) { photoId in
                PhotoDetailSheet(
                    photoId: photoId,
                    allAssets: procedureAssets,
                    onDismiss: { selectedPhotoId = nil }
                )
            }
        }
    }

    // MARK: - Stats Header
    var statsHeader: some View {
        DPCard {
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

                Divider()
                    .frame(height: 40)

                StatItem(
                    value: "\(prepCount)",
                    label: "Prep",
                    color: AppTheme.Colors.warning
                )

                Divider()
                    .frame(height: 40)

                StatItem(
                    value: "\(restoCount)",
                    label: "Resto",
                    color: AppTheme.Colors.success
                )
            }
            .frame(maxWidth: .infinity)
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
    var gridContent: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.Spacing.xs
        ) {
            ForEach(procedureAssets, id: \.localIdentifier) { asset in
                LibraryPhotoThumbnail(
                    asset: asset,
                    isSelected: viewModel.selectedAssetIds.contains(asset.localIdentifier),
                    isSelectionMode: viewModel.isSelectionMode
                ) {
                    if viewModel.isSelectionMode {
                        viewModel.toggleSelection(for: asset.localIdentifier)
                    } else {
                        selectedPhotoId = asset.localIdentifier
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
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
                .foregroundColor(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
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

    var prepAssets: [PHAsset] {
        assets.filter { metadataManager.getMetadata(for: $0.localIdentifier)?.stage == "Preparation" }
    }

    var restoAssets: [PHAsset] {
        assets.filter { metadataManager.getMetadata(for: $0.localIdentifier)?.stage == "Restoration" }
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
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }

                    // Tooth label and count
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(toothLabel)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            if !prepAssets.isEmpty {
                                Text("\(prepAssets.count) Prep")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.warning)
                            }
                            if !restoAssets.isEmpty {
                                Text("\(restoAssets.count) Resto")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.success)
                            }
                        }
                    }

                    Spacer()

                    // Thumbnail preview (when collapsed)
                    if !isExpanded {
                        HStack(spacing: -8) {
                            ForEach(assets.prefix(3), id: \.localIdentifier) { asset in
                                AsyncThumbnailView(asset: asset, size: CGSize(width: 32, height: 32))
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
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(spacing: AppTheme.Spacing.md) {
                    // Preparation photos
                    if !prepAssets.isEmpty {
                        StagePhotoGrid(
                            stage: "Preparation",
                            assets: prepAssets,
                            isSelectionMode: isSelectionMode,
                            selectedIds: selectedIds,
                            onSelectAsset: onSelectAsset,
                            metadataManager: metadataManager
                        )
                    }

                    // Restoration photos
                    if !restoAssets.isEmpty {
                        StagePhotoGrid(
                            stage: "Restoration",
                            assets: restoAssets,
                            isSelectionMode: isSelectionMode,
                            selectedIds: selectedIds,
                            onSelectAsset: onSelectAsset,
                            metadataManager: metadataManager
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
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
                    .fill(stage == "Preparation" ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    .frame(width: 8, height: 8)

                Text(stage)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
    @ObservedObject var metadataManager = MetadataManager.shared

    var rating: Int {
        metadataManager.getRating(for: asset.localIdentifier) ?? 0
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
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
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

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
                                .stroke(AppTheme.Colors.textTertiary, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(4)
                }

                // Rating stars (bottom left)
                if !isSelectionMode && rating > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("\(rating)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        PhotoLibraryManager.shared.requestThumbnail(for: asset, size: CGSize(width: 150, height: 150)) { loadedImage in
            self.image = loadedImage
        }
    }
}

// MARK: - Async Thumbnail View

/// Async thumbnail loader for smaller preview images
struct AsyncThumbnailView: View {
    let asset: PHAsset
    let size: CGSize

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
            PhotoLibraryManager.shared.requestThumbnail(for: asset, size: size) { loadedImage in
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Photo Detail Sheet

/// Sheet wrapper for photo detail view
struct PhotoDetailSheet: View {
    let photoId: String
    let allAssets: [PHAsset]
    let onDismiss: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            if let asset = allAssets.first(where: { $0.localIdentifier == photoId }) {
                PhotoDetailContent(asset: asset, allAssets: allAssets)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                onDismiss()
                                dismiss()
                            }
                        }
                    }
            } else {
                Text("Photo not found")
            }
        }
    }
}

// MARK: - Photo Detail Content

/// Placeholder for photo detail view content
struct PhotoDetailContent: View {
    let asset: PHAsset
    let allAssets: [PHAsset]

    @State private var image: UIImage?
    @ObservedObject var metadataManager = MetadataManager.shared

    var metadata: PhotoMetadata? {
        metadataManager.getMetadata(for: asset.localIdentifier)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Full image
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                } else {
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceSecondary)
                        .aspectRatio(4/3, contentMode: .fit)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .overlay(ProgressView())
                }

                // Metadata info
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    if let meta = metadata {
                        if let procedure = meta.procedure {
                            MetadataRow(label: "Procedure", value: procedure)
                        }
                        if let toothNumber = meta.toothNumber {
                            MetadataRow(label: "Tooth", value: "#\(toothNumber)")
                        }
                        if let stage = meta.stage {
                            MetadataRow(label: "Stage", value: stage)
                        }
                        if let angle = meta.angle {
                            MetadataRow(label: "Angle", value: angle)
                        }
                        if let rating = meta.rating, rating > 0 {
                            HStack {
                                Text("Rating")
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(AppTheme.Colors.warning)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                        }
                    }

                    if let date = asset.creationDate {
                        MetadataRow(label: "Date", value: dateFormatter.string(from: date))
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            loadImage()
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }

    private func loadImage() {
        PhotoLibraryManager.shared.requestImage(for: asset, size: CGSize(width: 800, height: 800)) { loadedImage in
            self.image = loadedImage
        }
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
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - String Identifiable Extension

extension String: Identifiable {
    public var id: String { self }
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
                ActionBarButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    isDisabled: selectedCount == 0,
                    action: onShare
                )

                // Add to portfolio button
                ActionBarButton(
                    icon: "folder.badge.plus",
                    label: "Add to Portfolio",
                    isDisabled: selectedCount == 0,
                    action: onAddToPortfolio
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
                    .font(.system(size: 22))

                Text(label)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundColor(foregroundColor)
        }
        .disabled(isDisabled)
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
