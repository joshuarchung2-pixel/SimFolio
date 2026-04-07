// CameraService.swift
// SimFolio - Camera Session and Capture Management
//
// Manages AVCaptureSession for photo capture with focus, exposure, and zoom controls.

import AVFoundation
import UIKit
import SwiftUI
import Combine
import CoreImage
import CoreMedia

// MARK: - CameraService

/// Observable camera service for managing capture session and photo capture
class CameraService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = CameraService()

    // MARK: - Published State

    /// The capture session
    @Published var session = AVCaptureSession()

    /// Most recently captured image
    @Published var capturedImage: UIImage?

    /// Whether the session is ready for capture
    @Published var isSessionReady = false

    /// Current exposure bias value
    @Published var currentExposure: Float = 0.0

    /// Minimum exposure bias
    @Published var minExposure: Float = -2.0

    /// Maximum exposure bias
    @Published var maxExposure: Float = 2.0

    /// Current flash mode
    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    /// Current zoom factor
    @Published var currentZoom: CGFloat = 1.0

    /// Minimum zoom factor
    @Published var minZoom: CGFloat = 1.0

    /// Maximum zoom factor
    @Published var maxZoom: CGFloat = 5.0

    /// Whether camera permission is granted
    @Published var isAuthorized = false

    // MARK: - Focus & Exposure UI State

    /// Current focus point in normalized coordinates (0-1)
    @Published var focusPoint: CGPoint? = nil

    /// Whether AE/AF is locked
    @Published var isAEAFLocked: Bool = false

    /// Whether to show the focus indicator
    @Published var showFocusIndicator: Bool = false

    /// Current exposure compensation value
    @Published var exposureValue: Float = 0.0

    // MARK: - Private Properties

    private var videoInput: AVCaptureDeviceInput?
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var focusIndicatorTimer: Timer?
    private var focusObservation: NSKeyValueObservation?
    private var focusRevertTimer: Timer?

    // MARK: - Orientation Capture Properties

    /// Reference to the orientation manager for capturing device orientation at photo time
    private let orientationManager = OrientationManager.shared

    /// Stores the EXIF orientation captured at the moment of photo capture
    private var pendingCaptureOrientation: CGImagePropertyOrientation = .right

    /// CIContext for rendering orientation-corrected images (reused for performance)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    override init() {
        super.init()
        updatePermissionStatus()
    }

    // MARK: - Permissions

    /// Check camera permission status without requesting
    /// Use this to update UI state based on current permission status
    func updatePermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
        }
        if status == .authorized {
            setupCamera()
        }
    }

    /// Explicitly request camera permission (only call on user action)
    /// - Parameter completion: Optional callback with granted status
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
                completion?(true)
            }
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                    completion?(granted)
                }
            }
        default:
            DispatchQueue.main.async {
                self.isAuthorized = false
                completion?(false)
            }
        }
    }

    /// Legacy method - checks status without requesting
    /// Kept for backward compatibility
    func checkPermissions() {
        updatePermissionStatus()
    }

    // MARK: - Camera Setup

    /// Configure the capture session
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Add video input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                return
            }

            self.currentDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                }
            } catch {
                #if DEBUG
                print("Error setting up camera input: \(error)")
                #endif
                self.session.commitConfiguration()
                return
            }

            // Select optimal device format for highest photo quality
            do {
                try device.lockForConfiguration()
                if let bestFormat = device.formats
                    .filter({ $0.isHighPhotoQualitySupported })
                    .max(by: {
                        CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <
                        CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
                    }) {
                    device.activeFormat = bestFormat
                }
                device.unlockForConfiguration()
            } catch {
                #if DEBUG
                print("Error selecting device format: \(error)")
                #endif
            }

            // Add photo output
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                self.output.isHighResolutionCaptureEnabled = true
                self.output.maxPhotoQualityPrioritization = .quality
            }

            // Enable responsive capture and deferred delivery (iOS 17+)
            if #available(iOS 17.0, *) {
                if self.output.isResponsiveCaptureSupported {
                    self.output.isResponsiveCaptureEnabled = true
                }
                if self.output.isFastCapturePrioritizationSupported {
                    self.output.isFastCapturePrioritizationEnabled = true
                }
                if self.output.isAutoDeferredPhotoDeliverySupported {
                    self.output.isAutoDeferredPhotoDeliveryEnabled = true
                }
            }

            self.session.commitConfiguration()

            // Update zoom limits
            if let device = self.currentDevice {
                DispatchQueue.main.async {
                    self.minZoom = device.minAvailableVideoZoomFactor
                    self.maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0)
                    self.minExposure = device.minExposureTargetBias
                    self.maxExposure = device.maxExposureTargetBias
                }
            }

            // Start session
            self.session.startRunning()

            DispatchQueue.main.async {
                self.isSessionReady = true
            }
        }
    }

    /// Enable continuous auto focus mode
    func enableContinuousAutoFocus() {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            print("Error enabling auto focus: \(error)")
            #endif
        }
    }

    // MARK: - Focus & Exposure

    /// Set focus point with UI feedback (normalized 0-1 coordinates)
    /// - Parameter point: Normalized point (0-1) in the preview
    func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }

        // Cancel any pending revert from a previous tap
        focusRevertTimer?.invalidate()
        focusRevertTimer = nil
        focusObservation?.invalidate()
        focusObservation = nil

        do {
            try device.lockForConfiguration()

            // Set focus point
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            // Set exposure point
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()

            // Observe focus completion to revert to continuous AF
            focusObservation = device.observe(\.isAdjustingFocus, options: [.old, .new]) { [weak self] _, change in
                guard let self = self else { return }
                // Focus achieved: isAdjustingFocus transitioned true → false
                if change.oldValue == true && change.newValue == false {
                    self.focusObservation?.invalidate()
                    self.focusObservation = nil
                    self.scheduleFocusRevert(for: device)
                }
            }

            // Update UI state
            DispatchQueue.main.async {
                self.focusPoint = point
                self.showFocusIndicator = true
                self.isAEAFLocked = false
                // Reset exposure when setting new focus point
                self.exposureValue = 0.0
                self.setExposureCompensation(0.0)

                // Auto-hide focus indicator after 2 seconds
                self.startFocusIndicatorTimer()
            }

        } catch {
            #if DEBUG
            print("Focus error: \(error)")
            #endif
        }
    }

    /// Schedule a revert to continuous auto focus/exposure after a tap-to-focus
    private func scheduleFocusRevert(for device: AVCaptureDevice) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.focusRevertTimer?.invalidate()
            self.focusRevertTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self, !self.isAEAFLocked else { return }
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.unlockForConfiguration()
                } catch {
                    #if DEBUG
                    print("Error reverting to continuous AF: \(error)")
                    #endif
                }
            }
        }
    }

    /// Focus and expose at a specific point (legacy method for compatibility)
    /// - Parameter point: Normalized point (0-1) in the preview
    func focusAndExpose(at point: CGPoint) {
        setFocusPoint(point)
    }

    /// Lock AE/AF at current focus point
    func lockAEAF() {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }

            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }

            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.isAEAFLocked = true
                self.cancelFocusIndicatorTimer()
                // Cancel any pending revert to continuous AF
                self.focusRevertTimer?.invalidate()
                self.focusRevertTimer = nil
                self.focusObservation?.invalidate()
                self.focusObservation = nil
                // Keep focus indicator visible while locked
            }

        } catch {
            #if DEBUG
            print("AE/AF Lock error: \(error)")
            #endif
        }
    }

    /// Lock AE/AF at a specific point (legacy method)
    /// - Parameter point: Normalized point (0-1) in the preview
    func lockAEAF(at point: CGPoint) {
        setFocusPoint(point)
        // Small delay to allow focus to settle before locking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lockAEAF()
        }
    }

    /// Unlock AE/AF and return to continuous auto focus/exposure
    func unlockAEAF() {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.isAEAFLocked = false
            }

        } catch {
            #if DEBUG
            print("AE/AF Unlock error: \(error)")
            #endif
        }
    }

    /// Set exposure compensation value
    /// - Parameter value: Exposure value (-2.0 to 2.0 typically)
    func setExposureCompensation(_ value: Float) {
        guard let device = currentDevice else { return }

        // Clamp value to device limits
        let clampedValue = max(minExposure, min(maxExposure, value))

        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clampedValue, completionHandler: nil)
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.exposureValue = clampedValue
                self.currentExposure = clampedValue
            }

        } catch {
            #if DEBUG
            print("Exposure error: \(error)")
            #endif
        }
    }

    /// Adjust exposure bias by delta
    /// - Parameter delta: Change in exposure value
    func adjustExposure(delta: Float) {
        let newExposure = exposureValue + delta
        setExposureCompensation(newExposure)
    }

    /// Reset exposure to default (0)
    func resetExposure() {
        setExposureCompensation(0.0)
    }

    /// Hide focus indicator and clear focus point
    func hideFocusIndicator() {
        DispatchQueue.main.async {
            self.showFocusIndicator = false
            self.focusPoint = nil
        }
    }

    // MARK: - Focus Indicator Timer

    /// Start timer to auto-hide focus indicator
    private func startFocusIndicatorTimer() {
        cancelFocusIndicatorTimer()

        focusIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.isAEAFLocked == false else { return }
                self?.showFocusIndicator = false
                self?.focusPoint = nil
            }
        }
    }

    /// Cancel the focus indicator timer
    private func cancelFocusIndicatorTimer() {
        focusIndicatorTimer?.invalidate()
        focusIndicatorTimer = nil
    }

    // MARK: - Zoom

    /// Set the zoom factor
    /// - Parameter factor: Desired zoom factor
    func setZoom(factor: CGFloat) {
        guard let device = currentDevice else { return }

        let clampedFactor = max(minZoom, min(maxZoom, factor))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.currentZoom = clampedFactor
            }
        } catch {
            #if DEBUG
            print("Error setting zoom: \(error)")
            #endif
        }
    }

    // MARK: - Capture

    /// Capture a photo with current settings
    func takePhoto() {
        // Capture orientation at the moment of photo capture
        // This must be done before the async capture starts
        pendingCaptureOrientation = orientationManager.exifOrientation

        let settings = AVCapturePhotoSettings()

        // Prioritize quality for best ISP processing (Deep Fusion / Photonic Engine)
        settings.photoQualityPrioritization = .quality

        // Configure flash
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }

        output.capturePhoto(with: settings, delegate: self)
    }

    /// Clear the captured image for retake
    func retake() {
        capturedImage = nil
    }

    // MARK: - Camera Switching

    /// Toggle between front and back camera
    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.videoInput else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)

            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back

            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                self.session.addInput(currentInput)
                self.session.commitConfiguration()
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoInput = newInput
                    self.currentDevice = newDevice

                    // Update zoom limits for new device
                    DispatchQueue.main.async {
                        self.minZoom = newDevice.minAvailableVideoZoomFactor
                        self.maxZoom = min(newDevice.maxAvailableVideoZoomFactor, 10.0)
                        self.currentZoom = 1.0
                    }
                } else {
                    self.session.addInput(currentInput)
                }
            } catch {
                self.session.addInput(currentInput)
            }

            self.session.commitConfiguration()
        }
    }

    // MARK: - Session Control

    /// Start the capture session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // If session has no inputs, set up the camera first
            if self.session.inputs.isEmpty {
                // Configure session on this queue
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                // Add video input
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    self.session.commitConfiguration()
                    return
                }

                self.currentDevice = device

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoInput = input
                    }
                } catch {
                    #if DEBUG
                    print("Error setting up camera input: \(error)")
                    #endif
                    self.session.commitConfiguration()
                    return
                }

                // Select optimal device format for highest photo quality
                do {
                    try device.lockForConfiguration()
                    if let bestFormat = device.formats
                        .filter({ $0.isHighPhotoQualitySupported })
                        .max(by: {
                            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <
                            CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
                        }) {
                        device.activeFormat = bestFormat
                    }
                    device.unlockForConfiguration()
                } catch {
                    #if DEBUG
                    print("Error selecting device format: \(error)")
                    #endif
                }

                // Add photo output if not already added
                if !self.session.outputs.contains(self.output) {
                    if self.session.canAddOutput(self.output) {
                        self.session.addOutput(self.output)
                        self.output.isHighResolutionCaptureEnabled = true
                        self.output.maxPhotoQualityPrioritization = .quality
                    }
                }

                // Enable responsive capture and deferred delivery (iOS 17+)
                if #available(iOS 17.0, *) {
                    if self.output.isResponsiveCaptureSupported {
                        self.output.isResponsiveCaptureEnabled = true
                    }
                    if self.output.isFastCapturePrioritizationSupported {
                        self.output.isFastCapturePrioritizationEnabled = true
                    }
                    if self.output.isAutoDeferredPhotoDeliverySupported {
                        self.output.isAutoDeferredPhotoDeliveryEnabled = true
                    }
                }

                self.session.commitConfiguration()

                // Update zoom limits
                DispatchQueue.main.async {
                    self.minZoom = device.minAvailableVideoZoomFactor
                    self.maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0)
                    self.minExposure = device.minExposureTargetBias
                    self.maxExposure = device.maxExposureTargetBias
                }
            }

            // Start the session if not already running
            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isSessionReady = true
            }
        }
    }

    /// Stop the capture session
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            #if DEBUG
            print("Error capturing photo: \(error)")
            #endif
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            #if DEBUG
            print("Failed to get photo data representation")
            #endif
            return
        }

        // Apply orientation via metadata instead of CIImage pixel rotation
        // This preserves the full ISP-processed image quality
        let uiOrientation = UIImage.Orientation(pendingCaptureOrientation)
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            #if DEBUG
            print("Failed to create CGImage from photo data")
            #endif
            return
        }
        let finalImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: uiOrientation)

        DispatchQueue.main.async {
            self.capturedImage = finalImage
        }
    }
}

// MARK: - Camera Preview

/// Custom UIView that properly handles preview layer layout
class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update preview layer frame whenever bounds change
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }

    func setupPreviewLayer(for session: AVCaptureSession) {
        // Remove existing preview layer if any
        previewLayer?.removeFromSuperlayer()

        // Create new preview layer
        let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        newPreviewLayer.videoGravity = .resizeAspectFill
        newPreviewLayer.frame = bounds
        layer.insertSublayer(newPreviewLayer, at: 0)
        previewLayer = newPreviewLayer
    }
}

/// UIViewRepresentable for displaying the camera preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.setupPreviewLayer(for: session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Update the session if it changed
        if uiView.previewLayer?.session !== session {
            uiView.setupPreviewLayer(for: session)
        }

        // Ensure frame is updated
        DispatchQueue.main.async {
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
        }
    }
}

// MARK: - CGImagePropertyOrientation → UIImage.Orientation

extension UIImage.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}
