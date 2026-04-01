import SwiftUI
import AppKit

struct FolderMonitorSettingsView: View {
    @ObservedObject private var manager = FolderMonitorManager.shared
    @State private var presets: [Preset] = PresetsStore.shared.load()
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Folder Monitoring"))
                        .font(.headline)
                    Text(String(localized: "Automatically process new images added to monitored folders."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: addFolder) {
                    Label(String(localized: "Add Folder"), systemImage: "plus")
                }
            }

            if manager.folders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No folders monitored"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.folders) { folder in
                            FolderMonitorRow(
                                folder: folder,
                                presets: presets,
                                onToggle: { manager.toggleActive(id: folder.id) },
                                onPresetChange: { presetID in manager.updatePreset(id: folder.id, presetID: presetID) },
                                onOutputChange: { outputURL in manager.updateOutputURL(id: folder.id, outputURL: outputURL) },
                                onRemove: { manager.remove(id: folder.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            HStack {
                Spacer()
                Button(String(localized: "Done")) { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a folder to monitor for new images")
        if panel.runModal() == .OK, let url = panel.url {
            manager.add(url: url)
        }
    }
}

struct FolderMonitorRow: View {
    let folder: MonitoredFolder
    let presets: [Preset]
    let onToggle: () -> Void
    let onPresetChange: (UUID?) -> Void
    let onOutputChange: (URL?) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { folder.isActive },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(folderName)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.head)

                    if let path = folderPath {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: Binding(
                    get: { folder.presetID },
                    set: { onPresetChange($0) }
                )) {
                    Text(String(localized: "Default")).tag(nil as UUID?)
                    ForEach(presets) { preset in
                        Text(preset.displayName).tag(preset.id as UUID?)
                    }
                }
                .frame(width: 130)
                .labelsHidden()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(String(localized: "Output"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(outputLabel)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(String(localized: "Choose Output Folder")) {
                    chooseOutputFolder()
                }
                .buttonStyle(.bordered)
                if folder.resolveOutputURL() != nil {
                    Button(String(localized: "Reset Output")) {
                        onOutputChange(nil)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var folderName: String {
        folder.resolveURL()?.lastPathComponent ?? String(localized: "Unknown")
    }

    private var folderPath: String? {
        folder.resolveURL()?.deletingLastPathComponent().path
    }

    private var outputLabel: String {
        folder.resolveOutputURL()?.path ?? String(localized: "Same Folder")
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Select output location for processed images")
        panel.directoryURL = folder.resolveOutputURL() ?? folder.resolveURL()

        if panel.runModal() == .OK, let url = panel.url {
            onOutputChange(url)
        }
    }
}
