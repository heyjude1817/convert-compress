import AppIntents

struct ResizeImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Resize Images"
    static var description = IntentDescription("Resize images by width, height, or percentage.")

    @Parameter(title: "Images")
    var images: [IntentFile]

    @Parameter(title: "Width", default: nil)
    var width: Int?

    @Parameter(title: "Height", default: nil)
    var height: Int?

    @Parameter(title: "Percentage", default: nil)
    var percentage: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Resize \(\.$images) to \(\.$width)×\(\.$height) or \(\.$percentage)%")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let operation: ImageOperation
        if let pct = percentage {
            operation = ResizeOperation(mode: .percent(Double(pct) / 100.0))
        } else {
            operation = ResizeOperation(mode: .pixels(width: width, height: height))
        }

        let results = try await IntentsPipeline.process(
            files: images,
            format: nil,
            quality: 0.9,
            operations: [operation]
        )
        return .result(value: results)
    }
}
