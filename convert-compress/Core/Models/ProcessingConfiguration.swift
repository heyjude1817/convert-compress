import Foundation

/// Encapsulates all settings for image processing operations
struct ProcessingConfiguration: Codable {
    let resizeMode: ResizeMode
    let resizeWidth: String
    let resizeHeight: String
    let resizeLongEdge: String
    let selectedFormat: ImageFormat?
    let compressionPercent: Double
    let flipV: Bool
    let removeMetadata: Bool
    let removeBackground: Bool
    let namingTemplate: NamingTemplate?

    init(resizeMode: ResizeMode, resizeWidth: String, resizeHeight: String, resizeLongEdge: String, selectedFormat: ImageFormat?, compressionPercent: Double, flipV: Bool, removeMetadata: Bool, removeBackground: Bool, namingTemplate: NamingTemplate? = nil) {
        self.resizeMode = resizeMode
        self.resizeWidth = resizeWidth
        self.resizeHeight = resizeHeight
        self.resizeLongEdge = resizeLongEdge
        self.selectedFormat = selectedFormat
        self.compressionPercent = compressionPercent
        self.flipV = flipV
        self.removeMetadata = removeMetadata
        self.removeBackground = removeBackground
        self.namingTemplate = namingTemplate
    }
}

