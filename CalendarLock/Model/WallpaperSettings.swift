import Foundation

/// The user's choices for how the wallpaper looks and what it shows.
struct WallpaperSettings: Codable, Hashable {
    var theme: WallpaperTheme = .night
    var artwork: Artwork = .aurora
    var textSize: TextSize = .medium
    /// Base font size in points, set with a slider. Replaces `textSize`,
    /// which is only read to carry over older settings.
    var fontPoints: Double = 15.5
    var showReminders: Bool = true
    /// How many days after today are listed under "Nächste Tage" (0...4).
    var daysAhead: Int = 3
    var hidePastEvents: Bool = true
    /// Shows the ISO calendar week ("KW 46") next to the date.
    var showWeekNumber: Bool = true
    /// Shows a small month calendar with a calendar week column.
    var showMonth: Bool = false
    /// Shows a 5-day forecast above the agenda.
    var showWeather: Bool = false
    var weatherLocation: WeatherLocation?
    /// Where the weather row starts, as a fraction of the screen height.
    /// Right below the clock is about 0.27; with Lock Screen widgets about 0.35.
    var weatherTop: Double = 0.28
    /// Size of the weather row relative to the text size.
    var weatherScale: Double = 1.1
    /// Name of the user's shortcut in the Shortcuts app that creates and sets
    /// the wallpaper; the "Jetzt setzen" button starts it.
    var shortcutName: String = "Calendar Lock"
    /// How much an own photo is darkened behind the text, 0...1.
    var photoDimming: Double = 0.5
    static let maxDaysAhead = 4
    static let weatherScaleRange: ClosedRange<Double> = 0.8...1.6
    static let fontPointsRange: ClosedRange<Double> = 10...22
    static let weatherTopRange: ClosedRange<Double> = 0.22...0.42

    /// Calendar identifiers to show. Empty means every calendar.
    var calendarIDs: Set<String> = []
    /// Reminder list identifiers to show. Empty means every list.
    var reminderListIDs: Set<String> = []

    init() {}

    /// Reads every field if present, so settings saved by an older version
    /// keep working when new options are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WallpaperSettings()
        theme = (try? c.decodeIfPresent(WallpaperTheme.self, forKey: .theme)) ?? d.theme
        artwork = (try? c.decodeIfPresent(Artwork.self, forKey: .artwork)) ?? d.artwork
        textSize = (try? c.decodeIfPresent(TextSize.self, forKey: .textSize)) ?? d.textSize
        fontPoints = (try? c.decodeIfPresent(Double.self, forKey: .fontPoints)) ?? textSize.points
        showReminders = (try? c.decodeIfPresent(Bool.self, forKey: .showReminders)) ?? d.showReminders
        daysAhead = min(max((try? c.decodeIfPresent(Int.self, forKey: .daysAhead)) ?? d.daysAhead, 0), Self.maxDaysAhead)
        hidePastEvents = (try? c.decodeIfPresent(Bool.self, forKey: .hidePastEvents)) ?? d.hidePastEvents
        showWeekNumber = (try? c.decodeIfPresent(Bool.self, forKey: .showWeekNumber)) ?? d.showWeekNumber
        showMonth = (try? c.decodeIfPresent(Bool.self, forKey: .showMonth)) ?? d.showMonth
        showWeather = (try? c.decodeIfPresent(Bool.self, forKey: .showWeather)) ?? d.showWeather
        weatherLocation = try? c.decodeIfPresent(WeatherLocation.self, forKey: .weatherLocation)
        weatherTop = (try? c.decodeIfPresent(Double.self, forKey: .weatherTop)) ?? d.weatherTop
        weatherScale = (try? c.decodeIfPresent(Double.self, forKey: .weatherScale)) ?? d.weatherScale
        shortcutName = (try? c.decodeIfPresent(String.self, forKey: .shortcutName)) ?? d.shortcutName
        photoDimming = (try? c.decodeIfPresent(Double.self, forKey: .photoDimming)) ?? d.photoDimming
        calendarIDs = (try? c.decodeIfPresent(Set<String>.self, forKey: .calendarIDs)) ?? d.calendarIDs
        reminderListIDs = (try? c.decodeIfPresent(Set<String>.self, forKey: .reminderListIDs)) ?? d.reminderListIDs
    }

    enum TextSize: String, Codable, CaseIterable, Identifiable {
        case tiny, small, medium, large
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tiny: "Sehr klein"
            case .small: "Klein"
            case .medium: "Mittel"
            case .large: "Groß"
            }
        }

        /// Base font size in points for an event title.
        var points: Double {
            switch self {
            case .tiny: 12
            case .small: 13.5
            case .medium: 15.5
            case .large: 19
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

/// The picture behind the agenda. All motifs are drawn in code from the
/// theme's colors; `.photo` uses a picture the user picked.
enum Artwork: String, Codable, CaseIterable, Identifiable {
    case plain, aurora, dunes, stars, waves, bokeh, weather, photo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: "Verlauf"
        case .aurora: "Polarlicht"
        case .dunes: "Dünen"
        case .stars: "Sterne"
        case .waves: "Wellen"
        case .bokeh: "Lichter"
        case .weather: "Wetter"
        case .photo: "Eigene Fotos"
        }
    }
}

