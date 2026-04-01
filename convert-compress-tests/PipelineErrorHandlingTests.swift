import XCTest
import AppKit
@testable import convert_compress

final class PipelineErrorHandlingTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineErrorHandlingTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testMissingInputThrowsLoadFailed() {
        var pipeline = ProcessingPipeline()
        pipeline.exportDirectory = tempDir

        let missingURL = tempDir.appendingPathComponent("missing.png")
        let asset = ImageAsset(url: missingURL)

        XCTAssertThrowsError(try pipeline.run(on: asset)) { error in
            XCTAssertEqual(error as? ImageOperationError, .loadFailed)
        }
    }

    func testWritingIntoFilePathThrowsWriteFailed() throws {
        let inputURL = try makePNG(named: "input.png")
        let asset = ImageAsset(url: inputURL)

        let fileDestination = tempDir.appendingPathComponent("not_a_directory")
        try Data("blocked".utf8).write(to: fileDestination)

        var pipeline = ProcessingPipeline()
        pipeline.exportDirectory = fileDestination

        XCTAssertThrowsError(try pipeline.run(on: asset)) { error in
            guard case .writeFailed = error as? ImageOperationError else {
                return XCTFail("Expected writeFailed, got \(error)")
            }
        }
    }

    func testOutOfSpaceMapsToInsufficientDisk() {
        let error = CocoaError(.fileWriteOutOfSpace)
        let mapped = ProcessingError.from(error, assetName: "sample.png")
        XCTAssertEqual(mapped.reason, .insufficientDisk)
    }

    private func makePNG(named name: String) throws -> URL {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw XCTSkip("Failed to create PNG test data")
        }

        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
