// HomeView.swift
// Dental Portfolio - Home Dashboard
//
// The main dashboard view - first screen users see after launch.
// Shows portfolio progress, quick capture buttons, and actionable items.
//
// Sections:
// 1. Quick Capture - Start capturing for each procedure
// 2. Active Portfolios - Horizontal scroll of portfolio cards with progress
// 3. Needs Attention - Missing photos or incomplete items
// 4. Recent Captures - Last photos taken

import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared
    @State private var greeting: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {

                    // 1. Quick Capture Section
                    QuickCaptureSection()

                    // 2. Active Portfolios Section (only if portfolios exist)
                    if !metadataManager.portfolios.isEmpty {
                        ActivePortfoliosSection()
                    }

                    // 3. Needs Attention Section (only if items exist)
                    NeedsAttentionSection()

                    // 4. Recent Captures Section (only if photos exist)
                    if !library.assets.isEmpty {
                        RecentCapturesSection()
                    }

                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        // Notification bell (future feature)
                        DPIconButton(icon: "bell", size: 36) {
                            // TODO: Show notifications
                        }

                        // Settings - navigate to profile
                        DPIconButton(icon: "gearshape", size: 36) {
                            router.selectedTab = .profile
                        }
                    }
                }
            }
            .onAppear {
                updateGreeting()
                library.fetchAssets()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            greeting = "Good morning"
        } else if hour < 17 {
            greeting = "Good afternoon"
        } else {
            greeting = "Good evening"
        }
    }
}

// MARK: - Quick Capture Section

