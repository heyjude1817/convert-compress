import XCTest
@testable import convert_compress

final class NamingTemplateResolverTests: XCTestCase {
    let resolver = NamingTemplateResolver()

    func testSimpleNamePlaceholder() {
        let template = NamingTemplate(isEnabled: true, pattern: "{name}")
        let context = NamingContext(originalName: "photo", index: 1, width: 1920, height: 1080, targetExtension: "jpg")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "photo")
    }

    func testSequenceNumber() {
        let template = NamingTemplate(isEnabled: true, pattern: "img_{n}")
        let context = NamingContext(originalName: "photo", index: 5, width: nil, height: nil, targetExtension: "png")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "img_5")
    }

    func testZeroPaddedSequence() {
        let template = NamingTemplate(isEnabled: true, pattern: "img_{n:03}")
        let context = NamingContext(originalName: "photo", index: 5, width: nil, height: nil, targetExtension: "png")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "img_005")
    }

    func testDimensionPlaceholders() {
        let template = NamingTemplate(isEnabled: true, pattern: "{name}_{w}x{h}")
        let context = NamingContext(originalName: "photo", index: 1, width: 1920, height: 1080, targetExtension: "jpg")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "photo_1920x1080")
    }

    func testMixedPlaceholders() {
        let template = NamingTemplate(isEnabled: true, pattern: "{name}_compressed_{n:02}")
        let context = NamingContext(originalName: "DSC_001", index: 3, width: 800, height: 600, targetExtension: "webp")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "DSC_001_compressed_03")
    }

    func testIllegalCharactersRemoved() {
        let template = NamingTemplate(isEnabled: true, pattern: "{name}/test")
        let context = NamingContext(originalName: "photo", index: 1, width: nil, height: nil, targetExtension: "jpg")
        XCTAssertFalse(resolver.resolve(template: template, context: context).contains("/"))
    }

    func testEmptyPatternFallback() {
        let template = NamingTemplate(isEnabled: true, pattern: "")
        let context = NamingContext(originalName: "photo", index: 1, width: nil, height: nil, targetExtension: "jpg")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "unnamed")
    }

    func testBatchCollisionResolution() {
        let template = NamingTemplate(isEnabled: true, pattern: "output")
        let contexts = [
            NamingContext(originalName: "a", index: 1, width: nil, height: nil, targetExtension: "jpg"),
            NamingContext(originalName: "b", index: 2, width: nil, height: nil, targetExtension: "jpg"),
            NamingContext(originalName: "c", index: 3, width: nil, height: nil, targetExtension: "jpg"),
        ]
        let results = resolver.resolveBatch(template: template, contexts: contexts)
        XCTAssertEqual(results[0], "output")
        XCTAssertEqual(results[1], "output_1")
        XCTAssertEqual(results[2], "output_2")
    }

    func testUnknownPlaceholderPreserved() {
        let template = NamingTemplate(isEnabled: true, pattern: "{name}_{unknown}")
        let context = NamingContext(originalName: "photo", index: 1, width: nil, height: nil, targetExtension: "jpg")
        XCTAssertEqual(resolver.resolve(template: template, context: context), "photo_{unknown}")
    }
}
