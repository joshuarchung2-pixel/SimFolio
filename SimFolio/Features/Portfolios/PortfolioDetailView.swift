// PortfolioDetailView.swift
// SimFolio - Portfolio Detail View with Tabs
//
// This view displays the full details of a single portfolio with three tabs:
// - Overview: Progress stats, quick actions, and requirements summary
// - Checklist: Detailed checklist of all requirements (Prompt 5.3)
// - Photos: Grid of portfolio photos (Prompt 5.4)
//
// Features:
// - Tab-based navigation with swipe support
// - Large progress ring with statistics
// - Quick action buttons for common tasks
// - Menu with edit, export, capture, and delete options
// - Smart capture navigation with pre-filled metadata

import SwiftUI

// MARK: - PortfolioTab

/// Enum representing the three tabs in the portfolio detail view
enum PortfolioTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case checklist = "Checklist"
    case photos = "Photos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.pie"
        case .checklist: return "checklist"
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

    /// Always read the latest portfolio from the manager so inline mutations
    /// (add/edit/delete requirements) are reflected immediately throughout the view.
    var currentPortfolio: Portfolio {
        metadataManager.portfolios.first(where: { $0.id == portfolio.id }) ?? portfolio
    }

    /// Portfolio statistics (fulfilled and total photo counts)
    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(currentPortfolio)
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
        guard let dueDate = currentPortfolio.dueDate else {
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
                        portfolio: currentPortfolio,
                        stats: stats,
                        progress: progress,
                        dueStatus: dueStatus,
                        onCapturePressed: navigateToCapture,
                        onExportPressed: {
                            requirePremium(.portfolioExport, showPaywall: $showPremiumPaywall) {
                                showExportSheet = true
                            }
                        }
                    )
                    .tag(PortfolioTab.overview)

                    PortfolioChecklistTab(portfolio: currentPortfolio)
                        .tag(PortfolioTab.checklist)

                    PortfolioPhotosTab(portfolio: currentPortfolio)
                        .tag(PortfolioTab.photos)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(currentPortfolio.name)
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
                EditPortfolioSheet(portfolio: currentPortfolio, isPresented: $showEditSheet)
            }
            .sheet(isPresented: $showExportSheet) {
                PortfolioExportSheet(portfolio: currentPortfolio, isPresented: $showExportSheet)
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
                forPortfolioId: currentPortfolio.id
            )
        } else {
            router.navigateToCapture(forPortfolioId: currentPortfolio.id)
        }
    }

    /// Find the first incomplete requirement in the portfolio
    func findFirstIncompleteRequirement() -> (procedure: String, stage: String?, angle: String?)? {
        for requirement in currentPortfolio.requirements {
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
        metadataManager.deletePortfolio(currentPortfolio.id)
        dismiss()
    }
}

// MARK: - PortfolioOverviewTab

/// Overview tab showing progress, quick actions, and requirements summary
struct PortfolioOverviewTab: View {
    let portfolio: Portfolio
    let stats: (fulfilled: Int, total: Int)
    let progress: Double
    let dueStatus: (text: String, color: Color, icon: String)
    let onCapturePressed: () -> Void
    let onExportPressed: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared

    // MARK: - Inline Edit State

    @State private var showRequirementEditor: Bool = false
    @State private var editingRequirement: PortfolioRequirement? = nil
    @State private var showDeleteRequirementAlert: Bool = false
    @State private var requirementToDelete: PortfolioRequirement? = nil
    @State private var matchingPhotoCount: Int = 0

    /// Always read the latest portfolio from the manager so inline edits
    /// (add/edit/delete requirements) are reflected immediately.
    var currentPortfolio: Portfolio {
        metadataManager.portfolios.first(where: { $0.id == portfolio.id }) ?? portfolio
    }

    var isComplete: Bool {
        stats.total > 0 && stats.fulfilled >= stats.total
    }

    var body: some View {
        List {
            // Progress card
            progressCard
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: AppTheme.Spacing.md, leading: 0, bottom: 0, trailing: 0))

