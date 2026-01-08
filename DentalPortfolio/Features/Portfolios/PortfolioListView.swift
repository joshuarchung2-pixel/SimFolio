// PortfolioListView.swift
// Dental Portfolio - Portfolio List and Management
//
// This view displays all portfolios organized into Active and Completed sections.
// Active portfolios are sorted by due date (soonest first).
// Completed portfolios are sorted by creation date (most recent first).
//
// Features:
// - Two sections: Active (incomplete) and Completed
// - Progress rings showing completion percentage
// - Due date color coding (red = overdue, yellow = soon, gray = future)
// - Empty state for new users
// - Card tap opens portfolio detail view
// - Plus button creates new portfolio

import SwiftUI

// MARK: - PortfolioListView

/// Main view for displaying and managing portfolios
struct PortfolioListView: View {

    // MARK: - Properties

    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var showCreateSheet: Bool = false
    @State private var selectedPortfolioId: String? = nil

    // MARK: - Computed Properties

    /// Active portfolios (incomplete or no requirements)
    /// Sorted by due date ascending (soonest first), portfolios without due dates go to end
    var activePortfolios: [Portfolio] {
        metadataManager.portfolios
            .filter { portfolio in
                let stats = metadataManager.getPortfolioStats(portfolio)
                // Include if incomplete OR has no requirements yet
                return stats.fulfilled < stats.total || stats.total == 0
            }
            .sorted { lhs, rhs in
                // Sort by due date ascending, nil dates go to end
                switch (lhs.dueDate, rhs.dueDate) {
                case (nil, nil):
                    return lhs.createdDate > rhs.createdDate
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case (let lhsDate?, let rhsDate?):
                    return lhsDate < rhsDate
                }
            }
    }

