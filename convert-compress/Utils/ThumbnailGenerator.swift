import AppKit
import ImageIO

struct ThumbnailGenerator {
    struct Output: Sendable {
        let thumbnail: NSImage?
        let pixelSize: CGSize?
        let fileSizeBytes: Int?
    }

    static func load(for url: URL, maxPixelSize: CGFloat = 256) async -> Output {
        ImageToolsViewModel.ingestionLogger.debug("Loading thumbnail: \(url.lastPathComponent, privacy: .public)")
        
        let standardizedURL = url.standardizedFileURL
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let pixelMax = max(1, Int(maxPixelSize * scale))

        let fileSizeBytes = try? standardizedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize

        if SVGRasterizer.isSVG(standardizedURL) {
            return loadSVG(url: standardizedURL, maxPixelSize: pixelMax, scale: scale, fileSizeBytes: fileSizeBytes)
        }

        var pixelSize: CGSize?
        var thumbnail: NSImage?

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(standardizedURL as CFURL, sourceOptions as CFDictionary) else {
            return Output(thumbnail: nil, pixelSize: nil, fileSizeBytes: fileSizeBytes)
        }

        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let h = props[kCGImagePropertyPixelHeight] as? NSNumber {
            pixelSize = CGSize(width: CGFloat(truncating: w), height: CGFloat(truncating: h))
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelMax,
            kCGImageSourceShouldCacheImmediately: true
        ]

        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            let size = NSSize(width: CGFloat(cgThumb.width) / scale, height: CGFloat(cgThumb.height) / scale)
            thumbnail = NSImage(cgImage: cgThumb, size: size)
        }

        return Output(thumbnail: thumbnail, pixelSize: pixelSize, fileSizeBytes: fileSizeBytes)
    }

    private static func loadSVG(url: URL, maxPixelSize: Int, scale: CGFloat, fileSizeBytes: Int?) -> Output {
        guard let token = SandboxAccessToken(url: url) else {
            return Output(thumbnail: nil, pixelSize: nil, fileSizeBytes: fileSizeBytes)
        }
        defer { token.stop() }

        guard let (thumb, intrinsic) = try? SVGRasterizer.loadThumbnail(for: url, maxPixelSize: maxPixelSize) else {
            return Output(thumbnail: nil, pixelSize: nil, fileSizeBytes: fileSizeBytes)
        }

        return Output(thumbnail: thumb, pixelSize: intrinsic, fileSizeBytes: fileSizeBytes)
    }
}