import SwiftUI

struct BottomBar: View {
    @EnvironmentObject private var vm: ImageToolsViewModel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                PillButton(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Text(String(localized: "Clear"))
                }
                .help(String(localized: "Clear all images"))
                .disabled(vm.images.isEmpty)

                if let summary = vm.compressionSummaryText {
                    Text(summary)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryApplyControl()

            HStack(spacing: 8) {
                ExportDirectoryControl(
                    directory: $vm.exportDirectory,
                    sourceDirectory: vm.sourceDirectory,
                    hasActiveImages: !vm.images.isEmpty
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(Theme.Animations.spring(), value: vm.isExportingToSource)
        }
        .animation(Theme.Animations.spring(), value: vm.compressionSummaryText)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
