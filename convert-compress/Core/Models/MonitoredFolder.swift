import Foundation

/// Represents a directory being monitored for automatic image processing.
struct MonitoredFolder: Codable, Identifiable {
    let id: UUID
    var bookmarkData: Data
    var presetID: UUID?
    var outputBookmarkData: Data?
    var isActive: Bool

    init(url: URL, presetID: UUID? = nil, outputURL: URL? = nil, isActive: Bool = true) {
        self.id = UUID()
        self.bookmarkData = (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
        self.presetID = presetID
        self.outputBookmarkData = try? outputURL?.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        self.isActive = isActive
    }

    /// Resolves the bookmark data back to a URL, starting security-scoped access.
    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            // Bookmark is stale — caller should re-save
            return nil
        }
        return url
    }

    /// Resolves the output directory bookmark, if set.
    func resolveOutputURL() -> URL? {
        guard let data = outputBookmarkData else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
