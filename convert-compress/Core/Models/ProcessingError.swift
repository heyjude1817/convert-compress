import Foundation

/// Describes a per-image processing failure without interrupting the batch.
struct ProcessingError: Identifiable, Error {
    let id = UUID()
    let assetName: String
    let reason: Reason

    enum Reason: Equatable {
        case loadFailed
        case encodeFailed
        case writeFailed(String)
        case insufficientDisk
        case permissionDenied
        case unknown(String)
    }

    var localizedDescription: String {
        switch reason {
        case .loadFailed:
            return String(localized: "Failed to load image")
        case .encodeFailed:
            return String(localized: "Failed to encode image")
        case .writeFailed(let detail):
            return String(format: String(localized: "Failed to write file: %@"), detail)
        case .insufficientDisk:
            return String(localized: "Not enough disk space")
        case .permissionDenied:
            return String(localized: "Permission denied")
        case .unknown(let detail):
            return detail
        }
    }

    static func from(_ error: Error, assetName: String) -> ProcessingError {
        if let opError = error as? ImageOperationError {
            switch opError {
            case .loadFailed:
                return ProcessingError(assetName: assetName, reason: .loadFailed)
            case .exportFailed:
                return ProcessingError(assetName: assetName, reason: .encodeFailed)
            case .backgroundRemovalUnavailable:
                return ProcessingError(assetName: assetName, reason: .unknown(error.localizedDescription))
            case .permissionDenied:
                return ProcessingError(assetName: assetName, reason: .permissionDenied)
            case .writeFailed(let detail):
                return ProcessingError(assetName: assetName, reason: .writeFailed(detail))
            case .insufficientDisk:
                return ProcessingError(assetName: assetName, reason: .insufficientDisk)
            }
        }

        if let cocoaError = error as? CocoaError {
            switch cocoaError.code {
            case .fileWriteOutOfSpace:
                return ProcessingError(assetName: assetName, reason: .insufficientDisk)
            case .fileWriteNoPermission:
                return ProcessingError(assetName: assetName, reason: .permissionDenied)
            case .fileWriteUnknown,
                 .fileWriteInvalidFileName,
                 .fileWriteFileExists,
                 .fileWriteInapplicableStringEncoding,
                 .fileWriteUnsupportedScheme,
                 .fileWriteVolumeReadOnly:
                return ProcessingError(assetName: assetName, reason: .writeFailed(cocoaError.localizedDescription))
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return ProcessingError(assetName: assetName, reason: .insufficientDisk)
        }

        return ProcessingError(assetName: assetName, reason: .unknown(error.localizedDescription))
    }
}
