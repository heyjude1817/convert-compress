import Foundation
import CoreImage

struct TrueSizeEstimator {
    static func estimate(
        assets: [ImageAsset],
        configuration: ProcessingConfiguration
    ) async -> [UUID: Int] {
        guard !assets.isEmpty else { return [:] }

        let maxConcurrent = 4
        var results: [UUID: Int] = [:]
        var index = 0

        while index < assets.count {
            let end = min(index + maxConcurrent, assets.count)
            let slice = Array(assets[index..<end])
            await withTaskGroup(of: (UUID, Int)?.self) { group in
                for asset in slice {
                    group.addTask(priority: .utility) {
                        estimateOne(asset: asset, configuration: configuration)
                    }
                }
                for await item in group {
                    if let (id, bytes) = item { results[id] = bytes }
                }
            }
            index = end
            await Task.yield()
        }

        return results
    }

    private static func estimateOne(
        asset: ImageAsset,
        configuration: ProcessingConfiguration
    ) -> (UUID, Int)? {
        do {
            let pipeline = PipelineBuilder().build(configuration: configuration, exportDirectory: nil)

            guard let token = SandboxAccessToken(url: asset.originalURL) else { return nil }
            defer { token.stop() }

            var ci = try loadCIImage(from: asset.originalURL, operations: pipeline.operations)
            for op in pipeline.operations {
                ci = try op.transformed(ci)
            }

            let encoded = try ImageExporter.encodeToData(
                ciImage: ci,
                originalURL: asset.originalURL,
                format: pipeline.finalFormat,
                compressionQuality: pipeline.compressionPercent.map { max(min($0, 1.0), 0.01) },
                stripMetadata: pipeline.removeMetadata
            )
            return (asset.id, encoded.data.count)
        } catch {
            return nil
        }
    }
}
