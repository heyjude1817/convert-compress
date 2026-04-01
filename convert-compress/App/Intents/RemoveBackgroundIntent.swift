import AppIntents

struct RemoveBackgroundIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Image Background"
    static var description = IntentDescription("Remove the background from images using AI.")

    @Parameter(title: "Images")
    var images: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Remove background from \(\.$images)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let results = try await IntentsPipeline.process(
            files: images,
            format: ImageFormat(utType: .png),
            quality: 1.0,
            operations: [RemoveBackgroundOperation()]
        )
        return .result(value: results)
    }
}
