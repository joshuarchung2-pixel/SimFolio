// ToothPicker.swift
// SimFolio
//
// Reusable tooth picker component using a scroll wheel picker
// with anatomical tooth names display.

import SwiftUI

// MARK: - Tooth Picker Sheet

/// Sheet wrapper for tooth selection with wheel picker
/// Provides a consistent tooth selection experience across the app
struct ToothPickerSheet: View {
    @Binding var selectedTooth: Int?
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    /// Optional recent teeth for quick selection
    var recentTeeth: [ToothEntry] = []

    /// Whether to show the date picker
    var showDatePicker: Bool = true

    /// Callback when tooth is confirmed (for adding to tooth entries)
    var onConfirm: ((Int, Date) -> Void)?

    @State private var tempSelectedTooth: Int = 1

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Recent teeth quick select (if available)
                if !recentTeeth.isEmpty {
                    recentTeethSection
                }

                // Wheel picker section
                wheelPickerSection

                // Date picker (optional)
                if showDatePicker {
                    datePickerSection
                }

                Spacer()
            }
            .padding(.top, AppTheme.Spacing.md)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Select Tooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedTooth = tempSelectedTooth
                        onConfirm?(tempSelectedTooth, selectedDate)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempSelectedTooth = selectedTooth ?? 1
            }
        }
    }

    // MARK: - Recent Teeth Section

    private var recentTeethSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("RECENT TEETH")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(recentTeeth.prefix(5), id: \.id) { entry in
                        Button(action: {
                            tempSelectedTooth = entry.toothNumber
                            selectedDate = entry.date
                        }) {
                            VStack(spacing: AppTheme.Spacing.xxs) {
                                Text("#\(entry.toothNumber)")
                                    .font(AppTheme.Typography.headline)
                                    .foregroundStyle(
                                        tempSelectedTooth == entry.toothNumber
                                            ? .white
                                            : AppTheme.Colors.textPrimary
                                    )

                                Text(entry.date, style: .date)
                                    .font(AppTheme.Typography.caption2)
                                    .foregroundStyle(
                                        tempSelectedTooth == entry.toothNumber
                                            ? .white.opacity(0.8)
                                            : AppTheme.Colors.textSecondary
                                    )
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                tempSelectedTooth == entry.toothNumber
                                    ? AppTheme.Colors.info
                                    : AppTheme.Colors.surface
                            )
                            .cornerRadius(AppTheme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .stroke(
                                        tempSelectedTooth == entry.toothNumber
                                            ? AppTheme.Colors.info
                                            : AppTheme.Colors.surfaceSecondary,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }

    // MARK: - Wheel Picker Section

    private var wheelPickerSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Tooth picker row
            HStack(spacing: AppTheme.Spacing.lg) {
                // Label
                Text("Tooth #")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                // Number picker
                Picker("Tooth Number", selection: $tempSelectedTooth) {
                    ForEach(1...32, id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 120)
                .clipped()

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.large)
            .padding(.horizontal, AppTheme.Spacing.md)

            // Tooth name display badge
            Text(ToothUtility.name(for: tempSelectedTooth))
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.success)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.success.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.medium)
        }
    }

    // MARK: - Date Picker Section

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("PROCEDURE DATE")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)

            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()

                Spacer()
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ToothPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        ToothPickerSheet(
            selectedTooth: .constant(1),
            selectedDate: .constant(Date()),
            isPresented: .constant(true),
            recentTeeth: [
                ToothEntry(procedure: "Class 1", toothNumber: 14, date: Date()),
                ToothEntry(procedure: "Class 1", toothNumber: 19, date: Date().addingTimeInterval(-86400)),
                ToothEntry(procedure: "Class 1", toothNumber: 3, date: Date().addingTimeInterval(-172800))
            ]
        )
    }
}
#endif
