import XCTest
@testable import CalendarLock

final class MonthCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    func testRollingGridStartsOnMondayOfThisWeek() throws {
        // Sunday 15 November 2026 belongs to week 46, which starts Monday 9 November.
        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 9)))
        let grid = MonthGrid.rolling(from: sunday, weeks: 5, calendar: calendar)
        XCTAssertEqual(grid.weeks.map(\.number), [46, 47, 48, 49, 50])
        let first = try XCTUnwrap(grid.weeks.first?.days.first ?? nil)
        XCTAssertEqual(calendar.component(.day, from: first), 9)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.days.count == 7 && $0.days.allSatisfy { $0 != nil } })
    }

    func testRollingGridCrossesTheYear() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 23, hour: 9)))
        let grid = MonthGrid.rolling(from: date, weeks: 3, calendar: calendar)
        XCTAssertEqual(grid.weeks.map(\.number), [52, 53, 1])
    }

    func testFontPointsCarryOverFromOldTextSize() throws {
        let old = #"{"textSize":"large"}"#
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.fontPoints, WallpaperSettings.TextSize.large.points)
        XCTAssertEqual(settings.layout, .list)
    }
}
