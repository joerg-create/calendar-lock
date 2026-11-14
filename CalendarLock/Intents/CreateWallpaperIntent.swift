import AppIntents
import UniformTypeIdentifiers

/// Shortcuts action that returns today's wallpaper as an image.
///
/// Apps cannot change the wallpaper themselves on iOS. A Shortcuts automation
/// runs this action every morning and passes the image to the built-in
/// "Set Wallpaper" ("Hintergrundbild festlegen") action.
struct CreateWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Kalender-Hintergrund erstellen"
    static let description = IntentDescription(
        "Erstellt ein Hintergrundbild mit deinen heutigen Terminen und Erinnerungen. Gib das Ergebnis an „Hintergrundbild festlegen“ weiter.",
        categoryName: "Hintergrund"
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let png = try await WallpaperBuilder.makePNG(settings: WallpaperSettings.load())
        let file = IntentFile(data: png, filename: "calendar-lock.png", type: .png)
        return .result(value: file)
    }
}

struct CalendarLockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateWallpaperIntent(),
            phrases: [
                "Erstelle Hintergrund mit \(.applicationName)",
                "\(.applicationName) Hintergrund erstellen",
            ],
            shortTitle: "Hintergrund erstellen",
            systemImageName: "calendar"
        )
    }
}
