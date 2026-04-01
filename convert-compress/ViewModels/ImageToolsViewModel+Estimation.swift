import Foundation

extension ImageToolsViewModel {
    private func mergeEstimatedBytes(with map: [UUID: Int]) {
        estimatedBytes.merge(map) { _, new in new }
    }

    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let config = currentConfiguration

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let map = await TrueSizeEstimator.estimate(
                assets: visibleAssets,
                configuration: config
            )
            self.mergeEstimatedBytes(with: map)
        }
    }

    // MARK: - Batch Compression Summary

    /// Total original size of all loaded images in bytes.
    var totalOriginalBytes: Int {
        images.compactMap(\.originalFileSizeBytes).reduce(0, +)
    }

    /// Total estimated output size of all images that have estimates.
    var totalEstimatedBytes: Int {
        images.compactMap { estimatedBytes[$0.id] }.reduce(0, +)
    }

    /// Compression ratio as a fraction (0.0–1.0). Nil if no data available.
    var compressionRatio: Double? {
        let original = totalOriginalBytes
        let estimated = totalEstimatedBytes
        guard original > 0, estimated > 0 else { return nil }
        return 1.0 - (Double(estimated) / Double(original))
    }

    /// Human-readable summary like "12.3 MB → 3.4 MB (72% saved)".
    var compressionSummaryText: String? {
        let original = totalOriginalBytes
        let estimated = totalEstimatedBytes
        guard original > 0, estimated > 0 else { return nil }
        let ratio = compressionRatio ?? 0
        let percent = Int((ratio * 100).rounded())
        let originalStr = ByteCountFormatter.string(fromByteCount: Int64(original), countStyle: .file)
        let estimatedStr = ByteCountFormatter.string(fromByteCount: Int64(estimated), countStyle: .file)
        if percent > 0 {
            return "\(originalStr) → \(estimatedStr) (-\(percent)%)"
        } else if percent < 0 {
            return "\(originalStr) → \(estimatedStr) (+\(abs(percent))%)"
        }
        return "\(originalStr) → \(estimatedStr)"
    }
}


