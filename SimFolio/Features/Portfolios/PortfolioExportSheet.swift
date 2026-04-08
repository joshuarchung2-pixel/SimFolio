// PortfolioExportSheet.swift
// SimFolio - Portfolio Export Sheet
//
// This sheet allows users to export their portfolio photos in various formats.
// Supports ZIP archive and individual file export.
//
// Features:
// - Export format selection (ZIP, Individual)
// - Organization options (by requirement, by date, flat)
// - Image quality selection
// - Optional metadata in filenames
// - Progress overlay during export
// - Share sheet integration

import SwiftUI
import Photos
import UniformTypeIdentifiers

// MARK: - Export Enums

/// Export format options
enum ExportFormat: String, CaseIterable, Identifiable {
    case zip = "ZIP Archive"
    case individual = "Individual Files"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .zip: return "doc.zipper"
        case .individual: return "photo.stack"
        }
    }

    var description: String {
        switch self {
        case .zip: return "All photos in a single compressed file"
        case .individual: return "Share each photo separately"
        }
    }
}

/// Export organization options
enum ExportOrganization: String, CaseIterable, Identifiable {
    case byRequirement = "By Requirement"
    case byDate = "By Date"
    case flat = "No Organization"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .byRequirement: return "folder"
        case .byDate: return "calendar"
        case .flat: return "square.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .byRequirement: return "Organized in folders by procedure"
        case .byDate: return "Organized in folders by date"
        case .flat: return "All photos in one folder"
        }
    }
}

/// Export quality options
enum ExportQuality: String, CaseIterable, Identifiable {
    case original = "Original"
    case high = "High (2048px)"
    case medium = "Medium (1024px)"
    case low = "Low (512px)"

    var id: String { rawValue }

    var maxDimension: CGFloat? {
        switch self {
        case .original: return nil
        case .high: return 2048
        case .medium: return 1024
        case .low: return 512
        }
    }

    var icon: String {
        switch self {
        case .original: return "photo"
        case .high: return "photo.artframe"
        case .medium: return "photo.artframe"
        case .low: return "photo.artframe"
        }
    }

    var description: String {
        switch self {
        case .original: return "Full resolution, largest file size"
        case .high: return "Great quality, smaller files"
        case .medium: return "Good quality, moderate files"
        case .low: return "Reduced quality, smallest files"
        }
    }
}

// MARK: - PortfolioExportSheet

/// Sheet for exporting portfolio photos
struct PortfolioExportSheet: View {
    let portfolio: Portfolio
    @Binding var isPresented: Bool

    @ObservedObject var metadataManager = MetadataManager.shared
    @ObservedObject var library = PhotoLibraryManager.shared

    // MARK: - Export Options State

    @State private var exportFormat: ExportFormat = .zip
    @State private var organization: ExportOrganization = .byRequirement
    @State private var imageQuality: ExportQuality = .high
    @State private var includeMetadata: Bool = true

    // MARK: - Export Progress State

    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var exportStatusMessage: String = ""
    @State private var exportError: String? = nil
    @State private var exportedURL: URL? = nil
    @State private var showShareSheet: Bool = false

    // MARK: - Computed Properties

    /// All assets matching portfolio requirements
    var matchingAssets: [PHAsset] {
        library.assets.filter { asset in
            guard let metadata = metadataManager.getMetadata(for: asset.localIdentifier) else {
                return false
            }

            for requirement in portfolio.requirements {
                if metadata.procedure == requirement.procedure {
                    return true
                }
            }
            return false
        }
    }

    var photoCount: Int {
        matchingAssets.count
    }

    var stats: (fulfilled: Int, total: Int) {
        metadataManager.getPortfolioStats(portfolio)
    }

    var progress: Double {
        guard stats.total > 0 else { return 0 }
        return Double(stats.fulfilled) / Double(stats.total)
    }

