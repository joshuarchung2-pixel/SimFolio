// PerformanceMonitor.swift
// Dental Portfolio - Performance Monitoring (Debug Only)
//
// Provides real-time performance monitoring for development
// including FPS, memory usage, and CPU utilization.
//
// Features:
// - Real-time FPS tracking
// - Memory usage monitoring
// - CPU utilization display
// - Overlay view for debugging
// - Performance logging

import SwiftUI

#if DEBUG

// MARK: - Performance Monitor View

/// Overlay view showing real-time performance metrics
struct PerformanceMonitorView: View {
    @StateObject private var monitor = PerformanceMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(fpsColor)
                    .frame(width: 8, height: 8)

                Text("FPS: \(monitor.fps, specifier: "%.0f")")
            }

            Text("Memory: \(monitor.memoryUsage)")

            Text("CPU: \(monitor.cpuUsage, specifier: "%.1f")%")

            if monitor.thermalState != .nominal {
                Text("Thermal: \(monitor.thermalStateDescription)")
                    .foregroundColor(.orange)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .padding(8)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
    }

    private var fpsColor: Color {
        if monitor.fps >= 55 {
            return .green
        } else if monitor.fps >= 30 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Performance Monitor

/// Observable object that tracks performance metrics
class PerformanceMonitor: ObservableObject {
    // MARK: - Published Properties

    @Published var fps: Double = 0
    @Published var memoryUsage: String = "0 MB"
    @Published var cpuUsage: Double = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal

    // MARK: - Private Properties

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var metricsTimer: Timer?

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // FPS tracking via display link
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)

        // Update other metrics periodically
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }

    private func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
    }

    @objc private func updateFPS(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            DispatchQueue.main.async { [weak self] in
                self?.fps = Double(self?.frameCount ?? 0) / elapsed
            }
            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }

    private func updateMetrics() {
        memoryUsage = MemoryManager.shared.formattedMemoryUsage
        cpuUsage = getCPUUsage()
        thermalState = ProcessInfo.processInfo.thermalState
    }

    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else { break }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }

            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadsList)),
                vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride)
            )
        }

        return totalUsageOfCPU
    }

    var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Performance Overlay Modifier

/// Modifier that adds performance overlay to a view
struct PerformanceOverlayModifier: ViewModifier {
    let enabled: Bool
    let position: Alignment

    func body(content: Content) -> some View {
        content
            .overlay(alignment: position) {
                if enabled {
                    PerformanceMonitorView()
                        .padding(8)
                }
            }
    }
}

extension View {
    /// Add performance monitoring overlay
    /// - Parameters:
    ///   - enabled: Whether to show overlay
    ///   - position: Position of overlay
    func performanceOverlay(
        enabled: Bool = true,
        position: Alignment = .topLeading
    ) -> some View {
        modifier(PerformanceOverlayModifier(enabled: enabled, position: position))
    }
}

// MARK: - Performance Logger

/// Logs performance events and timings
class PerformanceLogger {
    static let shared = PerformanceLogger()

    private var timings: [String: CFAbsoluteTime] = [:]
    private let lock = NSLock()

    private init() {}

    /// Start timing an operation
    /// - Parameter name: Name of the operation
    func startTiming(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        timings[name] = CFAbsoluteTimeGetCurrent()
    }

    /// End timing and log result
    /// - Parameter name: Name of the operation
    /// - Returns: Elapsed time in seconds
    @discardableResult
    func endTiming(_ name: String) -> Double {
        lock.lock()
        defer { lock.unlock() }

        guard let startTime = timings[name] else {
            print("⚠️ No start time for: \(name)")
            return 0
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        timings.removeValue(forKey: name)

        let formattedTime: String
        if elapsed < 0.001 {
            formattedTime = String(format: "%.3f ms", elapsed * 1000)
        } else if elapsed < 1.0 {
            formattedTime = String(format: "%.2f ms", elapsed * 1000)
        } else {
            formattedTime = String(format: "%.2f s", elapsed)
        }

        print("⏱ \(name): \(formattedTime)")

        return elapsed
    }

    /// Time an operation
    /// - Parameters:
    ///   - name: Name of the operation
    ///   - operation: Operation to time
    /// - Returns: Result of the operation
    func time<T>(_ name: String, operation: () -> T) -> T {
        startTiming(name)
        let result = operation()
        endTiming(name)
        return result
    }

    /// Time an async operation
    /// - Parameters:
    ///   - name: Name of the operation
    ///   - operation: Async operation to time
    /// - Returns: Result of the operation
    func timeAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        startTiming(name)
        let result = try await operation()
        endTiming(name)
        return result
    }
}

// MARK: - Render Counter

/// Counts view renders for debugging
struct RenderCounter: View {
    let name: String
    @State private var renderCount = 0

    var body: some View {
        let _ = {
            renderCount += 1
            print("🎨 \(name) rendered \(renderCount) times")
        }()

        EmptyView()
    }
}

// MARK: - View Body Logger

/// Logs when view body is computed
struct ViewBodyLogger: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        let _ = print("📐 \(name) body computed")
        return content
    }
}

extension View {
    /// Log when view body is computed
    /// - Parameter name: Name to identify the view
    func logBodyComputation(_ name: String) -> some View {
        modifier(ViewBodyLogger(name: name))
    }
}

// MARK: - Frame Rate Indicator

/// Visual indicator of current frame rate
struct FrameRateIndicator: View {
    @StateObject private var monitor = PerformanceMonitor()

    var body: some View {
        ZStack {
            Circle()
                .fill(indicatorColor)
                .frame(width: 12, height: 12)

            Circle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: 12, height: 12)
        }
        .shadow(radius: 2)
    }

    private var indicatorColor: Color {
        if monitor.fps >= 55 {
            return .green
        } else if monitor.fps >= 45 {
            return .yellow
        } else if monitor.fps >= 30 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview Provider

struct PerformanceMonitor_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            Text("Performance Monitor Preview")
                .font(AppTheme.Typography.title2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .performanceOverlay(enabled: true)
    }
}

#endif
