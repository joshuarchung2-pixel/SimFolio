// OrientationManager.swift
// Dental Portfolio - Device Orientation Handling
//
// Manages device orientation changes for camera UI and photo metadata.

import SwiftUI
import UIKit

// MARK: - OrientationManager

/// Singleton manager for tracking device orientation
/// Used to rotate camera UI elements and set correct photo orientation
class OrientationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = OrientationManager()

    // MARK: - Published State

    /// Current device orientation
    @Published var deviceOrientation: UIDeviceOrientation = .portrait

    /// Whether the device is in landscape mode
    @Published var isLandscape: Bool = false

    // MARK: - Computed Properties

    /// Rotation angle for UI icons to stay upright
    var iconRotationAngle: Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        case .portraitUpsideDown:
            return .degrees(180)
        default:
            return .degrees(0)
        }
    }

    /// Rotation angle for AVCaptureConnection (in degrees)
    var videoRotationAngle: CGFloat {
        switch deviceOrientation {
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        case .portraitUpsideDown:
            return 270
        default:
            return 90
        }
    }

    // MARK: - Initialization

    private init() {
        // Set initial orientation
        updateOrientation()
    }

    // MARK: - Monitoring

    /// Start monitoring orientation changes
    func startMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        updateOrientation()
    }

    /// Stop monitoring orientation changes
    func stopMonitoring() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()

        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Private Methods

    @objc private func orientationDidChange() {
        updateOrientation()
    }

    private func updateOrientation() {
        let newOrientation = UIDevice.current.orientation

        // Filter out face up/down and unknown orientations
        guard newOrientation != .faceUp,
              newOrientation != .faceDown,
              newOrientation != .unknown else {
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            self.deviceOrientation = newOrientation
            self.isLandscape = newOrientation.isLandscape
        }
    }
}
