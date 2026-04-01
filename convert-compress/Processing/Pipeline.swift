import Foundation
import CoreImage
import UniformTypeIdentifiers

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var removeMetadata: Bool = false
    var exportDirectory: URL? = nil
    var folderStructureRoot: URL? = nil
    var finalFormat: ImageFormat? = nil
    var compressionPercent: Double? = nil
    var namingTemplate: NamingTemplate? = nil

    mutating func add(_ op: ImageOperation) {
        operations.append(op)
    }

    func run(on asset: ImageAsset) throws -> ImageAsset {
        let destinationURL = plannedDestinationURL(for: asset)
        return try run(on: asset, destinationURL: destinationURL)
    }

    func run(on asset: ImageAsset, destinationURL: URL) throws -> ImageAsset {
        let result = asset
        let currentURL = result.originalURL

        // Start security-scoped access if needed
        guard let sourceToken = SandboxAccessToken(url: currentURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { sourceToken.stop() }

        // Process and encode once according to selected format and compression
        let encoded = try processAndEncode(from: currentURL)
        let plan = destinationPlan(for: result, uti: encoded.uti, destinationURL: destinationURL)

        // Write into destination directory and atomically replace/move into place
        let destParent = plan.directory
        do {
            if !FileManager.default.fileExists(atPath: destParent.path) {
                try FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
            }
        } catch {
            throw Self.mapWriteError(error)
        }
        guard let accessToken = SandboxAccessManager.shared.beginAccess(for: destParent) else {
            throw ImageOperationError.permissionDenied
        }
        defer { accessToken.stop() }

        let tempFilename = plan.filenameStem + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + plan.fileExtension
        let tempInDest = destParent.appendingPathComponent(tempFilename)
        do {
            try encoded.data.write(to: tempInDest, options: [.atomic])
            if FileManager.default.fileExists(atPath: plan.url.path) {
                _ = try FileManager.default.replaceItemAt(plan.url, withItemAt: tempInDest, backupItemName: nil, options: [])
            } else {
                try FileManager.default.moveItem(at: tempInDest, to: plan.url)
            }
        } catch {
            throw Self.mapWriteError(error)
        }

        var updated = result
        updated.workingURL = plan.url
        updated.isEdited = true
        return updated
    }

    // Apply operations and return a temporary file URL for the processed image without committing to a destination
    func renderTemporaryURL(on asset: ImageAsset) throws -> URL {
        // processAndEncode handles its own sandbox token
        let encoded = try processAndEncode(from: asset.originalURL)
        let tempDir = FileManager.default.temporaryDirectory
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)
        let base = asset.originalURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = tempDir.appendingPathComponent(tempFilename)
        try encoded.data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    // Apply operations and return encoded data with the chosen UTType for clipboard or sharing
    func renderEncodedData(on asset: ImageAsset) throws -> (data: Data, uti: UTType) {
        return try processAndEncode(from: asset.originalURL)
    }

    // MARK: - DRY helper
    private func processAndEncode(from originalURL: URL) throws -> (data: Data, uti: UTType) {
        guard let token = SandboxAccessToken(url: originalURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { token.stop() }

        var ci = try loadCIImage(from: originalURL, operations: operations)
        for op in operations {
            ci = try op.transformed(ci)
        }
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: originalURL)
        let q = compressionPercent.map { max(min($0, 1.0), 0.01) }
        let encoded = try ImageExporter.encodeToData(ciImage: ci,
                                                     originalURL: originalURL,
                                                     format: chosenFormat,
                                                     compressionQuality: q,
                                                     stripMetadata: removeMetadata)
        return encoded
    }

    /// Compute the destination URL without performing any processing, matching the naming behavior of `run(on:)`.
    func plannedDestinationURL(for asset: ImageAsset) -> URL {
        plannedDestinationURLs(for: [asset])[asset.id] ?? fallbackDestinationURL(for: asset)
    }

    func plannedDestinationURLs(for assets: [ImageAsset]) -> [UUID: URL] {
        guard !assets.isEmpty else { return [:] }

        struct Entry {
            let assetID: UUID
            let directory: URL
            let stem: String
            let ext: String
        }

        var entries: [Entry] = []
        entries.reserveCapacity(assets.count)

        for (index, asset) in assets.enumerated() {
            let currentURL = asset.originalURL
            let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
            let finalUTI = ImageExporter.decideUTTypeForExport(originalURL: currentURL, requestedFormat: chosenFormat)
            let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: finalUTI)
            let directory = destinationDirectory(for: asset)
            let stem = filenameStem(for: asset, ext: ext, batchIndex: index)
            entries.append(Entry(assetID: asset.id, directory: directory, stem: stem, ext: ext))
        }

        var usedURLs: Set<String> = []
        var duplicateCounts: [String: Int] = [:]
        var results: [UUID: URL] = [:]

        for entry in entries {
            let baseKey = entry.directory.standardizedFileURL.path + "/" + entry.stem + "." + entry.ext
            var stem = entry.stem
            var candidate = entry.directory.appendingPathComponent(stem).appendingPathExtension(entry.ext)

            while usedURLs.contains(candidate.standardizedFileURL.path) {
                let next = (duplicateCounts[baseKey] ?? 0) + 1
                duplicateCounts[baseKey] = next
                stem = "\(entry.stem)_\(next)"
                candidate = entry.directory.appendingPathComponent(stem).appendingPathExtension(entry.ext)
            }

            usedURLs.insert(candidate.standardizedFileURL.path)
            results[entry.assetID] = candidate
        }

        return results
    }

    private func fallbackDestinationURL(for asset: ImageAsset) -> URL {
        let currentURL = asset.originalURL
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
        let finalUTI = ImageExporter.decideUTTypeForExport(originalURL: currentURL, requestedFormat: chosenFormat)
        let plan = destinationPlan(for: asset, uti: finalUTI)
        return plan.url
    }

    private static func mapWriteError(_ error: Error) -> ImageOperationError {
        if let opError = error as? ImageOperationError {
            return opError
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return .insufficientDisk
        }

        return .writeFailed(error.localizedDescription)
    }
}

