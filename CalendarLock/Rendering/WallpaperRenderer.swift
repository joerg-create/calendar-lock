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

/// Collects agenda, weather and month and turns them into a wallpaper image
/// at screen resolution.
enum WallpaperBuilder {
    @MainActor
    static func makeContent(settings: WallpaperSettings, now: Date = Date()) async throws -> WallpaperContent {
        let service = CalendarService.shared
        guard service.hasEventAccess else { throw WallpaperError.noCalendarAccess }

        var content = WallpaperContent(
            now: now,
            today: await service.agenda(for: now, settings: settings, includeReminders: true, now: now)
        )
        if settings.showTomorrow, let next = Calendar.current.date(byAdding: .day, value: 1, to: now) {
            content.tomorrow = await service.agenda(for: next, settings: settings, includeReminders: false, now: now)
        }
        if settings.showMonth {
            content.month = MonthGrid.make(for: now)
            content.eventDays = service.daysWithEvents(inMonthOf: now, settings: settings)
        }
        if settings.showWeather, let location = settings.weatherLocation {
            content.forecast = await WeatherService.forecast(for: location, days: 5, now: now)
        }
        if settings.artwork == .photo {
            content.photo = PhotoStore.load()
        }
        return content
    }

    @MainActor
    static func makeImage(settings: WallpaperSettings, now: Date = Date()) async throws -> UIImage {
        let content = try await makeContent(settings: settings, now: now)
        guard let image = WallpaperRenderer.image(content: content, settings: settings) else {
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

    static func image(content: WallpaperContent, settings: WallpaperSettings) -> UIImage? {
        let (size, scale) = screen
        let view = WallpaperView(content: content, settings: settings, size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
