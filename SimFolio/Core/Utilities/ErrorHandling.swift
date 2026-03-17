// ErrorHandling.swift
// SimFolio - Centralized Error Handling
//
// Provides a unified error handling system for the app.
// Includes error types, error handler, and UI components for displaying errors.

import Foundation
import SwiftUI
import Photos
import Combine

// MARK: - App Error Types

/// All possible errors in the SimFolio app
enum AppError: LocalizedError, Equatable {

    /// Dynamic app name from bundle
    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "SimFolio"
    }
    // Camera errors
    case cameraNotAvailable
    case cameraAccessDenied
    case cameraSessionFailed

    // Photo library errors
    case photoLibraryAccessDenied
    case photoLibraryLimitedAccess
    case photoSaveFailed(String)
    case photoLoadFailed
    case photoNotFound

    // Data errors
    case metadataSaveFailed
    case metadataLoadFailed
    case portfolioNotFound(String)
    case requirementNotFound
    case invalidData(String)
    case dataCorrupted

    // Export errors
    case exportFailed(String)
    case exportCancelled
    case insufficientStorage

    // Permission errors
    case notificationPermissionDenied

    // General errors
    case networkError
    case timeout
    case unknown(String)

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera Not Available"
        case .cameraAccessDenied:
            return "Camera Access Required"
        case .cameraSessionFailed:
            return "Camera Error"
        case .photoLibraryAccessDenied:
            return "Photo Library Access Required"
        case .photoLibraryLimitedAccess:
            return "Limited Photo Access"
        case .photoSaveFailed(let detail):
            return "Failed to Save Photo\(detail.isEmpty ? "" : ": \(detail)")"
        case .photoLoadFailed:
            return "Failed to Load Photo"
        case .photoNotFound:
            return "Photo Not Found"
        case .metadataSaveFailed:
            return "Failed to Save Data"
        case .metadataLoadFailed:
            return "Failed to Load Data"
        case .portfolioNotFound(let name):
            return "Portfolio Not Found\(name.isEmpty ? "" : ": \(name)")"
        case .requirementNotFound:
            return "Requirement Not Found"
        case .invalidData(let detail):
            return "Invalid Data\(detail.isEmpty ? "" : ": \(detail)")"
        case .dataCorrupted:
            return "Data Corrupted"
        case .exportFailed(let detail):
            return "Export Failed\(detail.isEmpty ? "" : ": \(detail)")"
        case .exportCancelled:
            return "Export Cancelled"
        case .insufficientStorage:
            return "Insufficient Storage"
        case .notificationPermissionDenied:
            return "Notifications Disabled"
        case .networkError:
            return "Network Error"
        case .timeout:
            return "Request Timed Out"
        case .unknown(let detail):
            return detail.isEmpty ? "An Error Occurred" : detail
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraNotAvailable:
            return "This feature requires a device with a camera."
        case .cameraAccessDenied:
            return "Go to Settings > \(Self.appName) > Camera to enable access."
        case .cameraSessionFailed:
            return "Please restart the app and try again."
        case .photoLibraryAccessDenied:
            return "Go to Settings > \(Self.appName) > Photos to enable access."
        case .photoLibraryLimitedAccess:
            return "Go to Settings > \(Self.appName) > Photos to allow full access."
        case .photoSaveFailed:
            return "Please check available storage and try again."
        case .photoLoadFailed:
            return "The photo may have been deleted or moved."
        case .photoNotFound:
            return "The photo may have been deleted from your library."
        case .metadataSaveFailed:
            return "Your changes may not be saved. Please try again."
        case .metadataLoadFailed:
            return "Some data could not be loaded. Please restart the app."
        case .portfolioNotFound:
            return "This portfolio may have been deleted."
        case .requirementNotFound:
            return "This requirement may have been removed."
        case .invalidData:
            return "Please check your input and try again."
        case .dataCorrupted:
            return "Some app data may be corrupted. Consider resetting in Settings."
        case .exportFailed:
            return "Please check available storage and try again."
        case .exportCancelled:
            return "The export was cancelled."
        case .insufficientStorage:
            return "Free up space on your device and try again."
        case .notificationPermissionDenied:
            return "Go to Settings > \(Self.appName) > Notifications to enable."
        case .networkError:
            return "Please check your internet connection."
        case .timeout:
            return "The operation took too long. Please try again."
        case .unknown:
            return "If this problem persists, please restart the app."
        }
    }

    var icon: String {
        switch self {
        case .cameraNotAvailable, .cameraAccessDenied, .cameraSessionFailed:
            return "camera.fill"
        case .photoLibraryAccessDenied, .photoLibraryLimitedAccess, .photoSaveFailed, .photoLoadFailed, .photoNotFound:
            return "photo.fill"
        case .metadataSaveFailed, .metadataLoadFailed, .invalidData, .dataCorrupted:
            return "exclamationmark.triangle.fill"
        case .portfolioNotFound, .requirementNotFound:
            return "folder.fill"
        case .exportFailed, .exportCancelled:
            return "square.and.arrow.up"
        case .insufficientStorage:
            return "externaldrive.fill"
        case .notificationPermissionDenied:
            return "bell.slash.fill"
        case .networkError:
            return "wifi.slash"
        case .timeout:
            return "clock.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    /// Whether this error can be resolved by opening Settings
    var canOpenSettings: Bool {
        switch self {
        case .cameraAccessDenied, .photoLibraryAccessDenied, .photoLibraryLimitedAccess, .notificationPermissionDenied:
            return true
        default:
            return false
        }
    }

    /// Whether this error should be logged (vs just displayed)
    var shouldLog: Bool {
        switch self {
        case .exportCancelled:
            return false
        default:
            return true
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Error Handler

/// Central error handler for the app
@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showError: Bool = false

    private init() {}

    /// Handle a generic Error
    func handle(_ error: Error, context: String = "") {
        let appError: AppError

        if let existing = error as? AppError {
            appError = existing
        } else {
            appError = .unknown(error.localizedDescription)
        }

        handle(appError, context: context)
    }

    /// Handle an AppError
    func handle(_ appError: AppError, context: String = "") {
        // Log error
        if appError.shouldLog {
            logError(appError, context: context)
        }

        // Show to user
        currentError = appError
        showError = true
    }

    /// Dismiss the current error
    func dismiss() {
        currentError = nil
        showError = false
    }

    /// Log error (debug builds only)
    private func logError(_ error: AppError, context: String) {
        #if DEBUG
        let contextString = context.isEmpty ? "" : " [\(context)]"
        print("❌ Error\(contextString): \(error.localizedDescription)")
        if let recovery = error.recoverySuggestion {
            print("   Recovery: \(recovery)")
        }
        #endif
    }

    /// Open device settings
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Error Alert Modifier

/// View modifier that displays error alerts
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorDescription ?? "Error",
                isPresented: $errorHandler.showError,
                presenting: errorHandler.currentError
            ) { error in
                Button("OK", role: .cancel) {
                    errorHandler.dismiss()
                }

                if error.canOpenSettings {
                    Button("Open Settings") {
                        errorHandler.openSettings()
                        errorHandler.dismiss()
                    }
                }
            } message: { error in
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                }
            }
    }
}