/// Built-in color themes. Names and palettes are our own.
enum WallpaperTheme: String, Codable, CaseIterable, Identifiable {
    case night, paper, forest, dusk, ocean, sand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .night: "Nacht"
        case .paper: "Papier"
        case .forest: "Wald"
        case .dusk: "Abendrot"
        case .ocean: "Ozean"
        case .sand: "Sand"
        }
    }

    /// Top and bottom color of the background gradient.
    var background: (top: RGBColor, bottom: RGBColor) {
        switch self {
        case .night: (RGBColor(red: 0.05, green: 0.06, blue: 0.12), RGBColor(red: 0.13, green: 0.15, blue: 0.26))
        case .paper: (RGBColor(red: 0.97, green: 0.95, blue: 0.90), RGBColor(red: 0.89, green: 0.86, blue: 0.79))
        case .forest: (RGBColor(red: 0.05, green: 0.15, blue: 0.12), RGBColor(red: 0.12, green: 0.29, blue: 0.21))
        case .dusk: (RGBColor(red: 0.20, green: 0.10, blue: 0.27), RGBColor(red: 0.86, green: 0.42, blue: 0.33))
        case .ocean: (RGBColor(red: 0.02, green: 0.11, blue: 0.22), RGBColor(red: 0.04, green: 0.36, blue: 0.48))
        case .sand: (RGBColor(red: 0.93, green: 0.80, blue: 0.64), RGBColor(red: 0.76, green: 0.52, blue: 0.38))
        }
    }

    /// Colors used by the drawn motifs (light streaks, dunes, lights).
    var accents: [RGBColor] {
        switch self {
        case .night: [RGBColor(red: 0.36, green: 0.42, blue: 0.95), RGBColor(red: 0.62, green: 0.38, blue: 0.92), RGBColor(red: 0.22, green: 0.75, blue: 0.85)]
        case .paper: [RGBColor(red: 0.85, green: 0.70, blue: 0.55), RGBColor(red: 0.70, green: 0.78, blue: 0.70), RGBColor(red: 0.92, green: 0.80, blue: 0.68)]
        case .forest: [RGBColor(red: 0.25, green: 0.85, blue: 0.55), RGBColor(red: 0.55, green: 0.85, blue: 0.35), RGBColor(red: 0.15, green: 0.55, blue: 0.50)]
        case .dusk: [RGBColor(red: 1.00, green: 0.55, blue: 0.40), RGBColor(red: 0.95, green: 0.35, blue: 0.55), RGBColor(red: 1.00, green: 0.78, blue: 0.45)]
        case .ocean: [RGBColor(red: 0.20, green: 0.80, blue: 0.85), RGBColor(red: 0.30, green: 0.55, blue: 0.95), RGBColor(red: 0.45, green: 0.95, blue: 0.80)]
        case .sand: [RGBColor(red: 0.98, green: 0.88, blue: 0.70), RGBColor(red: 0.85, green: 0.60, blue: 0.45), RGBColor(red: 0.95, green: 0.72, blue: 0.55)]
        }
    }

    var isLight: Bool { self == .paper || self == .sand }

    var text: RGBColor {
        isLight ? RGBColor(red: 0.16, green: 0.12, blue: 0.10) : RGBColor(red: 0.97, green: 0.97, blue: 0.97)
    }

    /// Background of the cards, kept subtle so the clock stays readable.
    var cardOpacity: Double { isLight ? 0.5 : 0.14 }
}
