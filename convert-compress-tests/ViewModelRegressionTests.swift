import XCTest
@testable import convert_compress

@MainActor
final class ViewModelRegressionTests: XCTestCase {

    func testApplyPresetRestoresNamingTemplate() {
        let vm = ImageToolsViewModel()
        vm.namingTemplate = NamingTemplate(isEnabled: true, pattern: "stale")

        let preset = Preset(
            configuration: ProcessingConfiguration(
                resizeMode: .resize,
                resizeWidth: "",
                resizeHeight: "",
                resizeLongEdge: "",
                selectedFormat: nil,
                compressionPercent: 0.8,
                flipV: false,
                removeMetadata: false,
                removeBackground: false,
                namingTemplate: NamingTemplate(isEnabled: true, pattern: "{name}_{n:02}")
            )
        )

        vm.applyPreset(preset)

        XCTAssertEqual(vm.namingTemplate, NamingTemplate(isEnabled: true, pattern: "{name}_{n:02}"))
    }

    func testCompressionSummaryMetricsRequireEstimatesForAllImages() {
        let vm = ImageToolsViewModel()
        let first = makeAsset(fileSize: 100)
        let second = makeAsset(fileSize: 100)
        vm.images = [first, second]
        vm.estimatedBytes = [first.id: 50]

        XCTAssertNil(vm.compressionSummaryMetrics)
        XCTAssertNil(vm.compressionSummaryText)
        XCTAssertNil(vm.compressionRatio)
    }

    func testCompressionSummaryMetricsUseFullBatch() {
        let vm = ImageToolsViewModel()
        let first = makeAsset(fileSize: 100)
        let second = makeAsset(fileSize: 300)
        vm.images = [first, second]
        vm.estimatedBytes = [first.id: 50, second.id: 150]

        let metrics = try? XCTUnwrap(vm.compressionSummaryMetrics)
        XCTAssertEqual(metrics?.imageCount, 2)
        XCTAssertEqual(metrics?.originalBytes, 400)
        XCTAssertEqual(metrics?.estimatedBytes, 200)
        XCTAssertEqual(vm.compressionRatio, 0.5)
    }

    func testCriticalMemoryPressureStillSchedulesAfterInflightDrain() {
        XCTAssertFalse(
            ImageToolsViewModel.shouldScheduleNextExportTask(
                memoryLevel: .critical,
                inFlightTaskCount: 2
            )
        )
        XCTAssertTrue(
            ImageToolsViewModel.shouldScheduleNextExportTask(
                memoryLevel: .critical,
                inFlightTaskCount: 0
            )
        )
        XCTAssertTrue(
            ImageToolsViewModel.shouldScheduleNextExportTask(
                memoryLevel: .warning,
                inFlightTaskCount: 3
            )
        )
    }

    private func makeAsset(fileSize: Int) -> ImageAsset {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        var asset = ImageAsset(url: url)
        asset.originalFileSizeBytes = fileSize
        return asset
    }
}
