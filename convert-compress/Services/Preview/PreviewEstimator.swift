import Foundation

struct PreviewInfo {
    let targetPixelSize: CGSize?
    let estimatedOutputBytes: Int?
}

struct PreviewEstimator {
    // Keep only target pixel size calculation for layout; do not estimate bytes here.
    func estimate(for asset: ImageAsset,
                  resizeMode: ResizeMode,
                  resizeWidth: String,
                  resizeHeight: String,
                  resizeLongEdge: String,
                  compressionPercent: Double,
                  selectedFormat: ImageFormat?) -> PreviewInfo {
        let baseSize: CGSize? = asset.originalPixelSize
        let isVector = VectorImageSupport.isVectorImage(asset.originalURL)
        let targetSize: CGSize? = {
            guard let base = baseSize else { return CGSize(width: 0, height: 0) }
            
            let input: ResizeInput
            if let longEdge = Int(resizeLongEdge) {
                input = .longEdge(longEdge)
            } else {
                input = .pixels(width: Int(resizeWidth), height: Int(resizeHeight))
            }
            
            let hasResizeInput = Int(resizeLongEdge) != nil || Int(resizeWidth) != nil || Int(resizeHeight) != nil
            let effectiveBase = (isVector && hasResizeInput) ? VectorImageSupport.generousSize(for: base) : base
            var size = ResizeMath.targetSize(for: effectiveBase, input: input, noUpscale: true)
            
            // In crop mode with both dimensions, show target crop size
            if resizeMode == .crop, let w = Int(resizeWidth), let h = Int(resizeHeight) {
                size = CGSize(width: w, height: h)
            }
            
            // If format enforces square sizes in preview, clamp to min side
            if let selected = selectedFormat, ImageIOCapabilities.shared.sizeRestrictions(forUTType: selected.utType) != nil {
                let side = min(size.width, size.height)
                size = CGSize(width: side, height: side)
            }
            return size
        }()
        // Report no bytes here; UI will show "--- KB" until background estimator fills it.
        return PreviewInfo(targetPixelSize: targetSize, estimatedOutputBytes: nil)
    }
}

