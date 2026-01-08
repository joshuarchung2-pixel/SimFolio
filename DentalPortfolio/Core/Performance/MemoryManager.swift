// MemoryManager.swift
// Dental Portfolio - Memory Management
//
// Provides memory monitoring and management utilities
// for handling low memory situations gracefully.
//
// Features:
// - Memory warning detection and handling
// - Cache cleanup on memory pressure
// - Memory usage monitoring
// - View modifiers for memory-aware components

import SwiftUI
import Combine

// MARK: - Memory Manager

/// Manages app memory and responds to memory warnings
class MemoryManager: ObservableObject {
    /// Shared singleton instance
    static let shared = MemoryManager()

    // MARK: - Published Properties

    /// Whether a memory warning was recently received
    @Published var memoryWarningReceived: Bool = false

    /// Current memory pressure level
    @Published var memoryPressure: MemoryPressure = .normal

    // MARK: - Memory Pressure Levels

    enum MemoryPressure {
        case normal
        case warning
        case critical

        var description: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupMemoryWarningObserver()
        setupTerminationObserver()
    }

    // MARK: - Observer Setup

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }

    private func setupTerminationObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleTermination()
            }
            .store(in: &cancellables)
    }

    // MARK: - Memory Warning Handling

    private func handleMemoryWarning() {
        memoryWarningReceived = true
        memoryPressure = .warning

        // Clear image cache
        Task {
            await ImageCache.shared.clearCache()
        }

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Notify observers
        NotificationCenter.default.post(
            name: .memoryWarningReceived,
            object: nil
        )

        print("Memory warning handled - caches cleared")

        // Reset flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.memoryWarningReceived = false
            self?.memoryPressure = .normal
        }
    }

    private func handleTermination() {
        // Clean up before app terminates
        Task {
            await ImageCache.shared.clearCache()
        }
    }

    // MARK: - Manual Cache Clearing

    /// Manually trigger cache cleanup
    func clearAllCaches() {
        Task {
            await ImageCache.shared.clearCache()
        }
        URLCache.shared.removeAllCachedResponses()

        print("All caches manually cleared")
    }

    /// Clear only image caches
    func clearImageCache() {
        Task {
            await ImageCache.shared.clearCache()
        }
    }

    // MARK: - Memory Usage Info

    /// Current memory usage in bytes
    var currentMemoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    /// Formatted memory usage string
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(currentMemoryUsage), countStyle: .memory)
    }

    /// Memory usage in megabytes
    var memoryUsageMB: Double {
        Double(currentMemoryUsage) / (1024 * 1024)
    }

    /// Check if memory usage is high
    var isMemoryUsageHigh: Bool {
        memoryUsageMB > 200 // Over 200 MB
    }

    /// Check if memory usage is critical
    var isMemoryUsageCritical: Bool {
        memoryUsageMB > 400 // Over 400 MB
    }

    // MARK: - Proactive Memory Management

    /// Check memory and clean if needed
    func checkAndCleanIfNeeded() {
        if isMemoryUsageCritical {
            memoryPressure = .critical
            clearAllCaches()
        } else if isMemoryUsageHigh {
            memoryPressure = .warning
            clearImageCache()
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when a memory warning is received
    static let memoryWarningReceived = Notification.Name("memoryWarningReceived")
}

// MARK: - Memory Warning Modifier

/// View modifier that responds to memory warnings
struct MemoryWarningModifier: ViewModifier {
    @ObservedObject var memoryManager = MemoryManager.shared
    let onMemoryWarning: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: memoryManager.memoryWarningReceived) { received in
                if received {
                    onMemoryWarning()
                }
            }
    }
}

extension View {
    /// Perform action when memory warning is received
    /// - Parameter action: Action to perform on memory warning
    func onMemoryWarning(perform action: @escaping () -> Void) -> some View {
        modifier(MemoryWarningModifier(onMemoryWarning: action))
    }
}

// MARK: - Memory Pressure Modifier

/// View modifier that adapts to memory pressure levels
struct MemoryPressureModifier: ViewModifier {
    @ObservedObject var memoryManager = MemoryManager.shared
    let onPressureChange: (MemoryManager.MemoryPressure) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: memoryManager.memoryPressure) { pressure in
                onPressureChange(pressure)
            }
    }
}

extension View {
    /// React to memory pressure changes
    /// - Parameter action: Action to perform when pressure changes
    func onMemoryPressureChange(perform action: @escaping (MemoryManager.MemoryPressure) -> Void) -> some View {
        modifier(MemoryPressureModifier(onPressureChange: action))
    }
}

// MARK: - Auto-Cleanup View

/// A view wrapper that automatically cleans up on memory warnings
struct AutoCleanupView<Content: View>: View {
    @ObservedObject private var memoryManager = MemoryManager.shared
    let cleanup: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isVisible: Bool = false

    var body: some View {
        content()
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
                // Clean up when view disappears
                cleanup()
            }
            .onChange(of: memoryManager.memoryWarningReceived) { received in
                if received && !isVisible {
                    // Clean up if not visible during memory warning
                    cleanup()
                }
            }
    }
}

// MARK: - Memory Efficient Image

/// An image view that reduces quality under memory pressure
struct MemoryEfficientImage: View {
    let asset: PHAsset
    let targetSize: CGSize

    @ObservedObject private var memoryManager = MemoryManager.shared

    private var adjustedSize: CGSize {
        switch memoryManager.memoryPressure {
        case .normal:
            return targetSize
        case .warning:
            return CGSize(
                width: targetSize.width * 0.75,
                height: targetSize.height * 0.75
            )
        case .critical:
            return CGSize(
                width: targetSize.width * 0.5,
                height: targetSize.height * 0.5
            )
        }
    }

    var body: some View {
        CachedAsyncImage(
            asset: asset,
            targetSize: adjustedSize
        )
    }
}

// MARK: - Preview Provider

#if DEBUG
struct MemoryManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Memory Manager")
                .font(AppTheme.Typography.title2)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Memory Usage: \(MemoryManager.shared.formattedMemoryUsage)")
                Text("Pressure: \(MemoryManager.shared.memoryPressure.description)")
            }
            .font(AppTheme.Typography.body)

            DPButton("Clear Caches", style: .secondary) {
                MemoryManager.shared.clearAllCaches()
            }
        }
        .padding()
    }
}
#endif
