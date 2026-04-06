import SwiftUI

struct ReportSheet: View {
    let targetType: SocialReport.ReportTargetType
    let targetId: String
    let postId: String? // needed for comment reports
    var onComplete: (() -> Void)?

    @State private var selectedReason: SocialReport.ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(SocialReport.ReportReason.allCases, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Text(reason.rawValue)
                                        .font(AppTheme.Typography.body)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppTheme.Colors.primary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select a reason")
                    }

                    if selectedReason == .other {
                        Section {
                            TextField("Provide details...", text: $details, axis: .vertical)
                                .lineLimit(3...6)
                                .font(AppTheme.Typography.body)
                        } header: {
                            Text("Additional details")
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Submit button
                VStack {
                    DPButton(
                        "Submit Report",
                        style: .destructive,
                        size: .large,
                        isFullWidth: true,
                        isLoading: isSubmitting,
                        isDisabled: selectedReason == nil
                    ) {
                        Task { await submitReport() }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("Report \(targetType.rawValue.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    onComplete?()
                    dismiss()
                }
            } message: {
                Text("Thank you. We'll review this within 24 hours.")
            }
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch targetType {
            case .post:
                try await ModerationService.shared.reportPost(
                    postId: targetId,
                    reason: reason,
                    details: details.isEmpty ? nil : details
                )
            case .comment:
                try await ModerationService.shared.reportComment(
                    postId: postId ?? "",
                    commentId: targetId,
                    reason: reason,
                    details: details.isEmpty ? nil : details
                )
            case .user:
                try await ModerationService.shared.reportPost(
                    postId: targetId,
                    reason: reason,
                    details: details.isEmpty ? nil : details
                )
            }
            showSuccess = true
        } catch {
            // Handle error
        }
    }
}
