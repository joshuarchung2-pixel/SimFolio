// CaptureFlowView.swift
// Dental Portfolio - Multi-step Capture Flow
//
// A redesigned capture experience with clear flow stages:
// 1. Setup Stage: Pre-select procedure, tooth, stage, angle
// 2. Camera Stage: Full-screen camera with minimal controls
// 3. Review Stage: Review captured photos with ratings
//
// Key features:
// - Tag BEFORE shooting (optionally)
// - Batch capture multiple photos with same tags
// - Review all photos before saving
// - Cleaner camera UI with fewer visible controls

import SwiftUI
import AVFoundation
import Photos

// MARK: - Capture Flow State

/// Observable state manager for the capture flow
/// Tracks current step, tag selections, and captured photos
class CaptureFlowState: ObservableObject {

    // MARK: - Flow Steps

    enum Step: Equatable {
        case setup      // Pre-capture tagging
        case camera     // Active camera
        case review     // Review captured photos
    }

    @Published var currentStep: Step = .setup

    // MARK: - Tag Selections

    @Published var selectedProcedure: String?
    @Published var selectedToothNumber: Int?
    @Published var selectedToothDate: Date = Date()
    @Published var selectedStage: String?
    @Published var selectedAngle: String?

    // MARK: - Captured Photos

    /// Photos captured in this session
    @Published var capturedPhotos: [CapturedPhoto] = []

    // MARK: - Context State

    /// Whether we came from a specific requirement (pre-filled tags)
    @Published var isFromRequirement: Bool = false

    /// Source portfolio ID if navigating from a requirement
    @Published var sourcePortfolioId: String?

    // MARK: - Computed Properties

    /// Returns true if any tag is selected
    var hasAnyTags: Bool {
        selectedProcedure != nil
    }

    /// Returns true if all required tags are selected
    var hasAllTags: Bool {
        selectedProcedure != nil &&
        selectedToothNumber != nil &&
        selectedStage != nil &&
        selectedAngle != nil
    }

    /// Human-readable summary of selected tags
    var tagSummary: String {
        var parts: [String] = []
        if let p = selectedProcedure { parts.append(p) }
        if let t = selectedToothNumber { parts.append("#\(t)") }
        if let s = selectedStage { parts.append(s == "Preparation" ? "Prep" : "Resto") }
        if let a = selectedAngle { parts.append(a) }

        if parts.isEmpty {
            return "Tap to add tags"
        }
        return parts.joined(separator: " • ")
    }

    /// Photos marked to keep (not discarded)
    var photosToKeep: [CapturedPhoto] {
        capturedPhotos.filter { $0.shouldKeep }
    }

    // MARK: - Methods

    /// Pre-fill tags from external navigation (e.g., from requirement card)
    /// - Parameters:
    ///   - procedure: Pre-selected procedure type
    ///   - stage: Pre-selected stage
    ///   - angle: Pre-selected angle
    ///   - toothNumber: Pre-selected tooth number
    ///   - portfolioId: Source portfolio ID
    func prefill(procedure: String?, stage: String?, angle: String?, toothNumber: Int?, portfolioId: String?) {
        self.selectedProcedure = procedure
        self.selectedStage = stage
        self.selectedAngle = angle
        self.selectedToothNumber = toothNumber
        self.sourcePortfolioId = portfolioId
        self.isFromRequirement = procedure != nil

        // If tags are pre-filled, skip setup
        if isFromRequirement {
            currentStep = .camera
        }
    }

    /// Transition from setup to camera
    func startCapturing() {
        currentStep = .camera
    }

    /// Add a newly captured photo to the session
    /// - Parameter image: The captured UIImage
    func addPhoto(image: UIImage) {
        let photo = CapturedPhoto(image: image)
        capturedPhotos.append(photo)
        HapticsManager.shared.mediumTap()
    }

    /// Remove a photo at the specified index
    /// - Parameter index: Index of the photo to remove
    func removePhoto(at index: Int) {
        guard capturedPhotos.indices.contains(index) else { return }
        capturedPhotos.remove(at: index)
    }

