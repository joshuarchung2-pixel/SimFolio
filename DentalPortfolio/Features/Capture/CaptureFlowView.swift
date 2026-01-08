// CaptureFlowView.swift
// Multi-step capture flow (setup, camera, review)
//
// Will contain:
//
// CaptureFlowView:
// A redesigned capture experience with clear flow stages.
//
// Flow Stages:
//
// 1. Setup Stage (optional, can skip):
//    - Pre-select procedure, tooth, stage, angle
//    - Recent selections for quick access
//    - "Skip to Camera" option
//
// 2. Camera Stage:
//    - Full-screen camera preview
//    - Minimal floating controls (flash, grid, ghost)
//    - Exposure/zoom gestures
//    - Focus tap and AE/AF lock
//    - Large capture button
//    - Current tag summary pill (compact)
//
// 3. Review Stage:
//    - Captured image preview
//    - Tag editor (if not pre-selected)
//    - Retake / Use Photo buttons
//    - Success animation on save
//
// Supporting Views:
// - CameraPreviewView: AVCaptureSession preview with gestures
// - CaptureControlsOverlay: Floating camera controls
// - TagQuickSelector: Compact tag selection
// - PhotoReviewView: Post-capture review screen
//
// State:
// - flowStage: SetupStage enum (setup, camera, review)
// - currentMetadata: PhotoMetadata
// - capturedImage: UIImage?
// - Camera settings (exposure, zoom, flash, grid, ghost)
//
// Migration notes:
// - Extract DentalCameraSetupView from gem1 lines 2086-2723
// - Extract CameraPreview from lines 2726-2822
// - Extract PhotoInfoPillView from lines 2981-3657
// - Split into smaller, focused components
// - Reduce 21 @State properties to manageable ViewModel

import SwiftUI
import AVFoundation

// Placeholder - implementation will be refactored from gem1
