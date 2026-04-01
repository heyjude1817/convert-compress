import Foundation

extension ImageToolsViewModel {
    struct CompressionSummaryMetrics: Equatable {
        let imageCount: Int
        let originalBytes: Int
        let estimatedBytes: Int

        var ratio: Double {
            1.0 - (Double(estimatedBytes) / Double(originalBytes))
        }
    }

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

    var compressionSummaryMetrics: CompressionSummaryMetrics? {
        guard !images.isEmpty else { return nil }

        var originals = 0
        var estimates = 0

        for image in images {
            guard let originalBytes = image.originalFileSizeBytes,
                  let estimatedBytes = estimatedBytes[image.id] else {
                return nil
            }
            originals += originalBytes
            estimates += estimatedBytes
        }

        guard originals > 0, estimates > 0 else { return nil }
        return CompressionSummaryMetrics(
            imageCount: images.count,
            originalBytes: originals,
            estimatedBytes: estimates
        )
    }

    /// Compression ratio as a fraction (0.0–1.0). Nil if no data available.
    var compressionRatio: Double? {
        compressionSummaryMetrics?.ratio
    }

    /// Human-readable summary like "12.3 MB → 3.4 MB (72% saved)".
    var compressionSummaryText: String? {
        guard let metrics = compressionSummaryMetrics else { return nil }
        let ratio = metrics.ratio
        let percent = Int((ratio * 100).rounded())
        let count = metrics.imageCount
        let originalStr = ByteCountFormatter.string(fromByteCount: Int64(metrics.originalBytes), countStyle: .file)
        let estimatedStr = ByteCountFormatter.string(fromByteCount: Int64(metrics.estimatedBytes), countStyle: .file)
        let delta = percent > 0 ? "-\(percent)%" : percent < 0 ? "+\(abs(percent))%" : "0%"
        let format = count == 1
            ? String(localized: "1 image · %@ → %@ (%@)")
            : String(localized: "%d images · %@ → %@ (%@)")
        if percent > 0 {
            return count == 1
                ? String(format: format, originalStr, estimatedStr, delta)
                : String(format: format, count, originalStr, estimatedStr, delta)
        }
        if percent < 0 {
            return count == 1
                ? String(format: format, originalStr, estimatedStr, delta)
                : String(format: format, count, originalStr, estimatedStr, delta)
        }
        return count == 1
            ? String(format: format, originalStr, estimatedStr, delta)
            : String(format: format, count, originalStr, estimatedStr, delta)
    }
}
