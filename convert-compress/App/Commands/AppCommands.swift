import SwiftUI

extension Notification.Name {
    static let showFolderMonitorSettings = Notification.Name("showFolderMonitorSettings")
}

struct AppCommands: Commands {
    @AppStorage(PreferencesStore.revealExportInFinder) private var revealExportInFinder = true
    @AppStorage(PreferencesStore.keepFolderStructure) private var keepFolderStructure = false

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Toggle(isOn: $revealExportInFinder) {
                Label("Select Images after Export", systemImage: "folder")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Toggle(isOn: $keepFolderStructure) {
                Label("Keep Folder Structure", systemImage: "folder.badge.gearshape")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            Button {
                NotificationCenter.default.post(name: .showFolderMonitorSettings, object: nil)
            } label: {
                Label("Folder Monitoring…", systemImage: "folder.badge.questionmark")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}