private extension ProcessingPipeline {
    struct DestinationPlan {
        let url: URL
        let directory: URL
        let filenameStem: String
        let fileExtension: String
    }

    func destinationPlan(for asset: ImageAsset, uti: UTType, batchIndex: Int = 0, destinationURL: URL? = nil) -> DestinationPlan {
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: uti)
        let resolvedDestination = destinationURL ?? destinationDirectory(for: asset)
            .appendingPathComponent(filenameStem(for: asset, ext: ext, batchIndex: batchIndex))
            .appendingPathExtension(ext)
        let directory = resolvedDestination.deletingLastPathComponent()
        let stem = resolvedDestination.deletingPathExtension().lastPathComponent
        return DestinationPlan(url: resolvedDestination, directory: directory, filenameStem: stem, fileExtension: ext)
    }

    func filenameStem(for asset: ImageAsset, ext: String, batchIndex: Int) -> String {
        let originalBase = asset.originalURL.deletingPathExtension().lastPathComponent
        guard let template = namingTemplate, template.isEnabled else {
            return originalBase
        }

        let context = NamingContext(
            originalName: originalBase,
            index: batchIndex + 1,
            width: asset.originalPixelSize.map { Int($0.width) },
            height: asset.originalPixelSize.map { Int($0.height) },
            targetExtension: ext
        )
        return NamingTemplateResolver().resolve(template: template, context: context)
    }

    func destinationDirectory(for asset: ImageAsset) -> URL {
        let currentURL = asset.originalURL
        let tempDirPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isTempSource = currentURL.standardizedFileURL.path.hasPrefix(tempDirPath)

        if let exportDir = exportDirectory {
            if let root = folderStructureRoot {
                let assetDir = currentURL.deletingLastPathComponent().standardizedFileURL
                let sourcePath = root.standardizedFileURL.path
                let assetPath = assetDir.path
                let relative = assetPath.hasPrefix(sourcePath)
                    ? String(assetPath.dropFirst(sourcePath.count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    : ""
                return relative.isEmpty ? exportDir : exportDir.appendingPathComponent(relative)
            }
            return exportDir
        }

        if isTempSource {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }

        return currentURL.deletingLastPathComponent()
    }
}