    /// Completed portfolios (100% complete with requirements)
    /// Sorted by creation date descending (most recent first)
    var completedPortfolios: [Portfolio] {
        metadataManager.portfolios
            .filter { portfolio in
                let stats = metadataManager.getPortfolioStats(portfolio)
                // Include if fulfilled equals or exceeds total AND has requirements
                return stats.fulfilled >= stats.total && stats.total > 0
            }
            .sorted { lhs, rhs in
                lhs.createdDate > rhs.createdDate
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Active portfolios section
                    if !activePortfolios.isEmpty {
                        activePortfoliosSection
                    }

                    // Completed portfolios section
                    if !completedPortfolios.isEmpty {
                        completedPortfoliosSection
                    }

                    // Empty state (if no portfolios at all)
                    if metadataManager.portfolios.isEmpty {
                        emptyState
                    }

                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Portfolios")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePortfolioSheet(isPresented: $showCreateSheet)
            }
            .sheet(item: $selectedPortfolioId) { portfolioId in
                if let portfolio = metadataManager.portfolios.first(where: { $0.id == portfolioId }) {
                    PortfolioDetailView(portfolio: portfolio)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subviews

    /// Active portfolios section with header and cards
    var activePortfoliosSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Active",
                subtitle: "\(activePortfolios.count) portfolio\(activePortfolios.count == 1 ? "" : "s")"
            )
            .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(activePortfolios) { portfolio in
                    PortfolioListCard(portfolio: portfolio) {
                        selectedPortfolioId = portfolio.id
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    /// Completed portfolios section with header and cards
    var completedPortfoliosSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Completed",
                subtitle: "\(completedPortfolios.count) portfolio\(completedPortfolios.count == 1 ? "" : "s")"
            )
            .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(completedPortfolios) { portfolio in
                    PortfolioListCard(portfolio: portfolio, isCompleted: true) {
                        selectedPortfolioId = portfolio.id
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    /// Empty state view shown when no portfolios exist
    var emptyState: some View {
        VStack {
            Spacer()

            DPEmptyState(
                icon: "folder.badge.plus",
                title: "No Portfolios",
                message: "Create portfolios to track required photos for assignments and exams.",
                actionTitle: "Create Portfolio"
            ) {
                showCreateSheet = true
            }

            Spacer()
        }
        .padding(.top, 100)
    }
}

// MARK: - PortfolioListCard

/// Card component displaying a portfolio summary with progress
struct PortfolioListCard: View {
    let portfolio: Portfolio
    var isCompleted: Bool = false
    let onTap: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var isPressed: Bool = false

    // MARK: - Computed Properties

    /// Portfolio statistics (fulfilled and total photo counts)
    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    /// Progress as a decimal (0.0 to 1.0)
    var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    /// Due status text and color based on days until due
    var dueStatus: (text: String, color: Color) {
        guard let dueDate = portfolio.dueDate else {
            return ("No deadline", AppTheme.Colors.textTertiary)
        }

        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if days < 0 {
            let absDays = abs(days)
            return ("Overdue by \(absDays) day\(absDays == 1 ? "" : "s")", AppTheme.Colors.error)
        } else if days == 0 {
            return ("Due today", AppTheme.Colors.error)
        } else if days == 1 {
            return ("Due tomorrow", AppTheme.Colors.warning)
        } else if days <= 7 {
            return ("Due in \(days) days", AppTheme.Colors.warning)
        } else {
            return ("Due in \(days) days", AppTheme.Colors.textSecondary)
        }
    }

    /// Number of photos still needed
    var missingCount: Int {
        stats.total - stats.fulfilled
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.md) {
                // Header row: Name, date, and progress ring
                headerRow

                // Progress bar
                DPProgressBar(
                    progress: progress,
                    height: 6,
                    foregroundColor: isCompleted ? AppTheme.Colors.success : nil
                )

                // Stats row: Photo count and due date
                statsRow

                // Missing requirements indicator (only for active incomplete portfolios)
                if !isCompleted && missingCount > 0 {
                    missingIndicator
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Subviews

    /// Header row with title, date, and progress ring
    var headerRow: some View {
        HStack(alignment: .top) {
            // Title and date
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(portfolio.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("Created \(portfolio.dateString)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }

            Spacer()

            // Progress ring
            DPProgressRing(
                progress: progress,
                size: 50,
                lineWidth: 5,
                foregroundColor: isCompleted ? AppTheme.Colors.success : nil,
                showLabel: true,
                labelStyle: .percentage
            )
        }
    }

    /// Stats row with photo count and due date
    var statsRow: some View {
        HStack {
            // Photos count
            Label {
                Text("\(stats.fulfilled)/\(stats.total) photos")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } icon: {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            // Due date or completed status
            if isCompleted {
                Label {
                    Text("Completed")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.success)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.success)
                }
            } else {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(dueStatus.text)
                        .font(AppTheme.Typography.caption)
                }
                .foregroundColor(dueStatus.color)
            }
        }
    }

    /// Missing photos indicator shown for incomplete portfolios
    var missingIndicator: some View {
        HStack {
            Text("\(missingCount) photo\(missingCount == 1 ? "" : "s") needed")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.warning)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
    }
}

// MARK: - String+Identifiable

/// Make String conform to Identifiable for use with .sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Placeholder Views

/// Placeholder for CreatePortfolioSheet - will be implemented in Prompt 5.6
struct CreatePortfolioSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Create Portfolio Sheet")
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Coming in a future prompt")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// NOTE: PortfolioDetailView is now implemented in PortfolioDetailView.swift

// MARK: - Preview Provider

#if DEBUG
struct PortfolioListView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with sample data
        PortfolioListViewPreviewContainer()
    }
}

struct PortfolioListViewPreviewContainer: View {
    @StateObject private var router = NavigationRouter()

    var body: some View {
        PortfolioListView()
            .environmentObject(router)
    }
}

// Preview for individual card
struct PortfolioListCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Active portfolio card
            PortfolioListCard(
                portfolio: Portfolio(
                    name: "Restorative Dentistry Final",
                    createdDate: Date().addingTimeInterval(-86400 * 7),
                    dueDate: Date().addingTimeInterval(86400 * 3),
                    requirements: [
                        PortfolioRequirement(
                            procedure: "Class 1",
                            stages: ["Preparation", "Restoration"],
                            angles: ["Occlusal", "Buccal/Facial"]
                        )
                    ]
                )
            ) { }

            // Completed portfolio card
            PortfolioListCard(
                portfolio: Portfolio(
                    name: "Crown Prep Exam",
                    createdDate: Date().addingTimeInterval(-86400 * 30)
                ),
                isCompleted: true
            ) { }

            // Overdue portfolio card
            PortfolioListCard(
                portfolio: Portfolio(
                    name: "Overdue Assignment",
                    createdDate: Date().addingTimeInterval(-86400 * 14),
                    dueDate: Date().addingTimeInterval(-86400 * 2),
                    requirements: [
                        PortfolioRequirement(
                            procedure: "Class 2",
                            stages: ["Preparation"],
                            angles: ["Occlusal"]
                        )
                    ]
                )
            ) { }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
