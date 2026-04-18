// PortfolioDetailView.swift
// SimFolio - Portfolio Detail View with Tabs
//
// This view displays the full details of a single portfolio with two tabs:
// - Overview: Progress stats, quick actions, and expandable requirement checklist
// - Photos: Grid of portfolio photos
//
// Features:
// - Tab-based navigation with swipe support
// - Large progress ring with statistics
// - Quick action buttons for common tasks
// - Expandable requirement cards inline in Overview with Expand/Collapse All toggle
// - Menu with edit, export, capture, and delete options
// - Smart capture navigation with pre-filled metadata

import SwiftUI

// MARK: - PortfolioTab

/// Enum representing the tabs in the portfolio detail view
enum PortfolioTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case photos = "Photos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.pie"
        case .photos: return "photo.on.rectangle"
        }
    }
}

// MARK: - PortfolioDetailView

/// Main view showing full portfolio details with tabbed interface
struct PortfolioDetailView: View {
    let portfolio: Portfolio

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - State

    @State private var selectedTab: PortfolioTab = .overview
    @State private var showEditSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showPremiumPaywall: Bool = false

    // MARK: - Computed Properties

    /// Portfolio statistics (fulfilled and total photo counts)
    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    /// Progress as a decimal (0.0 to 1.0)
    var progress: Double {
        guard stats.total > 0 else { return 0 }
        // Use SafeProgressValue to ensure valid range
        return SafeProgressValue(current: stats.fulfilled, total: stats.total).value
    }

    /// Whether the portfolio is complete
    var isComplete: Bool {
        stats.total > 0 && stats.fulfilled >= stats.total
    }

