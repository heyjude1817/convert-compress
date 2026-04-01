import Foundation

/// Describes a per-image processing failure without interrupting the batch.
struct ProcessingError: Identifiable {
    let id = UUID()
    let assetName: String
    let reason: Reason

    enum Reason {
        case loadFailed
        case encodeFailed
        case writeFailed(String)
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
            return String(localized: "Failed to write file: \(detail)")
        case .permissionDenied:
            return String(localized: "Permission denied")
        case .unknown(let detail):
            return detail
        }
    }
}
