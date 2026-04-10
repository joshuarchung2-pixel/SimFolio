// HomeView.swift
// SimFolio - Home Dashboard
//
// Clarity design: clean scrollable layout with header, stats row,
// recent captures, and portfolio list. No slideshow or gradients.

import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var photoStorage = PhotoStorageService.shared
    @State private var showingCreatePortfolio = false

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 0..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }

        if let fullName = UserDefaults.standard.string(forKey: "userName"),
           let firstName = fullName.split(separator: " ").first,
           !firstName.isEmpty {
            return "\(timeGreeting), \(firstName)"
        }
        return timeGreeting
    }

    // MARK: - Computed Stats

    private var totalPhotoCount: Int {
        photoStorage.records.count
    }

    private var completionPercentage: Int {
        let portfolios = metadataManager.portfolios
        guard !portfolios.isEmpty else { return 0 }

        var totalFulfilled = 0
        var totalRequired = 0
        for portfolio in portfolios {
            let stats = metadataManager.getPortfolioStats(portfolio)
            totalFulfilled += stats.fulfilled
            totalRequired += stats.total
        }
        guard totalRequired > 0 else { return 0 }
        return Int((Double(totalFulfilled) / Double(totalRequired)) * 100)
    }

    private var hasPhotos: Bool {
        !photoStorage.records.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // 1. Header
                headerSection

                // 2. Stats Row
                statsRowSection

                // 3. Recent Captures or Empty State
                if hasPhotos {
                    recentCapturesSection
                } else {
                    emptyStateSection
                }

                // 4. Portfolios Section
                portfoliosSection
            }
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreatePortfolio) {
            CreatePortfolioSheet(isPresented: $showingCreatePortfolio)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Text("SIMFOLIO")
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .tracking(0.8)

            Text(greeting)
                .font(AppTheme.Typography.title)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Stats Row

    private var statsRowSection: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Photo count card
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("\(totalPhotoCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Photos")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )

            // Completion % card
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("\(completionPercentage)%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Complete")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.accentLight)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .strokeBorder(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Recent Captures

    private var recentCapturesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Section header
            HStack {
                Text("RECENT")
                    .font(AppTheme.Typography.sectionLabel)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .tracking(0.8)
                Spacer()
                Button("See all") {
                    router.navigateToLibrary()
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
                    count: 3
                ),
                spacing: AppTheme.Spacing.sm
            ) {
                ForEach(Array(photoStorage.records.prefix(3))) { record in
                    RecentThumbnailView(record: record)
                        .onTapGesture {
                            router.navigateToPhotoDetail(id: record.id.uuidString)
                        }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "camera")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 64, height: 64)
                .background(AppTheme.Colors.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

            Text("Start your portfolio")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Capture your first dental procedure\nto begin tracking progress")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            DPButton("Take Photo", icon: "camera") {
                router.navigateToCapture()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Portfolios Section

    private var portfoliosSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("PORTFOLIOS")
                .font(AppTheme.Typography.sectionLabel)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .tracking(0.8)
                .padding(.horizontal, AppTheme.Spacing.md)

            ForEach(metadataManager.portfolios) { portfolio in
                PortfolioRowCard(portfolio: portfolio)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .onTapGesture {
                        router.navigateToPortfolio(id: portfolio.id)
                    }
            }

            Button {
                showingCreatePortfolio = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Portfolio")
                }
                .font(AppTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .strokeBorder(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1, antialiased: true)
                )
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Recent Thumbnail View

/// Square thumbnail for recent captures grid — fills its cell width
struct RecentThumbnailView: View {
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
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        ProgressView()
                            .tint(AppTheme.Colors.textTertiary)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .onAppear {
            image = PhotoStorageService.shared.loadThumbnail(id: record.id)
        }
    }
}

// MARK: - Procedure Thumb View

/// Square dimension for the portfolio card's procedure thumbnails and overflow pill.
private let portfolioCardThumbSize: CGFloat = 44

/// 44pt square thumbnail used inside PortfolioThumbStrip.
/// Loads the thumbnail on appear and renders a procedure-colored border.
/// On load failure, falls back to a solid procedure-color square.
private struct ProcedureThumbView: View {
    let assetId: String
    let procedure: String
    @State private var image: UIImage?
    @State private var didAttemptLoad: Bool = false

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if didAttemptLoad {
                // Load failed — fall back to solid procedure color
                AppTheme.procedureBackgroundColor(for: procedure)
            } else {
                AppTheme.Colors.surface
            }
        }
        .frame(width: portfolioCardThumbSize, height: portfolioCardThumbSize)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .strokeBorder(AppTheme.procedureBorderColor(for: procedure), lineWidth: 2)
        )
        .onAppear {
            guard !didAttemptLoad else { return }
            didAttemptLoad = true
            if let uuid = UUID(uuidString: assetId) {
                image = PhotoStorageService.shared.loadThumbnail(id: uuid)
            }
        }
    }
}

