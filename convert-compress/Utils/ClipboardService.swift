import AppKit

enum ClipboardService {
    
    /// Copy a file URL to the clipboard. The file is copied as a file reference,
    /// preserving its format (WebP, JPEG, PNG, etc.) when pasted into apps.
    static func copyFileURL(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }
    
}

