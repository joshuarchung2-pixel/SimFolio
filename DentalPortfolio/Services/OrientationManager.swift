// OrientationManager.swift
// Device orientation handling
//
// Will contain:
//
// OrientationManager (ObservableObject, singleton):
//
// Published State:
// - deviceOrientation: UIDeviceOrientation (portrait, landscapeLeft, landscapeRight)
// - isLandscape: Bool
//
// Computed Properties:
// - iconRotationAngle: Angle - Rotation for UI elements to stay upright
// - videoRotationAngle: CGFloat - Rotation for AVCaptureConnection
//
// Lifecycle:
// - startMonitoring(): Begin orientation notifications
// - stopMonitoring(): End orientation notifications
//
// Private:
// - orientationDidChange(): Handle orientation change notification
// - Filter out faceUp/faceDown orientations
// - Animate orientation changes
//
// Usage:
// - Camera tab: Rotate controls to match device orientation
// - Photo capture: Set correct orientation metadata
// - UI elements: Keep text readable regardless of orientation
//
// Migration notes:
// - Extract OrientationManager from gem1 lines 69-133
// - Consider using UIWindowScene.orientation for more reliable orientation
// - Add support for iPad multitasking orientations

import SwiftUI
import UIKit

// Placeholder - implementation will be migrated from gem1
