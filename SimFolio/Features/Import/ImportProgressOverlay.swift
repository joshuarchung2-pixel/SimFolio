// ImportProgressOverlay.swift
// SimFolio - Blocking progress overlay shown while a batch import runs

import SwiftUI

struct ImportProgressOverlay: View {
    @ObservedObject var state: ImportFlowState
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                ProgressView(
                    value: Double(state.progress.completed),
                    total: Double(max(state.progress.total, 1))
                )
                .tint(.white)
                .frame(width: 220)

                Text("Importing \(state.progress.completed) of \(state.progress.total)…")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.white)

                if state.progress.skipped > 0 || state.progress.failed > 0 {
                    Text(subDetail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                DPButton("Cancel", style: .secondary, size: .medium) {
                    onCancel()
                }
            }
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color.black.opacity(0.75))
            )
            .padding(AppTheme.Spacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importing \(state.progress.completed) of \(state.progress.total)")
    }

    private var subDetail: String {
        var parts: [String] = []
        if state.progress.skipped > 0 {
            parts.append("\(state.progress.skipped) skipped")
        }
        if state.progress.failed > 0 {
            parts.append("\(state.progress.failed) failed")
        }
        return parts.joined(separator: " • ")
    }
}
