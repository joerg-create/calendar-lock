import XCTest
@testable import CalendarLock

final class MonthGridTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testWeekNumbersFollowISO8601() {
        XCTAssertEqual(MonthGrid.weekNumber(of: date(2026, 11, 14), calendar: calendar), 46)
        // 1 January 2027 is a Friday, so it still belongs to week 53 of 2026.
        XCTAssertEqual(MonthGrid.weekNumber(of: date(2027, 1, 1), calendar: calendar), 53)
        XCTAssertEqual(MonthGrid.weekNumber(of: date(2027, 1, 4), calendar: calendar), 1)
    }

    func testNovember2026Layout() {
        let grid = MonthGrid.make(for: date(2026, 11, 14), calendar: calendar)
        // 1 November 2026 is a Sunday: six leading blanks in the first week.
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertEqual(grid.weeks.first?.number, 44)
        XCTAssertEqual(grid.weeks.first?.days.prefix(6).allSatisfy { $0 == nil }, true)
        XCTAssertNotNil(grid.weeks.first?.days[6])
        XCTAssertEqual(grid.weeks.last?.number, 49)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.days.count == 7 })
        XCTAssertEqual(grid.weeks.flatMap(\.days).compactMap { $0 }.count, 30)
    }

    func testMonthStartingOnMondayHasNoLeadingBlanks() {
        // 1 June 2026 is a Monday.
        let grid = MonthGrid.make(for: date(2026, 6, 10), calendar: calendar)
        XCTAssertNotNil(grid.weeks.first?.days[0])
        XCTAssertEqual(grid.weeks.first?.number, 23)
    }
}

final class WeatherParsingTests: XCTestCase {
    func testParsesDailyForecast() throws {
        let json = """
        {"daily":{"time":["2026-11-14","2026-11-15","2026-11-16"],
        "weather_code":[3,61,null],
        "temperature_2m_max":[9.4,7.1,6.0],
        "temperature_2m_min":[3.2,2.5,1.0]}}
        """
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let days = try WeatherService.parseForecast(Data(json.utf8), timeZone: berlin)
        XCTAssertEqual(days.count, 2, "Days with missing values are skipped")
        XCTAssertEqual(days[0].code, 3)
        XCTAssertEqual(days[0].high, 9.4)
        XCTAssertEqual(days[1].symbolName, "cloud.rain.fill")
    }

    func testParsesPlaces() throws {
        let json = """
        {"results":[{"name":"Hamburg","latitude":53.55,"longitude":9.99,"admin1":"Hamburg","country_code":"DE"},
        {"name":"Hamburg","latitude":42.71,"longitude":-78.82,"country_code":"US"}]}
        """
        let places = try WeatherService.parsePlaces(Data(json.utf8))
        XCTAssertEqual(places.map(\.name), ["Hamburg (Hamburg, DE)", "Hamburg (US)"])
        XCTAssertEqual(try WeatherService.parsePlaces(Data("{}".utf8)), [])
    }

    func testCacheReturnsDaysFromToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (-1..<6).map { offset in
            DailyForecast(date: calendar.date(byAdding: .day, value: offset, to: today)!, code: 0, high: 1, low: 0)
        }
        let cache = ForecastCache(location: WeatherLocation(latitude: 0, longitude: 0, name: "X"), fetchedAt: Date(), days: days)
        let result = cache.days(from: Date(), count: 5)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result.first?.date, today)
    }
}

final class SettingsMigrationTests: XCTestCase {
    func testOldSettingsWithoutNewKeysStillLoad() throws {
        let old = #"{"theme":"forest","textSize":"large","showReminders":false,"showTomorrow":true,"hidePastEvents":true,"calendarIDs":["a"],"reminderListIDs":[]}"#
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.theme, .forest)
        XCTAssertEqual(settings.textSize, .large)
        XCTAssertFalse(settings.showReminders)
        XCTAssertEqual(settings.calendarIDs, ["a"])
        XCTAssertEqual(settings.artwork, WallpaperSettings().artwork)
        XCTAssertTrue(settings.showWeekNumber)
        XCTAssertNil(settings.weatherLocation)
    }
}
