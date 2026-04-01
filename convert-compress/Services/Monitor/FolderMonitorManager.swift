import Foundation
import Combine

/// Singleton that coordinates multiple FolderWatcher instances and processes new images automatically.
@MainActor
final class FolderMonitorManager: ObservableObject {
    static let shared = FolderMonitorManager()

    @Published var folders: [MonitoredFolder] = []
    private var watchers: [UUID: FolderWatcher] = [:]
    private var accessingURLs: [UUID: URL] = [:]

    private init() {
        folders = FolderMonitorStore.load()
    }

    // MARK: - Lifecycle

    func restoreAndStart() {
        for folder in folders where folder.isActive {
            startWatcher(for: folder)
        }
    }

    func stopAll() {
        for (id, watcher) in watchers {
            watcher.stop()
            stopAccess(for: id)
        }
        watchers.removeAll()
    }

    // MARK: - CRUD

    func add(url: URL, presetID: UUID? = nil, outputURL: URL? = nil) {
        let folder = MonitoredFolder(url: url, presetID: presetID, outputURL: outputURL)
        folders.append(folder)
        save()
        startWatcher(for: folder)
    }

    func remove(id: UUID) {
        watchers[id]?.stop()
        watchers.removeValue(forKey: id)
        stopAccess(for: id)
        folders.removeAll { $0.id == id }
        save()
    }

    func toggleActive(id: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].isActive.toggle()
        save()
        if folders[idx].isActive {
            startWatcher(for: folders[idx])
        } else {
            watchers[id]?.stop()
            watchers.removeValue(forKey: id)
            stopAccess(for: id)
        }
    }

    func updatePreset(id: UUID, presetID: UUID?) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].presetID = presetID
        save()
    }

    func updateOutputURL(id: UUID, outputURL: URL?) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].outputBookmarkData = try? outputURL?.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        save()
    }

    // MARK: - Watcher Management

    private func startWatcher(for folder: MonitoredFolder) {
        watchers[folder.id]?.stop()
        stopAccess(for: folder.id)
        guard let url = folder.resolveURL() else { return }
        _ = url.startAccessingSecurityScopedResource()
        accessingURLs[folder.id] = url

        let watcher = FolderWatcher(url: url) { [weak self] newFiles in
            Task { @MainActor [weak self] in
                self?.processNewFiles(newFiles, folderID: folder.id, sourceURL: url)
            }
        }
        watchers[folder.id] = watcher
        watcher.start()
    }

    private func stopAccess(for id: UUID) {
        if let url = accessingURLs.removeValue(forKey: id) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Auto Processing

    private func processNewFiles(_ urls: [URL], folderID: UUID, sourceURL: URL) {
        let folder = folders.first { $0.id == folderID }
        let presetID = folder?.presetID
        let outputURL = folder?.resolveOutputURL()
        let config: ProcessingConfiguration
        if let presetID, let preset = PresetsStore.shared.load().first(where: { $0.id == presetID }) {
            config = preset.configuration
        } else {
            // Default: compress as JPEG at 80%
            config = ProcessingConfiguration(
                resizeMode: .resize,
                resizeWidth: "",
                resizeHeight: "",
                resizeLongEdge: "",
                selectedFormat: nil,
                compressionPercent: 0.8,
                flipV: false,
                removeMetadata: false,
                removeBackground: false
            )
        }

        let exportDir = outputURL ?? sourceURL.appendingPathComponent("_converted")
        let pipeline = PipelineBuilder().build(configuration: config, exportDirectory: exportDir)

        Task.detached(priority: .utility) {
            // Ensure output directory exists
            try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

            for url in urls {
                let asset = ImageAsset(url: url)
                _ = try? pipeline.run(on: asset)
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        FolderMonitorStore.save(folders)
    }
}
