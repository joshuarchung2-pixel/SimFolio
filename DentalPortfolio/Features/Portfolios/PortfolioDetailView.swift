// PortfolioDetailView.swift
// Dental Portfolio - Portfolio Detail View with Tabs
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
import Photos

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
    @ObservedObject var library = PhotoLibraryManager.shared

    // MARK: - State

    @State private var selectedTab: PortfolioTab = .overview
    @State private var showEditSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false

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
                        onExportPressed: { showExportSheet = true }
                    )
                    .tag(PortfolioTab.overview)

                    PortfolioChecklistTab(portfolio: portfolio)
                        .tag(PortfolioTab.checklist)

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

                        Button(action: { showExportSheet = true }) {
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
                    HapticsManager.shared.selectionChanged()
                }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(AppTheme.Typography.subheadline)
                        }
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
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
        HapticsManager.shared.success()
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

    var isComplete: Bool {
        stats.total > 0 && stats.fulfilled >= stats.total
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
                // Large progress ring
                DPProgressRing(
                    progress: progress,
                    size: 120,
                    lineWidth: 10,
                    foregroundColor: isComplete ? AppTheme.Colors.success : nil,
                    showLabel: true,
                    labelStyle: .percentage
                )

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
                .foregroundColor(dueStatus.color)
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
                .foregroundColor(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Quick Actions

    /// Section with quick action buttons
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Quick Actions")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
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
                    subtitle: "ZIP, PDF, or individual files",
                    isDisabled: stats.fulfilled == 0,
                    action: onExportPressed
                )

                // Share
                QuickActionButton(
                    icon: "square.and.arrow.up.on.square",
                    iconColor: .purple,
                    title: "Share Portfolio",
                    subtitle: "Share progress or completed work",
                    isDisabled: false,
                    action: {
                        // TODO: Implement sharing
                    }
                )
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Requirements Summary

    /// Section showing all requirements with progress
    var requirementsSummarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Requirements")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)

            if portfolio.requirements.isEmpty {
                DPCard {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text("No requirements added yet")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(portfolio.requirements) { requirement in
                        RequirementSummaryRow(
                            requirement: requirement,
                            metadataManager: metadataManager
                        )
                    }
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

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                HapticsManager.shared.lightTap()
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
                        .foregroundColor(isDisabled ? AppTheme.Colors.textTertiary : iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDisabled ? AppTheme.Colors.textTertiary : AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed && !isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isDisabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
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
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            // Progress ring (small)
            DPProgressRing(
                progress: progress,
                size: 32,
                lineWidth: 3,
                foregroundColor: isComplete ? AppTheme.Colors.success : nil,
                showLabel: false
            )

            // Fraction text
            Text("\(stats.fulfilled)/\(stats.total)")
                .font(AppTheme.Typography.caption)
                .foregroundColor(isComplete ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Placeholder Views

/// Placeholder for PortfolioChecklistTab - will be implemented in Prompt 5.3
struct PortfolioChecklistTab: View {
    let portfolio: Portfolio

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: 60)

                Image(systemName: "checklist")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Checklist Tab")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Coming in Prompt 5.3")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

/// Placeholder for PortfolioPhotosTab - will be implemented in Prompt 5.4
struct PortfolioPhotosTab: View {
    let portfolio: Portfolio

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer(minLength: 60)

                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Photos Tab")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Coming in Prompt 5.4")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

/// Placeholder for PortfolioExportSheet - will be implemented in Prompt 5.5
struct PortfolioExportSheet: View {
    let portfolio: Portfolio
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Export Sheet")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Coming in Prompt 5.5")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

/// Placeholder for EditPortfolioSheet - will be implemented in Prompt 5.6
struct EditPortfolioSheet: View {
    let portfolio: Portfolio
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                Image(systemName: "pencil.circle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Edit Portfolio")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Coming in Prompt 5.6")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

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
