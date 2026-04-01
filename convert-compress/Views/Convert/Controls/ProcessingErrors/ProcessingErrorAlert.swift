import SwiftUI

struct ProcessingErrorAlert: ViewModifier {
    @Binding var errors: [ProcessingError]
    @State private var isShowingSummary = false
    @State private var isShowingDetails = false

    func body(content: Content) -> some View {
        content
            .onChange(of: errors.count) { _, newCount in
                guard newCount > 0 else {
                    isShowingSummary = false
                    isShowingDetails = false
                    return
                }
                isShowingSummary = true
            }
            .alert(String(localized: "Some images failed to process"), isPresented: $isShowingSummary) {
                Button(String(localized: "Show Details")) {
                    isShowingDetails = true
                }
                Button(String(localized: "Dismiss"), role: .cancel) {
                    errors.removeAll()
                }
            } message: {
                Text(String(format: String(localized: "%d of the images could not be processed."), errors.count))
            }
            .sheet(isPresented: $isShowingDetails, onDismiss: {
                errors.removeAll()
            }) {
                ProcessingErrorSheet(errors: errors) {
                    isShowingDetails = false
                    errors.removeAll()
                }
            }
    }
}

struct ProcessingErrorSheet: View {
    let errors: [ProcessingError]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)

                Text(String(localized: "Some images failed to process"))
                    .font(.headline)

                Text(String(format: String(localized: "%d of the images could not be processed."), errors.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(errors) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.assetName)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 200)

            Button(String(localized: "OK")) {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 380)
    }
}

extension View {
    func processingErrorAlert(errors: Binding<[ProcessingError]>) -> some View {
        modifier(ProcessingErrorAlert(errors: errors))
    }
}
