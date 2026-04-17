import UIKit
@testable import SimFolio

// MARK: - Mock Metadata Manager

final class MockMetadataManager: MetadataManaging {
    var portfolios: [Portfolio] = []
    var procedureConfigs: [ProcedureConfig] = []
    var stageConfigs: [StageConfig] = []
    var assetMetadata: [String: PhotoMetadata] = [:]
    var importedAssetIds: Set<String> = []

    var addPortfolioCalls: [Portfolio] = []
    var updatePortfolioCalls: [Portfolio] = []
    var deletePortfolioCalls: [String] = []
    var assignMetadataCalls: [(metadata: PhotoMetadata, assetId: String)] = []
    var deleteMetadataCalls: [String] = []
    var setRatingCalls: [(rating: Int?, assetId: String)] = []
    var markImportedCalls: [String] = []

    func addPortfolio(_ portfolio: Portfolio) {
        addPortfolioCalls.append(portfolio)
        portfolios.append(portfolio)
    }

    func updatePortfolio(_ portfolio: Portfolio) {
        updatePortfolioCalls.append(portfolio)
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
        }
    }

    func deletePortfolio(_ portfolioId: String) {
        deletePortfolioCalls.append(portfolioId)
        portfolios.removeAll { $0.id == portfolioId }
    }

    func getPortfolio(by id: String) -> Portfolio? {
        portfolios.first { $0.id == id }
    }

    func assignMetadata(_ metadata: PhotoMetadata, to assetId: String) {
        assignMetadataCalls.append((metadata, assetId))
        assetMetadata[assetId] = metadata
    }

    func getMetadata(for assetId: String) -> PhotoMetadata? {
        assetMetadata[assetId]
    }

    func deleteMetadata(for assetId: String) {
        deleteMetadataCalls.append(assetId)
        assetMetadata.removeValue(forKey: assetId)
    }

    func getPortfolioStats(_ portfolio: Portfolio) -> (fulfilled: Int, total: Int) {
        let total = portfolio.requirements.reduce(0) { $0 + $1.totalRequired }
        return (0, total)
    }

    func getPortfolioCompletionPercentage(_ portfolio: Portfolio) -> Double {
        let stats = getPortfolioStats(portfolio)
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    func getMatchingPhotoCount(procedure: String, stage: String, angle: String) -> Int {
        assetMetadata.values.filter {
            $0.procedure == procedure && $0.stage == stage && $0.angle == angle
        }.count
    }

    func getEnabledProcedureNames() -> [String] {
        procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    func getEnabledStageNames() -> [String] {
        stageConfigs.map { $0.name }
    }

    func getRating(for assetId: String) -> Int? {
        assetMetadata[assetId]?.rating
    }

    func setRating(_ rating: Int?, for assetId: String) {
        setRatingCalls.append((rating, assetId))
        assetMetadata[assetId]?.rating = rating
    }

    func photoCount(for procedure: String) -> Int {
        assetMetadata.values.filter { $0.procedure == procedure }.count
    }

    func hasImported(assetId: String) -> Bool {
        importedAssetIds.contains(assetId)
    }

    func markImported(assetId: String) {
        markImportedCalls.append(assetId)
        importedAssetIds.insert(assetId)
    }
}

// MARK: - Mock Photo Storage

final class MockPhotoStorage: PhotoStoring {
    var records: [PhotoRecord] = []
    var storedImages: [UUID: UIImage] = [:]

    var savePhotoCalls: [UIImage] = []
    var savePhotoWithDateCalls: [(image: UIImage, createdDate: Date)] = []
    var deletePhotoCalls: [UUID] = []

    func savePhoto(_ image: UIImage, compressionQuality: CGFloat) -> PhotoRecord {
        savePhotoCalls.append(image)
        let record = PhotoRecord(id: UUID(), createdDate: TestData.referenceDate, fileSize: 1024)
        records.append(record)
        storedImages[record.id] = image
        return record
    }

    func savePhoto(_ image: UIImage, createdDate: Date, compressionQuality: CGFloat) -> PhotoRecord {
        savePhotoCalls.append(image)
        savePhotoWithDateCalls.append((image, createdDate))
        let record = PhotoRecord(id: UUID(), createdDate: createdDate, fileSize: 1024)
        records.append(record)
        storedImages[record.id] = image
        return record
    }

    func loadImage(id: UUID) -> UIImage? { storedImages[id] }
    func loadThumbnail(id: UUID) -> UIImage? { storedImages[id] }
    func loadEditedImage(id: UUID) -> UIImage? { storedImages[id] }
    func loadEditedThumbnail(id: UUID) -> UIImage? { storedImages[id] }

    func deletePhoto(id: UUID) {
        deletePhotoCalls.append(id)
        records.removeAll { $0.id == id }
        storedImages.removeValue(forKey: id)
    }

    func deletePhotos(ids: [UUID]) {
        ids.forEach { deletePhoto(id: $0) }
    }
}

// MARK: - Mock Edit State Persistence

final class MockEditStatePersistence: EditStatePersisting {
    var editStates: [String: EditState] = [:]

    var saveCalls: [(editState: EditState, assetId: String)] = []
    var deleteCalls: [String] = []

    func saveEditState(_ editState: EditState, for assetId: String) {
        saveCalls.append((editState, assetId))
        editStates[assetId] = editState
    }

    func getEditState(for assetId: String) -> EditState? { editStates[assetId] }
    func hasEditState(for assetId: String) -> Bool { editStates[assetId] != nil }

    func deleteEditState(for assetId: String) {
        deleteCalls.append(assetId)
        editStates.removeValue(forKey: assetId)
    }

    func getEditSummary(for assetId: String) -> String? {
        guard let state = editStates[assetId], state.hasChanges else { return nil }
        return "Edited"
    }
}

// MARK: - Mock Image Processing

final class MockImageProcessing: ImageProcessing {
    var applyEditsCalls = 0
    var generatePreviewCalls = 0

    func applyEdits(to image: UIImage, editState: EditState) -> UIImage? {
        applyEditsCalls += 1
        return image
    }

    func generatePreview(from image: UIImage, editState: EditState, maxDimension: CGFloat) -> UIImage? {
        generatePreviewCalls += 1
        return image
    }

    func applyAdjustmentsOnly(to image: UIImage, adjustments: ImageAdjustments) -> UIImage? {
        return image
    }
}

// MARK: - Mock Navigation Router

final class MockNavigationRouter: NavigationRouting {
    var selectedTab: MainTab = .home
    var isTabBarVisible: Bool = true
    var activeSheet: NavigationRouter.SheetType?
    var captureFlowActive: Bool = false
    var libraryFilter: LibraryFilter = LibraryFilter()

    var navigateToHomeCalls = 0
    var navigateToCaptureCalls: [(procedure: String?, stage: String?)] = []
    var navigateToLibraryCalls = 0
    var navigateToPortfolioCalls: [String] = []
    var presentSheetCalls: [NavigationRouter.SheetType] = []

    func navigateToHome() {
        navigateToHomeCalls += 1
        selectedTab = .home
    }

    func navigateToCapture(procedure: String?, stage: String?, angle: String?, toothNumber: Int?, forPortfolioId: String?) {
        navigateToCaptureCalls.append((procedure, stage))
        selectedTab = .capture
        captureFlowActive = true
    }

    func navigateToLibrary(filter: LibraryFilter?) {
        navigateToLibraryCalls += 1
        if let filter = filter { libraryFilter = filter }
        selectedTab = .library
    }

    func navigateToPortfolio(id: String) {
        navigateToPortfolioCalls.append(id)
    }

    func presentSheet(_ sheet: NavigationRouter.SheetType) {
        presentSheetCalls.append(sheet)
        activeSheet = sheet
    }

    func dismissSheet() { activeSheet = nil }
    func showTabBar() { isTabBarVisible = true }
    func hideTabBar() { isTabBarVisible = false }
    func resetCaptureState() { captureFlowActive = false }

    func resetAll() {
        selectedTab = .home
        resetCaptureState()
        libraryFilter.reset()
        activeSheet = nil
        isTabBarVisible = true
    }
}
