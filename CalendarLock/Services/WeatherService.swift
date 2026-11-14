import Foundation

/// Weather from Open-Meteo (https://open-meteo.com). No account or API key needed.
/// The data is licensed CC BY 4.0, so the app credits Open-Meteo in the settings.
///
/// Note for an App Store release: Open-Meteo's free API is for non-commercial use.
/// A paid app should switch to Apple's WeatherKit or an Open-Meteo plan.
enum WeatherService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()

    /// How long a downloaded forecast is used without asking again.
    static let freshFor: TimeInterval = 3 * 3600
    /// How long an old forecast may still be shown when the network fails.
    static let usableFor: TimeInterval = 36 * 3600

    // MARK: Places

    static func searchPlaces(_ query: String) async throws -> [WeatherLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "de"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        return try parsePlaces(data)
    }

    static func parsePlaces(_ data: Data) throws -> [WeatherLocation] {
        struct Response: Decodable {
            struct Place: Decodable {
                var name: String
                var latitude: Double
                var longitude: Double
                var admin1: String?
                var country_code: String?
            }
            var results: [Place]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.results ?? []).map { place in
            let detail = [place.admin1, place.country_code].compactMap { $0 }.joined(separator: ", ")
            return WeatherLocation(
                latitude: place.latitude,
                longitude: place.longitude,
                name: detail.isEmpty ? place.name : "\(place.name) (\(detail))"
            )
        }
    }

    // MARK: Forecast

    /// Forecast for the wallpaper: uses a fresh cached forecast, otherwise downloads
    /// one, and falls back to an older cached one when the download fails.
    static func forecast(for location: WeatherLocation, days: Int = 5, now: Date = Date()) async -> [DailyForecast] {
        let cache = ForecastCache.load()
        let cacheMatches = cache?.location == location
        if let cache, cacheMatches, now.timeIntervalSince(cache.fetchedAt) < freshFor {
            return cache.days(from: now, count: days)
        }
        do {
            let fetched = try await download(for: location)
            ForecastCache(location: location, fetchedAt: now, days: fetched).save()
            return Array(fetched.filter { $0.date >= Calendar.current.startOfDay(for: now) }.prefix(days))
        } catch {
            if let cache, cacheMatches, now.timeIntervalSince(cache.fetchedAt) < usableFor {
                return cache.days(from: now, count: days)
            }
            return []
        }
    }

    private static func download(for location: WeatherLocation) async throws -> [DailyForecast] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try parseForecast(data)
    }

    static func parseForecast(_ data: Data, timeZone: TimeZone = .current) throws -> [DailyForecast] {
        struct Response: Decodable {
            struct Daily: Decodable {
                var time: [String]
                var weather_code: [Int?]
                var temperature_2m_max: [Double?]
                var temperature_2m_min: [Double?]
            }
            var daily: Daily
        }
        let daily = try JSONDecoder().decode(Response.self, from: data).daily

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        var result: [DailyForecast] = []
        for (index, day) in daily.time.enumerated() {
            guard let date = formatter.date(from: day),
                  index < daily.weather_code.count, let code = daily.weather_code[index],
                  index < daily.temperature_2m_max.count, let high = daily.temperature_2m_max[index],
                  index < daily.temperature_2m_min.count, let low = daily.temperature_2m_min[index]
            else { continue }
            result.append(DailyForecast(date: date, code: code, high: high, low: low))
        }
        return result
    }
}