    /// Toggle whether a photo should be kept
    /// - Parameter id: UUID of the photo
    func togglePhotoKeep(id: UUID) {
        if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
            capturedPhotos[index].shouldKeep.toggle()
        }
    }

    /// Set the rating for a photo
    /// - Parameters:
    ///   - rating: Star rating (0-5)
    ///   - id: UUID of the photo
    func setRating(_ rating: Int, for id: UUID) {
        if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
            capturedPhotos[index].rating = rating
        }
    }

    /// Transition from camera to review
    func finishCapturing() {
        if !capturedPhotos.isEmpty {
            currentStep = .review
        }
    }

    /// Reset all state to initial values
    func reset() {
        currentStep = .setup
        selectedProcedure = nil
        selectedToothNumber = nil
        selectedToothDate = Date()
        selectedStage = nil
        selectedAngle = nil
        capturedPhotos = []
        isFromRequirement = false
        sourcePortfolioId = nil
    }
}

// MARK: - Captured Photo Model

/// Represents a photo captured during this session
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    var rating: Int = 0
    var shouldKeep: Bool = true
    let capturedAt: Date = Date()
}

// MARK: - Capture Flow Container View

/// Main container view for the capture flow
/// Routes between setup, camera, and review stages
struct CaptureFlowView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var captureState = CaptureFlowState()
    @ObservedObject var cameraService: CameraService

    @State private var showCancelConfirmation = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Content based on current step
            Group {
                switch captureState.currentStep {
                case .setup:
                    CaptureSetupView(captureState: captureState)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                case .camera:
                    CameraCaptureView(captureState: captureState, cameraService: cameraService)
                        .transition(.opacity)

                case .review:
                    CaptureReviewView(captureState: captureState)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: captureState.currentStep)
        }
        .onAppear {
            // Apply pre-filled values from router
            captureState.prefill(
                procedure: router.capturePrefilledProcedure,
                stage: router.capturePrefilledStage,
                angle: router.capturePrefilledAngle,
                toothNumber: router.capturePrefilledToothNumber,
                portfolioId: router.captureFromPortfolioId
            )
        }
        .alert("Discard Photos?", isPresented: $showCancelConfirmation) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                captureState.reset()
                router.resetCaptureState()
                router.selectedTab = .home
            }
        } message: {
            Text("You have \(captureState.capturedPhotos.count) unsaved photo(s). Discard them?")
        }
    }

    /// Handle cancel action with confirmation if photos exist
    func handleCancel() {
        if captureState.capturedPhotos.isEmpty {
            captureState.reset()
            router.resetCaptureState()
            router.selectedTab = .home
        } else {
            showCancelConfirmation = true
        }
    }
}

// MARK: - Capture Setup View (Placeholder)

/// Pre-capture tagging screen
/// Allows user to select procedure, tooth number, stage, and angle before capturing
struct CaptureSetupView: View {
    @ObservedObject var captureState: CaptureFlowState

    var body: some View {
        Text("Setup View")
            .foregroundColor(.white)
    }
}

// MARK: - Camera Capture View (Placeholder)

/// Active camera view with minimal controls
/// Supports batch capture with current tag settings
struct CameraCaptureView: View {
    @ObservedObject var captureState: CaptureFlowState
    @ObservedObject var cameraService: CameraService

    var body: some View {
        Text("Camera View")
            .foregroundColor(.white)
    }
}

// MARK: - Capture Review View (Placeholder)

/// Post-capture review screen
/// Shows all captured photos with rating and keep/discard options
struct CaptureReviewView: View {
    @ObservedObject var captureState: CaptureFlowState

    var body: some View {
        Text("Review View")
            .foregroundColor(.white)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CaptureFlowView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureFlowPreviewContainer()
    }
}

struct CaptureFlowPreviewContainer: View {
    @StateObject private var router = NavigationRouter()
    @StateObject private var cameraService = CameraService()

    var body: some View {
        CaptureFlowView(cameraService: cameraService)
            .environmentObject(router)
    }
}
#endif
