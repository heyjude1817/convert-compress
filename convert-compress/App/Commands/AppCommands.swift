import SwiftUI

struct AppCommands: Commands {
    @AppStorage(PreferencesStore.revealExportInFinder) private var revealExportInFinder = true
    
    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Toggle(isOn: $revealExportInFinder) {
                Label("Select Images after Export", systemImage: "folder")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

