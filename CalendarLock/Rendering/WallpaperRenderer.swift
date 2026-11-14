import SwiftUI
import UIKit

enum WallpaperError: Error, LocalizedError, CustomLocalizedStringResourceConvertible {
    case noCalendarAccess
    case renderingFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noCalendarAccess:
            "Calendar Lock hat keinen Zugriff auf deinen Kalender. Öffne die App einmal und erlaube den Zugriff."
        case .renderingFailed:
            "Das Hintergrundbild konnte nicht erstellt werden."
        }
    }

    var errorDescription: String? { String(localized: localizedStringResource) }
}

/// Collects the agenda and turns it into a wallpaper image at screen resolution.
enum WallpaperBuilder {
    @MainActor
    static func makeImage(settings: WallpaperSettings, now: Date = Date()) async throws -> UIImage {
        let service = CalendarService.shared
        guard service.hasEventAccess else { throw WallpaperError.noCalendarAccess }

        let today = await service.agenda(for: now, settings: settings, includeReminders: true, now: now)
        var tomorrow: DayAgenda?
        if settings.showTomorrow, let next = Calendar.current.date(byAdding: .day, value: 1, to: now) {
            tomorrow = await service.agenda(for: next, settings: settings, includeReminders: false, now: now)
        }

        guard let image = WallpaperRenderer.image(today: today, tomorrow: tomorrow, settings: settings) else {
            throw WallpaperError.renderingFailed
        }
        return image
    }

    @MainActor
    static func makePNG(settings: WallpaperSettings, now: Date = Date()) async throws -> Data {
        let image = try await makeImage(settings: settings, now: now)
        guard let data = image.pngData() else { throw WallpaperError.renderingFailed }
        return data
    }
}

@MainActor
enum WallpaperRenderer {
    /// The screen size in points and its scale. `nativeBounds` is always portrait.
    static var screen: (size: CGSize, scale: CGFloat) {
        let screen = UIScreen.main
        let scale = screen.nativeScale
        let size = CGSize(width: screen.nativeBounds.width / scale, height: screen.nativeBounds.height / scale)
        return (size, scale)
    }

    static func image(today: DayAgenda, tomorrow: DayAgenda?, settings: WallpaperSettings) -> UIImage? {
        let (size, scale) = screen
        let view = WallpaperView(today: today, tomorrow: tomorrow, settings: settings, size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
