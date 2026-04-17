// NeedsTaggingChipBar.swift
// SimFolio - Two-chip row above the Library grid: "All" | "Needs Tagging (N)".
//
// The chip bar is a persistent filter surface separate from the filter sheet.
// Toggling it flips `LibraryFilter.showUntaggedOnly`. The untagged count is passed
// in from LibraryView, which binds it to MetadataManager.incompleteAssetCount.

import SwiftUI

struct NeedsTaggingChipBar: View {
    @Binding var showUntaggedOnly: Bool
    let untaggedCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            chip(
                title: "All",
                identifier: "needs-tagging-chip-all",
                isSelected: !showUntaggedOnly
            ) {
                if showUntaggedOnly {
                    showUntaggedOnly = false
                }
            }
            chip(
                title: untaggedCount > 0
                    ? "Needs Tagging (\(untaggedCount))"
                    : "Needs Tagging",
                identifier: "needs-tagging-chip-needs-tagging",
                isSelected: showUntaggedOnly
            ) {
                if !showUntaggedOnly {
                    showUntaggedOnly = true
                    AnalyticsService.logUntaggedFilterViewed()
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.background)
    }

    @ViewBuilder
    private func chip(
        title: String,
        identifier: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(AppTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
struct NeedsTaggingChipBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NeedsTaggingChipBar(showUntaggedOnly: .constant(false), untaggedCount: 12)
            NeedsTaggingChipBar(showUntaggedOnly: .constant(true), untaggedCount: 12)
            NeedsTaggingChipBar(showUntaggedOnly: .constant(false), untaggedCount: 0)
        }
        .background(AppTheme.Colors.background)
    }
}
#endif
