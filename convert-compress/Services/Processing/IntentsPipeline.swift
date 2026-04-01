import Foundation
import AppIntents
import UniformTypeIdentifiers

/// Headless pipeline for Shortcuts/AppIntents: processes image data without UI dependencies.
enum IntentsPipeline {
    /// Processes image files with the given configuration, returning encoded output data.
    static func process(
        files: [IntentFile],
        format: ImageFormat?,
        quality: Double,
        operations: [ImageOperation] = []
    ) async throws -> [IntentFile] {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("intents_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: "",
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: format,
            compressionPercent: quality,
            flipV: false,
            removeMetadata: false,
            removeBackground: false
        )

        var pipeline = PipelineBuilder().build(configuration: config, exportDirectory: nil)
        for op in operations {
            pipeline.add(op)
        }

        var results: [IntentFile] = []

        for file in files {
            let inputURL = tempDir.appendingPathComponent(file.filename ?? "image_\(UUID().uuidString)")
            try file.data.write(to: inputURL)

            let asset = ImageAsset(url: inputURL)
            let encoded = try pipeline.renderEncodedData(on: asset)

            let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let outputName = "\(baseName).\(ext)"

            let result = IntentFile(data: encoded.data, filename: outputName, type: encoded.uti)
            results.append(result)
        }

        return results
    }
}
