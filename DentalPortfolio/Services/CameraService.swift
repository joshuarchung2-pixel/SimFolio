// CameraService.swift
// Dental Portfolio - Camera Session and Capture Management
//
// Manages AVCaptureSession for photo capture with focus, exposure, and zoom controls.

import AVFoundation
import UIKit
import SwiftUI

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

    // MARK: - Private Properties

    private var videoInput: AVCaptureDeviceInput?
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    // MARK: - Initialization

    override init() {
        super.init()
        checkPermissions()
    }

    // MARK: - Permissions

    /// Check and request camera permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
        }
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
                print("Error setting up camera input: \(error)")
                self.session.commitConfiguration()
                return
            }

            // Add photo output
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                self.output.isHighResolutionCaptureEnabled = true
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
            print("Error enabling auto focus: \(error)")
        }
    }

    // MARK: - Focus & Exposure

    /// Focus and expose at a specific point
    /// - Parameter point: Normalized point (0-1) in the preview
    func focusAndExpose(at point: CGPoint) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        } catch {
            print("Error focusing: \(error)")
        }
    }

    /// Lock AE/AF at a specific point
    /// - Parameter point: Normalized point (0-1) in the preview
    func lockAEAF(at point: CGPoint) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .locked
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .locked
            }

            device.unlockForConfiguration()
        } catch {
            print("Error locking AE/AF: \(error)")
        }
    }

    /// Adjust exposure bias
    /// - Parameter delta: Change in exposure value
    func adjustExposure(delta: Float) {
        guard let device = currentDevice else { return }

        let newExposure = max(minExposure, min(maxExposure, currentExposure + delta))

        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(newExposure) { _ in }
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.currentExposure = newExposure
            }
        } catch {
            print("Error adjusting exposure: \(error)")
        }
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
            print("Error setting zoom: \(error)")
        }
    }

    // MARK: - Capture

    /// Capture a photo with current settings
    func takePhoto() {
        let settings = AVCapturePhotoSettings()

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
            self?.session.startRunning()
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
            print("Error capturing photo: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

// MARK: - Camera Preview

/// UIViewRepresentable for displaying the camera preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