// MARK: - Portfolio Thumb Strip

/// Horizontal strip of up to 4 ProcedureThumbView + optional "+N" overflow pill.
/// Caller is responsible for slicing `visibleRepresentatives` to at most 4 entries.
private struct PortfolioThumbStrip: View {
    let visibleRepresentatives: [MetadataManager.ProcedureRepresentative]  // already capped at 4
    let overflowCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(visibleRepresentatives, id: \.assetId) { rep in
                ProcedureThumbView(assetId: rep.assetId, procedure: rep.procedure)
            }
            if overflowCount > 0 {
                overflowPill
            }
        }
    }

    private var overflowPill: some View {
        Text("+\(overflowCount)")
            .font(AppTheme.Typography.caption.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: portfolioCardThumbSize)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
            )
            .accessibilityLabel("\(overflowCount) more procedure\(overflowCount == 1 ? "" : "s")")
    }
}

// MARK: - Portfolio Row Card

/// Card row for a single portfolio with name, merged caption, thumbnail strip, and progress bar.
struct PortfolioRowCard: View {
    let portfolio: Portfolio
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var photoStorage = PhotoStorageService.shared

    // MARK: - Derived

    private var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    private var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    private var completionPercentage: Int {
        Int(progress * 100)
    }

    private var distinctProcedureCount: Int {
        Set(portfolio.requirements.map(\.procedure)).count
    }

    /// Visible thumbnail representatives (capped at 4) and the overflow count.
    /// Computed once per render via a local `let` in `body` so the underlying
    /// `getProcedureRepresentatives` walk doesn't run more than once per frame.
    private var representativeStrip: (visible: [MetadataManager.ProcedureRepresentative], overflow: Int) {
        let all = metadataManager.getProcedureRepresentatives(
            for: portfolio,
            photoRecords: photoStorage.records
        )
        return (visible: Array(all.prefix(4)), overflow: max(0, all.count - 4))
    }

    private var captionSegments: [String] {
        portfolioCardCaptionSegments(
            dueDate: portfolio.dueDate,
            photoCount: stats.fulfilled,
            totalPhotos: stats.total,
            distinctProcedureCount: distinctProcedureCount
        )
    }

    // MARK: - Body

    var body: some View {
        let strip = representativeStrip
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Title row
            HStack {
                Text(portfolio.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(completionPercentage)%")
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Caption row (hidden if no segments)
            if !captionSegments.isEmpty {
                captionRow
            }

            // Thumbnail strip (hidden if no representatives)
            if !strip.visible.isEmpty {
                PortfolioThumbStrip(
                    visibleRepresentatives: strip.visible,
                    overflowCount: strip.overflow
                )
            }

            // Progress bar
            DPProgressBar(progress: progress)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
        )
    }

    private var captionRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(captionSegments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text("·")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                Text(segment)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Portfolio Card Caption

private let portfolioCardDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

/// Pure formatter for the portfolio card's caption row.
/// Returns segment strings to join with " · ". Returns empty array if the row
/// would be empty (caller should hide the row entirely).
func portfolioCardCaptionSegments(
    dueDate: Date?,
    photoCount: Int,
    totalPhotos: Int,
    distinctProcedureCount: Int
) -> [String] {
    var segments: [String] = []

    if let dueDate = dueDate {
        segments.append("Due \(portfolioCardDateFormatter.string(from: dueDate))")
    }

    if totalPhotos > 0 {
        segments.append("\(photoCount)/\(totalPhotos) photos")
    }

    if distinctProcedureCount > 0 {
        let noun = distinctProcedureCount == 1 ? "procedure" : "procedures"
        segments.append("\(distinctProcedureCount) \(noun)")
    }

    // Hide row if only the due date is left — due date already gives context,
    // but without any photo/procedure info the row would just repeat what's implicit.
    // Spec: hide when totalPhotos == 0 AND distinctProcedureCount == 0.
    if totalPhotos == 0 && distinctProcedureCount == 0 {
        return []
    }

    return segments
}

// MARK: - Preview Provider

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
                .environmentObject(NavigationRouter())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
#endif