    /// Due status with text, color, and icon
    var dueStatus: (text: String, color: Color, icon: String) {
        guard let dueDate = portfolio.dueDate else {
            return ("No deadline", AppTheme.Colors.textTertiary, "calendar")
        }

        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if days < 0 {
            let absDays = abs(days)
            return ("Overdue by \(absDays) day\(absDays == 1 ? "" : "s")", AppTheme.Colors.error, "exclamationmark.circle.fill")
        } else if days == 0 {
            return ("Due today", AppTheme.Colors.error, "exclamationmark.circle.fill")
        } else if days == 1 {
            return ("Due tomorrow", AppTheme.Colors.warning, "clock.fill")
        } else if days <= 7 {
            return ("Due in \(days) days", AppTheme.Colors.warning, "clock")
        } else {
            return ("Due in \(days) days", AppTheme.Colors.textSecondary, "calendar")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker

                // Tab content
                TabView(selection: $selectedTab) {
                    PortfolioOverviewTab(
                        portfolio: portfolio,
                        stats: stats,
                        progress: progress,
                        dueStatus: dueStatus,
                        onCapturePressed: navigateToCapture,
                        onRequirementCapturePressed: navigateToCapture(procedure:stage:angle:),
                        onExportPressed: {
                            requirePremium(.portfolioExport, showPaywall: $showPremiumPaywall) {
                                showExportSheet = true
                            }
                        },
                        onEditRequirementsPressed: { showEditSheet = true },
                        onDeletePressed: { showDeleteConfirmation = true }
                    )
                    .tag(PortfolioTab.overview)

                    PortfolioPhotosTab(portfolio: portfolio)
                        .tag(PortfolioTab.photos)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(portfolio.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showEditSheet = true }) {
                            Label("Edit Portfolio", systemImage: "pencil")
                        }

                        Button(action: {
                            requirePremium(.portfolioExport, showPaywall: $showPremiumPaywall) {
                                showExportSheet = true
                            }
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Button(action: navigateToCapture) {
                            Label("Capture Photos", systemImage: "camera")
                        }

                        Divider()

                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Label("Delete Portfolio", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditPortfolioSheet(portfolio: portfolio, isPresented: $showEditSheet)
            }
            .sheet(isPresented: $showExportSheet) {
                PortfolioExportSheet(portfolio: portfolio, isPresented: $showExportSheet)
            }
            .alert("Delete Portfolio?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePortfolio()
                }
            } message: {
                Text("This will delete the portfolio and all its requirements. Your photos will not be deleted.")
            }
            .premiumGate(for: .portfolioExport, showPaywall: $showPremiumPaywall)
            .onChange(of: stats.fulfilled) { newFulfilled in
                if newFulfilled >= stats.total && stats.total > 0 {
                    ReviewPromptService.requestIfEligible(for: .firstPortfolioCompleted)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subviews

    /// Tab picker with underline indicator
    var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(AppTheme.Typography.subheadline)
                        }
                        .foregroundStyle(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)

                        // Selection indicator
                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.Colors.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Actions

    /// Navigate to capture flow with pre-filled values for first incomplete requirement
    func navigateToCapture() {
        dismiss()

        // Find the first incomplete requirement to pre-fill
        if let firstIncomplete = findFirstIncompleteRequirement() {
            router.navigateToCapture(
                procedure: firstIncomplete.procedure,
                stage: firstIncomplete.stage,
                angle: firstIncomplete.angle,
                toothNumber: nil,
                forPortfolioId: portfolio.id
            )
        } else {
            router.navigateToCapture(forPortfolioId: portfolio.id)
        }
    }

    /// Navigate to capture flow pre-filled with the given procedure/stage/angle
    func navigateToCapture(procedure: String, stage: String, angle: String) {
        dismiss()
        router.navigateToCapture(
            procedure: procedure,
            stage: stage,
            angle: angle,
            toothNumber: nil,
            forPortfolioId: portfolio.id
        )
    }

    /// Find the first incomplete requirement in the portfolio
    func findFirstIncompleteRequirement() -> (procedure: String, stage: String?, angle: String?)? {
        for requirement in portfolio.requirements {
            for stage in requirement.stages {
                for angle in requirement.angles {
                    let count = metadataManager.getMatchingPhotoCount(
                        procedure: requirement.procedure,
                        stage: stage,
                        angle: angle
                    )
                    let needed = requirement.angleCounts[angle] ?? 1
                    if count < needed {
                        return (requirement.procedure, stage, angle)
                    }
                }
            }
        }
        return nil
    }

    /// Delete the portfolio and dismiss the view
    func deletePortfolio() {
        metadataManager.deletePortfolio(portfolio.id)
        dismiss()
    }
}

// MARK: - PortfolioOverviewTab

/// Overview tab showing progress, quick actions, and expandable requirement checklist
struct PortfolioOverviewTab: View {
    let portfolio: Portfolio
    let stats: (fulfilled: Int, total: Int)
    let progress: Double
    let dueStatus: (text: String, color: Color, icon: String)
    let onCapturePressed: () -> Void
    let onRequirementCapturePressed: (String, String, String) -> Void
    let onExportPressed: () -> Void
    let onEditRequirementsPressed: () -> Void
    let onDeletePressed: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var expandedRequirements: Set<String> = []

    var isComplete: Bool {
        stats.total > 0 && stats.fulfilled >= stats.total
    }

    var allExpanded: Bool {
        expandedRequirements.count == portfolio.requirements.count && !portfolio.requirements.isEmpty
    }

    func toggleExpansion(for requirementId: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedRequirements.contains(requirementId) {
                expandedRequirements.remove(requirementId)
            } else {
                expandedRequirements.insert(requirementId)
            }
        }
    }

    func toggleAllExpansion() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedRequirements.count == portfolio.requirements.count {
                expandedRequirements.removeAll()
            } else {
                expandedRequirements = Set(portfolio.requirements.map { $0.id })
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Large progress card
                progressCard

                // Quick actions
                quickActionsSection

                // Requirements summary
                requirementsSummarySection

                Spacer(minLength: 50)
            }
            .padding(.top, AppTheme.Spacing.md)
        }
    }

    // MARK: - Progress Card

    /// Large card showing progress ring and statistics
    var progressCard: some View {
        DPCard(padding: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Progress bar with percentage
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text("\(Int(progress * 100))% Complete")
                            .font(AppTheme.Typography.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textPrimary)
                        Spacer()
                    }
                    DPProgressBar(progress: progress)
                }

                // Stats row
                HStack(spacing: 0) {
                    statItem(
                        value: "\(stats.fulfilled)",
                        label: "Complete",
                        color: AppTheme.Colors.success
                    )
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    statItem(
                        value: "\(stats.total - stats.fulfilled)",
                        label: "Remaining",
                        color: stats.total - stats.fulfilled > 0 ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary
                    )
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    statItem(
                        value: "\(stats.total)",
                        label: "Total",
                        color: AppTheme.Colors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                }

                // Due date status
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: dueStatus.icon)
                        .font(.system(size: 16))
                    Text(dueStatus.text)
                        .font(AppTheme.Typography.subheadline)
                }
                .foregroundStyle(dueStatus.color)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(dueStatus.color.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.small)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    /// Individual stat item with value and label
    func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Quick Actions

