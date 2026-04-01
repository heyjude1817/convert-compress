import AppIntents

struct ConvertImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Images"
    static var description = IntentDescription("Convert images to a different format with quality control.")

    @Parameter(title: "Images")
    var images: [IntentFile]

    @Parameter(title: "Format")
    var format: ImageFormatEntity

    @Parameter(title: "Quality", default: 85, controlStyle: .slider, inclusiveRange: (1, 100))
    var quality: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$images) to \(\.$format) at \(\.$quality)% quality")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let results = try await IntentsPipeline.process(
            files: images,
            format: format.toImageFormat(),
            quality: Double(quality) / 100.0
        )
        return .result(value: results)
    }
}