extension View {
    /// Add centralized error handling to a view
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - App Error Banner View

/// Inline error banner for non-blocking AppError display
struct AppErrorBanner: View {
    let error: AppError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .foregroundStyle(.white)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Result Extensions

extension Result {
    /// Execute closure on success
    @discardableResult
    func onSuccess(_ handler: (Success) -> Void) -> Result {
        if case .success(let value) = self {
            handler(value)
        }
        return self
    }

    /// Execute closure on failure
    @discardableResult
    func onFailure(_ handler: (Failure) -> Void) -> Result {
        if case .failure(let error) = self {
            handler(error)
        }
        return self
    }

    /// Map failure to AppError
    func mapToAppError(_ transform: (Failure) -> AppError) -> Result<Success, AppError> {
        mapError { transform($0) }
    }
}

// MARK: - Debug Logging Utility

/// Debug-only print function that includes file and line info
/// Use this instead of print() for debug output that should not appear in production
func debugLog(_ message: String, file: String = #file, line: Int = #line) {
    #if DEBUG
    let filename = (file as NSString).lastPathComponent
    print("[\(filename):\(line)] \(message)")
    #endif
}

// MARK: - Error Logging Utility

struct ErrorLogger {
    /// Log a non-fatal error for debugging
    static func log(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        var logMessage = "⚠️ [\(filename):\(line)] \(message)"
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        print(logMessage)
        #endif
    }

    /// Log an informational message
    static func info(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("ℹ️ [\(filename):\(line)] \(message)")
        #endif
    }

    /// Log a success message
    static func success(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("✅ [\(filename):\(line)] \(message)")
        #endif
    }
}

// MARK: - Try/Catch Helpers

/// Execute a throwing closure, returning nil on failure
func tryOrNil<T>(_ operation: () throws -> T) -> T? {
    do {
        return try operation()
    } catch {
        ErrorLogger.log("Operation failed", error: error)
        return nil
    }
}

/// Execute a throwing closure, returning default value on failure
func tryOrDefault<T>(_ defaultValue: T, _ operation: () throws -> T) -> T {
    do {
        return try operation()
    } catch {
        ErrorLogger.log("Operation failed, using default", error: error)
        return defaultValue
    }
}

/// Execute a throwing closure, handling errors with ErrorHandler
func tryWithErrorHandler<T>(
    context: String = "",
    operation: () throws -> T
) -> T? {
    do {
        return try operation()
    } catch {
        Task { @MainActor in
            ErrorHandler.shared.handle(error, context: context)
        }
        return nil
    }
}

/// Execute an async throwing closure, handling errors with ErrorHandler
func tryAsyncWithErrorHandler<T>(
    context: String = "",
    operation: () async throws -> T
) async -> T? {
    do {
        return try await operation()
    } catch {
        await ErrorHandler.shared.handle(error, context: context)
        return nil
    }
}
