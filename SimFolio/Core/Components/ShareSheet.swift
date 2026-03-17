// PhotoShareSheet.swift
// SimFolio - Photo Share Sheet Component
//
// Loads images from PHAsset IDs and presents a native share sheet.

import SwiftUI
import Photos
import UIKit

// MARK: - Generic Activity Sheet

struct ActivityViewSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Photo Share Sheet

struct PhotoShareSheet: UIViewControllerRepresentable {
    let photoIds: [String]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear

        DispatchQueue.main.async {
            self.loadAndPresent(from: controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private func loadAndPresent(from presenter: UIViewController) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: photoIds, options: nil)
        var images: [UIImage] = []
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat

        fetchResult.enumerateObjects { asset, _, _ in
            manager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                if let image = image {
                    images.append(image)
                }
            }
        }

        guard !images.isEmpty else { return }

        let activityVC = UIActivityViewController(
            activityItems: images,
            applicationActivities: nil
        )

        // iPad popover support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }
}