    /// Section with quick action buttons
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Quick Actions")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.sm) {
                // Capture Missing
                QuickActionButton(
                    icon: "camera.fill",
                    iconColor: AppTheme.Colors.primary,
                    title: "Capture Missing Photos",
                    subtitle: isComplete ? "All photos captured" : "\(stats.total - stats.fulfilled) photos needed",
                    isDisabled: isComplete,
                    action: onCapturePressed
                )

                // Export
                QuickActionButton(
                    icon: "square.and.arrow.up",
                    iconColor: AppTheme.Colors.success,
                    title: "Export Portfolio",
                    subtitle: "ZIP or individual files",
                    isDisabled: stats.fulfilled == 0,
                    action: onExportPressed
                )
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Requirements Summary

    /// Section showing all requirements as expandable checklist cards
    var requirementsSummarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Requirements")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                if !portfolio.requirements.isEmpty {
                    Button(action: toggleAllExpansion) {
                        Text(allExpanded ? "Collapse All" : "Expand All")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if portfolio.requirements.isEmpty {
                DPCard {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        Text("No requirements added yet")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(portfolio.requirements) { requirement in
                        RequirementChecklistCard(
                            requirement: requirement,
                            isExpanded: expandedRequirements.contains(requirement.id),
                            onToggleExpand: {
                                toggleExpansion(for: requirement.id)
                            },
                            onCapturePressed: { stage, angle in
                                onRequirementCapturePressed(requirement.procedure, stage, angle)
                            }
                        )
                    }

                    DPButton(
                        "Edit Requirements",
                        icon: "pencil",
                        style: .secondary,
                        isFullWidth: true,
                        action: onEditRequirementsPressed
                    )
                    .padding(.top, AppTheme.Spacing.sm)

                    DPButton(
                        "Delete Portfolio",
                        icon: "trash",
                        style: .destructive,
                        isFullWidth: true,
                        action: onDeletePressed
                    )
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - QuickActionButton

/// Styled button for quick actions with icon, title, and subtitle
struct QuickActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isDisabled ? 0.1 : 0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isDisabled ? AppTheme.Colors.textTertiary : iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(CardPressButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Notes

// NOTE: RequirementChecklistCard and related components live in PortfolioChecklistTab.swift
// NOTE: PortfolioPhotosTab is now implemented in PortfolioPhotosTab.swift
// NOTE: PortfolioExportSheet is now implemented in PortfolioExportSheet.swift
// NOTE: EditPortfolioSheet is now implemented in CreatePortfolioSheet.swift

// MARK: - Preview Provider

#if DEBUG
struct PortfolioDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioDetailViewPreviewContainer()
    }
}

struct PortfolioDetailViewPreviewContainer: View {
    @StateObject private var router = NavigationRouter()

    var body: some View {
        PortfolioDetailView(
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
                    ),
                    PortfolioRequirement(
                        procedure: "Crown",
                        stages: ["Preparation"],
                        angles: ["Buccal/Facial", "Lingual", "Occlusal"]
                    )
                ]
            )
        )
        .environmentObject(router)
    }
}

struct QuickActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            QuickActionButton(
                icon: "camera.fill",
                iconColor: AppTheme.Colors.primary,
                title: "Capture Missing Photos",
                subtitle: "5 photos needed",
                action: { }
            )

            QuickActionButton(
                icon: "square.and.arrow.up",
                iconColor: AppTheme.Colors.success,
                title: "Export Portfolio",
                subtitle: "ZIP, PDF, or individual files",
                isDisabled: true,
                action: { }
            )
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
