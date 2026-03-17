// MockServices.swift
// SimFolioTests - Mock Service Classes
//
// Provides mock implementations of app services for unit testing.
// These mocks track method calls and allow controlled test scenarios.

import Foundation
import Photos
import SwiftUI
@testable import SimFolio

// MARK: - Mock Metadata Manager

class MockMetadataManager: ObservableObject {
    // MARK: - Published State

    @Published var photoMetadata: [String: PhotoMetadata] = [:]
    @Published var portfolios: [Portfolio] = []
    @Published var procedureConfigs: [ProcedureConfig] = []
    @Published var procedures: [String] = []
    @Published var toothHistory: [String: [ToothEntry]] = [:]

    // MARK: - Call Tracking

    var saveMetadataCalled = false
    var savePortfoliosCalled = false
    var loadProceduresCalled = false
    var resetToDefaultsCalled = false
    var lastSavedMetadata: PhotoMetadata?
    var lastSavedPortfolio: Portfolio?

    // MARK: - Metadata Methods

    func saveMetadata(_ metadata: PhotoMetadata, for assetId: String) {
        photoMetadata[assetId] = metadata
        lastSavedMetadata = metadata
        saveMetadataCalled = true
    }

    func getMetadata(for assetId: String) -> PhotoMetadata? {
        photoMetadata[assetId]
    }

    func deleteMetadata(for assetId: String) {
        photoMetadata.removeValue(forKey: assetId)
    }

    func getRating(for assetId: String) -> Int? {
        photoMetadata[assetId]?.rating
    }

    func setRating(_ rating: Int?, for assetId: String) {
        if var metadata = photoMetadata[assetId] {
            metadata.rating = rating
            photoMetadata[assetId] = metadata
        } else {
            var metadata = PhotoMetadata()
            metadata.rating = rating
            photoMetadata[assetId] = metadata
        }
    }

    func photoCount(for procedure: String) -> Int {
        photoMetadata.values.filter { $0.procedure == procedure }.count
    }

    func getMatchingPhotoCount(procedure: String, stage: String, angle: String) -> Int {
        photoMetadata.values.filter { metadata in
            metadata.procedure == procedure &&
            metadata.stage == stage &&
            metadata.angle == angle
        }.count
    }

    // MARK: - Portfolio Methods

    func addPortfolio(_ portfolio: Portfolio) {
        portfolios.append(portfolio)
        lastSavedPortfolio = portfolio
        savePortfoliosCalled = true
    }