    var canExport: Bool {
        photoCount > 0 && !isExporting
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Summary card
                    summaryCard

                    // Format selection
                    formatSection

                    // Organization (not for individual)
                    if exportFormat != .individual {
                        organizationSection
                    }

                    // Quality selection
                    qualitySection

                    // Include metadata toggle
                    metadataToggle

                    // Export button
                    exportButton

                    Spacer(minLength: 50)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Export Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isExporting)
                }
            }
            .overlay {
                if isExporting {
                    exportingOverlay
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ExportShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Summary Card

    var summaryCard: some View {
        DPCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(portfolio.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("\(photoCount) photo\(photoCount == 1 ? "" : "s") to export")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if photoCount == 0 {
                    Text("No photos match this portfolio's requirements")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.warning)
                }

                DPProgressBar(progress: progress)
                Text("\(Int(progress * 100))%")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Format Section

    var formatSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Export Format")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(ExportFormat.allCases) { format in
                    ExportOptionRow(
                        icon: format.icon,
                        title: format.rawValue,
                        subtitle: format.description,
                        isSelected: exportFormat == format,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                exportFormat = format
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Organization Section

    var organizationSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Organization")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(ExportOrganization.allCases) { org in
                    ExportOptionRow(
                        icon: org.icon,
                        title: org.rawValue,
                        subtitle: org.description,
                        isSelected: organization == org,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                organization = org
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Quality Section

    var qualitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Image Quality")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(ExportQuality.allCases) { quality in
                    ExportOptionRow(
                        icon: quality.icon,
                        title: quality.rawValue,
                        subtitle: quality.description,
                        isSelected: imageQuality == quality,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                imageQuality = quality
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Metadata Toggle

    var metadataToggle: some View {
        DPCard {
            Toggle(isOn: $includeMetadata) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Include Metadata")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("Add procedure, stage, angle info to filenames")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .tint(AppTheme.Colors.primary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Export Button

    var exportButton: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            DPButton(
                "Export \(photoCount) Photo\(photoCount == 1 ? "" : "s")",
                icon: "square.and.arrow.up",
                style: .primary,
                size: .large,
                isFullWidth: true,
                isLoading: isExporting,
                isDisabled: !canExport
            ) {
                startExport()
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if photoCount == 0 {
                Text("Capture photos that match this portfolio's requirements to enable export")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }
        }
    }

    // MARK: - Exporting Overlay

    var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: exportProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: exportProgress)
                }

                Text("\(Int(exportProgress * 100))%")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(exportStatusMessage)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }

    // MARK: - Export Logic

    func startExport() {
        isExporting = true
        exportProgress = 0.0
        exportStatusMessage = "Preparing export..."

        Task {
            do {
                let url = try await performExport()

                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    showShareSheet = true
                    ReviewPromptService.requestIfEligible(for: .firstPortfolioExported)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    func performExport() async throws -> URL {
        switch exportFormat {
        case .zip:
            return try await exportAsZip()
        case .individual:
            return try await exportIndividual()
        }
    }

    func exportAsZip() async throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("PortfolioExport_\(UUID().uuidString)")

        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let total = Double(matchingAssets.count)

        for (index, asset) in matchingAssets.enumerated() {
            let metadata = metadataManager.getMetadata(for: asset.localIdentifier)

            // Determine folder path
            var folderPath = exportDir

            switch organization {
            case .byRequirement:
                if let procedure = metadata?.procedure {
                    folderPath = exportDir.appendingPathComponent(sanitizeFilename(procedure))
                }
            case .byDate:
                if let date = asset.creationDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let dateString = formatter.string(from: date)
                    folderPath = exportDir.appendingPathComponent(dateString)
                }
            case .flat:
                break
            }

            try fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true)

            // Generate filename
            let filename = generateFilename(for: asset, metadata: metadata, index: index)
            let filePath = folderPath.appendingPathComponent(filename)

            // Load and save image
            let image = try await loadImage(from: asset)
            let resizedImage = resizeImage(image, maxDimension: imageQuality.maxDimension)

            if let data = resizedImage.jpegData(compressionQuality: 0.9) {
                try data.write(to: filePath)
            }

            await MainActor.run {
                exportProgress = Double(index + 1) / total * 0.8 // 80% for processing
                exportStatusMessage = "Processing photo \(index + 1) of \(Int(total))..."
            }
        }

        // Create ZIP using file coordinator
        await MainActor.run {
            exportStatusMessage = "Creating ZIP archive..."
        }

        let zipURL = tempDir.appendingPathComponent("\(sanitizeFilename(portfolio.name))_Export.zip")

        // Remove existing zip if present
        try? fileManager.removeItem(at: zipURL)

        // Create zip using NSFileCoordinator
        try createZipArchive(from: exportDir, to: zipURL)

        await MainActor.run {
            exportProgress = 1.0
        }

        // Cleanup export directory
        try? fileManager.removeItem(at: exportDir)

        return zipURL
    }

    func exportIndividual() async throws -> URL {
        // For individual export, create a temporary directory
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("PortfolioExport_\(UUID().uuidString)")

        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let total = Double(matchingAssets.count)

        for (index, asset) in matchingAssets.enumerated() {
            let metadata = metadataManager.getMetadata(for: asset.localIdentifier)
            let filename = generateFilename(for: asset, metadata: metadata, index: index)
            let filePath = exportDir.appendingPathComponent(filename)

            let image = try await loadImage(from: asset)
            let resizedImage = resizeImage(image, maxDimension: imageQuality.maxDimension)

            if let data = resizedImage.jpegData(compressionQuality: 0.9) {
                try data.write(to: filePath)
            }

            await MainActor.run {
                exportProgress = Double(index + 1) / total
                exportStatusMessage = "Processing photo \(index + 1) of \(Int(total))..."
            }
        }

        return exportDir
    }

    // MARK: - Helper Functions

    func loadImage(from asset: PHAsset) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    // Apply any saved edits to the image
                    let editedImage = PhotoEditPersistenceService.shared.applyStoredEdits(
                        to: image,
                        assetId: asset.localIdentifier
                    )
                    continuation.resume(returning: editedImage)
                } else {
                    continuation.resume(throwing: ExportError.failedToLoadImage)
                }
            }
        }
    }

    func resizeImage(_ image: UIImage, maxDimension: CGFloat?) -> UIImage {
        guard let maxDim = maxDimension else { return image }

        let size = image.size
        let maxCurrentDim = max(size.width, size.height)

        if maxCurrentDim <= maxDim {
            return image
        }

        let scale = maxDim / maxCurrentDim
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    func generateFilename(for asset: PHAsset, metadata: PhotoMetadata?, index: Int) -> String {
        var parts: [String] = []

        if includeMetadata, let metadata = metadata {
            if let procedure = metadata.procedure {
                parts.append(sanitizeFilename(procedure))
            }
            if let stage = metadata.stage {
                parts.append(sanitizeFilename(stage))
            }
            if let angle = metadata.angle {
                parts.append(sanitizeFilename(angle))
            }
            if let tooth = metadata.toothNumber {
                parts.append("Tooth\(tooth)")
            }
        }

        // Add date
        if let date = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            parts.append(formatter.string(from: date))
        } else {
            parts.append("Photo\(index + 1)")
        }

        return parts.joined(separator: "_") + ".jpg"
    }

    func sanitizeFilename(_ string: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return string.components(separatedBy: invalidChars).joined(separator: "_")
    }

    func createZipArchive(from sourceURL: URL, to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var copyError: NSError?

        coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &coordinatorError) { tempZipURL in
            do {
                try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
            } catch {
                copyError = error as NSError
            }
        }

        if let error = coordinatorError ?? copyError {
            throw error
        }
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case failedToLoadImage
    case failedToCreateZip

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load one or more images"
        case .failedToCreateZip:
            return "Failed to create ZIP archive"
        }
    }
}

