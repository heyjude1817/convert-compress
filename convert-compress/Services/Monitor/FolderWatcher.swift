import Foundation
import Dispatch

/// Watches a single directory for newly added image files using DispatchSource.
final class FolderWatcher {
    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private let queue: DispatchQueue
    private var knownFiles: Set<String> = []
    private var pendingFiles: [String: Int64] = [:] // path → last known size
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 1.0
    let onNewFiles: ([URL]) -> Void

    init(url: URL, onNewFiles: @escaping ([URL]) -> Void) {
        self.url = url
        self.onNewFiles = onNewFiles
        self.queue = DispatchQueue(label: "com.convertcompress.folderwatcher.\(url.lastPathComponent)", qos: .utility)
        self.knownFiles = Self.currentFiles(in: url)
    }

    func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
        src.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        src.setCancelHandler {
            close(fd)
        }
        self.source = src
        src.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        source?.cancel()
        source = nil
    }

    // MARK: - Scanning

    private func scheduleScan() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.scan()
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    private func scan() {
        let currentFiles = Self.currentFiles(in: url)
        let newPaths = currentFiles.subtracting(knownFiles)

        guard !newPaths.isEmpty else { return }

        // File stability check: ensure files have finished writing
        // by comparing sizes between scans
        var stableURLs: [URL] = []
        for path in newPaths {
            let fileURL = url.appendingPathComponent(path)
            let currentSize = Self.fileSize(at: fileURL)
            if let previousSize = pendingFiles[path], previousSize == currentSize, currentSize > 0 {
                // Size stable — file is fully written
                stableURLs.append(fileURL)
                pendingFiles.removeValue(forKey: path)
            } else {
                // First seen or still writing — record and check next scan
                pendingFiles[path] = currentSize
            }
        }

        // Add stable files to known set
        for fileURL in stableURLs {
            knownFiles.insert(fileURL.lastPathComponent)
        }

        // Filter to supported image files
        let imageURLs = stableURLs.flatMap { IngestionCoordinator.expandToSupportedImageURLs(from: $0) }

        if !imageURLs.isEmpty {
            onNewFiles(imageURLs)
        }

        // If there are still pending files, schedule another scan
        if !pendingFiles.isEmpty {
            scheduleScan()
        }
    }

    // MARK: - Helpers

    private static func currentFiles(in directory: URL) -> Set<String> {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.path) else { return [] }
        return Set(contents.filter { !$0.hasPrefix(".") })
    }

    private static func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    deinit {
        stop()
    }
}