    func updatePortfolio(_ portfolio: Portfolio) {
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
        }
    }

    func deletePortfolio(_ portfolioId: String) {
        portfolios.removeAll { $0.id == portfolioId }
    }

    func getPortfolio(by portfolioId: String) -> Portfolio? {
        portfolios.first { $0.id == portfolioId }
    }

    func getPortfolioStats(_ portfolio: Portfolio) -> (fulfilled: Int, total: Int) {
        var totalRequired = 0
        var fulfilledCount = 0

        for requirement in portfolio.requirements {
            let requiredForThis = requirement.totalRequired
            totalRequired += requiredForThis

            for stage in requirement.stages {
                for angle in requirement.angles {
                    let count = requirement.angleCounts[angle] ?? 1
                    let matchingPhotos = getMatchingPhotoCount(
                        procedure: requirement.procedure,
                        stage: stage,
                        angle: angle
                    )
                    fulfilledCount += min(matchingPhotos, count)
                }
            }
        }

        return (fulfilled: fulfilledCount, total: totalRequired)
    }

    func getPortfolioCompletionPercentage(_ portfolio: Portfolio) -> Double {
        let stats = getPortfolioStats(portfolio)
        guard stats.total > 0 else { return 0.0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    // MARK: - Procedure Methods

    func loadProcedures() {
        loadProceduresCalled = true
        if procedureConfigs.isEmpty {
            procedureConfigs = ProcedureConfig.defaultProcedures
        }
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    func addProcedure(_ procedure: ProcedureConfig) {
        var newProcedure = procedure
        newProcedure.sortOrder = (procedureConfigs.map { $0.sortOrder }.max() ?? -1) + 1
        procedureConfigs.append(newProcedure)
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    func updateProcedure(_ procedure: ProcedureConfig) {
        if let index = procedureConfigs.firstIndex(where: { $0.id == procedure.id }) {
            procedureConfigs[index] = procedure
            procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
        }
    }

    func deleteProcedure(_ procedureId: String) {
        procedureConfigs.removeAll { $0.id == procedureId }
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    func resetToDefaults() {
        resetToDefaultsCalled = true
        procedureConfigs = ProcedureConfig.defaultProcedures
        procedures = procedureConfigs.filter { $0.isEnabled }.map { $0.name }
    }

    func getEnabledProcedures() -> [ProcedureConfig] {
        procedureConfigs.filter { $0.isEnabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func getEnabledProcedureNames() -> [String] {
        getEnabledProcedures().map { $0.name }
    }

    func procedureColor(for procedureName: String) -> Color {
        if let config = procedureConfigs.first(where: { $0.name.lowercased() == procedureName.lowercased() }) {
            return config.color
        }
        return .blue
    }

    // MARK: - Reset

    func reset() {
        photoMetadata = [:]
        portfolios = []
        procedureConfigs = []
        procedures = []
        toothHistory = [:]
        saveMetadataCalled = false
        savePortfoliosCalled = false
        loadProceduresCalled = false
        resetToDefaultsCalled = false
        lastSavedMetadata = nil
        lastSavedPortfolio = nil
    }
}

// MARK: - Mock Navigation Router

class MockNavigationRouter: ObservableObject {
    // MARK: - Published State

    @Published var selectedTab: MainTab = .home
    @Published var isTabBarVisible: Bool = true
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var captureFlowActive: Bool = false
    @Published var capturePrefilledProcedure: String?
    @Published var capturePrefilledStage: String?
    @Published var capturePrefilledAngle: String?
    @Published var capturePrefilledToothNumber: Int?
    @Published var captureFromPortfolioId: String?
    @Published var libraryFilter: LibraryFilter = LibraryFilter()
    @Published var selectedPortfolioId: String?
    @Published var activeSheet: NavigationRouter.SheetType?

    // MARK: - Call Tracking

    var navigateToCaptureCallCount = 0
    var navigateToPortfolioCallCount = 0
    var navigateToLibraryCallCount = 0
    var showAlertCallCount = 0
    var previousTab: MainTab = .home

    // MARK: - Navigation Methods

    func navigateToHome() {
        previousTab = selectedTab
        selectedTab = .home
    }

    func navigateToCapture(
        procedure: String? = nil,
        stage: String? = nil,
        angle: String? = nil,
        toothNumber: Int? = nil,
        forPortfolioId: String? = nil
    ) {
        capturePrefilledProcedure = procedure
        capturePrefilledStage = stage
        capturePrefilledAngle = angle
        capturePrefilledToothNumber = toothNumber
        captureFromPortfolioId = forPortfolioId
        previousTab = selectedTab
        selectedTab = .capture
        captureFlowActive = true
        navigateToCaptureCallCount += 1
    }

    func navigateToLibrary(filter: LibraryFilter? = nil) {
        if let filter = filter {
            libraryFilter = filter
        }
        previousTab = selectedTab
        selectedTab = .library
        navigateToLibraryCallCount += 1
    }

    func navigateToPortfolio(id: String) {
        selectedPortfolioId = id
        activeSheet = .portfolioDetail(id: id)
        navigateToPortfolioCallCount += 1
    }

    func navigateToPhotoDetail(id: String) {
        activeSheet = .photoDetail(id: id)
    }

    func switchTab(to tab: MainTab) {
        previousTab = selectedTab
        selectedTab = tab
    }

    func goBack() {
        selectedTab = previousTab
    }

    func resetCaptureState() {
        captureFlowActive = false
        capturePrefilledProcedure = nil
        capturePrefilledStage = nil
        capturePrefilledAngle = nil
        capturePrefilledToothNumber = nil
        captureFromPortfolioId = nil
    }

    func clearCapturePresets() {
        resetCaptureState()
    }

    func presentSheet(_ sheet: NavigationRouter.SheetType) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func showTabBar() {
        isTabBarVisible = true
    }

    func hideTabBar() {
        isTabBarVisible = false
    }

    func setTabBarVisible(_ visible: Bool) {
        isTabBarVisible = visible
    }

    func showAlertDialog(
        title: String,
        message: String,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        alertTitle = title
        alertMessage = message
        showAlert = true
        showAlertCallCount += 1
    }

    func dismissAlert() {
        showAlert = false
        alertTitle = ""
        alertMessage = ""
    }

    func resetAll() {
        selectedTab = .home
        resetCaptureState()
        libraryFilter.reset()
        selectedPortfolioId = nil
        activeSheet = nil
        isTabBarVisible = true
        dismissAlert()
    }

    // MARK: - Reset for Testing

    func reset() {
        selectedTab = .home
        previousTab = .home
        isTabBarVisible = true
        showAlert = false
        alertTitle = ""
        alertMessage = ""
        captureFlowActive = false
        capturePrefilledProcedure = nil
        capturePrefilledStage = nil
        capturePrefilledAngle = nil
        capturePrefilledToothNumber = nil
        captureFromPortfolioId = nil
        libraryFilter = LibraryFilter()
        selectedPortfolioId = nil
        activeSheet = nil
        navigateToCaptureCallCount = 0
        navigateToPortfolioCallCount = 0
        navigateToLibraryCallCount = 0
        showAlertCallCount = 0
    }
}

// MARK: - Mock Camera Service

class MockCameraService: ObservableObject {
    // MARK: - Published State

    @Published var isSessionRunning = false
    @Published var capturedImage: UIImage?
    @Published var flashMode: Int = 0 // 0 = auto, 1 = on, 2 = off
    @Published var isAuthorized = true
    @Published var error: Error?

    // MARK: - Call Tracking

    var startSessionCallCount = 0
    var stopSessionCallCount = 0
    var capturePhotoCallCount = 0
    var switchCameraCallCount = 0
    var setFlashModeCallCount = 0

    // MARK: - Methods

    func startSession() {
        if isAuthorized {
            isSessionRunning = true
        }
        startSessionCallCount += 1
    }

    func stopSession() {
        isSessionRunning = false
        stopSessionCallCount += 1
    }

    func capturePhoto() -> UIImage? {
        capturePhotoCallCount += 1
        capturedImage = TestUtilities.generateTestImage()
        return capturedImage
    }

    func switchCamera() {
        switchCameraCallCount += 1
    }

    func setFlashMode(_ mode: Int) {
        flashMode = mode
        setFlashModeCallCount += 1
    }

    func requestAuthorization() async -> Bool {
        return isAuthorized
    }

    // MARK: - Reset

    func reset() {
        isSessionRunning = false
        capturedImage = nil
        flashMode = 0
        isAuthorized = true
        error = nil
        startSessionCallCount = 0
        stopSessionCallCount = 0
        capturePhotoCallCount = 0
        switchCameraCallCount = 0
        setFlashModeCallCount = 0
    }
}

// MARK: - Mock Photo Library Manager

class MockPhotoLibraryManager: ObservableObject {
    // MARK: - Published State

    @Published var authorizationStatus: PHAuthorizationStatus = .authorized
    @Published var assetCount: Int = 0

    // MARK: - Call Tracking

    var fetchAssetsCallCount = 0
    var requestAuthorizationCallCount = 0
    var saveImageCallCount = 0
    var deleteAssetsCallCount = 0

    // MARK: - Mock Data

    var mockAssetIds: [String] = []

    // MARK: - Methods

    func requestAuthorization() async -> PHAuthorizationStatus {
        requestAuthorizationCallCount += 1
        return authorizationStatus
    }

    func fetchAssets() async -> [String] {
        fetchAssetsCallCount += 1
        return mockAssetIds
    }

    func saveImage(_ image: UIImage) async -> String? {
        saveImageCallCount += 1
        let newId = UUID().uuidString
        mockAssetIds.append(newId)
        assetCount = mockAssetIds.count
        return newId
    }

    func deleteAssets(_ assetIds: [String]) async -> Bool {
        deleteAssetsCallCount += 1
        mockAssetIds.removeAll { assetIds.contains($0) }
        assetCount = mockAssetIds.count
        return true
    }

    // MARK: - Reset

    func reset() {
        authorizationStatus = .authorized
        assetCount = 0
        fetchAssetsCallCount = 0
        requestAuthorizationCallCount = 0
        saveImageCallCount = 0
        deleteAssetsCallCount = 0
        mockAssetIds = []
    }

    // MARK: - Test Helpers

    func addMockAssets(count: Int) {
        for _ in 0..<count {
            mockAssetIds.append(UUID().uuidString)
        }
        assetCount = mockAssetIds.count
    }
}

// MARK: - Mock Notification Manager

class MockNotificationManager: ObservableObject {
    // MARK: - Published State

    @Published var isAuthorized = false
    @Published var pendingNotifications: [String] = []

    // MARK: - Call Tracking

    var requestAuthorizationCallCount = 0
    var scheduleNotificationCallCount = 0
    var cancelNotificationCallCount = 0
    var cancelAllNotificationsCallCount = 0

    // MARK: - Methods

    func requestAuthorization() async -> Bool {
        requestAuthorizationCallCount += 1
        return isAuthorized
    }

    func scheduleNotification(identifier: String, title: String, body: String, date: Date) {
        scheduleNotificationCallCount += 1
        pendingNotifications.append(identifier)
    }

    func cancelNotification(identifier: String) {
        cancelNotificationCallCount += 1
        pendingNotifications.removeAll { $0 == identifier }
    }

    func cancelAllNotifications() {
        cancelAllNotificationsCallCount += 1
        pendingNotifications.removeAll()
    }

    // MARK: - Reset

    func reset() {
        isAuthorized = false
        pendingNotifications = []
        requestAuthorizationCallCount = 0
        scheduleNotificationCallCount = 0
        cancelNotificationCallCount = 0
        cancelAllNotificationsCallCount = 0
    }
}
