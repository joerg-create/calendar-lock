import XCTest
@testable import CalendarLock

final class UpcomingDaysTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ offset: Int, events count: Int) -> DayAgenda {
        let date = base.addingTimeInterval(Double(offset) * 86_400)
        let events = (0..<count).map { index in
            AgendaItem(id: "\(offset)-\(index)", kind: .event, title: "E\(offset)-\(index)",
                       start: date.addingTimeInterval(Double(index) * 3600), end: nil,
                       isAllDay: false, isOverdue: false, color: .gray)
        }
        return DayAgenda(date: date, events: events, reminders: [])
    }

    func testRowsSkipEmptyDaysAndMarkFirstRowOfEachDay() {
        let result = AgendaLayout.upcomingRows([day(1, events: 2), day(2, events: 0), day(3, events: 1)], maxRows: 10)
        XCTAssertEqual(result.rows.map(\.item.id), ["1-0", "1-1", "3-0"])
        XCTAssertEqual(result.rows.map(\.startsDay), [true, false, true])
        XCTAssertEqual(result.hidden, 0)
    }

    func testRowsAreCutWithOverflowLine() {
        let result = AgendaLayout.upcomingRows([day(1, events: 3), day(2, events: 3)], maxRows: 4)
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.hidden, 3)
    }

    func testSplitGivesTodayWhatItNeedsUpToHalf() {
        XCTAssertEqual(AgendaLayout.splitRows(total: 10, todayCount: 2, upcomingCount: 6).today, 2)
        XCTAssertEqual(AgendaLayout.splitRows(total: 10, todayCount: 2, upcomingCount: 6).upcoming, 8)
        XCTAssertEqual(AgendaLayout.splitRows(total: 10, todayCount: 9, upcomingCount: 6).today, 5)
        XCTAssertEqual(AgendaLayout.splitRows(total: 10, todayCount: 0, upcomingCount: 6).today, 1)
        XCTAssertEqual(AgendaLayout.splitRows(total: 10, todayCount: 4, upcomingCount: 0).today, 10)
    }

    func testDaysAheadDefaultsToThreeForOlderSettings() throws {
        let old = #"{"theme":"night","showTomorrow":true}"#
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.daysAhead, 3)
    }

    func testSplitKeepsRoomForOneItemOnEachSide() {
        // With several items on both sides, each side needs 2 rows: one item
        // and "+ N weitere". A single row could only show "+ N weitere".
        let four = AgendaLayout.splitRows(total: 4, todayCount: 3, upcomingCount: 9)
        XCTAssertEqual(four.today, 2)
        XCTAssertEqual(four.upcoming, 2)
    }

    func testSplitLeavesOutComingDaysWhenThereIsNoRoom() {
        let result = AgendaLayout.splitRows(total: 3, todayCount: 3, upcomingCount: 9)
        XCTAssertEqual(result.today, 3)
        XCTAssertEqual(result.upcoming, 0)
        // One event on each side fits in two rows.
        let single = AgendaLayout.splitRows(total: 2, todayCount: 1, upcomingCount: 1)
        XCTAssertEqual(single.today, 1)
        XCTAssertEqual(single.upcoming, 1)
    }
}
