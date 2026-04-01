import Foundation

/// Template for batch file renaming during export.
///
/// Supported placeholders:
/// - `{name}` — original filename without extension
/// - `{n}` — sequence number (1, 2, 3...)
/// - `{n:03}` — zero-padded sequence number (001, 002, 003...)
/// - `{date}` — current date (yyyy-MM-dd)
/// - `{datetime}` — current date and time (yyyy-MM-dd_HH-mm-ss)
/// - `{w}` — image width in pixels
/// - `{h}` — image height in pixels
struct NamingTemplate: Codable, Equatable {
    var isEnabled: Bool
    var pattern: String

    init(isEnabled: Bool = false, pattern: String = "{name}") {
        self.isEnabled = isEnabled
        self.pattern = pattern
    }
}
