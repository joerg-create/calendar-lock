import Foundation

/// A saved place for the weather forecast.
struct WeatherLocation: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var name: String
}

/// One day of the forecast.
struct DailyForecast: Codable, Hashable, Identifiable {
    var date: Date
    /// WMO weather interpretation code, see https://open-meteo.com/en/docs
    var code: Int
    var high: Double
    var low: Double

    var id: Date { date }

    /// SF Symbol for the weather code.
    var symbolName: String {
        switch code {
        case 0: "sun.max.fill"
        case 1: "sun.min.fill"
        case 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: "cloud.rain.fill"
        case 65, 67, 82: "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

/// The last downloaded forecast, kept so the wallpaper still shows weather
/// when the morning automation runs without a network connection.
struct ForecastCache: Codable, Hashable {
    var location: WeatherLocation
    var fetchedAt: Date
    var days: [DailyForecast]

    private static let storageKey = "forecastCache.v1"

    static func load(from defaults: UserDefaults = .standard) -> ForecastCache? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ForecastCache.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// The days from `today` on, at most `count`. Empty when nothing usable is cached.
    func days(from today: Date, count: Int, calendar: Calendar = .current) -> [DailyForecast] {
        let start = calendar.startOfDay(for: today)
        return Array(days.filter { $0.date >= start }.prefix(count))
    }
}
