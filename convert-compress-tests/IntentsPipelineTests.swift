import XCTest
import AppKit
import AppIntents
import UniformTypeIdentifiers
import ImageIO
@testable import convert_compress

final class IntentsPipelineTests: XCTestCase {

    func testConvertProducesRequestedExtension() async throws {
        let input = try makeIntentFile(filename: "sample.png", size: CGSize(width: 24, height: 24))

        let results = try await IntentsPipeline.process(
            files: [input],
            format: ImageFormat(utType: .jpeg),
            quality: 0.8
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].filename, "sample.jpg")
        XCTAssertFalse(results[0].data.isEmpty)
    }

    func testResizeOperationChangesPixelWidth() async throws {
        let input = try makeIntentFile(filename: "sample.png", size: CGSize(width: 24, height: 12))

        let results = try await IntentsPipeline.process(
            files: [input],
            format: nil,
            quality: 0.9,
            operations: [ResizeOperation(mode: .pixels(width: 12, height: nil))]
        )

        XCTAssertEqual(results.count, 1)
        let pixelSize = try XCTUnwrap(pixelSize(for: results[0].data as NSData))
        XCTAssertEqual(pixelSize.width, 12)
        XCTAssertEqual(pixelSize.height, 6)
    }

    private func makeIntentFile(filename: String, size: CGSize) throws -> IntentFile {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemPink.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw XCTSkip("Failed to create intent input image")
        }

        return IntentFile(data: data, filename: filename, type: .png)
    }

    private func pixelSize(for data: NSData) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }
}
