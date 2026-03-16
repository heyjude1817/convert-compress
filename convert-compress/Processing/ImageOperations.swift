import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import UniformTypeIdentifiers
import ImageIO
import Vision

enum ImageOperationError: Error {
    case loadFailed
    case exportFailed
    case backgroundRemovalUnavailable
    case permissionDenied
}

protocol ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage
}

extension [ImageOperation] {
    var containsResizeOperation: Bool {
        contains { $0 is ResizeOperation || $0 is CropOperation || $0 is ConstrainSizeOperation }
    }
}

/// Loads a CIImage from any supported source, including vector formats (SVG, etc.).
/// For vector images, rasterizes at generous size when resize operations are present,
/// otherwise at intrinsic size. For raster images, applies EXIF orientation.
func loadCIImage(from url: URL, operations: [ImageOperation] = []) throws -> CIImage {
    if VectorImageSupport.isVectorImage(url) {
        let intrinsic = try VectorImageSupport.intrinsicSize(for: url)
        let size = operations.containsResizeOperation ? VectorImageSupport.generousSize(for: intrinsic) : intrinsic
        return try VectorImageSupport.loadAsCIImage(from: url, targetSize: size)
    }
    return try loadCIImageApplyingOrientation(from: url)
}

private func loadCIImageApplyingOrientation(from url: URL) throws -> CIImage {
    let options: [CIImageOption: Any] = [
        .applyOrientationProperty: true
    ]
    if let ci = CIImage(contentsOf: url, options: options) { return ci }
    throw ImageOperationError.loadFailed
}

// MARK: - Lanczos Scaling Helper

/// Applies Lanczos scaling with edge clamping to prevent border artifacts.
/// Clamping extends edge pixels infinitely so the filter doesn't sample undefined pixels.
private func lanczosScale(_ input: CIImage, scale: Float, aspectRatio: Float, targetSize: CGSize) throws -> CIImage {
    let lanczos = CIFilter.lanczosScaleTransform()
    lanczos.inputImage = input.clampedToExtent()
    lanczos.scale = scale
    lanczos.aspectRatio = aspectRatio
    guard let scaled = lanczos.outputImage else { throw ImageOperationError.exportFailed }
    return scaled.cropped(to: CGRect(origin: .zero, size: targetSize))
}

// MARK: - Operations

struct ResizeOperation: ImageOperation {
    enum Mode { case percent(Double); case pixels(width: Int?, height: Int?); case longEdge(Int) }
    let mode: Mode
    
    private var resizeInput: ResizeInput {
        switch mode {
        case .percent(let p): .percent(p)
        case .pixels(let w, let h): .pixels(width: w, height: h)
        case .longEdge(let size): .longEdge(size)
        }
    }

    func transformed(_ input: CIImage) throws -> CIImage {
        let original = input.extent.size
        let target = ResizeMath.targetSize(for: original, input: resizeInput, noUpscale: true)
        let scaleX = target.width / original.width
        let scaleY = target.height / original.height
        return try lanczosScale(input, scale: Float(min(scaleX, scaleY)), aspectRatio: Float(scaleX / scaleY), targetSize: target)
    }
}

/// Ensures the image matches the size restrictions of a target format by resizing when necessary.
struct ConstrainSizeOperation: ImageOperation {
    let targetFormat: ImageFormat

    func transformed(_ input: CIImage) throws -> CIImage {
        let caps = ImageIOCapabilities.shared
        let current = input.extent.size
        
        guard caps.sizeRestrictions(forUTType: targetFormat.utType) != nil,
              !caps.isValidPixelSize(current, for: targetFormat.utType),
              let side = caps.suggestedSquareSide(for: targetFormat.utType, source: current) else {
            return input
        }
        
        let target = CGSize(width: side, height: side)
        let scaleX = target.width / current.width
        let scaleY = target.height / current.height
        return try lanczosScale(input, scale: Float(min(scaleX, scaleY)), aspectRatio: Float(scaleX / scaleY), targetSize: target)
    }
}


/// Flips along the vertical axis (horizontal mirror / left-to-right flip)
struct FlipVerticalOperation: ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage {
        let extent = input.extent
        let transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
        return input.transformed(by: transform)
    }
}

struct CropOperation: ImageOperation {
    let targetWidth: Int
    let targetHeight: Int
    
    // Resize to cover target dimensions, then center crop to exact size
    func transformed(_ input: CIImage) throws -> CIImage {
        let current = input.extent.size
        let target = CGSize(width: targetWidth, height: targetHeight)
        
        // Scale to cover (use max to ensure full coverage)
        let scale = max(target.width / current.width, target.height / current.height)
        let scaledSize = CGSize(width: current.width * scale, height: current.height * scale)
        
        // Scale with clamping
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input.clampedToExtent()
        lanczos.scale = Float(scale)
        lanczos.aspectRatio = 1.0
        guard let scaled = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        
        // Center crop to target size
        let cropOrigin = CGPoint(
            x: ((scaledSize.width - target.width) / 2).rounded(.toNearestOrEven),
            y: ((scaledSize.height - target.height) / 2).rounded(.toNearestOrEven)
        )
        let cropRect = CGRect(origin: cropOrigin, size: target)
        return scaled.cropped(to: cropRect).transformed(by: CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y))
    }
}

struct RemoveBackgroundOperation: ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage {
        try removeBackground(from: input)
    }
}

// MARK: - Background Removal

private func generateForegroundMask(for image: CIImage) throws -> CIImage {
    let handler = VNImageRequestHandler(ciImage: image)
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])
    
    guard let result = request.results?.first else {
        throw ImageOperationError.backgroundRemovalUnavailable
    }
    let maskBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    return CIImage(cvPixelBuffer: maskBuffer)
}

private func removeBackground(from image: CIImage) throws -> CIImage {
    let mask = try generateForegroundMask(for: image)
    let filter = CIFilter.blendWithMask()
    filter.inputImage = image
    filter.maskImage = mask
    filter.backgroundImage = CIImage.empty()
    guard let output = filter.outputImage else { throw ImageOperationError.exportFailed }
    return output
}
