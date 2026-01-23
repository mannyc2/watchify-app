//
//  ImageService.swift
//  watchify
//

import Foundation
import Nuke

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

    enum DisplaySize {
        case productCard        // 120pt
        case thumbnailCompact   // 64pt
        case thumbnailExpanded  // 80pt
        case storePreview       // ~100pt
        case fullSize           // No resize

        var width: CGFloat? {
            switch self {
            case .productCard: 120
            case .thumbnailCompact: 64
            case .thumbnailExpanded: 80
            case .storePreview: 100
            case .fullSize: nil
            }
        }
    }

    static func processors(for size: DisplaySize, scale: CGFloat = 2.0) -> [any ImageProcessing] {
        guard let width = size.width else { return [] }
        let targetSize = CGSize(width: width * scale, height: width * scale)
        return [ImageProcessors.Resize(size: targetSize, contentMode: .aspectFill)]
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
