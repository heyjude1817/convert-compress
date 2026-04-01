import Foundation

/// Persists monitored folder configurations to UserDefaults.
enum FolderMonitorStore {
    private static let key = "\(AppConstants.bundleIdentifier).monitored_folders"

    static func load() -> [MonitoredFolder] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([MonitoredFolder].self, from: data)) ?? []
    }

    static func save(_ folders: [MonitoredFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
