// ImportFlowView.swift
// SimFolio - Container view for importing photos from the system Photos library
//
// Three-phase flow mirroring CaptureFlowView:
//   .picker     → PhotosPicker (or stub under --mock-photos-picker)
//   .review     → ImportReviewView (tag + curate selected photos)
//   .importing  → ImportProgressOverlay (blocking progress with Cancel)

import SwiftUI
import PhotosUI
import Photos

// MARK: - Mock picker support (UI tests)

/// When set, ImportFlowView bypasses the real PhotosPicker and seeds `candidates`
/// directly. Installed at app startup when --mock-photos-picker is present.
enum ImportFlowPickerOverride {
    /// A canned set of candidates to present in the review screen. When non-nil the
    /// picker phase is skipped entirely.
    nonisolated(unsafe) static var mockCandidates: [ImportCandidate]?
}

// MARK: - ImportFlowView

struct ImportFlowView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var importState = ImportFlowState()
    @Environment(\.dismiss) private var dismiss

    var prefilledProcedure: String?
    var prefilledStage: String?
    var prefilledAngle: String?
    var prefilledToothNumber: Int?
    var portfolioId: String?

    @State private var didApplyPrefill = false
    @State private var didSeedMockCandidates = false

    // MARK: Body

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            Group {
                switch importState.currentStep {
                case .picker:
                    pickerPhase
                case .review:
                    ImportReviewView(
                        importState: importState,
                        isPrefilledFromPortfolio: importState.isFromPortfolio,
                        onCancel: { dismissFlow() },
                        onStartImport: { runImport() }
                    )
                case .importing:
                    ImportReviewView(
                        importState: importState,
                        isPrefilledFromPortfolio: importState.isFromPortfolio,
                        onCancel: { },
                        onStartImport: { }
                    )
                    .disabled(true)
                }
            }

            if importState.isImporting {
                ImportProgressOverlay(state: importState) {
                    importState.isCancelled = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: importState.currentStep)
        .animation(.easeInOut(duration: 0.2), value: importState.isImporting)
        .onAppear {
            if !didApplyPrefill {
                didApplyPrefill = true
                importState.prefill(
                    procedure: prefilledProcedure,
                    stage: prefilledStage,
                    angle: prefilledAngle,
                    toothNumber: prefilledToothNumber,
                    portfolioId: portfolioId
                )
            }
            seedMockCandidatesIfNeeded()
        }
        .onChange(of: importState.selectedItems) { items in
            Task { await resolveCandidates(from: items) }
        }
    }

    // MARK: Picker Phase

    @ViewBuilder
    private var pickerPhase: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 96, height: 96)
                .background(AppTheme.Colors.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Import from Photos")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Bring procedure photos you already have\ninto SimFolio to tag and organize.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(
                selection: $importState.selectedItems,
                maxSelectionCount: 50,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "photo.stack")
                    Text("Select Photos")
                }
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .frame(height: 52)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            }
            .accessibilityIdentifier("import-select-photos")

            Button("Cancel", action: dismissFlow)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(AppTheme.Spacing.lg)
    }

    // MARK: Candidate Resolution

    private func resolveCandidates(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        var resolved: [ImportCandidate] = []
        let assetIdsToLookup = items.compactMap { $0.itemIdentifier }

        // Fetch PHAsset creation dates in one batch.
        var dateByAssetId: [String: Date] = [:]
        if !assetIdsToLookup.isEmpty {
            let fetched = PHAsset.fetchAssets(withLocalIdentifiers: assetIdsToLookup, options: nil)
            fetched.enumerateObjects { asset, _, _ in
                if let date = asset.creationDate {
                    dateByAssetId[asset.localIdentifier] = date
                }
            }
        }

        for item in items {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                let image = data.flatMap { UIImage(data: $0) }
                let assetId = item.itemIdentifier
                let createdDate = assetId.flatMap { dateByAssetId[$0] }

                resolved.append(ImportCandidate(
                    pickerItemId: assetId,
                    image: image,
                    pHAssetId: assetId,
                    originalCapturedDate: createdDate,
                    loadError: image == nil ? ImportError.loadFailed : nil
                ))
            } catch {
                resolved.append(ImportCandidate(
                    pickerItemId: item.itemIdentifier,
                    image: nil,
                    pHAssetId: item.itemIdentifier,
                    originalCapturedDate: nil,
                    loadError: error
                ))
            }
        }

        await MainActor.run {
            importState.candidates = resolved
            importState.currentStep = .review
        }
    }

    // MARK: Run Import

    private func runImport() {
        let baseMetadata = PhotoMetadata(
            procedure: importState.selectedProcedure,
            toothNumber: importState.selectedToothNumber,
            toothDate: importState.selectedToothDate,
            stage: importState.selectedStage,
            angle: importState.selectedAngle,
            rating: nil
        )

        importState.progress = ImportProgress(
            completed: 0,
            total: importState.candidatesToImport.count,
            skipped: 0,
            failed: 0
        )
        importState.isImporting = true
        importState.isCancelled = false
        importState.currentStep = .importing

        let candidatesToImport = importState.candidatesToImport

        Task { [importState] in
            let result = await PhotoImportService.shared.importCandidates(
                candidatesToImport,
                metadata: baseMetadata,
                onProgress: { progress in
                    Task { @MainActor in importState.progress = progress }
                },
                isCancelled: { importState.isCancelled }
            )

            await MainActor.run {
                importState.isImporting = false
                finish(with: result)
            }
        }
    }

    private func finish(with result: ImportResult) {
        let total = result.imported + result.skipped + result.failed
        AnalyticsService.logPhotoImported(
            count: result.imported,
            duplicatesSkipped: result.skipped,
            failed: result.failed,
            prefilled: importState.isFromPortfolio
        )

        if result.imported > 0 {
            ReviewPromptService.requestIfEligible(for: .firstPhotoCaptured)
        }

        let importedOk = result.imported > 0
        let toastMessage: String
        if importedOk {
            toastMessage = "\(result.imported) imported · Tap to tag"
        } else {
            toastMessage = self.toastMessage(for: result, total: total)
        }

        dismissFlow()

        let router = self.router
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var userInfo: [AnyHashable: Any] = [
                "message": toastMessage,
                "type": importedOk ? "success" : "info"
            ]
            if importedOk {
                let onTap: () -> Void = {
                    AnalyticsService.logImportNudgeTapped()
                    var filter = LibraryFilter()
                    filter.showUntaggedOnly = true
                    router.navigateToLibrary(filter: filter)
                }
                userInfo["onTap"] = onTap
            }
            NotificationCenter.default.post(
                name: .showGlobalToast,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func toastMessage(for result: ImportResult, total: Int) -> String {
        var parts: [String] = ["\(result.imported) imported"]
        if result.skipped > 0 {
            parts.append("\(result.skipped) already in library")
        }
        if result.failed > 0 {
            parts.append("\(result.failed) failed")
        }
        return parts.joined(separator: ", ")
    }

    private func dismissFlow() {
        importState.reset()
        dismiss()
    }

    // MARK: Mock Picker

    private func seedMockCandidatesIfNeeded() {
        guard !didSeedMockCandidates,
              let mocks = ImportFlowPickerOverride.mockCandidates,
              !mocks.isEmpty else { return }
        didSeedMockCandidates = true
        importState.candidates = mocks
        importState.currentStep = .review
    }
}

// MARK: - ImportError

enum ImportError: LocalizedError {
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed: return "Couldn't load photo"
        }
    }
}
