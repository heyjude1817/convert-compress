import AppIntents

struct ConvertCompressShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertImageIntent(),
            phrases: [
                "Convert images with \(.applicationName)",
                "用 \(.applicationName) 转换图片"
            ],
            shortTitle: "Convert Images",
            systemImageName: "arrow.triangle.2.circlepath"
        )

        AppShortcut(
            intent: ResizeImageIntent(),
            phrases: [
                "Resize images with \(.applicationName)",
                "用 \(.applicationName) 缩放图片"
            ],
            shortTitle: "Resize Images",
            systemImageName: "arrow.up.left.and.arrow.down.right"
        )

        AppShortcut(
            intent: RemoveBackgroundIntent(),
            phrases: [
                "Remove background with \(.applicationName)",
                "用 \(.applicationName) 去除背景"
            ],
            shortTitle: "Remove Background",
            systemImageName: "person.crop.rectangle"
        )
    }
}
