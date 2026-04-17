// BulkTagSheet.swift
// SimFolio - Bulk-tag sheet for multi-selected photos in the Library.
//
// Per-field touched semantics:
//   - Fields not touched preserve each photo's existing value.
//   - Fields touched (.set) overwrite that field for all selected photos.
//   - v1 does not support explicit `.cleared` (user can only overwrite or leave).
//
// The apply logic lives in `BulkTagEdits.apply(to:)` — a plain struct so it is
// unit-testable without the SwiftUI view layer.

import SwiftUI

// MARK: - FieldEdit

enum FieldEdit<Value: Equatable>: Equatable {
    case unchanged
    case set(Value)

    var isTouched: Bool {
        if case .unchanged = self { return false }
        return true
    }
}

// MARK: - BulkTagEdits

struct BulkTagEdits {
    var procedure: FieldEdit<String> = .unchanged
    var toothNumber: FieldEdit<Int> = .unchanged
    var stage: FieldEdit<String> = .unchanged
    var angle: FieldEdit<String> = .unchanged

    /// Date used for toothDate when a tooth is set. The sheet captures "now" at
    /// the moment the picker is changed; callers may override for determinism.
    var toothDateWhenTouched: Date = Date()

    var hasAnyChange: Bool {
        procedure.isTouched || toothNumber.isTouched ||
        stage.isTouched || angle.isTouched
    }

    var fieldsChanged: [String] {
        var out: [String] = []
        if procedure.isTouched { out.append("procedure") }
        if toothNumber.isTouched { out.append("tooth") }
        if stage.isTouched { out.append("stage") }
        if angle.isTouched { out.append("angle") }
        return out
    }

    /// Apply the touched fields on top of an existing PhotoMetadata row.
    /// Untouched fields preserve the existing value.
    func apply(to existing: PhotoMetadata) -> PhotoMetadata {
        var updated = existing
        if case let .set(value) = procedure { updated.procedure = value }
        if case let .set(value) = toothNumber {
            updated.toothNumber = value
            updated.toothDate = toothDateWhenTouched
        }
        if case let .set(value) = stage { updated.stage = value }
        if case let .set(value) = angle { updated.angle = value }
        return updated
    }
}

// MARK: - SharedValue helpers

private enum SharedValue<T: Hashable> {
    case none
    case all(T)
    case mixed

    init(_ values: [T?]) {
        let nonNil = values.compactMap { $0 }
        if nonNil.isEmpty { self = .none; return }
        let unique = Set(nonNil)
        if unique.count == 1, nonNil.count == values.count {
            self = .all(unique.first!)
        } else {
            self = .mixed
        }
    }

    var displayedValue: T? {
        if case let .all(v) = self { return v }
        return nil
    }

    var isMixed: Bool {
        if case .mixed = self { return true }
        return false
    }
}

// MARK: - BulkTagSheet View

struct BulkTagSheet: View {
    /// Asset IDs to apply edits to.
    let selectedAssetIds: Set<UUID>

    /// Called after edits are written; used by the caller to exit selection mode.
    var onApplied: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var metadataManager = MetadataManager.shared

    @State private var edits = BulkTagEdits()

    private var selectedIds: [String] {
        selectedAssetIds.map { $0.uuidString }
    }

    private var existingMetadata: [PhotoMetadata] {
        selectedIds.map { metadataManager.getMetadata(for: $0) ?? PhotoMetadata() }
    }

    private var sharedProcedure: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.procedure })
    }

    private var sharedStage: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.stage })
    }

    private var sharedAngle: SharedValue<String> {
        SharedValue(existingMetadata.map { $0.angle })
    }

    private var sharedToothNumber: SharedValue<Int> {
        SharedValue(existingMetadata.map { $0.toothNumber })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    procedureSection
                    toothSection
                    stageSection
                    angleSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Tag \(selectedAssetIds.count) Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyEdits() }
                        .fontWeight(.semibold)
                        .disabled(!edits.hasAnyChange)
                }
            }
        }
    }

    // MARK: Sections

    private var procedureSection: some View {
        sectionContainer(title: "PROCEDURE", mixed: sharedProcedure.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledProcedureNames(), id: \.self) { name in
                        DPTagPill(
                            name,
                            color: AppTheme.procedureColor(for: name),
                            isSelected: selectionState(for: edits.procedure, shared: sharedProcedure, value: name)
                        ) {
                            edits.procedure = .set(name)
                        }
                    }
                }
            }
        }
    }

    private var toothSection: some View {
        sectionContainer(title: "TOOTH", mixed: sharedToothNumber.isMixed) {
            Picker("Tooth Number", selection: Binding(
                get: {
                    if case let .set(value) = edits.toothNumber { return Optional(value) }
                    return Int?.none
                },
                set: { newValue in
                    if let v = newValue {
                        edits.toothNumber = .set(v)
                        edits.toothDateWhenTouched = Date()
                    } else {
                        edits.toothNumber = .unchanged
                    }
                }
            )) {
                Text("Unchanged").tag(Int?.none)
                ForEach(1...32, id: \.self) { number in
                    Text("\(number)").tag(Int?.some(number))
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .clipped()
        }
    }

    private var stageSection: some View {
        sectionContainer(title: "STAGE", mixed: sharedStage.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(metadataManager.getEnabledStages()) { config in
                        DPTagPill(
                            config.name,
                            color: config.color,
                            isSelected: selectionState(for: edits.stage, shared: sharedStage, value: config.name)
                        ) {
                            edits.stage = .set(config.name)
                        }
                    }
                }
            }
        }
    }

    private var angleSection: some View {
        sectionContainer(title: "ANGLE", mixed: sharedAngle.isMixed) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(MetadataManager.angles, id: \.self) { angle in
                        DPTagPill(
                            angle,
                            color: AppTheme.angleColor(for: angle),
                            isSelected: selectionState(for: edits.angle, shared: sharedAngle, value: angle)
                        ) {
                            edits.angle = .set(angle)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        mixed: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                if mixed {
                    Text("(Mixed)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            content()
        }
    }

    /// Whether a pill for `value` should render as selected.
    /// - Touched with `value` → selected.
    /// - Untouched AND the shared value is `value` → selected (reflects current shared state).
    /// - Otherwise → not selected.
    private func selectionState(
        for field: FieldEdit<String>,
        shared: SharedValue<String>,
        value: String
    ) -> Bool {
        switch field {
        case .set(let v):
            return v == value
        case .unchanged:
            return shared.displayedValue == value
        }
    }

    private func applyEdits() {
        var appliedCount = 0
        for assetId in selectedIds {
            let existing = metadataManager.getMetadata(for: assetId) ?? PhotoMetadata()
            let updated = edits.apply(to: existing)
            metadataManager.assignMetadata(updated, to: assetId)

            if let toothEntry = updated.toothEntry, edits.toothNumber.isTouched {
                metadataManager.addToothEntry(toothEntry)
            }
            appliedCount += 1
        }

        AnalyticsService.logBulkTagApplied(
            photoCount: appliedCount,
            fieldsChanged: edits.fieldsChanged
        )

        onApplied(appliedCount)
        dismiss()
    }
}

#if DEBUG
struct BulkTagSheet_Previews: PreviewProvider {
    static var previews: some View {
        BulkTagSheet(
            selectedAssetIds: [UUID(), UUID()],
            onApplied: { _ in }
        )
    }
}
#endif