// MARK: - ExportOptionRow

/// Selectable row for export options
struct ExportOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 32)

                // Text
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Colors.primary)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(isSelected ? AppTheme.Colors.primary.opacity(0.08) : AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ExportShareSheet

/// UIActivityViewController wrapper for sharing exported files
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview Provider

#if DEBUG
struct PortfolioExportSheet_Previews: PreviewProvider {
    @State static var isPresented = true

    static var previews: some View {
        PortfolioExportSheet(
            portfolio: Portfolio(
                name: "Restorative Dentistry Final",
                createdDate: Date().addingTimeInterval(-86400 * 7),
                dueDate: Date().addingTimeInterval(86400 * 5),
                requirements: [
                    PortfolioRequirement(
                        procedure: "Class 1",
                        stages: ["Preparation", "Restoration"],
                        angles: ["Occlusal", "Buccal/Facial"]
                    ),
                    PortfolioRequirement(
                        procedure: "Class 2",
                        stages: ["Preparation", "Restoration"],
                        angles: ["Occlusal", "Proximal"]
                    )
                ]
            ),
            isPresented: $isPresented
        )
    }
}

struct ExportOptionRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ExportOptionRow(
                icon: "doc.zipper",
                title: "ZIP Archive",
                subtitle: "All photos in a single compressed file",
                isSelected: true,
                onTap: {}
            )

            ExportOptionRow(
                icon: "photo.stack",
                title: "Individual Files",
                subtitle: "Share each photo separately",
                isSelected: false,
                onTap: {}
            )
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
