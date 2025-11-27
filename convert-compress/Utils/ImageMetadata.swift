import Foundation
import ImageIO

struct ImageMetadata {
    static func pixelSize(for data: Data) -> CGSize? {
        if let src = CGImageSourceCreateWithData(data as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let wNum = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let hNum = props[kCGImagePropertyPixelHeight] as? NSNumber {
            return CGSize(width: CGFloat(truncating: wNum), height: CGFloat(truncating: hNum))
        }
        return nil
    }
}


