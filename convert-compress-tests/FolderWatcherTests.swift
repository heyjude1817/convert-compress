import XCTest
@testable import convert_compress

final class FolderWatcherTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderWatcherTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDetectsNewFile() throws {
        let expectation = expectation(description: "New file detected")
        var detectedURLs: [URL] = []

        let watcher = FolderWatcher(url: tempDir) { urls in
            detectedURLs = urls
            expectation.fulfill()
        }
        watcher.start()

        // Write a test file (PNG header bytes to pass image filtering)
        let testFile = tempDir.appendingPathComponent("test.png")
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngHeader.write(to: testFile)

        // Wait for debounce + stability check (need two scans)
        waitForExpectations(timeout: 5)

        watcher.stop()
        XCTAssertFalse(detectedURLs.isEmpty)
    }

    func testIgnoresHiddenFiles() throws {
        let expectation = expectation(description: "No detection for hidden files")
        expectation.isInverted = true

        let watcher = FolderWatcher(url: tempDir) { _ in
            expectation.fulfill()
        }
        watcher.start()

        let hiddenFile = tempDir.appendingPathComponent(".hidden_file")
        try Data("test".utf8).write(to: hiddenFile)

        waitForExpectations(timeout: 3)
        watcher.stop()
    }

    func testStopPreventsCallback() throws {
        let expectation = expectation(description: "No callback after stop")
        expectation.isInverted = true

        let watcher = FolderWatcher(url: tempDir) { _ in
            expectation.fulfill()
        }
        watcher.start()
        watcher.stop()

        let testFile = tempDir.appendingPathComponent("after_stop.png")
        try Data("test".utf8).write(to: testFile)

        waitForExpectations(timeout: 3)
    }
}
