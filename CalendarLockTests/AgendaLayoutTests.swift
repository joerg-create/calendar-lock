import XCTest
@testable import CalendarLock

final class AgendaLayoutTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ id: String, start: TimeInterval?, end: TimeInterval? = nil, allDay: Bool = false,
                      overdue: Bool = false, kind: AgendaItem.Kind = .event) -> AgendaItem {
        AgendaItem(
            id: id, kind: kind, title: id,
            start: start.map { base.addingTimeInterval($0) },
            end: end.map { base.addingTimeInterval($0) },
            isAllDay: allDay, isOverdue: overdue, color: .gray
        )
    }

    func testEventsSortAllDayFirstThenByStart() {
        let events = [item("b", start: 7200), item("allday", start: 0, allDay: true), item("a", start: 3600)]
        XCTAssertEqual(AgendaLayout.sortedEvents(events).map(\.id), ["allday", "a", "b"])
    }

    func testRemindersSortOverdueFirstUndatedLast() {
        let reminders = [
            item("undated", start: nil, kind: .reminder),
            item("later", start: 7200, kind: .reminder),
            item("overdue", start: -86400, overdue: true, kind: .reminder),
            item("soon", start: 3600, kind: .reminder),
        ]
        XCTAssertEqual(AgendaLayout.sortedReminders(reminders).map(\.id), ["overdue", "soon", "later", "undated"])
    }

    func testUpcomingDropsFinishedEventsButKeepsAllDay() {
        let events = [
            item("done", start: 0, end: 1800),
            item("running", start: 1800, end: 5400),
            item("allday", start: 0, end: 86400, allDay: true),
        ]
        let now = base.addingTimeInterval(3600)
        XCTAssertEqual(AgendaLayout.upcoming(events, now: now).map(\.id), ["running", "allday"])
    }

    func testFitKeepsEverythingWhenThereIsRoom() {
        let items = (0..<3).map { item("\($0)", start: Double($0)) }
        let result = AgendaLayout.fit(items, maxRows: 3)
        XCTAssertEqual(result.visible.count, 3)
        XCTAssertEqual(result.hidden, 0)
    }

    func testFitReservesARowForTheOverflowLine() {
        let items = (0..<6).map { item("\($0)", start: Double($0)) }
        let result = AgendaLayout.fit(items, maxRows: 4)
        XCTAssertEqual(result.visible.map(\.id), ["0", "1", "2"])
        XCTAssertEqual(result.hidden, 3)
    }

    func testSettingsRoundTripThroughUserDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AgendaLayoutTests"))
        defaults.removePersistentDomain(forName: "AgendaLayoutTests")
        var settings = WallpaperSettings()
        settings.theme = .forest
        settings.calendarIDs = ["abc"]
        settings.save(to: defaults)
        XCTAssertEqual(WallpaperSettings.load(from: defaults), settings)
    }
}
