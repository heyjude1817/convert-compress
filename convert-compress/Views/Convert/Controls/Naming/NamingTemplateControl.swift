import SwiftUI

struct NamingTemplateControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @State private var showPopover = false

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            ZStack {
                Circle()
                    .fill(vm.namingTemplate.isEnabled ? Color.accentColor : Theme.Colors.iconBackground)
                Image(systemName: "textformat.abc")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.namingTemplate.isEnabled ? Color.white : Theme.Colors.iconForeground)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: controlHeight)
        .aspectRatio(1, contentMode: .fit)
        .help(String(localized: "Rename"))
        .popover(isPresented: $showPopover) {
            NamingTemplatePopover(template: $vm.namingTemplate, previewName: previewName)
        }
    }

    private var previewName: String? {
        guard let firstImage = vm.images.first else { return nil }
        let context = NamingContext(
            originalName: firstImage.originalURL.deletingPathExtension().lastPathComponent,
            index: 1,
            width: firstImage.originalPixelSize.map { Int($0.width) },
            height: firstImage.originalPixelSize.map { Int($0.height) },
            targetExtension: vm.selectedFormat?.preferredFilenameExtension ?? "jpg"
        )
        let ext = vm.selectedFormat?.preferredFilenameExtension ?? firstImage.originalURL.pathExtension
        let stem = NamingTemplateResolver().resolve(template: vm.namingTemplate, context: context)
        return "\(stem).\(ext)"
    }
}

struct NamingTemplatePopover: View {
    @Binding var template: NamingTemplate
    let previewName: String?

    private let quickTemplates: [(String, String)] = [
        ("{name}_compressed", "name_compressed"),
        ("{date}_{n:03}", "2026-04-01_001"),
        ("product_{n:03}", "product_001"),
        ("{name}_{w}x{h}", "name_1920x1080"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $template.isEnabled) {
                Text(String(localized: "Rename Files"))
                    .font(.headline)
            }

            if template.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(String(localized: "Pattern"), text: $template.pattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    // Quick templates
                    HStack(spacing: 6) {
                        ForEach(quickTemplates, id: \.0) { pattern, _ in
                            Button(pattern) {
                                template.pattern = pattern
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .buttonStyle(.bordered)
                        }
                    }

                    // Preview
                    if let preview = previewName {
                        HStack(spacing: 4) {
                            Text(String(localized: "Preview:"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(preview)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Placeholder help
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Placeholders:"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Group {
                            Text("{name} — ") + Text(String(localized: "original filename"))
                            Text("{n} — ") + Text(String(localized: "sequence number"))
                            Text("{n:03} — ") + Text(String(localized: "zero-padded number"))
                            Text("{date} — ") + Text(String(localized: "current date"))
                            Text("{w} {h} — ") + Text(String(localized: "dimensions"))
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Theme.Animations.spring(), value: template.isEnabled)
        .padding(16)
        .frame(width: 320)
    }
}
