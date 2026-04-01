import XCTest
@testable import convert_compress

final class MonitoredFolderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonitoredFolderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCodableRoundTripPreservesBookmarksAndFlags() throws {
        let outputURL = tempDir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let folder = MonitoredFolder(url: tempDir, presetID: UUID(), outputURL: outputURL, isActive: false)
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(MonitoredFolder.self, from: data)

        XCTAssertEqual(decoded.id, folder.id)
        XCTAssertEqual(decoded.presetID, folder.presetID)
        XCTAssertEqual(decoded.isActive, folder.isActive)
        XCTAssertFalse(decoded.bookmarkData.isEmpty)
        XCTAssertFalse(decoded.outputBookmarkData?.isEmpty ?? true)
    }

    func testResolvedURLsMatchOriginalPaths() throws {
        let outputURL = tempDir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let folder = MonitoredFolder(url: tempDir, outputURL: outputURL)

        XCTAssertEqual(folder.resolveURL()?.standardizedFileURL.path, tempDir.standardizedFileURL.path)
        XCTAssertEqual(folder.resolveOutputURL()?.standardizedFileURL.path, outputURL.standardizedFileURL.path)
    }
}