/// Quick capture buttons for each procedure type
struct QuickCaptureSection: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Section header
            DPSectionHeader("Quick Capture", subtitle: "Tap a procedure to start")
                .padding(.horizontal, AppTheme.Spacing.md)

            // Horizontal scroll of procedure buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.procedures, id: \.self) { procedure in
                        QuickCaptureProcedureButton(
                            procedure: procedure,
                            color: AppTheme.procedureColor(for: procedure),
                            photoCount: metadataManager.photoCount(for: procedure)
                        ) {
                            router.navigateToCapture(procedure: procedure)
                        }
                    }

                    // Add new procedure button
                    AddProcedureButton {
                        // TODO: Show add procedure sheet
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Quick Capture Procedure Button

/// A button for quickly starting capture with a specific procedure
struct QuickCaptureProcedureButton: View {
    let procedure: String
    let color: Color
    let photoCount: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            VStack(spacing: AppTheme.Spacing.sm) {
                // Color circle with camera icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Procedure name
                Text(procedure)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                // Photo count
                Text("\(photoCount) photos")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 80)
            .padding(.vertical, AppTheme.Spacing.sm)
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

// MARK: - Add Procedure Button

/// Button to add a new custom procedure
struct AddProcedureButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AppTheme.Colors.textTertiary,
                            style: StrokeStyle(lineWidth: 2, dash: [5])
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                Text("Add New")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                // Empty text for alignment
                Text(" ")
                    .font(AppTheme.Typography.caption2)
            }
            .frame(width: 80)
            .padding(.vertical, AppTheme.Spacing.sm)
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

// MARK: - Active Portfolios Section

/// Horizontal scrolling list of active portfolios with progress
struct ActivePortfoliosSection: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    /// Only show portfolios that are not 100% complete
    var activePortfolios: [Portfolio] {
        metadataManager.portfolios.filter { portfolio in
            let stats = metadataManager.getPortfolioStats(portfolio)
            return stats.fulfilled < stats.total || stats.total == 0
        }.sorted { p1, p2 in
            // Sort by due date (soonest first), then by name
            guard let d1 = p1.dueDate else { return false }
            guard let d2 = p2.dueDate else { return true }
            return d1 < d2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Active Portfolios",
                actionTitle: "See All"
            ) {
                router.selectedTab = .profile // Or dedicated portfolios tab
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if activePortfolios.isEmpty {
                // Empty state card
                DPCard {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.textTertiary)

                        Text("No active portfolios")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        DPButton("Create Portfolio", style: .secondary, size: .small) {
                            // TODO: Show create portfolio sheet
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                // Horizontal scroll of portfolio cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        ForEach(activePortfolios) { portfolio in
                            PortfolioPreviewCard(portfolio: portfolio) {
                                router.navigateToPortfolio(id: portfolio.id)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
        }
    }
}

// MARK: - Portfolio Preview Card

/// A card showing portfolio summary with progress ring
struct PortfolioPreviewCard: View {
    let portfolio: Portfolio
    let onTap: () -> Void

    @ObservedObject var metadataManager = MetadataManager.shared
    @State private var isPressed = false

    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    var completionPercentage: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    var dueStatus: (text: String, color: Color) {
        guard let days = portfolio.daysUntilDue else {
            return ("No deadline", AppTheme.Colors.textTertiary)
        }

        if days < 0 {
            return ("Overdue by \(abs(days))d", AppTheme.Colors.error)
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

    var progressColor: Color {
        if completionPercentage >= 1.0 { return AppTheme.Colors.success }
        if completionPercentage >= 0.75 { return AppTheme.Colors.success }
        if completionPercentage >= 0.5 { return AppTheme.Colors.warning }
        if completionPercentage >= 0.25 { return Color(hex: "F97316") } // Orange
        return AppTheme.Colors.error
    }

    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Header: Name and created date
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(portfolio.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text("Created \(portfolio.dateString)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                // Progress section
                HStack(spacing: AppTheme.Spacing.md) {
                    // Progress ring
                    DPProgressRing(
                        progress: completionPercentage,
                        size: 70,
                        lineWidth: 6,
                        showLabel: true,
                        labelStyle: .fraction(current: stats.fulfilled, total: stats.total)
                    )

                    // Stats
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(String(format: "%.0f%%", completionPercentage * 100))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(progressColor)

                        Text("complete")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                Divider()

                // Due date status
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))

                    Text(dueStatus.text)
                        .font(AppTheme.Typography.caption)
                }
                .foregroundColor(dueStatus.color)

                // Missing count
                if stats.total - stats.fulfilled > 0 {
                    Text("\(stats.total - stats.fulfilled) photos needed")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(width: 260)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadowMedium()
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

// MARK: - Needs Attention Section

/// List of items that need attention (missing photos, incomplete metadata)
struct NeedsAttentionSection: View {
    @EnvironmentObject var router: NavigationRouter
    @ObservedObject var metadataManager = MetadataManager.shared

    @State private var showAllItems = false

    /// Get all missing requirements from portfolios due within 14 days
    var missingRequirements: [MissingRequirement] {
        var missing: [MissingRequirement] = []

        for portfolio in metadataManager.portfolios {
            // Only check portfolios due within 14 days
            guard let daysUntil = portfolio.daysUntilDue, daysUntil <= 14 else { continue }

            for requirement in portfolio.requirements {
                for stage in requirement.stages {
                    for angle in requirement.angles {
                        let currentCount = metadataManager.getPhotoCount(
                            for: requirement,
                            stage: stage,
                            angle: angle
                        )
                        let neededCount = requirement.angleCounts[angle] ?? 1

                        if currentCount < neededCount {
                            missing.append(MissingRequirement(
                                portfolio: portfolio,
                                requirement: requirement,
                                stage: stage,
                                angle: angle,
                                currentCount: currentCount,
                                neededCount: neededCount
                            ))
                        }
                    }
                }
            }
        }

        // Sort by urgency (portfolio due date)
        return missing.sorted { m1, m2 in
            (m1.portfolio.daysUntilDue ?? 999) < (m2.portfolio.daysUntilDue ?? 999)
        }
    }

    var displayedItems: [MissingRequirement] {
        if showAllItems {
            return missingRequirements
        } else {
            return Array(missingRequirements.prefix(5))
        }
    }

    var body: some View {
        if !missingRequirements.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                DPSectionHeader(
                    "Needs Attention",
                    subtitle: "\(missingRequirements.count) missing"
                )
                .padding(.horizontal, AppTheme.Spacing.md)

                VStack(spacing: 0) {
                    ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                        MissingRequirementRow(item: item) {
                            router.navigateToCapture(
                                procedure: item.requirement.procedure,
                                stage: item.stage,
                                angle: item.angle,
                                forPortfolioId: item.portfolio.id
                            )
                        }

                        if index < displayedItems.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }

                    // Show more button
                    if missingRequirements.count > 5 && !showAllItems {
                        Button(action: {
                            withAnimation(.dpSpring) {
                                showAllItems = true
                            }
                        }) {
                            HStack {
                                Text("Show \(missingRequirements.count - 5) more")
                                    .font(AppTheme.Typography.subheadline)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                        }
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .shadowSmall()
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Missing Requirement Model

/// Represents a missing photo requirement for a portfolio
struct MissingRequirement: Identifiable {
    let id = UUID()
    let portfolio: Portfolio
    let requirement: PortfolioRequirement
    let stage: String
    let angle: String
    let currentCount: Int
    let neededCount: Int

    var description: String {
        "\(requirement.procedure) \(stage) - \(angle)"
    }

    var countText: String {
        let missing = neededCount - currentCount
        if missing > 1 {
            return "Need \(missing) more"
        }
        return ""
    }
}

// MARK: - Missing Requirement Row

/// A row displaying a missing photo requirement with capture button
struct MissingRequirementRow: View {
    let item: MissingRequirement
    let onCaptureTap: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.warning.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.warning)
            }

            // Requirement info
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(item.description)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.xs) {
                    Text("For \(item.portfolio.name)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)

                    if !item.countText.isEmpty {
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text(item.countText)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.warning)
                    }
                }
            }

            Spacer()

            // Capture button
            DPIconButton(
                icon: "camera.fill",
                size: 40,
                backgroundColor: AppTheme.Colors.primary,
                iconColor: .white
            ) {
                HapticsManager.shared.lightTap()
                onCaptureTap()
            }
        }
        .padding(AppTheme.Spacing.md)
    }
}

// MARK: - Recent Captures Section

/// Grid of recently captured photos
struct RecentCapturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DPSectionHeader(
                "Recent Captures",
                actionTitle: "See All"
            ) {
                // Navigate to library
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Placeholder content
            DPCard {
                Text("Recent Captures Section")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(NavigationRouter())
    }
}
#endif
