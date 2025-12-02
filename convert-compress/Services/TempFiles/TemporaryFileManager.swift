import Foundation

/// Cleans up temp files from the app's container temp directory on launch.
enum TemporaryFileManager {
    
    /// Clean up accumulated temp files from the container temp directory.
    /// Call this on app launch to prevent buildup.
    static func cleanupTempFiles() {
        DispatchQueue.global(qos: .utility).async {
            let containerTempDir = FileManager.default.temporaryDirectory
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: containerTempDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else { return }
            
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
