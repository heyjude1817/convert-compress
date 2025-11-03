import Foundation
import Combine

extension ImageToolsViewModel {
    // Setup persistence - automatically saves when values change
    func setupPersistenceObservation() {
        let defaults = UserDefaults.standard
        
        $exportDirectory.dropFirst().sink { dir in
            if let dir { defaults.set(dir.path, forKey: PersistenceKeys.exportDirectory) }
            else { defaults.removeObject(forKey: PersistenceKeys.exportDirectory) }
        }.store(in: &cancellables)
        
        $resizeMode.dropFirst().sink { mode in
            defaults.set(mode == .resize ? "resize" : "crop", forKey: PersistenceKeys.resizeMode)
        }.store(in: &cancellables)
        
        $resizeWidth.dropFirst().sink { width in
            defaults.set(width, forKey: PersistenceKeys.resizeWidth)
        }.store(in: &cancellables)
        
        $resizeHeight.dropFirst().sink { height in
            defaults.set(height, forKey: PersistenceKeys.resizeHeight)
        }.store(in: &cancellables)
        
        $resizeLongEdge.dropFirst().sink { longEdge in
            defaults.set(longEdge, forKey: PersistenceKeys.resizeLongEdge)
        }.store(in: &cancellables)
        
        $selectedFormat.dropFirst().sink { [weak self] newFormat in
            defaults.set(newFormat?.id, forKey: PersistenceKeys.selectedFormat)
            self?.onSelectedFormatChanged(newFormat)
        }.store(in: &cancellables)
        
        $recentFormats.dropFirst().sink { formats in
            defaults.set(formats.map { $0.id }, forKey: PersistenceKeys.recentFormats)
        }.store(in: &cancellables)
        
        $compressionPercent.dropFirst().sink { percent in
            defaults.set(percent, forKey: PersistenceKeys.compressionPercent)
        }.store(in: &cancellables)
        
        $flipV.dropFirst().sink { flip in
            defaults.set(flip, forKey: PersistenceKeys.flipV)
        }.store(in: &cancellables)
        
        $removeBackground.dropFirst().sink { remove in
            defaults.set(remove, forKey: PersistenceKeys.removeBackground)
        }.store(in: &cancellables)
        
        $removeMetadata.dropFirst().sink { remove in
            defaults.set(remove, forKey: PersistenceKeys.removeMetadata)
        }.store(in: &cancellables)
    }
    
    private enum PersistenceKeys {
        static let exportDirectory = "convert-compress.export_directory.v1"
        static let resizeMode = "convert-compress.resize_mode.v1"
        static let resizeWidth = "convert-compress.resize_width.v1"
        static let resizeHeight = "convert-compress.resize_height.v1"
        static let resizeLongEdge = "convert-compress.resize_long_edge.v1"
        static let selectedFormat = "convert-compress.selected_format.v1"
        static let recentFormats = "convert-compress.recent_formats.v1"
        static let compressionPercent = "convert-compress.compression_percent.v1"
        static let flipV = "convert-compress.flip_v.v1"
        static let removeBackground = "convert-compress.remove_background.v1"
        static let removeMetadata = "convert-compress.remove_metadata.v1"
    }

    func loadPersistedState() {
        let defaults = UserDefaults.standard
        
        // Export directory
        if let exportPath = defaults.string(forKey: PersistenceKeys.exportDirectory) {
            exportDirectory = URL(fileURLWithPath: exportPath)
        }
        
        // Resize settings
        if let modeRaw = defaults.string(forKey: PersistenceKeys.resizeMode) {
            resizeMode = (modeRaw == "resize") ? .resize : .crop
        }
        if let width = defaults.string(forKey: PersistenceKeys.resizeWidth) {
            resizeWidth = width
        }
        if let height = defaults.string(forKey: PersistenceKeys.resizeHeight) {
            resizeHeight = height
        }
        if let longEdge = defaults.string(forKey: PersistenceKeys.resizeLongEdge) {
            resizeLongEdge = longEdge
        }
        
        // Format settings
        if let selRaw = defaults.string(forKey: PersistenceKeys.selectedFormat),
           let fmt = ImageIOCapabilities.shared.format(forIdentifier: selRaw) {
            let caps = ImageIOCapabilities.shared
            if caps.supportsWriting(utType: fmt.utType) {
                selectedFormat = fmt
            }
        }
        if let raw = defaults.array(forKey: PersistenceKeys.recentFormats) as? [String] {
            let mapped = raw.compactMap { ImageIOCapabilities.shared.format(forIdentifier: $0) }
            if !mapped.isEmpty {
                recentFormats = Array(mapped.prefix(3))
            }
        }
        
        // Transform settings
        if defaults.object(forKey: PersistenceKeys.compressionPercent) != nil {
            compressionPercent = defaults.double(forKey: PersistenceKeys.compressionPercent)
        }
        if defaults.object(forKey: PersistenceKeys.flipV) != nil {
            flipV = defaults.bool(forKey: PersistenceKeys.flipV)
        }
        if defaults.object(forKey: PersistenceKeys.removeBackground) != nil {
            removeBackground = defaults.bool(forKey: PersistenceKeys.removeBackground)
        }
        if defaults.object(forKey: PersistenceKeys.removeMetadata) != nil {
            removeMetadata = defaults.bool(forKey: PersistenceKeys.removeMetadata)
        }
    }
    
}


