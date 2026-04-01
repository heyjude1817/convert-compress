import XCTest
import AppKit
@testable import convert_compress

final class PipelineNamingTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineNamingTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDuplicateNamesGainSuffixesWithinSameOutputDirectory() throws {
        let firstDir = tempDir.appendingPathComponent("first")
        let secondDir = tempDir.appendingPathComponent("second")
        let exportDir = tempDir.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: firstDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDir, withIntermediateDirectories: true)

        let firstURL = firstDir.appendingPathComponent("photo.png")
        let secondURL = secondDir.appendingPathComponent("photo.png")
        try Data().write(to: firstURL)
        try Data().write(to: secondURL)

        let config = ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: "",
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: ImageFormat(utType: .png),
            compressionPercent: 1,
            flipV: false,
            removeMetadata: false,
            removeBackground: false,
            namingTemplate: NamingTemplate(isEnabled: true, pattern: "{name}")
        )
        let pipeline = PipelineBuilder().build(configuration: config, exportDirectory: exportDir)
        let plans = pipeline.plannedDestinationURLs(for: [ImageAsset(url: firstURL), ImageAsset(url: secondURL)])
        let names = Set(plans.values.map(\.lastPathComponent))

        XCTAssertEqual(names, ["photo.png", "photo_1.png"])
    }

    func testPreservedFolderStructureDoesNotSuffixAcrossDifferentDirectories() throws {
        let root = tempDir.appendingPathComponent("root")
        let firstDir = root.appendingPathComponent("first")
        let secondDir = root.appendingPathComponent("second")
        let exportDir = tempDir.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: firstDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDir, withIntermediateDirectories: true)

        let firstURL = firstDir.appendingPathComponent("photo.png")
        let secondURL = secondDir.appendingPathComponent("photo.png")
        try Data().write(to: firstURL)
        try Data().write(to: secondURL)

        let config = ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: "",
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: ImageFormat(utType: .png),
            compressionPercent: 1,
            flipV: false,
            removeMetadata: false,
            removeBackground: false,
            namingTemplate: NamingTemplate(isEnabled: true, pattern: "{name}")
        )
        let pipeline = PipelineBuilder().build(configuration: config, exportDirectory: exportDir, folderStructureRoot: root)
        let plans = pipeline.plannedDestinationURLs(for: [ImageAsset(url: firstURL), ImageAsset(url: secondURL)])
        let sortedPaths = plans.values.map(\.standardizedFileURL.path).sorted()

        XCTAssertEqual(sortedPaths, [
            exportDir.appendingPathComponent("first/photo.png").standardizedFileURL.path,
            exportDir.appendingPathComponent("second/photo.png").standardizedFileURL.path,
        ])
    }

    func testSequentialRunsWithSharedPlanDoNotOverwriteMonitoredBatch() throws {
        let exportDir = tempDir.appendingPathComponent("export")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let firstURL = try makePNG(named: "photo-a.png")
        let secondURL = try makePNG(named: "photo-b.png")
        let assets = [ImageAsset(url: firstURL), ImageAsset(url: secondURL)]

        let config = ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: "",
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: ImageFormat(utType: .png),
            compressionPercent: 1,
            flipV: false,
            removeMetadata: false,
            removeBackground: false,
            namingTemplate: NamingTemplate(isEnabled: true, pattern: "output")
        )
        let pipeline = PipelineBuilder().build(configuration: config, exportDirectory: exportDir)
        let plan = pipeline.plannedDestinationURLs(for: assets)

        for asset in assets {
            let destinationURL = try XCTUnwrap(plan[asset.id])
            _ = try pipeline.run(on: asset, destinationURL: destinationURL)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportDir.appendingPathComponent("output.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportDir.appendingPathComponent("output_1.png").path))
    }

    private func makePNG(named name: String) throws -> URL {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 10, height: 10)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw XCTSkip("Failed to create PNG fixture")
        }

        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
