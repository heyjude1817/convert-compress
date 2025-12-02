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

// Load a CIImage while applying EXIF/TIFF orientation so pixels are normalized to 'up'
func loadCIImageApplyingOrientation(from url: URL) throws -> CIImage {
    let options: [CIImageOption: Any] = [
        .applyOrientationProperty: true
    ]
    if let ci = CIImage(contentsOf: url, options: options) { return ci }
    throw ImageOperationError.loadFailed
}

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
        let originalExtent = input.extent
        let targetSize = ResizeMath.targetSize(for: originalExtent.size, input: resizeInput, noUpscale: true)
        
        let scaleX = targetSize.width / originalExtent.width
        let scaleY = targetSize.height / originalExtent.height
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        return output
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
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        return output
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
        let extent = input.extent
        let currentWidth = extent.width
        let currentHeight = extent.height
        
        let targetW = CGFloat(targetWidth)
        let targetH = CGFloat(targetHeight)
        
        // Calculate scale to COVER the target dimensions (not fit within)
        let scaleX = targetW / currentWidth
        let scaleY = targetH / currentHeight
        let scale = max(scaleX, scaleY) // Use max to cover, not min to fit
        
        // Resize to cover the target dimensions
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(scale)
        lanczos.aspectRatio = 1.0
        guard let scaled = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        
        let scaledExtent = scaled.extent
        
        // Now center crop to exact target dimensions
        // Round x and y to avoid sub-pixel positioning that can cause off-by-one errors
        let x = ((scaledExtent.width - targetW) / 2).rounded(.toNearestOrEven)
        let y = ((scaledExtent.height - targetH) / 2).rounded(.toNearestOrEven)
        
        let cropRect = CGRect(x: x, y: y, width: targetW, height: targetH)
        return scaled.cropped(to: cropRect)
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
