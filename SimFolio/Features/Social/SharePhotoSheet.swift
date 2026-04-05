import SwiftUI

struct SharePhotoSheet: View {
    let image: UIImage
    let metadata: PhotoMetadata
    var assetId: String?
    var onComplete: (() -> Void)?

    @ObservedObject private var sharingService = PhotoSharingService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var caption = ""
    @State private var isSimulationConfirmed = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let maxCaptionLength = 280

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Photo preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 250)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    // Simulation confirmation
                    Button {
                        isSimulationConfirmed.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                            Image(systemName: isSimulationConfirmed ? "checkmark.square.fill" : "square")
                                .foregroundColor(isSimulationConfirmed ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                .font(.title3)

                            Text("I confirm this is simulation work (not a real patient)")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    // Caption
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        TextField("Add a caption (optional)", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppTheme.Typography.body)
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.Colors.surfaceSecondary)
                            .cornerRadius(AppTheme.CornerRadius.medium)

                        HStack {
                            Spacer()
                            Text("\(caption.count)/\(maxCaptionLength)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(caption.count > maxCaptionLength ? AppTheme.Colors.error : AppTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    if let error = errorMessage {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.error)
                            .padding(.horizontal, AppTheme.Spacing.md)
                    }

                    // Tags preview
                    if let procedure = metadata.procedure {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                DPTagPill(text: procedure, color: AppTheme.procedureColor(for: procedure))
                                if let stage = metadata.stage {
                                    DPTagPill(text: stage, color: AppTheme.Colors.secondary)
                                }
                                if let angle = metadata.angle {
                                    DPTagPill(text: angle, color: AppTheme.Colors.secondary)
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                        }
                    }

                    // Share button
                    DPButton(
                        title: "Share to Class Feed",
                        style: .primary,
                        size: .large,
                        isFullWidth: true,
                        isLoading: sharingService.isUploading,
                        isDisabled: !isSimulationConfirmed || caption.count > maxCaptionLength
                    ) {
                        Task { await sharePhoto() }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    DPButton(title: "Cancel", style: .secondary, size: .large, isFullWidth: true) {
                        dismiss()
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .navigationTitle("Share Photo")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Shared!", isPresented: $showSuccess) {
                Button("OK") {
                    onComplete?()
                    dismiss()
                }
            } message: {
                Text("Your photo has been shared to the class feed.")
            }
        }
    }

    private func sharePhoto() async {
        errorMessage = nil

        do {
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await sharingService.sharePhoto(
                image: image,
                metadata: metadata,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
                assetId: assetId
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
