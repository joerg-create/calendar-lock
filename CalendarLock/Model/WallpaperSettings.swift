import Foundation

/// The user's choices for how the wallpaper looks and what it shows.
struct WallpaperSettings: Codable, Hashable {
    var theme: WallpaperTheme = .night
    var textSize: TextSize = .medium
    var showReminders: Bool = true
    var showTomorrow: Bool = false
    var hidePastEvents: Bool = true
    /// Calendar identifiers to show. Empty means every calendar.
    var calendarIDs: Set<String> = []
    /// Reminder list identifiers to show. Empty means every list.
    var reminderListIDs: Set<String> = []

    enum TextSize: String, Codable, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }

        var label: String {
            switch self {
            case .small: "Klein"
            case .medium: "Mittel"
            case .large: "Groß"
            }
        }

        /// Base font size in points for an event title.
        var points: Double {
            switch self {
            case .small: 15
            case .medium: 18
            case .large: 22
            }
        }
    }
}

extension WallpaperSettings {
    private static let storageKey = "wallpaperSettings.v1"

    static func load(from defaults: UserDefaults = .standard) -> WallpaperSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(WallpaperSettings.self, from: data)
        else { return WallpaperSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Built-in color themes. Names and palettes are our own.
enum WallpaperTheme: String, Codable, CaseIterable, Identifiable {
    case night, paper, forest, dusk

    var id: String { rawValue }

    var label: String {
        switch self {
        case .night: "Nacht"
        case .paper: "Papier"
        case .forest: "Wald"
        case .dusk: "Abendrot"
        }
    }

    /// Top and bottom color of the background gradient.
    var background: (top: RGBColor, bottom: RGBColor) {
        switch self {
        case .night: (RGBColor(red: 0.06, green: 0.07, blue: 0.12), RGBColor(red: 0.13, green: 0.15, blue: 0.24))
        case .paper: (RGBColor(red: 0.96, green: 0.94, blue: 0.89), RGBColor(red: 0.90, green: 0.87, blue: 0.80))
        case .forest: (RGBColor(red: 0.07, green: 0.18, blue: 0.14), RGBColor(red: 0.13, green: 0.30, blue: 0.22))
        case .dusk: (RGBColor(red: 0.27, green: 0.13, blue: 0.30), RGBColor(red: 0.85, green: 0.42, blue: 0.33))
        }
    }

    var text: RGBColor {
        switch self {
        case .paper: RGBColor(red: 0.15, green: 0.13, blue: 0.11)
        default: RGBColor(red: 0.97, green: 0.97, blue: 0.97)
        }
    }

    /// Background of the card behind the list, kept subtle so the clock stays readable.
    var cardOpacity: Double {
        switch self {
        case .paper: 0.55
        default: 0.14
        }
    }
}
