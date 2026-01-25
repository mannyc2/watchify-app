//
//  ImageService.swift
//  watchify
//

import AppKit
import Foundation
import Nuke
import Vision

// MARK: - Salient Crop Processor

/// A Nuke processor that crops an image to focus on its salient region.
/// Saliency is computed on-demand via Vision. Nuke caches the final result,
/// so saliency only runs once per unique image.
struct SalientCropProcessor: ImageProcessing, Hashable {
    let targetSize: CGSize

    var identifier: String {
        // Saliency is deterministic for a given image, so we don't need it in the key
        "com.watchify.salient/\(Int(targetSize.width))x\(Int(targetSize.height))"
    }

    func process(_ image: PlatformImage) -> PlatformImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Compute saliency on-demand
        let rect = computeSalientRect(for: cgImage)

        // Calculate salient center in pixel coordinates
        let salientCenterX = (rect.origin.x + rect.width / 2) * imageWidth
        let salientCenterY = (rect.origin.y + rect.height / 2) * imageHeight

        // Determine crop size to match target aspect ratio
        let targetAspect = targetSize.width / targetSize.height

        // Start with the salient rect size and expand to match target aspect ratio
        var cropWidth = rect.width * imageWidth
        var cropHeight = rect.height * imageHeight
        let salientAspect = cropWidth / cropHeight

        if salientAspect > targetAspect {
            // Salient region is wider than target - expand height
            cropHeight = cropWidth / targetAspect
        } else {
            // Salient region is taller than target - expand width
            cropWidth = cropHeight * targetAspect
        }

        // Ensure crop doesn't exceed image bounds (scale down if needed)
        if cropWidth > imageWidth {
            cropWidth = imageWidth
            cropHeight = cropWidth / targetAspect
        }
        if cropHeight > imageHeight {
            cropHeight = imageHeight
            cropWidth = cropHeight * targetAspect
        }

        // Calculate crop origin centered on salient center, clamped to bounds
        let cropX = min(max(salientCenterX - cropWidth / 2, 0), imageWidth - cropWidth)
        let cropY = min(max(salientCenterY - cropHeight / 2, 0), imageHeight - cropHeight)

        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)

        // Crop the image
        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            return image
        }

        // Scale to target size
        let scaledImage = NSImage(size: targetSize)
        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: croppedCG, size: NSSize(width: cropWidth, height: cropHeight))
            .draw(in: NSRect(origin: .zero, size: targetSize))
        scaledImage.unlockFocus()

        return scaledImage
    }

    /// Runs Vision saliency analysis synchronously.
    /// Returns a normalized CGRect (0-1 range) representing the most interesting area.
    private func computeSalientRect(for cgImage: CGImage) -> CGRect {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            if let observation = request.results?.first,
               let salientRect = observation.salientObjects?.first?.boundingBox {
                // Vision returns normalized coordinates (0-1) with origin at bottom-left
                // Convert to top-left origin for CoreGraphics
                return CGRect(
                    x: salientRect.origin.x,
                    y: 1 - salientRect.origin.y - salientRect.height,
                    width: salientRect.width,
                    height: salientRect.height
                )
            }
        } catch {
            // Fall through to center crop
        }

        // Default: center crop (middle 50%)
        return CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    }
}

// MARK: - Image Service

enum ImageService {
    static let defaultCacheSizeMB = 500
    static let cacheSizeKey = "imageCacheSizeLimitMB"

    static let dataCache: DataCache? = {
        let cache = try? DataCache(name: "com.watchify.images")
        let persistedMB = UserDefaults.standard.integer(forKey: cacheSizeKey)
        let sizeMB = persistedMB > 0 ? persistedMB : defaultCacheSizeMB
        cache?.sizeLimit = sizeMB * 1024 * 1024
        return cache
    }()

    static let pipeline: ImagePipeline = {
        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache
        config.isDecompressionEnabled = true
        return ImagePipeline(configuration: config)
    }()

    /// Display sizes for cached images. Each size uses appropriate processing:
    /// - `storePreview`: Vision saliency crop (focuses on interesting region)
    /// - All others: Simple aspect-fill resize
    enum DisplaySize {
        /// 120pt square - ProductCard in store detail view
        case productCard
        /// 64pt square - ActivityRow thumbnails (compact)
        case thumbnailCompact
        /// 80pt square - ActivityRow thumbnails (expanded)
        case thumbnailExpanded
        /// 320x180pt landscape - StoreCard hero image (uses saliency cropping)
        case storePreview
        /// No resize - QuickLook preview
        case fullSize

        var size: CGSize? {
            switch self {
            case .productCard: CGSize(width: 120, height: 120)
            case .thumbnailCompact: CGSize(width: 64, height: 64)
            case .thumbnailExpanded: CGSize(width: 80, height: 80)
            case .storePreview: CGSize(width: 320, height: 180)
            case .fullSize: nil
            }
        }
    }

    static func processors(for size: DisplaySize, scale: CGFloat = 2.0) -> [any ImageProcessing] {
        guard let baseSize = size.size else { return [] }
        let targetSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)

        if size == .storePreview {
            return [SalientCropProcessor(targetSize: targetSize)]
        } else {
            return [ImageProcessors.Resize(size: targetSize, contentMode: .aspectFill)]
        }
    }

    /// Returns a local file URL for the cached image if available, otherwise the original remote URL.
    /// Use this for QuickLook to avoid re-downloading already-cached images.
    static func cachedFileURL(for remoteURL: URL) -> URL {
        let cacheKey = pipeline.cache.makeDataCacheKey(for: ImageRequest(url: remoteURL))
        if let fileURL = dataCache?.url(for: cacheKey) {
            return fileURL
        }
        return remoteURL
    }

    // MARK: - Cache Management

    /// Current cache size in bytes
    static var cacheSize: Int {
        dataCache?.totalSize ?? 0
    }

    /// Number of cached items
    static var cacheCount: Int {
        dataCache?.totalCount ?? 0
    }

    /// Cache size limit in bytes
    static var cacheSizeLimit: Int {
        get { dataCache?.sizeLimit ?? 0 }
        set { dataCache?.sizeLimit = newValue }
    }

    /// Cache size limit in MB (persisted to UserDefaults)
    static var cacheSizeLimitMB: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: cacheSizeKey)
            return stored > 0 ? stored : defaultCacheSizeMB
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cacheSizeKey)
            dataCache?.sizeLimit = newValue * 1024 * 1024
        }
    }

    /// Cache directory URL
    static var cacheURL: URL? {
        dataCache?.path
    }

    /// Clear all cached images
    static func clearCache() {
        dataCache?.removeAll()
    }
}