            // Quick actions
            quickActionsSection
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: AppTheme.Spacing.lg, leading: 0, bottom: 0, trailing: 0))

            // Requirements section header
            requirementsSectionHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: AppTheme.Spacing.lg, leading: AppTheme.Spacing.md, bottom: AppTheme.Spacing.sm, trailing: AppTheme.Spacing.md))

            // Each requirement is its own row so swipe actions work
            ForEach(currentPortfolio.requirements) { requirement in
                RequirementSummaryRow(
                    requirement: requirement,
                    metadataManager: metadataManager
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: AppTheme.Spacing.xs, leading: AppTheme.Spacing.md, bottom: AppTheme.Spacing.xs, trailing: AppTheme.Spacing.md))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Order matters: trailing swipeActions render right-to-left,
                    // so the FIRST button is the rightmost — Delete on the screen edge,
                    // matching iOS Notifications.
                    Button(role: .destructive) {
                        requirementToDelete = requirement
                        matchingPhotoCount = computeMatchingPhotoCount(for: requirement)
                        showDeleteRequirementAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        editingRequirement = requirement
                        showRequirementEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(AppTheme.Colors.primary)
                }
            }

            // Inline "Add Requirement" button at the bottom of the list
            addRequirementButton
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: AppTheme.Spacing.sm, leading: AppTheme.Spacing.md, bottom: AppTheme.Spacing.md, trailing: AppTheme.Spacing.md))

            // Bottom spacer to keep the last row clear of the tab bar
            Color.clear
                .frame(height: 50)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .sheet(isPresented: $showRequirementEditor) {
            RequirementEditorSheet(
                isPresented: $showRequirementEditor,
                existingRequirement: editingRequirement,
                onSave: { saved in
                    saveRequirement(saved)
                    editingRequirement = nil
                }
            )
        }
        .alert("Remove Requirement?", isPresented: $showDeleteRequirementAlert) {
            Button("Cancel", role: .cancel) {
                requirementToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let requirement = requirementToDelete {
                    deleteRequirement(requirement)
                }
                requirementToDelete = nil
            }
        } message: {
            if matchingPhotoCount > 0 {
                Text("This requirement has \(matchingPhotoCount) matching photo\(matchingPhotoCount == 1 ? "" : "s"). The photos will remain in your library but will no longer count toward this portfolio.")
            } else {
                Text("This requirement will be removed from the portfolio.")
            }
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
                HStack(spacing: AppTheme.Spacing.xl) {
                    statItem(
                        value: "\(stats.fulfilled)",
                        label: "Complete",
                        color: AppTheme.Colors.success
                    )

                    Divider()
                        .frame(height: 40)

                    statItem(
                        value: "\(stats.total - stats.fulfilled)",
                        label: "Remaining",
                        color: stats.total - stats.fulfilled > 0 ? AppTheme.Colors.warning : AppTheme.Colors.textTertiary
                    )

                    Divider()
                        .frame(height: 40)

                    statItem(
                        value: "\(stats.total)",
                        label: "Total",
                        color: AppTheme.Colors.textSecondary
                    )
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

    // MARK: - Requirements

    /// Header row for the requirements section in the List
    var requirementsSectionHeader: some View {
        HStack {
            Text("Requirements")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
        }
    }

    /// Inline "Add Requirement" button shown at the bottom of the requirements list.
    /// Opens the same `RequirementEditorSheet` used by the Edit Portfolio flow.
    var addRequirementButton: some View {
        Button {
            editingRequirement = nil
            showRequirementEditor = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))

                Text("Add Requirement")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }
            .foregroundStyle(AppTheme.Colors.primary)
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Mutation Helpers

    /// Add or update a requirement and persist via `MetadataManager.updatePortfolio`.
    /// Matched by `id` so the existing requirement is replaced in place when editing.
    private func saveRequirement(_ requirement: PortfolioRequirement) {
        var updated = currentPortfolio
        let isNew: Bool
        if let index = updated.requirements.firstIndex(where: { $0.id == requirement.id }) {
            updated.requirements[index] = requirement
            isNew = false
        } else {
            updated.requirements.append(requirement)
            isNew = true
        }
        metadataManager.updatePortfolio(updated)
        if isNew {
            AnalyticsService.logEvent(.requirementAdded)
        }
    }

    /// Remove a requirement from the portfolio and persist via `MetadataManager.updatePortfolio`.
    private func deleteRequirement(_ requirement: PortfolioRequirement) {
        var updated = currentPortfolio
        updated.requirements.removeAll { $0.id == requirement.id }
        metadataManager.updatePortfolio(updated)
    }

    /// Count photos in the library that match this requirement's procedure/stage/angle combinations.
    /// Used to inform the user how many photos would be orphaned if they delete this requirement.
    private func computeMatchingPhotoCount(for requirement: PortfolioRequirement) -> Int {
        var count = 0
        for stage in requirement.stages {
            for angle in requirement.angles {
                count += metadataManager.getMatchingPhotoCount(
                    procedure: requirement.procedure,
                    stage: stage,
                    angle: angle
                )
            }
        }
        return count
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

// MARK: - RequirementSummaryRow

/// Row showing a single requirement with progress indicator
struct RequirementSummaryRow: View {
    let requirement: PortfolioRequirement
    @ObservedObject var metadataManager: MetadataManager

    /// Calculate fulfilled and total counts for this requirement
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

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Procedure color indicator
            Circle()
                .fill(AppTheme.procedureColor(for: requirement.procedure))
                .frame(width: 12, height: 12)

            // Procedure name
            Text(requirement.procedure)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            // Fraction text
            Text("\(stats.fulfilled)/\(stats.total)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Notes

// NOTE: PortfolioChecklistTab is now implemented in PortfolioChecklistTab.swift
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
