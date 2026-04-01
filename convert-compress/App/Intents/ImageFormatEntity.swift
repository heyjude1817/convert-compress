import AppIntents
import UniformTypeIdentifiers

/// Image format options exposed to Apple Shortcuts.
enum ImageFormatEntity: String, AppEnum {
    case jpeg
    case png
    case heic
    case webp
    case avif

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Image Format")

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .jpeg: "JPEG",
        .png: "PNG",
        .heic: "HEIC",
        .webp: "WebP",
        .avif: "AVIF"
    ]

    /// Maps to the app's internal ImageFormat type.
    func toImageFormat() -> ImageFormat {
        let utType: UTType
        switch self {
        case .jpeg: utType = .jpeg
        case .png:  utType = .png
        case .heic: utType = .heic
        case .webp: utType = UTType("org.webmproject.webp") ?? .png
        case .avif: utType = UTType("public.avif") ?? .png
        }
        return ImageFormat(utType: utType)
    }
}
